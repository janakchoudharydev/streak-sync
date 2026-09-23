import 'dart:async';
import 'package:flutter/material.dart';
import 'package:streak/core/sync/auth_service.dart';
import 'package:streak/core/sync/sync_queue.dart';
import 'package:streak/core/sync/sync_worker.dart';

enum SyncStatus { idle, syncing, offline, error }

class SyncController extends ChangeNotifier {
  SyncController({this.onRemoteDataChanged}) {
    _init();
  }

  final VoidCallback? onRemoteDataChanged;
  SyncStatus _status = SyncStatus.idle;
  Timer? _periodicTimer;

  SyncStatus get status => _status;
  bool get isSyncing => _status == SyncStatus.syncing || SyncWorker.isSyncing;
  bool get isLoggedIn => AuthService.instance.isLoggedIn;
  String? get userEmail => AuthService.instance.userEmail;
  String? get lastSyncedAt => SyncWorker.lastSyncedAt;
  int get pendingCount => SyncQueue.count;

  Future<void> _init() async {
    await AuthService.instance.init();
    notifyListeners();

    if (isLoggedIn) {
      // Trigger background sync on initialization
      triggerSync();
      // Periodically sync every 5 minutes
      _periodicTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => triggerSync(),
      );
    }
  }

  Future<bool> triggerSync() async {
    if (!isLoggedIn) return false;
    _status = SyncStatus.syncing;
    notifyListeners();

    final success = await SyncWorker.sync(
      onDataChanged: () {
        onRemoteDataChanged?.call();
        notifyListeners();
      },
    );

    _status = success ? SyncStatus.idle : SyncStatus.offline;
    notifyListeners();
    return success;
  }

  Future<void> login(String email, String password) async {
    _status = SyncStatus.syncing;
    notifyListeners();
    try {
      await AuthService.instance.login(email, password);
      _status = SyncStatus.idle;
      notifyListeners();
      await triggerSync();
    } catch (e) {
      _status = SyncStatus.error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> register(String email, String password) async {
    _status = SyncStatus.syncing;
    notifyListeners();
    try {
      await AuthService.instance.register(email, password);
      _status = SyncStatus.idle;
      notifyListeners();
      await triggerSync();
    } catch (e) {
      _status = SyncStatus.error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    _periodicTimer?.cancel();
    _status = SyncStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
