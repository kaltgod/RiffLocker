import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/router.dart';
import 'package:app/config/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Replace with your actual Supabase coordinates
  // For the purpose of the MVP, if you don't have them yet, the app will crash on start.
  // Please update these values.
  const supabaseUrl = 'https://stnatibfanxmrbiaruhs.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN0bmF0aWJmYW54bXJiaWFydWhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3OTgyNzIsImV4cCI6MjA4NTM3NDI3Mn0.Cvro5yACuytXMuYBUcBZ2Xt8lIrPdEuljdQr9Y5wnxg';

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (e) {
    // Determine how to handle initialization failure (likely due to placebo keys)
    debugPrint('Supabase init failed: $e');
  }

  runApp(const ProviderScope(child: RiffLockerApp()));
}

class RiffLockerApp extends ConsumerWidget {
  const RiffLockerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'RiffLocker',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
