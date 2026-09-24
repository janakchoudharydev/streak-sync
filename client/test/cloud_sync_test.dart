import 'package:flutter_test/flutter_test.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/sync/sync_queue.dart';

import 'support/app_harness.dart';

void main() {
  useEmptyStore();

  setUp(() async {
    await SyncQueue.clear();
  });

  group('SyncQueue', () {
    test('enqueues and peeks mutations with valid metadata', () async {
      expect(SyncQueue.isEmpty, isTrue);

      await SyncQueue.enqueue(
        entityId: 'test-habit-1',
        entityType: 'habit',
        action: 'create',
        payload: {'id': 'test-habit-1', 'name': 'Morning Exercise'},
      );

      expect(SyncQueue.count, 1);
      final batch = SyncQueue.peekBatch();
      expect(batch.length, 1);
      expect(batch.first.entityId, 'test-habit-1');
      expect(batch.first.entityType, 'habit');
      expect(batch.first.action, 'create');
      expect(batch.first.payload?['name'], 'Morning Exercise');
      expect(batch.first.clientTimestamp, isNotEmpty);
    });

    test('dequeues processed mutations by ID', () async {
      await SyncQueue.enqueue(
        entityId: 'habit-a',
        entityType: 'habit',
        action: 'update',
      );
      await SyncQueue.enqueue(
        entityId: 'habit-b',
        entityType: 'habit',
        action: 'delete',
      );

      expect(SyncQueue.count, 2);
      final batch = SyncQueue.peekBatch();
      expect(batch.length, 2);

      final toRemove = batch.firstWhere((m) => m.entityId == 'habit-a');
      await SyncQueue.dequeue([toRemove.mutationId]);
      expect(SyncQueue.count, 1);
      expect(SyncQueue.peekBatch().first.entityId, 'habit-b');
    });

    test('triggers onMutationEnqueued callback when a mutation is added', () async {
      var triggered = false;
      SyncQueue.onMutationEnqueued = () => triggered = true;

      await SyncQueue.enqueue(
        entityId: 'trigger-test',
        entityType: 'todo',
        action: 'create',
      );

      expect(triggered, isTrue);
      SyncQueue.onMutationEnqueued = null;
    });

    test('clears entire queue', () async {
      await SyncQueue.enqueue(
        entityId: 'item-1',
        entityType: 'todo',
        action: 'update',
      );
      expect(SyncQueue.isNotEmpty, isTrue);

      await SyncQueue.clear();
      expect(SyncQueue.isEmpty, isTrue);
    });
  });

  group('LocalStore & SyncQueue integration', () {
    test('LocalStore.writeHabit automatically queues a mutation', () async {
      await SyncQueue.clear();
      expect(SyncQueue.isEmpty, isTrue);

      final habit = testHabit(id: 'sync-test-h1', name: 'Drink Water');
      await LocalStore.writeHabit(habit);

      expect(SyncQueue.count, 1);
      final batch = SyncQueue.peekBatch();
      expect(batch.first.entityId, 'sync-test-h1');
      expect(batch.first.entityType, 'habit');
      expect(batch.first.action, 'update');
    });

    test('LocalStore.removeHabit automatically queues a delete mutation', () async {
      await SyncQueue.clear();

      await LocalStore.removeHabit('sync-test-h1');
      expect(SyncQueue.count, 1);
      final batch = SyncQueue.peekBatch();
      expect(batch.first.entityId, 'sync-test-h1');
      expect(batch.first.action, 'delete');
    });

    test('LocalStore.isSyncAbsorption suppresses mutation queueing to prevent feedback loops', () async {
      await SyncQueue.clear();
      expect(SyncQueue.isEmpty, isTrue);

      LocalStore.isSyncAbsorption = true;
      try {
        final habit = testHabit(id: 'remote-absorbed-habit', name: 'Cloud Habit');
        await LocalStore.writeHabit(habit);
      } finally {
        LocalStore.isSyncAbsorption = false;
      }

      // No mutation should be queued when absorption flag is true
      expect(SyncQueue.isEmpty, isTrue);
    });
  });
}
