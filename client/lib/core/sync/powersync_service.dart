import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

class PowerSyncService {
  PowerSyncService._();

  static final PowerSyncService instance = PowerSyncService._();

  PowerSyncDatabase? _db;
  bool _initialized = false;

  PowerSyncDatabase? get db => _db;
  bool get isInitialized => _initialized;

  static const schema = Schema([
    Table('sync_entities', [
      Column.text('user_id'),
      Column.text('entity_type'),
      Column.text('id'),
      Column.text('data'),
      Column.text('client_updated_at'),
      Column.integer('is_deleted'),
    ]),
  ]);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/powersync_streak.db';
      _db = PowerSyncDatabase(schema: schema, path: path);
      await _db!.initialize();
      _initialized = true;
      debugPrint('PowerSync database initialized successfully at $path');
    } catch (e) {
      debugPrint('PowerSync initialization notice: $e');
    }
  }

  Future<void> recordMutation({
    required String entityId,
    required String entityType,
    required String action,
    required String clientTimestamp,
    Map<String, dynamic>? payload,
    String? userId,
  }) async {
    if (!_initialized || _db == null) return;
    try {
      await _db!.execute(
        '''
        INSERT OR REPLACE INTO sync_entities (id, user_id, entity_type, data, client_updated_at, is_deleted)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [
          entityId,
          userId ?? 'local',
          entityType,
          payload != null ? payload.toString() : '',
          clientTimestamp,
          action == 'delete' ? 1 : 0,
        ],
      );
    } catch (e) {
      debugPrint('PowerSync recordMutation error: $e');
    }
  }
}
