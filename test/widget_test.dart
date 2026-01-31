import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/auth/presentation/auth_screen.dart';
import 'package:app/config/theme.dart';

void main() {
  testWidgets('AuthScreen renders correctly', (WidgetTester tester) async {
    // Build AuthScreen wrapped in ProviderScope and MaterialApp
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.darkTheme, home: const AuthScreen()),
      ),
    );

    // Verify logo/text presence
    expect(find.text('RiffLocker'), findsOneWidget);
    expect(find.text('Your ultimate songbook.'), findsOneWidget);

    // Verify buttons
    expect(find.text('Sign in with Email'), findsOneWidget);
    expect(find.text('Enter as Guest'), findsOneWidget);

    // Check input field
    expect(find.byType(TextField), findsOneWidget);
  });
}
