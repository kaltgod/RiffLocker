import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/songs/presentation/widgets/chord_renderer.dart';
import 'package:app/config/theme.dart';

void main() {
  testWidgets('ChordLyricsRenderer parses and renders correctly', (
    WidgetTester tester,
  ) async {
    const String content = "Hello [Am]world\nLine [C]Two";

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme, // Ensure correct theme for styles
        home: const Scaffold(body: ChordLyricsRenderer(content: content)),
      ),
    );

    // Verify "Am" chord is rendered
    expect(find.text('Am'), findsOneWidget);

    // Verify "world" lyric is rendered
    expect(find.text('world'), findsOneWidget);

    // Verify "Hello " is rendered (implicit split)
    expect(find.text('Hello '), findsOneWidget);

    // Verify Second line "C"
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('ChordLyricsRenderer handles complex stacking', (
    WidgetTester tester,
  ) async {
    const String content = "Nested [Em] [G]chords";

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: ChordLyricsRenderer(content: content)),
      ),
    );

    expect(find.text('Em'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('chords'), findsOneWidget);
    // "Nested "
    expect(find.text('Nested '), findsOneWidget);
  });
}
