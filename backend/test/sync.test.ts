import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../src/db';
import { AuthService } from '../src/services/auth';
import { SyncEngine } from '../src/services/syncEngine';

describe('Streak Backend & Sync Engine', () => {
  beforeEach(async () => {
    await db.clear();
  });

  describe('AuthService', () => {
    it('registers a new user and generates a valid JWT', async () => {
      const res = await AuthService.register('test@example.com', 'password123');
      assert.ok(res.token);
      assert.equal(res.user.email, 'test@example.com');
      assert.ok(res.user.id);

      const verified = AuthService.verifyToken(res.token);
      assert.equal(verified.email, 'test@example.com');
      assert.equal(verified.userId, res.user.id);
    });

    it('rejects duplicate email registrations', async () => {
      await AuthService.register('test@example.com', 'password123');
      await assert.rejects(
        () => AuthService.register('test@example.com', 'anotherpassword'),
        /already exists/
      );
    });

    it('authenticates with valid credentials', async () => {
      await AuthService.register('user@example.com', 'correctpass');
      const loginRes = await AuthService.login('user@example.com', 'correctpass');
      assert.ok(loginRes.token);
      assert.equal(loginRes.user.email, 'user@example.com');
    });

    it('fails login with invalid password', async () => {
      await AuthService.register('user@example.com', 'correctpass');
      await assert.rejects(
        () => AuthService.login('user@example.com', 'wrongpass'),
        /Invalid email or password/
      );
    });
  });

  describe('SyncEngine (LWW Conflict Resolution & Bidirectional Sync)', () => {
    it('applies client habit creations and updates', async () => {
      const user = await AuthService.register('sync1@example.com', 'pass123');
      const time1 = '2026-09-23T10:00:00.000Z';

      const response = await SyncEngine.processSync(user.user.id, {
        mutations: [
          {
            id: 'habit-1',
            entityType: 'habit',
            action: 'create',
            payload: {
              id: 'habit-1',
              name: 'Drink Water',
              order: 1,
              completions: {
                '2026-09-23': { date: '2026-09-23', count: 1 },
              },
            },
            clientTimestamp: time1,
          },
        ],
      });

      assert.equal(response.appliedCount, 1);
      assert.equal(response.changes.length, 1);
      assert.equal(response.changes[0].id, 'habit-1');
      assert.equal(response.changes[0].action, 'upsert');
      assert.equal(response.changes[0].payload?.name, 'Drink Water');
    });

    it('implements Last-Write-Wins: rejects outdated mutations', async () => {
      const user = await AuthService.register('sync2@example.com', 'pass123');
      const timeNewer = '2026-09-23T12:00:00.000Z';
      const timeOlder = '2026-09-23T08:00:00.000Z';

      // 1. Device A writes with newer timestamp
      await SyncEngine.processSync(user.user.id, {
        mutations: [
          {
            id: 'habit-2',
            entityType: 'habit',
            action: 'create',
            payload: { id: 'habit-2', name: 'Newer Name', order: 1 },
            clientTimestamp: timeNewer,
          },
        ],
      });

      // 2. Device B sends delayed/stale mutation with older timestamp
      const staleRes = await SyncEngine.processSync(user.user.id, {
        mutations: [
          {
            id: 'habit-2',
            entityType: 'habit',
            action: 'update',
            payload: { id: 'habit-2', name: 'Older Name', order: 2 },
            clientTimestamp: timeOlder,
          },
        ],
      });

      // The mutation should NOT override the newer name
      assert.equal(staleRes.appliedCount, 0);

      // Verify stored record retains the newer name
      const stored = await db.getEntity(user.user.id, 'habit', 'habit-2');
      assert.equal(stored?.data.name, 'Newer Name');
    });

    it('merges offline completions from multiple devices', async () => {
      const user = await AuthService.register('sync3@example.com', 'pass123');

      // Device A completes on day 1
      await SyncEngine.processSync(user.user.id, {
        mutations: [
          {
            id: 'habit-3',
            entityType: 'habit',
            action: 'create',
            payload: {
              id: 'habit-3',
              name: 'Exercise',
              completions: {
                '2026-09-21': { date: '2026-09-21', count: 1 },
              },
            },
            clientTimestamp: '2026-09-23T10:00:00.000Z',
          },
        ],
      });

      // Device B completes on day 2 and syncs later
      await SyncEngine.processSync(user.user.id, {
        mutations: [
          {
            id: 'habit-3',
            entityType: 'habit',
            action: 'update',
            payload: {
              id: 'habit-3',
              name: 'Exercise',
              completions: {
                '2026-09-22': { date: '2026-09-22', count: 1 },
              },
            },
            clientTimestamp: '2026-09-23T11:00:00.000Z',
          },
        ],
      });

      // Stored record should contain BOTH completions
      const stored = await db.getEntity(user.user.id, 'habit', 'habit-3');
      assert.ok(stored?.data.completions['2026-09-21']);
      assert.ok(stored?.data.completions['2026-09-22']);
    });

    it('returns only deltas modified since client last sync', async () => {
      const user = await AuthService.register('sync4@example.com', 'pass123');

      // Sync Habit A
      const resA = await SyncEngine.processSync(user.user.id, {
        mutations: [
          {
            id: 'habit-a',
            entityType: 'habit',
            action: 'create',
            payload: { id: 'habit-a', name: 'Habit A' },
            clientTimestamp: '2026-09-23T10:00:00.000Z',
          },
        ],
      });
      const checkpoint = resA.serverTimestamp;

      // Small pause to guarantee timestamp advancement
      await new Promise((r) => setTimeout(r, 10));

      // Sync Habit B
      await SyncEngine.processSync(user.user.id, {
        mutations: [
          {
            id: 'habit-b',
            entityType: 'habit',
            action: 'create',
            payload: { id: 'habit-b', name: 'Habit B' },
            clientTimestamp: '2026-09-23T10:05:00.000Z',
          },
        ],
      });

      // Query changes since checkpoint: should ONLY return Habit B
      const deltaRes = await SyncEngine.processSync(user.user.id, {
        since: checkpoint,
      });

      assert.equal(deltaRes.changes.length, 1);
      assert.equal(deltaRes.changes[0].id, 'habit-b');
    });
  });
});
