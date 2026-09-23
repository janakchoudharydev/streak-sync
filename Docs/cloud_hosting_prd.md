# Product Requirement Document (PRD): Cloud Server Hosting & Cross-Platform Synchronization

## Executive Summary
This document specifies the technical architecture, hosting strategy, database provisioning, and implementation roadmap to deploy the `InlitX/streak` synchronization backend to a high-availability cloud infrastructure at **$0.00/month (100% Free Forever)**. 

Once deployed, the cloud server will bridge macOS and Android devices (and future iOS/web clients), enabling seamless, non-blocking, offline-first bidirectional habit synchronization anywhere in the world over WiFi, 4G, and 5G networks.

---

## 1. Problem Statement & Motivation

### Current State
* The backend currently operates locally on macOS at `http://localhost:3000` via in-memory storage (`MemoryDatabase`).
* Android mobile devices cannot communicate with the Mac's `localhost` loopback interface.
* When the Mac is asleep, shut down, or disconnected from the local home network, mobile habits cannot sync.
* In-memory storage does not persist across backend restarts.

### Desired State
* A globally accessible, secure HTTPS backend (`https://streak-sync-[app].vercel.app`) running 24/7 with zero maintenance.
* Persistent cloud database storing user accounts, habit records, completions, notes, todos, and categories.
* Automatic, non-blocking synchronization between the macOS desktop app and the Moto G52 (Android) mobile app.
* 100% preservation of offline-first operation: habits are recorded locally with zero latency, and queued changes sync in the background when connectivity is present.

---

## 2. Architecture & Data Flow

```mermaid
graph TD
    subgraph Client Tier
        MAC[macOS Desktop App\nHive LocalStore]
        AND[Android Moto G52\nHive LocalStore]
    end

    subgraph Cloud Edge (Vercel Serverless)
        CDN[Global Vercel Edge CDN\nAutomatic HTTPS / SSL]
        API[Express Serverless Functions\n/api/auth/* & /api/sync]
        LWW[LWW Conflict Resolution\n& Completion Merging Engine]
    end

    subgraph Database Tier (Supabase / Neon)
        POOL[PgBouncer Connection Pooler]
        PG[(PostgreSQL Database\nusers, habits, notes, todos)]
    end

    MAC -- "1. Background REST (Bearer JWT)" --> CDN
    AND -- "1. Background REST (Bearer JWT)" --> CDN
    CDN --> API
    API --> LWW
    LWW --> POOL
    POOL --> PG
    PG -- "2. Returning Server Deltas" --> POOL
    POOL --> API
    API -- "3. HTTP 200 OK + Sync Checkpoint" --> CDN
    CDN --> MAC
    CDN --> AND
```

### Data Synchronization Protocol
1. **Local Action**: User checks off habit on Android or Mac. `LocalStore` immediately updates Hive storage (0ms UI latency) and enqueues a mutation in `SyncQueue`.
2. **Background Dispatch**: `SyncWorker` detects network connectivity and triggers a POST request to `/api/sync` containing pending mutations and client checkpoint (`last_synced_at`).
3. **Conflict Resolution**: The cloud engine executes Last-Write-Wins (LWW) per entity and merges daily habit completions via set unions.
4. **Absorption**: The client receives newly modified records from other devices, writes them to `LocalStore` with `isSyncAbsorption = true` (preventing feedback loops), and updates the local checkpoint.

---

## 3. Cloud Infrastructure & Platform Evaluation

To guarantee the **$0.00/month** hosting constraint while ensuring enterprise-grade reliability, four free hosting architectures were benchmarked:

| Criterion | Architecture A: Vercel + Supabase (Recommended) | Architecture B: Render.com Free | Architecture C: Fly.io Free | Architecture D: Railway Free |
| :--- | :--- | :--- | :--- | :--- |
| **Compute Cost** | **$0.00/month** (100k invocations/day) | $0.00/month | Free allowance expired | $5 trial credit only |
| **Database Cost** | **$0.00/month** (500MB PostgreSQL) | $0.00 (expires in 30 days) | 3GB volume free | Paid only |
| **Cold Starts** | Instant (~100ms serverless) | **30-50s sleep delay** | Instant | Instant |
| **SSL / HTTPS** | Automatic wildcard SSL | Automatic SSL | Manual config | Automatic |
| **Uptime / Sleep** | **24/7 Always Active** | Spins down after 15m idle | Active | Active |
| **Maintenance** | Zero maintenance | Needs keepalive cron | High Docker overhead | Medium |

### Selected Architecture: Vercel Serverless + Supabase PostgreSQL
* **Compute (Vercel)**:
  * Serverless functions scale to zero when idle and execute in ~100ms when invoked.
  * Generous free tier: 100 GB-hours of compute, 1,000,000 function invocations per month (sufficient for >10,000 daily sync cycles).
* **Database (Supabase)**:
  * Managed PostgreSQL 15+ database with built-in connection pooling (`PgBouncer`).
  * 500 MB database storage (stores ~500,000 habit records with full completion history).
  * Automated daily backups.

---

## 4. Database Schema Specification

The cloud database runs PostgreSQL with UUID primary keys and ISO-8601 UTC timestamp tracking.

```sql
-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Core Entities Table (Habits, Notes, Todos, Categories, Focus)
CREATE TABLE IF NOT EXISTS sync_entities (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type VARCHAR(64) NOT NULL,
    id VARCHAR(128) NOT NULL,
    data JSONB NOT NULL,
    client_updated_at TIMESTAMPTZ NOT NULL,
    server_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (user_id, entity_type, id)
);

CREATE INDEX IF NOT EXISTS idx_sync_entities_lookup 
ON sync_entities (user_id, server_updated_at);
```

---

## 5. Implementation Roadmap (Step-by-Step)

```mermaid
gantt
    title Cloud Server Hosting Roadmap
    dateFormat  X
    axisFormat  Day %d
    section Step 1: DB Provisioning
    Create Supabase Project & Execute Schema        :active, s1, 0, 1
    section Step 2: Backend DB Driver
    Add pg Pool Driver to backend/src/db/index.ts   :crit, s2, 1, 2
    section Step 3: Vercel Deployment
    Deploy to Vercel via CLI or GitHub             :s3, 2, 3
    Configure Environment Variables (DATABASE_URL) :s4, 3, 4
    section Step 4: Client Cloud URL Update
    Set defaultServerUrl in client auth_service     :s5, 4, 5
    Cross-Device Verification (Mac <-> Android)     :s6, 5, 6
```

### Step 1: Provision Free Database (Supabase)
1. Sign in to [Supabase](https://supabase.com) (Free Tier, 0 credit card needed).
2. Create project: `streak-cloud-sync`.
3. Open **SQL Editor** and paste the provided schema from [`backend/src/db/schema.sql`](file:///Users/janakchoudhary/Documents/Devops/Streak%20For%20Mac/backend/src/db/schema.sql).
4. Copy the connection string:
   `postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres` (or Transaction Pooler on port 6543).

### Step 2: Implement PostgreSQL Driver in Backend
Currently, `backend/src/db/index.ts` uses `MemoryDatabase`. We add `PostgresDatabase` using the `pg` client:
* If `DATABASE_URL` is provided in environment variables: connect to PostgreSQL with SSL.
* If `DATABASE_URL` is omitted: fallback cleanly to `MemoryDatabase` (for unit tests and offline testing).

### Step 3: Deploy Backend to Vercel
1. Install Vercel CLI or link GitHub repository:
   ```bash
   npx vercel
   ```
2. Configure project root to `backend/`.
3. Set environment variables in Vercel Dashboard:
   - `DATABASE_URL`: Your Supabase connection string.
   - `JWT_SECRET`: A 64-character random secure key.
   - `NODE_ENV`: `production`.
4. Deploy! Vercel provides a live URL:
   `https://streak-sync-production.vercel.app`

### Step 4: Connect Client Applications
1. In `client/lib/core/sync/auth_service.dart`, update:
   ```dart
   static const _defaultServerUrl = 'https://streak-sync-production.vercel.app';
   ```
2. The user registers on Mac or Android via **Settings → Cloud Sync**.
3. The user logs in on the other device with the same email and password.
4. Habits instantly sync between Mac and Android!

---

## 6. Security, Authentication & Data Isolation

* **Transport Security**: Strictly enforced HTTPS/TLS 1.3 on all client-server communications. Plain HTTP is rejected.
* **Authentication**: Industry-standard **bcrypt** (salt factor 10) password hashing. Passwords are never stored or logged in plain text.
* **Session Tokens**: Stateless JSON Web Tokens (JWT) signed with HMAC-SHA256, 30-day validity, automatically stored in `FlutterSecureStorage` (iOS Keychain / Android EncryptedSharedPreferences).
* **Multi-Tenant Data Isolation**: Every database query is strictly scoped by `user_id` extracted from the cryptographically verified JWT (`WHERE user_id = $1`). Users cannot query or mutate records belonging to any other user.
* **No Telemetry / Privacy**: Zero third-party trackers, zero analytical beacons, and zero telemetry.

---

## 7. Operational Health & Free Tier Longevity

### Supabase Pausing Protection
Supabase pauses free projects if they experience 7 consecutive days of zero traffic. Because Streak's mobile and desktop apps check in during active habit tracking, normal usage prevents pausing. To provide 100% guarantee against pausing even during vacations:
* A scheduled health check ping can be set to call `/api/health` once every 3 days.

### Zero-Cost Budget Verification
* **Vercel Hobby Plan**: $0.00/month (100k invocations/day). Average usage for 2 devices = ~30-50 syncs/day. (0.05% of limit).
* **Supabase Free Plan**: $0.00/month (500MB DB). 1 habit with 365 daily completions = ~4KB. 100 habits = ~400KB. 500MB accommodates years of data.
* **Total Monthly Bill**: **$0.00 / month forever**.

---

## 8. Cross-Device Acceptance Test Matrix

| Test ID | Test Scenario | Execution Steps | Expected Outcome |
| :--- | :--- | :--- | :--- |
| **SYNC-01** | Initial Account Creation | Register `user@example.com` on Moto G52. | 201 Created; JWT stored securely; account visible in UI. |
| **SYNC-02** | Mac Desktop Pairing | Log in with `user@example.com` on Mac. | 200 OK; Mac immediately downloads habits from cloud. |
| **SYNC-03** | Real-Time Habit Completion | Check off "Breakfast ☕" on Moto G52. | Within 2 seconds, Mac shows "Breakfast ☕" checked off. |
| **SYNC-04** | Offline Resilience | Put Moto G52 on Airplane Mode; complete habit; reconnect. | Mutation enqueued offline, flushed automatically on reconnect. |
| **SYNC-05** | Conflict Resolution | Change habit title on Mac at 14:00; edit color on phone at 14:01. | LWW retains latest edits; both devices converge to identical state. |
