# Product Requirements Document: Multi-Platform Sync

## Objective
Enable real-time and background data synchronization for `InlitX/streak` across Android, iOS, Windows, and macOS devices while maintaining its offline-first architecture.

## Infrastructure Constraint
*   **Hosting:** Free tiers strictly (Vercel for serverless API, Render for web services/cron, or free database tiers like MongoDB Atlas / Supabase PostgreSQL).
*   **Cost:** $0.00/month.

## Core Requirements
1.  **Authentication:** Lightweight user authentication to separate user data (Email/Password).
2.  **Bidirectional Sync:** 
    *   Push local habit completions, creations, and edits to the cloud.
    *   Pull remote changes from other devices and merge them locally.
3.  **Conflict Resolution:** Last-Write-Wins (LWW) based on UTC timestamps.
4.  **Cross-Platform Parity:** Must compile and sync seamlessly on Android, iOS (in progress), Windows, and macOS (planned).

## Out of Scope
*   Social features, habit sharing, or public leaderboards.
*   Push notifications from the server (local notifications remain unchanged).