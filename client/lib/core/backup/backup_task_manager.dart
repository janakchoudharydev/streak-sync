import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/services/backup_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await LocalStore.init();
      final scheduleSetting = LocalStore.setting('autoBackup', 0);
      if (scheduleSetting > 0) {
        final folder = LocalStore.setting('autoBackupFolder', '');
        final readable = LocalStore.setting('readableCopy', false);
        await BackupService.runAuto(folder: folder, readable: readable);
      }
      return true;
    } catch (e) {
      debugPrint('Background backup task failed: $e');
      return false;
    }
  });
}

class BackupTaskManager {
  const BackupTaskManager._();

  static Future<void> init() async {
    if (Platform.isAndroid) {
      try {
        await Workmanager().initialize(callbackDispatcher);
      } catch (e) {
        debugPrint('Workmanager init notice: $e');
      }
    }
  }

  static Future<void> updateSchedule(int scheduleSetting) async {
    if (Platform.isAndroid) {
      try {
        if (scheduleSetting == 0) {
          await Workmanager().cancelByUniqueName('streak_auto_backup');
        } else {
          final Duration frequency = switch (scheduleSetting) {
            1 => const Duration(hours: 24),
            2 => const Duration(days: 7),
            3 => const Duration(days: 30),
            _ => const Duration(hours: 24),
          };
          await Workmanager().registerPeriodicTask(
            'streak_auto_backup',
            'streakBackupTask',
            frequency: frequency,
            existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          );
        }
      } catch (e) {
        debugPrint('Failed to schedule workmanager backup: $e');
      }
    }
  }
}
