# Execution Phases

## Phase 1: Backend Provisioning
*   Provision free PostgreSQL (Supabase) or MongoDB (Atlas).
*   Deploy serverless API on Vercel/Render for standard CRUD endpoints and Authentication.
*   Verify API connectivity and define JSON payload schemas.

## Phase 2: Client Authentication
*   Add `flutter_secure_storage` dependency (minimal diff).
*   Implement Auth UI in Settings and connect to Backend API.
*   Securely store JWT/Session tokens.

## Phase 3: Local Sync Abstraction
*   Implement `SyncQueue` local storage schema.
*   Wrap existing database write operations to simultaneously log to `SyncQueue`.

## Phase 4: Sync Engine Implementation
*   Create `SyncWorker` to handle HTTP requests.
*   Implement Last-Write-Wins (LWW) conflict resolution logic.
*   Test bidirectional syncing on a single device (simulate offline mode, make changes, reconnect).

## Phase 5: Multi-Platform Builds & Testing
*   Verify Windows compilation (`flutter build windows`).
*   Verify Android APK compilation.
*   Complete iOS setup (update Podfile/Runner as needed for secure storage dependencies).
*   Test cross-device sync (e.g., check habit on Windows, verify UI update on Android).