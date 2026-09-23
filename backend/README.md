# Streak Multi-Platform Sync Backend

Lightweight, zero-cost ($0.00/month) serverless synchronization backend for `Streak`. Compatible with **Vercel Serverless Functions**, **Render Web Services**, and **Supabase (PostgreSQL)**.

## Features
- **User Authentication**: Secure JWT-based registration and login with bcrypt hashing.
- **Offline-First Synchronization**: Receives batched mutations (`create`, `update`, `delete`) and returns remote deltas.
- **Last-Write-Wins (LWW)**: UTC timestamp conflict resolution ensuring consistent state across Android, iOS, Windows, and macOS devices.
- **Intelligent Habit Merging**: Deep merges daily completions so habits checked off across different devices while offline are fully preserved.

## API Specification

### Authentication
* `POST /api/auth/register`
  * Body: `{ "email": "user@example.com", "password": "password123" }`
  * Response: `{ "token": "jwt...", "user": { "id": "uuid", "email": "user@example.com" } }`
* `POST /api/auth/login`
  * Body: `{ "email": "user@example.com", "password": "password123" }`
  * Response: `{ "token": "jwt...", "user": { "id": "uuid", "email": "user@example.com" } }`

### Sync
* `POST /api/sync` (Requires `Authorization: Bearer <token>`)
  * Body:
    ```json
    {
      "since": "2026-09-23T10:00:00.000Z",
      "mutations": [
        {
          "id": "habit-123",
          "entityType": "habit",
          "action": "update",
          "payload": { ... },
          "clientTimestamp": "2026-09-23T12:00:00.000Z"
        }
      ]
    }
    ```
  * Response:
    ```json
    {
      "serverTimestamp": "2026-09-23T12:00:05.123Z",
      "appliedCount": 1,
      "changes": [
        {
          "id": "habit-456",
          "entityType": "habit",
          "action": "upsert",
          "payload": { ... },
          "clientUpdatedAt": "2026-09-23T11:45:00.000Z",
          "serverUpdatedAt": "2026-09-23T11:45:02.000Z"
        }
      ]
    }
    ```

## Local Development & Testing

```bash
cd backend
npm install
npm test       # Runs the automated test suite (node:test + tsx)
npm run dev    # Starts the local development server at http://localhost:3000
```

## Free Tier Deployment Guide ($0.00/month)

### Deploy to Vercel:
1. Push this repository to GitHub.
2. Import the project into [Vercel](https://vercel.com).
3. Set the Root Directory to `backend`.
4. Configure environment variables in Vercel Dashboard:
   - `JWT_SECRET`: Random 32+ character string.
   - `DATABASE_URL`: Your Supabase connection string.
5. Deploy.

### Provision Database on Supabase:
1. Create a free project at [Supabase](https://supabase.com).
2. Go to the SQL Editor and execute [`src/db/schema.sql`](src/db/schema.sql).
3. Copy the database connection string into your Vercel / Render environment variables.
