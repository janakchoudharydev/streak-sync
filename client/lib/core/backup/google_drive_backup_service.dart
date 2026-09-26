import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/sync/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class GoogleDriveBackupService {
  GoogleDriveBackupService._();

  static final GoogleDriveBackupService instance = GoogleDriveBackupService._();

  static const _lastDriveBackupKey = 'lastGoogleDriveBackupAt';
  static const _driveBackupEnabledKey = 'googleDriveBackupEnabled';
  static const _kMaxDriveBackups = 5;

  bool get isDriveBackupEnabled =>
      LocalStore.setting<bool>(_driveBackupEnabledKey, false);

  Future<void> setDriveBackupEnabled(bool enabled) async {
    await LocalStore.writeSetting(_driveBackupEnabledKey, enabled);
  }

  String? get lastBackupTimestamp =>
      LocalStore.setting<String>(_lastDriveBackupKey, '');

  DateTime? get lastBackupDate {
    final str = lastBackupTimestamp;
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str)?.toLocal();
  }

  List<int> createZipBackup() {
    final habits = LocalStore.readHabits().values.toList();
    final notes = LocalStore.readNotes().map((n) => n.toMap()).toList();
    final focus = LocalStore.readFocusSessions().map((f) => f.toMap()).toList();
    final todos = LocalStore.readTodos().map((t) => t.toMap()).toList();
    final todoTags = LocalStore.readTodoTags().map((t) => t.toMap()).toList();
    final categories = LocalStore.readCategories().map((c) => c.toMap()).toList();

    final payload = {
      'app': 'streak',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'habits': habits.map((h) => h.toMap()).toList(),
      'notes': notes,
      'focus': focus,
      'todos': todos,
      'todoTags': todoTags,
      'categories': categories,
    };

    final jsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(payload));

    final archive = Archive();
    archive.addFile(ArchiveFile('streak_backup.json', jsonBytes.length, jsonBytes));

    final zipData = ZipEncoder().encode(archive);
    return zipData ?? const <int>[];
  }

  Future<bool> uploadBackup({bool force = false}) async {
    try {
      final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
      String? accessToken;

      // 1. Try Supabase session providerToken (works seamlessly on desktop and web)
      final supabaseSession = Supabase.instance.client.auth.currentSession;
      if (supabaseSession?.providerToken != null && supabaseSession!.providerToken!.isNotEmpty) {
        accessToken = supabaseSession.providerToken;
      }
      accessToken ??= AuthService.instance.googleAccessToken;

      // 2. Try native GoogleSignIn on platforms that support it (Android/iOS or desktop with client ID)
      final clientId = AuthService.instance.googleClientId;
      if (accessToken == null || accessToken.isEmpty) {
        if (!isDesktop || clientId.isNotEmpty) {
          try {
            final googleSignIn = GoogleSignIn(
              clientId: clientId.isNotEmpty ? clientId : null,
              scopes: [
                'email',
                'profile',
                'https://www.googleapis.com/auth/drive.appdata',
              ],
            );

            var account = googleSignIn.currentUser;
            account ??= await googleSignIn.signInSilently();
            if (account == null && force) {
              account = await googleSignIn.signIn();
            }
            if (account != null) {
              final auth = await account.authentication;
              accessToken = auth.accessToken;
            }
          } catch (e) {
            debugPrint('Native GoogleSignIn note: $e');
          }
        }
      }

      // 3. If force is requested and still no access token, initiate Google OAuth with Drive scope
      if ((accessToken == null || accessToken.isEmpty) && force) {
        await AuthService.instance.signInWithGoogle();
        accessToken = Supabase.instance.client.auth.currentSession?.providerToken ??
            AuthService.instance.googleAccessToken;
      }

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('Google Drive backup skipped: No Google access token available');
        return false;
      }

      final authClient = _GoogleAuthClient({'Authorization': 'Bearer $accessToken'});

      try {
        final driveApi = drive.DriveApi(authClient);
        final zipBytes = createZipBackup();

        final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
        final fileName = 'streak_backup_$stamp.zip';

        final fileMetadata = drive.File()
          ..name = fileName
          ..parents = ['appDataFolder']
          ..mimeType = 'application/zip';

        final media = drive.Media(
          Stream.value(zipBytes),
          zipBytes.length,
          contentType: 'application/zip',
        );

        final uploadedFile = await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );

        debugPrint('Successfully uploaded backup to Drive appDataFolder: ${uploadedFile.id}');

        await LocalStore.writeSetting(
          _lastDriveBackupKey,
          DateTime.now().toUtc().toIso8601String(),
        );

        // Prune older backups in appDataFolder (keep latest 5)
        await _pruneOldBackups(driveApi);

        return true;
      } on drive.DetailedApiRequestError catch (apiErr) {
        debugPrint('Google Drive API error (${apiErr.status}): ${apiErr.message}');
        if ((apiErr.status == 401 || apiErr.status == 403) && force) {
          // Token expired or missing drive.appdata scope; re-authenticate
          await AuthService.instance.signInWithGoogle();
        }
        return false;
      } finally {
        authClient.close();
      }
    } catch (e) {
      debugPrint('Google Drive backup error: $e');
      return false;
    }
  }

  Future<void> _pruneOldBackups(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "mimeType = 'application/zip' and name contains 'streak_backup_'",
        orderBy: 'createdTime desc',
        $fields: 'files(id, name, createdTime)',
      );

      final files = fileList.files;
      if (files != null && files.length > _kMaxDriveBackups) {
        for (var i = _kMaxDriveBackups; i < files.length; i++) {
          final fileId = files[i].id;
          if (fileId != null) {
            await driveApi.files.delete(fileId);
            debugPrint('Pruned old Google Drive backup: $fileId');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to prune old Google Drive backups: $e');
    }
  }

  /// Evaluates whether an automated backup should execute based on the user's schedule
  bool shouldRunBackup(int scheduleSetting) {
    if (scheduleSetting == 0) return false; // Off
    final last = lastBackupDate;
    if (last == null) return true;

    final now = DateTime.now();
    final difference = now.difference(last);

    return switch (scheduleSetting) {
      1 => difference.inHours >= 24, // Daily
      2 => difference.inDays >= 7,    // Weekly
      3 => difference.inDays >= 30,   // Monthly
      _ => false,
    };
  }
}
