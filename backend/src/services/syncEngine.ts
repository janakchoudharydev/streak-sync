import { db, SyncEntityRecord } from '../db';

export interface ClientMutation {
  id: string;
  entityType: 'habit' | 'category' | 'note' | 'focus' | 'todo' | 'todo_tag';
  action: 'create' | 'update' | 'delete';
  payload?: Record<string, any>;
  clientTimestamp: string; // ISO 8601 UTC
}

export interface SyncRequest {
  since?: string; // ISO 8601 UTC of last successful sync
  mutations?: ClientMutation[];
}

export interface ServerDelta {
  id: string;
  entityType: string;
  action: 'upsert' | 'delete';
  payload?: Record<string, any>;
  clientUpdatedAt: string;
  serverUpdatedAt: string;
}

export interface SyncResponse {
  serverTimestamp: string;
  appliedCount: number;
  changes: ServerDelta[];
}

export class SyncEngine {
  /**
   * Processes a batch of client mutations and returns delta changes since last sync.
   * Uses Last-Write-Wins (LWW) conflict resolution based on client UTC timestamps.
   */
  static async processSync(userId: string, request: SyncRequest): Promise<SyncResponse> {
    const nowIso = new Date().toISOString();
    const mutations = request.mutations || [];
    let appliedCount = 0;

    for (const mutation of mutations) {
      const { id, entityType, action, payload, clientTimestamp } = mutation;
      if (!id || !entityType || !clientTimestamp) continue;

      const mutationTime = new Date(clientTimestamp).getTime();
      const existing = await db.getEntity(userId, entityType, id);

      if (existing) {
        const existingClientTime = new Date(existing.client_updated_at).getTime();

        // Last-Write-Wins (LWW): only update if incoming mutation timestamp is >= existing
        if (mutationTime >= existingClientTime) {
          const isDeleted = action === 'delete';
          
          let mergedData = payload || existing.data;
          // If habit with completions, merge completions intelligently if existing has newer completions
          if (entityType === 'habit' && !isDeleted && payload && existing.data) {
            mergedData = this.mergeHabitData(existing.data, payload);
          }

          const updatedRecord: SyncEntityRecord = {
            user_id: userId,
            id,
            entity_type: entityType,
            data: isDeleted ? existing.data : mergedData,
            client_updated_at: clientTimestamp,
            server_updated_at: nowIso,
            is_deleted: isDeleted,
          };

          await db.saveEntity(updatedRecord);
          appliedCount++;
        }
      } else {
        // Record does not exist yet
        const isDeleted = action === 'delete';
        const newRecord: SyncEntityRecord = {
          user_id: userId,
          id,
          entity_type: entityType,
          data: payload || {},
          client_updated_at: clientTimestamp,
          server_updated_at: nowIso,
          is_deleted: isDeleted,
        };

        await db.saveEntity(newRecord);
        appliedCount++;
      }
    }

    // Retrieve all remote changes modified on server since `request.since`
    const sinceIso = request.since || '';
    const modifiedRecords = await db.getEntitiesModifiedSince(userId, sinceIso);

    // Format changes to return to the client
    const changes: ServerDelta[] = modifiedRecords.map((r) => ({
      id: r.id,
      entityType: r.entity_type,
      action: r.is_deleted ? 'delete' : 'upsert',
      payload: r.is_deleted ? undefined : r.data,
      clientUpdatedAt: r.client_updated_at,
      serverUpdatedAt: r.server_updated_at,
    }));

    return {
      serverTimestamp: nowIso,
      appliedCount,
      changes,
    };
  }

  /**
   * Deep merge completions for habits so progress recorded across multiple offline devices is preserved,
   * while ensuring that explicitly undone/deleted completions are reliably removed.
   */
  private static mergeHabitData(existing: Record<string, any>, incoming: Record<string, any>): Record<string, any> {
    const merged = { ...incoming };
    const existingCompletions = existing.completions || {};
    const incomingCompletions = incoming.completions || {};

    const mergedCompletions = { ...existingCompletions };
    for (const [dayKey, inComp] of Object.entries(incomingCompletions)) {
      const exComp = mergedCompletions[dayKey];
      if (!exComp) {
        mergedCompletions[dayKey] = inComp;
      } else {
        const exObj = (typeof exComp === 'object' && exComp !== null) ? exComp : {};
        const inObj = (typeof inComp === 'object' && inComp !== null) ? inComp : {};

        // Take maximum completion count and union sub-steps & marks arrays
        const exCount = (exObj as any).numberOfCompletions ?? (exObj as any).count ?? 0;
        const inCount = (inObj as any).numberOfCompletions ?? (inObj as any).count ?? 0;

        const exSteps = Array.isArray((exObj as any).steps) ? (exObj as any).steps : [];
        const inSteps = Array.isArray((inObj as any).steps) ? (inObj as any).steps : [];
        const mergedSteps = Array.from(new Set([...exSteps, ...inSteps]));

        const exMarks = Array.isArray((exObj as any).marks) ? (exObj as any).marks : [];
        const inMarks = Array.isArray((inObj as any).marks) ? (inObj as any).marks : [];
        const mergedMarks = Array.from(new Set([...exMarks, ...inMarks]));

        const mergedEntry: Record<string, any> = {
          ...exObj,
          ...inObj,
          numberOfCompletions: Math.max(exCount, inCount),
        };
        if (mergedSteps.length > 0) mergedEntry.steps = mergedSteps;
        if (mergedMarks.length > 0) mergedEntry.marks = mergedMarks;

        mergedCompletions[dayKey] = mergedEntry;
      }
    }

    // Process explicit completion deletions/undones
    const existingRemoved: string[] = Array.isArray(existing.removedCompletions) ? existing.removedCompletions : [];
    const incomingRemoved: string[] = Array.isArray(incoming.removedCompletions) ? incoming.removedCompletions : [];
    const allRemoved = new Set([...existingRemoved, ...incomingRemoved]);

    // If an incoming completion was re-added, remove it from allRemoved
    for (const dayKey of Object.keys(incomingCompletions)) {
      allRemoved.delete(dayKey);
    }

    // Delete any undone day keys from the merged completions map
    for (const dayKey of allRemoved) {
      delete mergedCompletions[dayKey];
    }

    merged.completions = mergedCompletions;
    if (allRemoved.size > 0) {
      merged.removedCompletions = Array.from(allRemoved);
    } else {
      delete merged.removedCompletions;
    }
    return merged;
  }
}
