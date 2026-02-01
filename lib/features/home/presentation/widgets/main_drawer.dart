import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../common/providers/locale_provider.dart';

class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primary),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_note, size: 48, color: Colors.black),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('app_title', ref),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Menu Items
          ListTile(
            leading: const Icon(Icons.library_music, color: AppTheme.primary),
            title: Text(context.tr('my_songs', ref)),
            onTap: () {
              context.pop(); // Close drawer
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.search, color: AppTheme.primary),
            title: Text(context.tr('search_songs', ref)),
            onTap: () {
              context.pop();
              context.push('/search');
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune, color: AppTheme.primary),
            title: Text(context.tr('tune_guitar', ref)),
            onTap: () {
              context.pop();
              context.push('/tuner');
            },
          ),

          const Spacer(),
          const Divider(),

          // Account Link
          ListTile(
            leading: const Icon(Icons.person, color: AppTheme.primary),
            title: Text(context.tr('account', ref)),
            onTap: () {
              context.pop();
              context.push('/profile');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
