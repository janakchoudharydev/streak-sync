# Technical Architecture

## 1. Client App (Flutter)
*   **State Management:** Retain existing architecture.
*   **Local Storage:** Retain existing local DB (Isar/Hive).
*   **Sync Engine (New):** 
    *   `SyncQueue`: A local table/box tracking un-synced mutations (Create, Update, Delete).
    *   `SyncWorker`: Background isolate that processes the `SyncQueue` when network is available.

## 2. Backend Infrastructure
*   **API Hosting:** Vercel (Serverless Functions via Node.js or Dart Edge) or Render (Web Service).
*   **Database:** Supabase (PostgreSQL) or MongoDB Atlas (Free Tier). 
*   **API Protocol:** REST over HTTPS.

## 3. Data Flow
1. User marks habit as complete (offline).
2. UI updates instantly (optimistic update).
3. Record written to local DB + record appended to `SyncQueue`.
4. `SyncWorker` detects network, authenticates via JWT.
5. `SyncWorker` POSTs `SyncQueue` payload to Vercel/Render API.
6. API resolves conflicts (Timestamp comparison) -> Updates DB -> Returns merged state.
7. `SyncWorker` updates local DB with merged state and clears `SyncQueue`.