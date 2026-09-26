import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streak/core/database/local_store.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _tokenKey = 'streak_auth_token';
  static const _emailKey = 'streak_user_email';
  static const _userIdKey = 'streak_user_id';
  static const _displayNameKey = 'streak_user_display_name';
  static const _photoUrlKey = 'streak_user_photo_url';
  static const _idTokenKey = 'streak_id_token';
  static const _accessTokenKey = 'streak_access_token';
  static const _serverUrlKey = 'streak_sync_server_url';
  static const _supabaseUrlKey = 'streak_supabase_url';
  static const _supabaseAnonKey = 'streak_supabase_anon_key';
  static const _googleClientIdKey = 'streak_google_client_id';
  static const _providerTokenKey = 'streak_google_provider_token';
  static const _defaultServerUrl = 'https://streak-sync.onrender.com';
  static const _defaultSupabaseUrl = 'https://bstgzyaxxwebgprbbcsp.supabase.co';
  static const _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdGd6eWF4eHdlYmdwcmJiY3NwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5NTc2MDMsImV4cCI6MjA4NzUzMzYwM30.eRZu3CrgE0ZdjrLPPjciDkVGlFuDg64gLrX5BFa4k90';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _cachedToken;
  String? _cachedEmail;
  String? _cachedUserId;
  String? _cachedDisplayName;
  String? _cachedPhotoUrl;
  String? _cachedIdToken;
  String? _cachedAccessToken;
  String? _cachedProviderToken;
  bool _supabaseInitialized = false;
  VoidCallback? onAuthStateChanged;

  bool get isLoggedIn => _cachedToken != null && _cachedToken!.isNotEmpty;

  String? get token => _cachedToken;

  String? get userEmail => _cachedEmail;

  String? get userId => _cachedUserId;

  String? get displayName => _cachedDisplayName;

  String? get photoUrl => _cachedPhotoUrl;

  String? get idToken => _cachedIdToken;

  String? get accessToken => _cachedAccessToken;

  String? get googleAccessToken =>
      _cachedProviderToken ??
      Supabase.instance.client.auth.currentSession?.providerToken ??
      _cachedAccessToken;

  bool get isSupabaseInitialized => _supabaseInitialized;

  String get googleClientId =>
      LocalStore.setting<String>(_googleClientIdKey, '').trim();

  Future<void> setGoogleClientId(String clientId) async {
    await LocalStore.writeSetting(_googleClientIdKey, clientId.trim());
  }

  String get supabaseUrl {
    final val = LocalStore.setting<String>(_supabaseUrlKey, _defaultSupabaseUrl).trim();
    return val.isNotEmpty ? val : _defaultSupabaseUrl;
  }

  String get supabaseAnonKey {
    final val = LocalStore.setting<String>(_supabaseAnonKey, _defaultSupabaseAnonKey).trim();
    return val.isNotEmpty ? val : _defaultSupabaseAnonKey;
  }

  Future<void> setSupabaseConfig({required String url, required String anonKey}) async {
    await LocalStore.writeSetting(_supabaseUrlKey, url.trim());
    await LocalStore.writeSetting(_supabaseAnonKey, anonKey.trim());
    await initSupabase();
  }

  String get serverUrl {
    var raw = LocalStore.setting(_serverUrlKey, _defaultServerUrl).trim();
    if (raw.isEmpty || raw == 'http://localhost:3000' || raw.contains('your-service.onrender.com')) {
      raw = _defaultServerUrl;
    }
    // Normalize by stripping any trailing slashes
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> setServerUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await LocalStore.writeSetting(_serverUrlKey, clean);
  }

  Future<void> initSupabase() async {
    final url = supabaseUrl;
    final anonKey = supabaseAnonKey;
    if (url.isNotEmpty && anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: url,
          // ignore: deprecated_member_use
          anonKey: anonKey,
          debug: kDebugMode,
        );
        _supabaseInitialized = true;
        _listenToSupabaseAuth();
      } catch (e) {
        debugPrint('Supabase initialize info: $e');
        _supabaseInitialized = true;
      }
    }
  }

  void _listenToSupabaseAuth() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        final user = session?.user;
        if (user != null && (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed)) {
          final meta = user.userMetadata;
          final displayName = meta?['full_name'] as String? ??
              meta?['name'] as String? ??
              user.email ??
              '';
          final photoUrl = meta?['avatar_url'] as String? ??
              meta?['picture'] as String? ??
              '';
          await _saveSession(
            token: session?.accessToken ?? user.id,
            email: user.email ?? '',
            userId: user.id,
            displayName: displayName,
            photoUrl: photoUrl,
            providerToken: session?.providerToken,
          );
        }
      });
    } catch (e) {
      debugPrint('Supabase auth listener setup: $e');
    }
  }

  Future<void> init() async {
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
      _cachedEmail = await _storage.read(key: _emailKey);
      _cachedUserId = await _storage.read(key: _userIdKey);
      _cachedDisplayName = await _storage.read(key: _displayNameKey);
      _cachedPhotoUrl = await _storage.read(key: _photoUrlKey);
      _cachedIdToken = await _storage.read(key: _idTokenKey);
      _cachedAccessToken = await _storage.read(key: _accessTokenKey);
      _cachedProviderToken = await _storage.read(key: _providerTokenKey);
    } catch (e) {
      debugPrint('Failed to read secure storage: $e');
    }
    // Fallback to local settings store if secure storage is empty or unavailable
    _cachedToken ??= LocalStore.setting<String>(_tokenKey, '');
    if (_cachedToken!.isEmpty) _cachedToken = null;
    _cachedEmail ??= LocalStore.setting<String>(_emailKey, '');
    if (_cachedEmail!.isEmpty) _cachedEmail = null;
    _cachedUserId ??= LocalStore.setting<String>(_userIdKey, '');
    if (_cachedUserId!.isEmpty) _cachedUserId = null;
    _cachedDisplayName ??= LocalStore.setting<String>(_displayNameKey, '');
    if (_cachedDisplayName!.isEmpty) _cachedDisplayName = null;
    _cachedPhotoUrl ??= LocalStore.setting<String>(_photoUrlKey, '');
    if (_cachedPhotoUrl!.isEmpty) _cachedPhotoUrl = null;
    _cachedProviderToken ??= LocalStore.setting<String>(_providerTokenKey, '');
    if (_cachedProviderToken!.isEmpty) _cachedProviderToken = null;

    await initSupabase();
  }

  Future<void> signInWithGoogle() async {
    final clientId = googleClientId;
    final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    if (_supabaseInitialized) {
      // Safe, cross-platform OAuth web redirect via Supabase
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.streak://login-callback/',
      );
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final meta = user.userMetadata;
        final displayName = meta?['full_name'] as String? ?? meta?['name'] as String? ?? user.email ?? '';
        final photoUrl = meta?['avatar_url'] as String? ?? meta?['picture'] as String? ?? '';
        await _saveSession(
          token: Supabase.instance.client.auth.currentSession?.accessToken ?? user.id,
          email: user.email ?? '',
          userId: user.id,
          displayName: displayName,
          photoUrl: photoUrl,
          providerToken: Supabase.instance.client.auth.currentSession?.providerToken,
        );
      }
      return;
    }

    if (isDesktop && clientId.isEmpty) {
      throw Exception(
        'To sign in with Google, please configure your Supabase URL & Anon Key in "Configure Server / Supabase".',
      );
    }

    final googleSignIn = GoogleSignIn(
      clientId: clientId.isNotEmpty ? clientId : null,
      scopes: [
        'email',
        'profile',
      ],
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google Sign-In was cancelled');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;

    String userId = account.id;
    String email = account.email;
    String displayName = account.displayName ?? '';
    String photoUrl = account.photoUrl ?? '';

    // If Supabase is configured and initialized, authenticate with Supabase OIDC
    if (_supabaseInitialized && idToken != null) {
      try {
        final res = await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        if (res.user != null) {
          userId = res.user!.id;
          email = res.user!.email ?? email;
          final meta = res.user!.userMetadata;
          if (meta != null) {
            displayName = meta['full_name'] as String? ??
                meta['name'] as String? ??
                displayName;
            photoUrl = meta['avatar_url'] as String? ??
                meta['picture'] as String? ??
                photoUrl;
          }
        }
      } catch (e) {
        debugPrint('Supabase signInWithIdToken warning: $e');
      }
    }

    await _saveSession(
      token: idToken ?? accessToken ?? 'google_${account.id}',
      email: email,
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> register(String email, String password) async {
    final uri = Uri.parse('$serverUrl/api/auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    Map<String, dynamic>? data;
    try {
      if (response.body.isNotEmpty) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {}

    if (response.statusCode != 201) {
      throw Exception(data?['error'] ?? 'Registration failed (HTTP ${response.statusCode})');
    }
    if (data == null) {
      throw Exception('Invalid server response (HTTP ${response.statusCode})');
    }

    await _saveSession(
      token: data['token'] as String,
      email: data['user']['email'] as String,
      userId: data['user']['id'] as String,
    );
  }

  Future<void> login(String email, String password) async {
    final uri = Uri.parse('$serverUrl/api/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    Map<String, dynamic>? data;
    try {
      if (response.body.isNotEmpty) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {}

    if (response.statusCode != 200) {
      throw Exception(data?['error'] ?? 'Login failed (HTTP ${response.statusCode})');
    }
    if (data == null) {
      throw Exception('Invalid server response (HTTP ${response.statusCode})');
    }

    await _saveSession(
      token: data['token'] as String,
      email: data['user']['email'] as String,
      userId: data['user']['id'] as String,
    );
  }

  Future<void> logout() async {
    try {
      if (_supabaseInitialized) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}

    final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    if (!isDesktop || googleClientId.isNotEmpty) {
      try {
        await GoogleSignIn(clientId: googleClientId.isNotEmpty ? googleClientId : null).signOut();
      } catch (_) {}
    }

    _cachedToken = null;
    _cachedEmail = null;
    _cachedUserId = null;
    _cachedDisplayName = null;
    _cachedPhotoUrl = null;
    _cachedIdToken = null;
    _cachedAccessToken = null;
    _cachedProviderToken = null;

    // Reset all local content and sync flags so the app starts completely fresh
    await LocalStore.wipeContent();
    await LocalStore.writeSetting('cloud_initial_seed_done', false);
    await LocalStore.writeSetting('streak_last_synced_at', '');

    await LocalStore.writeSetting(_tokenKey, '');
    await LocalStore.writeSetting(_emailKey, '');
    await LocalStore.writeSetting(_userIdKey, '');
    await LocalStore.writeSetting(_displayNameKey, '');
    await LocalStore.writeSetting(_photoUrlKey, '');
    await LocalStore.writeSetting(_idTokenKey, '');
    await LocalStore.writeSetting(_accessTokenKey, '');
    await LocalStore.writeSetting(_providerTokenKey, '');
    await LocalStore.writeSetting('lastCloudSyncAt', '');

    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _userIdKey);
      await _storage.delete(key: _displayNameKey);
      await _storage.delete(key: _photoUrlKey);
      await _storage.delete(key: _idTokenKey);
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _providerTokenKey);
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Failed to delete secure storage credentials: $e');
    }

    onAuthStateChanged?.call();
  }

  Future<void> _saveSession({
    required String token,
    required String email,
    required String userId,
    String? displayName,
    String? photoUrl,
    String? idToken,
    String? accessToken,
    String? providerToken,
  }) async {
    _cachedToken = token;
    _cachedEmail = email;
    _cachedUserId = userId;
    _cachedDisplayName = displayName;
    _cachedPhotoUrl = photoUrl;
    _cachedIdToken = idToken;
    _cachedAccessToken = accessToken;
    if (providerToken != null && providerToken.isNotEmpty) {
      _cachedProviderToken = providerToken;
    }

    await LocalStore.writeSetting(_tokenKey, token);
    await LocalStore.writeSetting(_emailKey, email);
    await LocalStore.writeSetting(_userIdKey, userId);
    if (displayName != null) {
      await LocalStore.writeSetting(_displayNameKey, displayName);
      if (displayName.isNotEmpty) {
        await LocalStore.writeSetting('profileName', displayName);
      }
    }
    if (photoUrl != null) {
      await LocalStore.writeSetting(_photoUrlKey, photoUrl);
      if (photoUrl.isNotEmpty) {
        await LocalStore.writeSetting('profilePhoto', photoUrl);
      }
    }
    if (idToken != null) {
      await LocalStore.writeSetting(_idTokenKey, idToken);
    }
    if (accessToken != null) {
      await LocalStore.writeSetting(_accessTokenKey, accessToken);
    }
    if (providerToken != null && providerToken.isNotEmpty) {
      await LocalStore.writeSetting(_providerTokenKey, providerToken);
    }

    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _userIdKey, value: userId);
      if (displayName != null) {
        await _storage.write(key: _displayNameKey, value: displayName);
      }
      if (photoUrl != null) {
        await _storage.write(key: _photoUrlKey, value: photoUrl);
      }
      if (idToken != null) {
        await _storage.write(key: _idTokenKey, value: idToken);
      }
      if (accessToken != null) {
        await _storage.write(key: _accessTokenKey, value: accessToken);
      }
      if (providerToken != null && providerToken.isNotEmpty) {
        await _storage.write(key: _providerTokenKey, value: providerToken);
      }
    } catch (e) {
      debugPrint('Failed to persist session to secure storage: $e');
    }

    onAuthStateChanged?.call();
  }
}

