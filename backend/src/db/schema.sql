-- Supabase / PostgreSQL Schema for Multi-Platform Habit Sync
-- Cost: $0.00 / month on Supabase Free Tier

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (supports lightweight custom auth or Supabase Auth)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Core Sync Entities Table (Unified LWW store for habits, notes, todos, categories, etc.)
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
CREATE INDEX IF NOT EXISTS idx_sync_entities_lookup ON sync_entities(user_id, server_updated_at);

-- Individual entity tables for optional granular reporting/views
CREATE TABLE IF NOT EXISTS habits (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id VARCHAR(128) NOT NULL,
    data JSONB NOT NULL,
    client_updated_at TIMESTAMPTZ NOT NULL,
    server_updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_habits_sync ON habits(user_id, server_updated_at);

CREATE TABLE IF NOT EXISTS categories (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id VARCHAR(128) NOT NULL,
    data JSONB NOT NULL,
    client_updated_at TIMESTAMPTZ NOT NULL,
    server_updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_categories_sync ON categories(user_id, server_updated_at);

CREATE TABLE IF NOT EXISTS habit_notes (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id VARCHAR(128) NOT NULL,
    data JSONB NOT NULL,
    client_updated_at TIMESTAMPTZ NOT NULL,
    server_updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_notes_sync ON habit_notes(user_id, server_updated_at);

CREATE TABLE IF NOT EXISTS focus_sessions (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id VARCHAR(128) NOT NULL,
    data JSONB NOT NULL,
    client_updated_at TIMESTAMPTZ NOT NULL,
    server_updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_focus_sync ON focus_sessions(user_id, server_updated_at);

CREATE TABLE IF NOT EXISTS todos (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id VARCHAR(128) NOT NULL,
    data JSONB NOT NULL,
    client_updated_at TIMESTAMPTZ NOT NULL,
    server_updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_todos_sync ON todos(user_id, server_updated_at);

CREATE TABLE IF NOT EXISTS todo_tags (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id VARCHAR(128) NOT NULL,
    data JSONB NOT NULL,
    client_updated_at TIMESTAMPTZ NOT NULL,
    server_updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_todo_tags_sync ON todo_tags(user_id, server_updated_at);
