import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/presentation/auth_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/songs/presentation/editor_screen.dart';
import 'features/songs/presentation/song_detail_screen.dart';
import 'features/songs/domain/song_model.dart';

import 'features/auth/providers.dart';
import 'features/auth/presentation/profile_screen.dart';
import 'features/songs/presentation/global_search_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state but only rebuild if the session status changes (Login/Logout).
  // This prevents the router from resetting when we update user metadata (like language).
  ref.watch(
    authStateProvider.select((asyncAuth) => asyncAuth.value?.session != null),
  );

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/editor',
        builder: (context, state) => EditorScreen(song: state.extra as Song?),
      ),
      GoRoute(
        path: '/song',
        builder: (context, state) {
          final song = state.extra as Song;
          return SongDetailScreen(song: song);
        },
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    ],
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final isAuthRoute = state.uri.path == '/auth';

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/auth';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      return null;
    },
  );
});
