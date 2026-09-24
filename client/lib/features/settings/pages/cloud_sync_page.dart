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

  bool _isRegistering = false;
  bool _loading = false;
  bool _showCustomServer = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
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
      await AuthService.instance.setServerUrl(_urlController.text.trim());
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

    return Column(
      children: [
        Card(
          child: Column(
            children: [
              SettingRow(
                icon: LucideIcons.user,
                title: 'Account',
                subtitle: sync.userEmail ?? 'Unknown user',
                trailing: const Icon(LucideIcons.check, color: Colors.green, size: 18),
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
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('Log Out'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await sync.logout();
              messenger.showSnackBar(
                const SnackBar(content: Text('Logged out of cloud sync')),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            icon: const Icon(LucideIcons.trash2, size: 16),
            label: const Text('Log Out & Clear Local Data'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Log Out & Clear Device Data?'),
                  content: const Text(
                    'This will remove all habits and tasks from this device and return the app to a fresh, clean state. Your data stored on the cloud will remain safe.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Clear & Log Out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                final messenger = ScaffoldMessenger.of(context);
                await sync.logout(clearLocalData: true);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Device data cleared and logged out')),
                );
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
                      Text(
                        _isRegistering ? 'Create Account' : 'Sign In to Sync',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            const SizedBox(height: 20),
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
                  helperText: 'e.g., https://your-streak-sync.vercel.app',
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
                  _showCustomServer ? 'Hide Server URL' : 'Configure Server URL',
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
                  : Text(_isRegistering ? 'Register & Enable Sync' : 'Sign In'),
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
