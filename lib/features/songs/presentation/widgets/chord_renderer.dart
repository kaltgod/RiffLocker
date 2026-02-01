import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import 'chord_transposer.dart';

class ChordLyricsRenderer extends StatelessWidget {
  final String content;
  final int transpose;
  final TextStyle? textStyle;
  final TextStyle? chordStyle;

  const ChordLyricsRenderer({
    super.key,
    required this.content,
    this.transpose = 0,
    this.textStyle,
    this.chordStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Clean content from invisible/control characters
    final cleanContent = content
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    final lines = cleanContent.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _buildLine(context, line)).toList(),
    );
  }

  Widget _buildLine(BuildContext context, String line) {
    // If line has no chords, just return text
    if (!line.contains('[')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          line,
          style:
              textStyle ??
              Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5, color: Colors.white),
        ),
      );
    }

    // Parse chords and lyrics
    final List<Widget> children = [];
    final regex = RegExp(r'\[(.*?)\]([^\[]*)');

    // Check if line starts with text before first chord
    final firstBracket = line.indexOf('[');
    if (firstBracket > 0) {
      children.add(_buildChunk(context, null, line.substring(0, firstBracket)));
    }

    final matches = regex.allMatches(line);
    for (final match in matches) {
      final chord = match.group(1) ?? '';
      final lyric = match.group(2) ?? '';
      children.add(_buildChunk(context, chord, lyric));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: children,
      ),
    );
  }

  Widget _buildChunk(BuildContext context, String? chord, String text) {
    final transposedChord = chord != null
        ? ChordTransposer.transpose(chord, transpose)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (transposedChord != null)
          Text(
            transposedChord,
            style:
                chordStyle ??
                const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  fontSize: 14,
                ),
          ),
        Text(
          text.isEmpty
              ? ' '
              : text, // Ensure spacing if lyric is empty but chord exists
          style:
              textStyle ??
              Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5, color: Colors.white),
        ),
      ],
    );
  }
}
