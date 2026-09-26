# Streak for Mac and Mobile Sync 🚀

<div align="center">

<img src="client/assets/banner.png" alt="Streak for Mac and Mobile Sync" width="100%" />

<br/>
<br/>

[![GitHub Release](https://img.shields.io/github/v/release/janakchoudharydev/streakformac?style=flat-square&color=FFB703&label=Release)](https://github.com/janakchoudharydev/streakformac/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?style=flat-square&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Node.js](https://img.shields.io/badge/Node.js-22.x-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![macOS](https://img.shields.io/badge/macOS-Sonoma%20%7C%20Sequoia-000000?style=flat-square&logo=apple&logoColor=white)](https://apple.com)
[![Android](https://img.shields.io/badge/Android-12%2B-3DDC84?style=flat-square&logo=android&logoColor=white)](https://android.com)
[![License](https://img.shields.io/badge/License-GPLv3-7C3AED?style=flat-square)](LICENSE)

### The ultra-fast, private, cross-platform habit tracker with seamless zero-cost cloud synchronization.

Built with **Flutter** and backed by a modern **TypeScript / PostgreSQL** sync engine, **Streak for Mac** pairs minimalist aesthetics with desktop power — offering real-time multi-device sync, offline-first reliability, focus timers, and in-depth analytics.

<br/>

<p>
  <a href="https://github.com/janakchoudharydev/streakformac/releases/download/v2.1.0/Streak.dmg">
    <img src="https://img.shields.io/badge/Download-Streak.dmg%20(macOS)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download macOS DMG" height="38" />
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/janakchoudharydev/streakformac/releases/download/v2.1.0/Streak.apk">
    <img src="https://img.shields.io/badge/Download-Streak.apk%20(Android)-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Download Android APK" height="38" />
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/janakchoudharydev/streakformac/releases/tag/v2.1.0">
    <img src="https://img.shields.io/badge/All%20Releases-v2.1.0-FFB703?style=for-the-badge&logo=github&logoColor=black" alt="All GitHub Releases" height="38" />
  </a>
</p>

</div>

---

## 📦 Downloads & Package List

| Platform | Package Format | Requirements | Direct Download |
| :--- | :--- | :--- | :--- |
| 🍏 **macOS** | **`Streak.dmg`** *(Installer with Applications shortcut)* | macOS 12+ (Apple Silicon & Intel) | [**⬇️ Download Streak.dmg** (43 MB)](https://github.com/janakchoudharydev/streakformac/releases/download/v2.1.0/Streak.dmg) |
| 🤖 **Android** | **`Streak.apk`** *(Installable package)* | Android 10+ (API 29+) | [**⬇️ Download Streak.apk** (92 MB)](https://github.com/janakchoudharydev/streakformac/releases/download/v2.1.0/Streak.apk) |
| 🌐 **Cloud Backend** | **Render Blueprint** | Node.js 18+ / PostgreSQL 16 | [**🚀 Deploy on Render**](render.yaml) |

## 📸 Screenshots & Aesthetics

<div align="center">

<img src="client/screenshots/01-today.png" width="22%" alt="Today View" />
<img src="client/screenshots/02-focus.png" width="22%" alt="Focus & Pomodoro" />
<img src="client/screenshots/03-stats.png" width="22%" alt="Statistics" />
<img src="client/screenshots/04-insights.png" width="22%" alt="Insights & Heatmaps" />

<br/>

<img src="client/screenshots/05-amount.png" width="22%" alt="Quantitative Habits" />
<img src="client/screenshots/06-notes.png" width="22%" alt="Day Notes" />
<img src="client/screenshots/07-customize.png" width="22%" alt="Themes & Customization" />
<img src="client/screenshots/08-private.png" width="22%" alt="Privacy First" />

<sub><b>Today</b> · <b>Focus Sessions</b> · <b>Detailed Statistics</b> · <b>Consistency Heatmap</b> · <b>Quant Targets</b> · <b>Day Notes</b> · <b>Aesthetics</b> · <b>Privacy</b></sub>

</div>

---

## ✨ Key Highlights

### 🖥️ Native macOS Experience
- **Fluid Desktop Layout**: Adaptive multi-column rail navigation, expanded wide cards, and detail inspector pane designed specifically for macOS.
- **Instant Keyboard Shortcuts**: Press **`⌘R`** anytime to trigger an instant cloud sync and refresh. Press **`Esc`** to navigate back and dismiss modal inspectors.
- **Desktop Context Menus**: Right-click (*Secondary Click*) any habit card to edit, view statistics, enter vacation mode, or sync. Right-click empty canvas space for desktop quick actions.
- **Top Bar Sync Indicator**: Dedicated animated refresh button and real-time cloud status indicator.

### ⚡ Offline-First Cloud Synchronization
- **Zero-Cost Serverless Backend**: Powered by an Express TypeScript API with managed PostgreSQL, deployed seamlessly to Render's free tier.
- **Bidirectional LWW Conflict Resolution**: Timestamped Last-Write-Wins (LWW) engine ensures edits across phone and Mac reconcile deterministically.
- **Offline Mutation Queue**: Changes made offline are queued safely in local Hive storage (`SyncQueue`) and pushed the moment your connection returns.
- **Smart Completion Deletion & Undone Tracking**: Habit un-completions automatically generate tombstone markers so undone habits stay undone across all devices without resurfacing.
- **Lifecycle Auto-Sync**: The instant the app resumes from the background (e.g. unlocking your Mac or waking your phone), an automated sync executes in the background.
- **Cold-Start Resilience**: Built-in 45-second network timeout tolerance to gracefully await cloud database spin-ups without dropping payloads.

### 🎯 Comprehensive Habit Tracking
- **3 Dynamic Themes**: Choose between **Express** (bouncy micro-interactions), **Classic** (structured week-strip cards), or **Minimal** (compact high-density heatmaps).
- **Multiple Habit Types**:
  - **Positive Habits**: Daily or scheduled streaks (gym, reading, meditation).
  - **Avoidance / Negative Habits**: Break bad habits with relapse tracking and recovery timers.
  - **Quantitative Habits**: Log amounts (liters of water, pages read, workout minutes) with custom targets.
- **Deep Focus & Pomodoro**: Built-in focus timer with ambient soundscapes (rain in cabin, fireplace room, night city, lo-fi study scenes).
- **Vacation & Rest Modes**: Pause habits during travel or schedule weekly rest days without breaking streaks.

---

## 🏛️ System Architecture

```mermaid
graph TD
    subgraph Clients ["Client Layer (Flutter Cross-Platform)"]
        MacApp["Streak for Mac (Desktop macOS)"]
        MobileApp["Streak Mobile (Android / iOS)"]
        LocalHive[("Hive Local Storage")]
        SyncQ["SyncQueue (Offline Buffer)"]
        Worker["SyncWorker"]
    end

    subgraph Cloud ["Cloud Layer (Render Free Tier)"]
        API["Node.js / Express API (TypeScript)"]
        Auth["JWT AuthService"]
        Engine["SyncEngine (LWW + Tombstones)"]
        PG[("PostgreSQL Database")]
    end

    MacApp --> LocalHive
    MobileApp --> LocalHive
    LocalHive --> SyncQ
    SyncQ --> Worker
    Worker -- "POST /api/sync (TLS 1.3)" --> API
    API --> Auth
    API --> Engine
    Engine --> PG
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: `>=3.24.0` ([Install Guide](https://docs.flutter.dev/get-started/install))
- **Node.js**: `>=18.0.0`
- **Xcode**: 15+ (for macOS / iOS builds)
- **CocoaPods** / Swift Package Manager

---

### Quick Start (macOS Desktop)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/janakchoudharydev/streakformac.git
   cd streakformac/client
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the macOS desktop app:**
   ```bash
   flutter run -d macos
   ```

4. **Build a standalone `.app` bundle:**
   ```bash
   flutter build macos --release
   cp -R build/macos/Build/Products/Release/streak.app /Applications/
   ```

---

### Mobile App (Android)

1. **Ensure device or emulator is connected:**
   ```bash
   flutter devices
   ```

2. **Run or install:**
   ```bash
   flutter run -d <device-id>
   # or build release APK
   flutter build apk --release
   ```

---

### Cloud Sync Backend Setup

The backend can be self-hosted on any Node.js environment or deployed to Render for $0/mo.

#### 1. Running Locally
```bash
cd backend
npm install
npm run build

# Configure environment in backend/.env:
# PORT=3000
# JWT_SECRET=your_jwt_secret_key
# DATABASE_URL=postgresql://user:pass@localhost:5432/streak

npm test     # Run test suite
npm start    # Start server on http://localhost:3000
```

#### 2. Deploy to Render (Zero Cost Blueprint)
This repository includes a turnkey [`render.yaml`](render.yaml) blueprint:
1. Log in to [Render.com](https://render.com).
2. Click **New +** -> **Blueprint**.
3. Connect `janakchoudharydev/streakformac`.
4. Render will automatically spin up the Node.js web service and the managed PostgreSQL database on the free plan!

---

## ⌨️ macOS Shortcuts & Gestures

| Action | Shortcut / Gesture |
| :--- | :--- |
| **Sync & Refresh** | <kbd>⌘</kbd> + <kbd>R</kbd> |
| **Dismiss / Pop Sheet** | <kbd>Esc</kbd> |
| **Habit Actions Menu** | Right-Click (*Secondary Click*) on Habit Card |
| **Global Canvas Menu** | Right-Click (*Secondary Click*) on Background |
| **Quick Log Habit** | Left-Click on Checkmark / Day Strip |
| **Custom Amount Log** | Long-Press / Right-Click on Amount Tile |

---

## 🧪 Testing

Both backend and client include comprehensive test coverage:

- **Client Test Suite (402 Tests)**:
  ```bash
  cd client
  flutter test
  ```
- **Backend Test Suite (Unit & LWW Verification)**:
  ```bash
  cd backend
  npm test
  ```

---

## 🛡️ Privacy & Security

- **End-to-End Control**: Your habits live primarily on your device in encrypted local storage.
- **Token-Based Authentication**: Synchronization requires an authenticated, salted bcrypt password hash and JWT bearer tokens.
- **Zero Third-Party Trackers**: No Google Analytics, no Facebook SDKs, no ad networks, no data broker sales.

---

## 🖥️ Server Setup & Deployment Guide (Self-Hosting & Cloud)

Streak includes a high-performance, lightweight synchronization server written in **TypeScript (Node.js)** with **PostgreSQL** storage and **Last-Write-Wins (LWW)** conflict resolution. You can deploy it for **$0/month** on cloud platforms or self-host it on your own hardware / VPS.

```
┌────────────────────────────────────────────────────────┐
│                   Streak Client                        │
│             (macOS Desktop / Android)                  │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTPS / TLS (Bearer JWT)
                           ▼
┌────────────────────────────────────────────────────────┐
│            Streak Sync Backend (Node.js / Express)      │
│  • JWT Auth & Bcrypt    • LWW Conflict Resolution     │
│  • Batched Sync Engine  • Habit Deep-Merging Engine    │
└──────────────────────────┬─────────────────────────────┘
                           │ Connection Pool
                           ▼
┌────────────────────────────────────────────────────────┐
│             PostgreSQL Database 15+                    │
│   (Managed Supabase / Local Postgres / Docker / Neon)  │
└────────────────────────────────────────────────────────┘
```

---

### Method 1: Instant Zero-Cost Deploy on Render (Recommended)

This repository includes a turnkey [render.yaml](render.yaml) blueprint that provisions both the **Node.js Web Service** and a **Managed PostgreSQL Database** on Render's free tier.

1. Fork or push this repository to your GitHub account: `https://github.com/janakchoudharydev/streakformac`.
2. Sign in to [Render.com](https://render.com).
3. In the Render Dashboard, click **New +** → **Blueprint**.
4. Select your connected `streakformac` repository and branch `main`.
5. Render will automatically parse [render.yaml](render.yaml) and configure:
   - **Web Service:** `streak-sync-backend` (Node.js, build: `npm install --include=dev && npm run build`, start: `npm start`)
   - **Managed Database:** `streak-postgres` (PostgreSQL 16)
   - **Environment Variables:** Automatic generation of `JWT_SECRET` and secure internal linking of `DATABASE_URL`.
6. Click **Apply**. Within 2-3 minutes, Render will output your public server URL:
   ```
   https://streak-sync-backend-xxxx.onrender.com
   ```
7. Verify health by opening `https://your-url.onrender.com/api/health` in your browser. It should return:
   ```json
   { "status": "ok", "timestamp": "...", "db": "postgres" }
   ```

---

### Method 2: Self-Hosting with Docker & Docker Compose

For homeservers, NAS (Synology/TrueNAS), or private VPS instances (DigitalOcean, Hetzner, Linode):

#### 1. Create `docker-compose.yml` in your backend or root directory:
```yaml
version: '3.8'

services:
  streak-db:
    image: postgres:16-alpine
    container_name: streak-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: streak
      POSTGRES_PASSWORD: your_strong_db_password
      POSTGRES_DB: streak
    volumes:
      - streak_pg_data:/var/lib/postgresql/data
      - ./backend/src/db/schema.sql:/docker-entrypoint-initdb.d/init.sql:ro
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U streak"]
      interval: 10s
      timeout: 5s
      retries: 5

  streak-api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: streak-api
    restart: unless-stopped
    depends_on:
      streak-db:
        condition: service_healthy
    environment:
      PORT: 3000
      NODE_ENV: production
      JWT_SECRET: your_random_32_char_jwt_secret_key_here
      DATABASE_URL: postgresql://streak:your_strong_db_password@streak-db:5432/streak
    ports:
      - "3000:3000"

volumes:
  streak_pg_data:
```

#### 2. Start the stack:
```bash
docker compose up -d
```

Your server will be running on `http://localhost:3000` with automated database schema provisioning.

---

### Method 3: Manual Bare-Metal / VPS Setup (Linux / macOS)

#### Prerequisites
- **Node.js**: `>= 20.0.0`
- **npm**: `>= 10.0.0`
- **PostgreSQL**: `>= 15.0`
- **Git**

#### 1. Clone & Install Dependencies
```bash
git clone https://github.com/janakchoudharydev/streakformac.git
cd streakformac/backend
npm install
```

#### 2. Configure PostgreSQL Database
Log in to your PostgreSQL instance and create the database:
```sql
CREATE DATABASE streak;
CREATE USER streak WITH ENCRYPTED PASSWORD 'supersecretpassword';
GRANT ALL PRIVILEGES ON DATABASE streak TO streak;
```

Run the schema migration file to create tables and indexes:
```bash
psql -U streak -d streak -f src/db/schema.sql
```

#### 3. Configure Environment Variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Edit `.env`:
```env
PORT=3000
NODE_ENV=production
JWT_SECRET=generate_a_random_32_character_secret_string
DATABASE_URL=postgresql://streak:supersecretpassword@localhost:5432/streak
```

#### 4. Build & Run
```bash
npm run build    # Compiles TypeScript to dist/
npm test         # Validates sync and LWW test suite
npm start        # Launches production server on port 3000
```

#### 5. Configure systemd (Optional for background VPS service)
Create `/etc/systemd/system/streak.service`:
```ini
[Unit]
Description=Streak Sync API Server
After=network.target postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/streakformac/backend
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
EnvironmentFile=/var/www/streakformac/backend/.env

[Install]
WantedBy=multi-user.target
```
Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable streak
sudo systemctl start streak
```

#### 6. Configure HTTPS Reverse Proxy (Caddy or Nginx)
Using **Caddy** (automatic Let's Encrypt SSL):
```caddy
sync.yourdomain.com {
    reverse_proxy localhost:3000
}
```

---

### Method 4: Supabase Cloud Database + Vercel Deployment

If you want a 100% serverless, zero-maintenance deployment:
1. Create a free project at [Supabase.com](https://supabase.com).
2. In Supabase Dashboard, open **SQL Editor** and run the contents of [`backend/src/db/schema.sql`](backend/src/db/schema.sql).
3. Retrieve your connection string from **Project Settings** → **Database** (`postgresql://postgres:[PASSWORD]@...`).
4. Import `janakchoudharydev/streakformac` into [Vercel](https://vercel.com) with Root Directory set to `backend`.
5. Set Environment Variables:
   - `JWT_SECRET`: your secret string
   - `DATABASE_URL`: your Supabase connection string
6. Deploy!

---

### 📱 Connecting Streak Clients (macOS & Mobile)

Once your server is online:

1. Launch **Streak** on macOS or Android.
2. Navigate to **Settings** (gear icon) → **Cloud Sync & Backup**.
3. Under **Server Configuration**:
   - If using custom backend: Enter your server endpoint (e.g. `https://sync.yourdomain.com` or `https://your-app.onrender.com`).
   - If using Google Sign-In + Supabase: Tap **Sign in with Google** for automated zero-config pairing!
4. Register or log in with your email and password.
5. All habits, notes, todos, categories, and focus sessions will immediately synchronize across all your connected devices in real time!

---

## 📜 License

Distributed under the **GNU General Public License v3.0**. See [`LICENSE`](LICENSE) for more information.

---

<div align="center">
  <sub>Built with ❤️ by <a href="https://github.com/janakchoudharydev">janakchoudharydev</a></sub>
</div>
