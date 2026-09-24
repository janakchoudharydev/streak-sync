import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/sync/auth_service.dart';
import 'package:streak/core/sync/sync_queue.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/habits/data/category.dart';
import 'package:streak/features/habits/data/completion.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/habits/data/habit_note.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_tag.dart';
import 'package:streak/services/folder_sync.dart';

class SyncWorker {
  const SyncWorker._();

  static const _lastSyncedKey = 'lastCloudSyncAt';
  static bool _isSyncing = false;

  static bool get isSyncing => _isSyncing;

  static String? get lastSyncedAt =>
      LocalStore.setting<String>(_lastSyncedKey, '');

  static Future<bool> sync({VoidCallback? onDataChanged}) async {
    if (_isSyncing) return false;
    final auth = AuthService.instance;
    if (!auth.isLoggedIn) return false;

    _isSyncing = true;
    try {
      final batch = SyncQueue.peekBatch(limit: 100);
      final lastSync = LocalStore.setting<String>(_lastSyncedKey, '');

      final requestPayload = {
        if (lastSync.isNotEmpty) 'since': lastSync,
        'mutations': batch
            .map((m) => {
                  'id': m.entityId,
                  'entityType': m.entityType,
                  'action': m.action,
                  if (m.payload != null) 'payload': m.payload,
                  'clientTimestamp': m.clientTimestamp,
                })
            .toList(),
      };

      final uri = Uri.parse('${auth.serverUrl}/api/sync');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${auth.token}',
            },
            body: json.encode(requestPayload),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 401) {
        debugPrint('Sync failed: Unauthorized token');
        await auth.logout();
        return false;
      }

      if (response.statusCode != 200) {
        debugPrint('Sync failed with status ${response.statusCode}: ${response.body}');
        return false;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final changes = (data['changes'] as List?) ?? const [];
      final serverTimestamp = data['serverTimestamp'] as String?;

      final sentMutationIds = batch.map((m) => m.mutationId).toSet();

      if (changes.isNotEmpty) {
        await _applyRemoteChanges(changes, sentMutationIds);
        onDataChanged?.call();
      }

      // Dequeue successfully synced local mutations
      if (batch.isNotEmpty) {
        await SyncQueue.dequeue(sentMutationIds);
      }

      if (serverTimestamp != null && serverTimestamp.isNotEmpty) {
        await LocalStore.writeSetting(_lastSyncedKey, serverTimestamp);
      }

      return true;
    } catch (e) {
      // Offline-first silent failure: keeps items in queue and retries when connected
      debugPrint('Sync silent retry notice: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _applyRemoteChanges(List changes, Set<String> sentMutationIds) async {
    LocalStore.isSyncAbsorption = true;
    try {
      final localHabits = LocalStore.readHabits();

      for (final rawChange in changes) {
        try {
          final change = Map<String, dynamic>.from(rawChange as Map);
          final id = change['id'] as String;
          final entityType = change['entityType'] as String;
          final action = change['action'] as String;
          
          if (SyncQueue.hasPendingMutationNot(id, sentMutationIds)) {
            continue;
          }

          final payload = change['payload'] != null
              ? Map<String, dynamic>.from(change['payload'] as Map)
              : null;

          if (action == 'delete') {
            switch (entityType) {
              case 'habit':
                await LocalStore.removeHabit(id);
                break;
              case 'category':
                await LocalStore.removeCategory(id);
                break;
              case 'note':
                await LocalStore.removeNote(id);
                break;
              case 'focus':
                await LocalStore.removeFocusSessions([id]);
                break;
              case 'todo':
                await LocalStore.removeTodo(id);
                break;
              case 'todo_tag':
                await LocalStore.removeTodoTag(id);
                break;
            }
          } else if (action == 'upsert' && payload != null) {
            switch (entityType) {
              case 'habit':
                final incomingHabit = Habit.fromMap(payload);
                final existingHabit = localHabits[id];
                final removedCompletions = (payload['removedCompletions'] as List?)
                    ?.map((e) => e.toString())
                    .toSet() ?? const <String>{};

                final baseCompletions = existingHabit == null
                    ? incomingHabit.completions
                    : FolderSync.mergeCompletions(
                        existingHabit.completions,
                        incomingHabit.completions,
                      );

                final finalCompletions = Map<String, Completion>.from(baseCompletions)
                  ..removeWhere((k, _) => removedCompletions.contains(k));

                final mergedHabit = (existingHabit == null ? incomingHabit : incomingHabit).copyWith(
                  completions: finalCompletions,
                );
                await LocalStore.writeHabit(mergedHabit);
                break;
              case 'category':
                await LocalStore.writeCategory(Category.fromMap(payload));
                break;
              case 'note':
                await LocalStore.writeNote(HabitNote.fromMap(payload));
                break;
              case 'focus':
                await LocalStore.writeFocusSession(FocusSession.fromMap(payload));
                break;
              case 'todo':
                await LocalStore.writeTodo(Todo.fromMap(payload));
                break;
              case 'todo_tag':
                await LocalStore.writeTodoTag(
                  TodoTag.fromJson(json.encode(payload)),
                );
                break;
            }
          }
        } catch (e) {
          debugPrint('Error applying remote entity change: $e');
        }
      }
    } finally {
      LocalStore.isSyncAbsorption = false;
    }
  }
}
