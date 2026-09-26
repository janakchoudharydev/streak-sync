import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/inset_extensions.dart';
import 'package:streak/core/sync/auth_service.dart';
import 'package:streak/core/sync/sync_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key});

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController(text: AuthService.instance.serverUrl);
  final _supabaseUrlController = TextEditingController(text: AuthService.instance.supabaseUrl);
  final _supabaseAnonKeyController = TextEditingController(text: AuthService.instance.supabaseAnonKey);
  final _googleClientIdController = TextEditingController(text: AuthService.instance.googleClientId);

  bool _isRegistering = false;
  bool _loading = false;
  bool _showCustomServer = false;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = context.read<SyncController>().isLoggedIn;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _supabaseUrlController.dispose();
    _supabaseAnonKeyController.dispose();
    _googleClientIdController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final server = _urlController.text.trim();
    if (server.isNotEmpty) {
      await AuthService.instance.setServerUrl(server);
    }
    final clientId = _googleClientIdController.text.trim();
    await AuthService.instance.setGoogleClientId(clientId);
    final supUrl = _supabaseUrlController.text.trim();
    final supKey = _supabaseAnonKeyController.text.trim();
    if (supUrl.isNotEmpty && supKey.isNotEmpty) {
      await AuthService.instance.setSupabaseConfig(
        url: supUrl,
        anonKey: supKey,
      );
    }
  }

  Future<void> _handleGoogleSignIn(SyncController sync) async {
    final messenger = ScaffoldMessenger.of(context);
    await _saveConfig();
    if (!mounted) return;

    if (AuthService.instance.supabaseUrl.isEmpty || AuthService.instance.supabaseAnonKey.isEmpty) {
      setState(() => _showCustomServer = true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter your Supabase URL & Anon Key below first.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await sync.signInWithGoogle();
      messenger.showSnackBar(
        const SnackBar(content: Text('Opening Google Sign-In in browser...')),
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (!msg.toLowerCase().contains('cancelled')) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            action: msg.contains('configure')
                ? SnackBarAction(
                    label: 'Configure',
                    onPressed: () {
                      setState(() => _showCustomServer = true);
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAuth(SyncController sync) async {
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    if (_showCustomServer) {
      await _saveConfig();
    }

    setState(() => _loading = true);
    try {
      if (_isRegistering) {
        await sync.register(email, password);
        messenger.showSnackBar(
          const SnackBar(content: Text('Account created and logged in!')),
        );
      } else {
        await sync.login(email, password);
        messenger.showSnackBar(
          const SnackBar(content: Text('Successfully logged in!')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();

    if (!_wasLoggedIn && sync.isLoggedIn && !_loading) {
      _wasLoggedIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed in with Google! Synced smoothly.')),
          );
          Navigator.of(context).pop();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Sync')),
      body: ListView(
        padding: context.pagePadding(16, 16, 16, 104),
        children: [
          if (sync.isLoggedIn) ...[
            _buildLoggedInView(context, sync),
          ] else ...[
            _buildLoggedOutView(context, sync),
          ],
        ],
      ),
    );
  }

  Widget _buildLoggedInView(BuildContext context, SyncController sync) {
    final formattedLastSync = sync.lastSyncedAt != null && sync.lastSyncedAt!.isNotEmpty
        ? DateTime.tryParse(sync.lastSyncedAt!)?.toLocal().toString().split('.').first ?? sync.lastSyncedAt!
        : 'Never';

    final displayName = sync.displayName ?? sync.userEmail ?? 'Streak User';
    final photoUrl = sync.photoUrl;

    return Column(
      children: [
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (photoUrl != null && photoUrl.isNotEmpty)
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(photoUrl),
                        backgroundColor: context.colors.surfaceContainerHighest,
                      )
                    else
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: context.colors.primaryContainer,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: context.colors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (sync.userEmail != null && sync.userEmail != displayName)
                            Text(
                              sync.userEmail!,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.badgeCheck, color: Colors.green, size: 20),
                  ],
                ),
              ),
              settingsDivider(context),
              SettingRow(
                icon: LucideIcons.cloud,
                title: 'Status',
                subtitle: sync.isSyncing
                    ? 'Syncing in background...'
                    : 'Last synced: $formattedLastSync',
                trailing: sync.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        sync.status == SyncStatus.offline
                            ? LucideIcons.cloudOff
                            : LucideIcons.cloudCheck,
                        size: 20,
                        color: sync.status == SyncStatus.offline
                            ? context.colors.error
                            : Colors.green,
                      ),
              ),
              if (sync.pendingCount > 0) ...[
                settingsDivider(context),
                SettingRow(
                  icon: LucideIcons.clock,
                  title: 'Pending Offline Mutations',
                  subtitle: '${sync.pendingCount} local changes queued for sync',
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            icon: sync.isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.refreshCw, size: 18),
            label: Text(sync.isSyncing ? 'Syncing...' : 'Sync Now'),
            onPressed: sync.isSyncing
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await sync.triggerSync();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Sync completed successfully'
                              : 'Sync offline; will retry automatically',
                        ),
                      ),
                    );
                  },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('Log Out & Clear Device Data'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Log Out & Start Fresh?'),
                  content: const Text(
                    'Logging out will clear this device so the app starts fresh. All your habits and tasks remain safe in your Google cloud account and will restore whenever you sign in.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Log Out & Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                await sync.logout(clearLocalData: true);
                if (!context.mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Logged out and device reset to fresh state')),
                );
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedOutView(BuildContext context, SyncController sync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(icon: LucideIcons.cloud, tint: Colors.blue),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cloud Sync & Backup',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Keep your habits synced across Android, iOS, Mac, and Windows.',
                        style: TextStyle(
                          color: context.colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Standard "Sign in with Google" button
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.surfaceContainerHighest,
                foregroundColor: context.colors.onSurface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.colors.outlineVariant),
                ),
              ),
              onPressed: _loading ? null : () => _handleGoogleSignIn(sync),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sign in with Google',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Powered by Supabase Cloud Sync',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Divider(color: context.colors.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR WITH EMAIL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: context.colors.outlineVariant)),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(LucideIcons.mail, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(LucideIcons.lock, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
            if (_showCustomServer) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Custom Server URL',
                  prefixIcon: Icon(LucideIcons.server, size: 18),
                  border: OutlineInputBorder(),
                  helperText: 'e.g., https://streak-sync.onrender.com',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _supabaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Supabase URL',
                  prefixIcon: Icon(LucideIcons.database, size: 18),
                  border: OutlineInputBorder(),
                  helperText: 'e.g., https://xyzcompany.supabase.co',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _supabaseAnonKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Supabase Anon Key',
                  prefixIcon: Icon(LucideIcons.key, size: 18),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _googleClientIdController,
                decoration: const InputDecoration(
                  labelText: 'Google Client ID (macOS / Web)',
                  prefixIcon: Icon(LucideIcons.fingerprint, size: 18),
                  border: OutlineInputBorder(),
                  helperText: 'From Google Cloud Console OAuth credentials',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: const Text('Save Configuration'),
                  onPressed: () async {
                    await _saveConfig();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Configuration saved!')),
                      );
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(
                  _showCustomServer ? LucideIcons.chevronUp : LucideIcons.settings,
                  size: 14,
                ),
                label: Text(
                  _showCustomServer ? 'Hide Server / Supabase Config' : 'Configure Server / Supabase',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  setState(() => _showCustomServer = !_showCustomServer);
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : () => _submitAuth(sync),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRegistering ? 'Register & Enable Sync' : 'Sign In with Email'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() => _isRegistering = !_isRegistering);
                    },
              child: Text(
                _isRegistering
                    ? 'Already have an account? Sign In'
                    : "Don't have an account? Create One",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

