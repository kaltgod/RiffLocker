import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../common/providers/locale_provider.dart';
import '../../home/presentation/widgets/main_drawer.dart';
import '../../auth/presentation/widgets/change_password_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/auth');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = user?.isAnonymous ?? true;

    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: context.tr('menu_tooltip', ref),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(context.tr('account', ref)),
        actions: [
          // Language Switcher Dropdown
          DropdownButton<String>(
            value: ref.watch(localeProvider).languageCode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ru', child: Text('Русский')),
              DropdownMenuItem(value: 'zh', child: Text('中文')),
            ],
            onChanged: (val) {
              if (val != null) {
                ref.read(localeProvider.notifier).setLocale(Locale(val));
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primary,
                    child: Icon(Icons.person, size: 40, color: Colors.black),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isGuest ? 'Guest User' : (user?.email ?? 'Unknown'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (isGuest) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Sign up to save your songs to the cloud!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          if (!isGuest)
            ListTile(
              leading: const Icon(Icons.lock),
              title: Text(context.tr('change_password', ref)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const ChangePasswordDialog(),
                );
              },
            ),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              context.tr('logout', ref),
              style: const TextStyle(color: Colors.red),
            ),
            onTap: _isLoading ? null : _signOut,
            trailing: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
