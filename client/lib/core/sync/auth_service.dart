import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:streak/core/database/local_store.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _tokenKey = 'streak_auth_token';
  static const _emailKey = 'streak_user_email';
  static const _userIdKey = 'streak_user_id';
  static const _serverUrlKey = 'streak_sync_server_url';
  static const _defaultServerUrl = 'http://localhost:3000';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _cachedToken;
  String? _cachedEmail;
  String? _cachedUserId;

  bool get isLoggedIn => _cachedToken != null && _cachedToken!.isNotEmpty;

  String? get token => _cachedToken;

  String? get userEmail => _cachedEmail;

  String? get userId => _cachedUserId;

  String get serverUrl {
    final raw = LocalStore.setting(_serverUrlKey, _defaultServerUrl).trim();
    // Normalize by stripping any trailing slashes
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> setServerUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await LocalStore.writeSetting(_serverUrlKey, clean);
  }

  Future<void> init() async {
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
      _cachedEmail = await _storage.read(key: _emailKey);
      _cachedUserId = await _storage.read(key: _userIdKey);
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
    _cachedToken = null;
    _cachedEmail = null;
    _cachedUserId = null;
    await LocalStore.writeSetting(_tokenKey, '');
    await LocalStore.writeSetting(_emailKey, '');
    await LocalStore.writeSetting(_userIdKey, '');
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _userIdKey);
    } catch (e) {
      debugPrint('Failed to delete secure storage credentials: $e');
    }
  }

  Future<void> _saveSession({
    required String token,
    required String email,
    required String userId,
  }) async {
    _cachedToken = token;
    _cachedEmail = email;
    _cachedUserId = userId;

    await LocalStore.writeSetting(_tokenKey, token);
    await LocalStore.writeSetting(_emailKey, email);
    await LocalStore.writeSetting(_userIdKey, userId);

    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _userIdKey, value: userId);
    } catch (e) {
      debugPrint('Failed to persist session to secure storage: $e');
    }
  }
}
