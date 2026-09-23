import crypto from 'crypto';
import { Pool } from 'pg';

export interface UserRecord {
  id: string;
  email: string;
  password_hash: string;
  created_at: string;
  updated_at: string;
}

export interface SyncEntityRecord {
  user_id: string;
  id: string;
  entity_type: string;
  data: Record<string, any>;
  client_updated_at: string; // ISO 8601 UTC
  server_updated_at: string; // ISO 8601 UTC
  is_deleted: boolean;
}

export interface IDatabase {
  findUserByEmail(email: string): Promise<UserRecord | null>;
  findUserById(id: string): Promise<UserRecord | null>;
  createUser(email: string, passwordHash: string): Promise<UserRecord>;
  getEntity(userId: string, entityType: string, id: string): Promise<SyncEntityRecord | null>;
  saveEntity(record: SyncEntityRecord): Promise<void>;
  getEntitiesModifiedSince(userId: string, sinceServerIso: string): Promise<SyncEntityRecord[]>;
  clear(): Promise<void>;
}

// In-Memory Database Implementation (for local tests / dev mode)
export class MemoryDatabase implements IDatabase {
  private users = new Map<string, UserRecord>();
  private entities = new Map<string, SyncEntityRecord>();

  private entityKey(userId: string, entityType: string, id: string): string {
    return `${userId}:${entityType}:${id}`;
  }

  async findUserByEmail(email: string): Promise<UserRecord | null> {
    const normalized = email.toLowerCase().trim();
    for (const user of this.users.values()) {
      if (user.email.toLowerCase() === normalized) {
        return user;
      }
    }
    return null;
  }

  async findUserById(id: string): Promise<UserRecord | null> {
    return this.users.get(id) || null;
  }

  async createUser(email: string, passwordHash: string): Promise<UserRecord> {
    const user: UserRecord = {
      id: crypto.randomUUID(),
      email: email.toLowerCase().trim(),
      password_hash: passwordHash,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.users.set(user.id, user);
    return user;
  }

  async getEntity(userId: string, entityType: string, id: string): Promise<SyncEntityRecord | null> {
    return this.entities.get(this.entityKey(userId, entityType, id)) || null;
  }

  async saveEntity(record: SyncEntityRecord): Promise<void> {
    this.entities.set(this.entityKey(record.user_id, record.entity_type, record.id), { ...record });
  }

  async getEntitiesModifiedSince(userId: string, sinceServerIso: string): Promise<SyncEntityRecord[]> {
    const sinceDate = sinceServerIso ? new Date(sinceServerIso).getTime() : 0;
    const results: SyncEntityRecord[] = [];

    for (const record of this.entities.values()) {
      if (record.user_id === userId) {
        const recordDate = new Date(record.server_updated_at).getTime();
        if (recordDate > sinceDate) {
          results.push({ ...record });
        }
      }
    }

    return results;
  }

  async clear(): Promise<void> {
    this.users.clear();
    this.entities.clear();
  }
}

// Production PostgreSQL Database Implementation (for Supabase / Neon / Managed Postgres)
export class PostgresDatabase implements IDatabase {
  private pool: Pool;

  constructor(connectionString: string) {
    const isLocalhost = connectionString.includes('localhost') || connectionString.includes('127.0.0.1');
    this.pool = new Pool({
      connectionString,
      ssl: isLocalhost ? false : { rejectUnauthorized: false },
      max: 10,
      idleTimeoutMillis: 30000,
    });
  }

  async findUserByEmail(email: string): Promise<UserRecord | null> {
    const res = await this.pool.query(
      'SELECT id, email, password_hash, created_at, updated_at FROM users WHERE LOWER(email) = LOWER($1)',
      [email.trim()]
    );
    if (!res.rows.length) return null;
    const r = res.rows[0];
    return {
      id: r.id,
      email: r.email,
      password_hash: r.password_hash,
      created_at: new Date(r.created_at).toISOString(),
      updated_at: new Date(r.updated_at).toISOString(),
    };
  }

  async findUserById(id: string): Promise<UserRecord | null> {
    const res = await this.pool.query(
      'SELECT id, email, password_hash, created_at, updated_at FROM users WHERE id = $1',
      [id]
    );
    if (!res.rows.length) return null;
    const r = res.rows[0];
    return {
      id: r.id,
      email: r.email,
      password_hash: r.password_hash,
      created_at: new Date(r.created_at).toISOString(),
      updated_at: new Date(r.updated_at).toISOString(),
    };
  }

  async createUser(email: string, passwordHash: string): Promise<UserRecord> {
    const id = crypto.randomUUID();
    const now = new Date().toISOString();
    const res = await this.pool.query(
      'INSERT INTO users (id, email, password_hash, created_at, updated_at) VALUES ($1, $2, $3, $4, $5) RETURNING id, email, password_hash, created_at, updated_at',
      [id, email.toLowerCase().trim(), passwordHash, now, now]
    );
    const r = res.rows[0];
    return {
      id: r.id,
      email: r.email,
      password_hash: r.password_hash,
      created_at: new Date(r.created_at).toISOString(),
      updated_at: new Date(r.updated_at).toISOString(),
    };
  }

  async getEntity(userId: string, entityType: string, id: string): Promise<SyncEntityRecord | null> {
    const res = await this.pool.query(
      'SELECT user_id, entity_type, id, data, client_updated_at, server_updated_at, is_deleted FROM sync_entities WHERE user_id = $1 AND entity_type = $2 AND id = $3',
      [userId, entityType, id]
    );
    if (!res.rows.length) return null;
    const r = res.rows[0];
    return {
      user_id: r.user_id,
      entity_type: r.entity_type,
      id: r.id,
      data: typeof r.data === 'string' ? JSON.parse(r.data) : r.data,
      client_updated_at: new Date(r.client_updated_at).toISOString(),
      server_updated_at: new Date(r.server_updated_at).toISOString(),
      is_deleted: !!r.is_deleted,
    };
  }

  async saveEntity(record: SyncEntityRecord): Promise<void> {
    await this.pool.query(
      `INSERT INTO sync_entities (user_id, entity_type, id, data, client_updated_at, server_updated_at, is_deleted)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (user_id, entity_type, id) DO UPDATE SET
         data = EXCLUDED.data,
         client_updated_at = EXCLUDED.client_updated_at,
         server_updated_at = EXCLUDED.server_updated_at,
         is_deleted = EXCLUDED.is_deleted`,
      [
        record.user_id,
        record.entity_type,
        record.id,
        JSON.stringify(record.data),
        record.client_updated_at,
        record.server_updated_at,
        record.is_deleted,
      ]
    );
  }

  async getEntitiesModifiedSince(userId: string, sinceServerIso: string): Promise<SyncEntityRecord[]> {
    const sinceDate = sinceServerIso ? new Date(sinceServerIso).toISOString() : new Date(0).toISOString();
    const res = await this.pool.query(
      'SELECT user_id, entity_type, id, data, client_updated_at, server_updated_at, is_deleted FROM sync_entities WHERE user_id = $1 AND server_updated_at > $2 ORDER BY server_updated_at ASC',
      [userId, sinceDate]
    );
    return res.rows.map((r: any) => ({
      user_id: r.user_id,
      entity_type: r.entity_type,
      id: r.id,
      data: typeof r.data === 'string' ? JSON.parse(r.data) : r.data,
      client_updated_at: new Date(r.client_updated_at).toISOString(),
      server_updated_at: new Date(r.server_updated_at).toISOString(),
      is_deleted: !!r.is_deleted,
    }));
  }

  async clear(): Promise<void> {
    await this.pool.query('DELETE FROM sync_entities');
    await this.pool.query('DELETE FROM users');
  }
}

// Database instance selection: Postgres if DATABASE_URL is configured, else Memory
const databaseUrl = process.env.DATABASE_URL;
export const db: IDatabase = databaseUrl
  ? new PostgresDatabase(databaseUrl)
  : new MemoryDatabase();

