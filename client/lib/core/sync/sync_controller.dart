import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/sync/auth_service.dart';
import 'package:streak/core/sync/sync_queue.dart';
import 'package:streak/core/sync/sync_worker.dart';

enum SyncStatus { idle, syncing, offline, error }

class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  SyncController({this.onRemoteDataChanged}) {
    _init();
    WidgetsBinding.instance.addObserver(this);
  }

  final VoidCallback? onRemoteDataChanged;
  SyncStatus _status = SyncStatus.idle;
  Timer? _periodicTimer;
  Timer? _autoSyncDebounce;
  StreamSubscription? _connectivitySubscription;

  SyncStatus get status => _status;
  bool get isSyncing => _status == SyncStatus.syncing || SyncWorker.isSyncing;
  bool get isLoggedIn => AuthService.instance.isLoggedIn;
  String? get userEmail => AuthService.instance.userEmail;
  String? get displayName => AuthService.instance.displayName;
  String? get photoUrl => AuthService.instance.photoUrl;
  String? get lastSyncedAt => SyncWorker.lastSyncedAt;
  int get pendingCount => SyncQueue.count;

  void _onMutationEnqueued() {
    notifyListeners();
    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = Timer(const Duration(milliseconds: 600), () {
      if (isLoggedIn && !isSyncing) {
        triggerSync();
      }
    });
  }

  Future<void> _init() async {
    await AuthService.instance.init();
    SyncQueue.onMutationEnqueued = _onMutationEnqueued;
    AuthService.instance.onAuthStateChanged = () async {
      notifyListeners();
      if (isLoggedIn && !isSyncing) {
        onRemoteDataChanged?.call();
        await triggerSync();
        onRemoteDataChanged?.call();
      } else if (!isLoggedIn) {
        onRemoteDataChanged?.call();
      }
    };

    // Use connectivity_plus to flush queues only when network is restored
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (isConnected && isLoggedIn && !isSyncing && SyncQueue.isNotEmpty) {
        triggerSync();
      }
    });

    notifyListeners();

    if (isLoggedIn) {
      // Trigger non-blocking background sync on initialization
      triggerSync();
      // Periodically sync every 5 minutes
      _periodicTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => triggerSync(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isLoggedIn && !isSyncing) {
        triggerSync();
      }
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

  Future<void> signInWithGoogle() async {
    _status = SyncStatus.syncing;
    notifyListeners();
    try {
      await AuthService.instance.signInWithGoogle();
      _status = SyncStatus.idle;
      notifyListeners();
      await triggerSync();
    } catch (e) {
      _status = SyncStatus.error;
      notifyListeners();
      rethrow;
    }
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

  Future<void> logout({bool clearLocalData = true}) async {
    await AuthService.instance.logout();
    _periodicTimer?.cancel();
    _status = SyncStatus.idle;
    if (clearLocalData) {
      await LocalStore.wipeContent();
      await LocalStore.writeSetting('cloud_initial_seed_done', false);
      await LocalStore.writeSetting('streak_last_synced_at', '');
      onRemoteDataChanged?.call();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _autoSyncDebounce?.cancel();
    if (SyncQueue.onMutationEnqueued == _onMutationEnqueued) {
      SyncQueue.onMutationEnqueued = null;
    }
    _periodicTimer?.cancel();
    super.dispose();
  }
}

