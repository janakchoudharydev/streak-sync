import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class SyncMutation {
  const SyncMutation({
    required this.mutationId,
    required this.entityId,
    required this.entityType,
    required this.action,
    required this.clientTimestamp,
    this.payload,
  });

  final String mutationId;
  final String entityId;
  final String entityType; // 'habit', 'category', 'note', 'focus', 'todo', 'todo_tag'
  final String action; // 'create', 'update', 'delete'
  final String clientTimestamp; // ISO 8601 UTC string
  final Map<String, dynamic>? payload;

  Map<String, dynamic> toMap() => {
        'mutationId': mutationId,
        'entityId': entityId,
        'entityType': entityType,
        'action': action,
        'clientTimestamp': clientTimestamp,
        if (payload != null) 'payload': payload,
      };

  factory SyncMutation.fromMap(Map<String, dynamic> map) => SyncMutation(
        mutationId: map['mutationId'] as String,
        entityId: map['entityId'] as String,
        entityType: map['entityType'] as String,
        action: map['action'] as String,
        clientTimestamp: map['clientTimestamp'] as String,
        payload: map['payload'] != null
            ? Map<String, dynamic>.from(map['payload'] as Map)
            : null,
      );

  String toJson() => json.encode(toMap());

  factory SyncMutation.fromJson(String source) =>
      SyncMutation.fromMap(json.decode(source) as Map<String, dynamic>);
}

class SyncQueue {
  const SyncQueue._();

  static const _boxName = 'sync_queue';
  static late Box _box;
  static const _uuid = Uuid();

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static int get count => _box.length;

  static bool get isEmpty => _box.isEmpty;

  static bool get isNotEmpty => _box.isNotEmpty;

  static VoidCallback? onMutationEnqueued;

  /// Enqueue an entity mutation (create, update, or delete)
  static Future<void> enqueue({
    required String entityId,
    required String entityType,
    required String action,
    Map<String, dynamic>? payload,
    DateTime? timestamp,
  }) async {
    final mutation = SyncMutation(
      mutationId: _uuid.v4(),
      entityId: entityId,
      entityType: entityType,
      action: action,
      clientTimestamp: (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
      payload: payload,
    );

    try {
      await _box.put(mutation.mutationId, mutation.toJson());
      onMutationEnqueued?.call();
    } catch (e) {
      debugPrint('Failed to enqueue sync mutation: $e');
    }
  }

  /// Retrieve up to [limit] pending mutations for sending to the backend
  static List<SyncMutation> peekBatch({int limit = 50}) {
    final list = <SyncMutation>[];
    for (final raw in _box.values) {
      try {
        list.add(SyncMutation.fromJson(raw as String));
        if (list.length >= limit) break;
      } catch (e) {
        debugPrint('Skipping unreadable sync mutation: $e');
      }
    }
    return list;
  }

  /// Dequeue successfully synced mutations by their mutationIds
  static Future<void> dequeue(Iterable<String> mutationIds) async {
    for (final id in mutationIds) {
      await _box.delete(id);
    }
  }

  /// Clear all pending mutations
  static Future<void> clear() async {
    await _box.clear();
  }

  /// Check if there is a pending mutation for [entityId] that is NOT in [exclude]
  static bool hasPendingMutationNot(String entityId, Set<String> exclude) {
    for (final raw in _box.values) {
      try {
        final mutation = SyncMutation.fromJson(raw as String);
        if (mutation.entityId == entityId && !exclude.contains(mutation.mutationId)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
