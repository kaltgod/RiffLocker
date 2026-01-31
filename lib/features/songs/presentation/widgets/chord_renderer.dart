import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/theme.dart';

class ChordLyricsRenderer extends StatelessWidget {
  final String content;
  final TextStyle? lyricStyle;
  final TextStyle? chordStyle;

  const ChordLyricsRenderer({
    super.key,
    required this.content,
    this.lyricStyle,
    this.chordStyle,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Split into lines to handle paragraphs/newlines explicitly.
    // Each line will be a Wrap widget.
    final lines = content.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _buildLine(context, line)).toList(),
    );
  }

  Widget _buildLine(BuildContext context, String line) {
    if (line.trim().isEmpty) {
      return const SizedBox(height: 16); // Paragraph spacing
    }

    final List<ChordWord> chordWords = _parseLine(line);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        alignment: WrapAlignment.start,
        runSpacing: 8, // Spacing between wrapped lines
        spacing: 0, // No extra spacing between words, they have their own
        children: chordWords.map((cw) => _buildChordWord(context, cw)).toList(),
      ),
    );
  }

  Widget _buildChordWord(BuildContext context, ChordWord cw) {
    final theme = Theme.of(context);

    // Default Styles
    final defaultLyricStyle = GoogleFonts.getFont(
      'JetBrains Mono',
      fontSize: 16,
      color: AppTheme.onSurface,
      height: 1.5,
    );

    final defaultChordStyle = GoogleFonts.getFont(
      'JetBrains Mono',
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: AppTheme.primary,
      height: 1.1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chord Line
        Text(cw.chord ?? '', style: chordStyle ?? defaultChordStyle),
        // Lyric Line
        Text(
          // If lyric is empty but chord exists, usually means a chord at end of line
          // or standalone. We might want to preserve a space if it was in source.
          cw.lyric.isEmpty ? ' ' : cw.lyric,
          style: lyricStyle ?? defaultLyricStyle,
        ),
      ],
    );
  }

  /// Parses a single line string into a list of [ChordWord].
  /// Logic: "Hello [Am]world" ->
  /// 1. "Hello " (Chord: null)
  /// 2. "world" (Chord: "Am")
  List<ChordWord> _parseLine(String line) {
    final List<ChordWord> result = [];

    // Scan string. If `[` found, capture text before as TextOnly.
    // Then capture `[...]` as Chord.
    // Then find the attachment point (next space or next bracket).

    int currentIndex = 0;

    while (currentIndex < line.length) {
      int nextBracket = line.indexOf('[', currentIndex);

      // Case A: No more chords
      if (nextBracket == -1) {
        String remaining = line.substring(currentIndex);
        result.addAll(_splitTextIntoWords(null, remaining));
        break;
      }

      // Case B: Text before the chord
      if (nextBracket > currentIndex) {
        String textBefore = line.substring(currentIndex, nextBracket);
        result.addAll(_splitTextIntoWords(null, textBefore));
      }

      // Case C: Process Chord
      int endBracket = line.indexOf(']', nextBracket);
      if (endBracket == -1) {
        // Malformed bracket, treat rest as text
        result.addAll(_splitTextIntoWords(null, line.substring(nextBracket)));
        break;
      }

      String chordRaw = line.substring(nextBracket + 1, endBracket); // "Am"
      currentIndex = endBracket + 1;

      // Now decide what text this chord attaches to.
      // We take the text up to the next SPACE or next BRACKET.

      String lookAhead = line.substring(currentIndex);

      if (lookAhead.isEmpty) {
        // Trailing chord
        result.add(ChordWord(chord: chordRaw, lyric: ''));
        continue;
      }

      int nextChordStart = lookAhead.indexOf('[');
      int nextSpace = lookAhead.indexOf(' ');

      int cutIndex = -1;

      // Determine the cut index for the "Atom"
      if (nextSpace != -1 &&
          (nextChordStart == -1 || nextSpace < nextChordStart)) {
        // Cut inclusive of the space, so "Word " stays together
        cutIndex = nextSpace + 1;
      } else if (nextChordStart != -1) {
        // Next chord comes first, so we cut right before it
        cutIndex = nextChordStart;
      } else {
        // End of line
        cutIndex = lookAhead.length;
      }

      // Special Case: Stacked Chords "[Am][C]"
      if (cutIndex == 0) {
        // Attaches to nothing (empty string)
        result.add(ChordWord(chord: chordRaw, lyric: ''));
        continue;
      }

      String attachedText = lookAhead.substring(0, cutIndex);
      result.add(ChordWord(chord: chordRaw, lyric: attachedText));
      currentIndex += attachedText.length;
    }

    return result;
  }

  /// Splits plain text into words (preserving spaces) so they can wrap.
  List<ChordWord> _splitTextIntoWords(String? chord, String text) {
    if (text.isEmpty) return [];

    final List<ChordWord> list = [];

    // Regex to split by whitespace but keep the whitespace attached to the preceding word.
    // e.g. "Hello world " -> ["Hello ", "world "]
    RegExp wordRegex = RegExp(r'([^\s]+)(\s*)');
    final matches = wordRegex.allMatches(text);

    int lastMatchEnd = 0;

    // Handle leading whitespace if any (e.g. indentation)
    if (matches.isNotEmpty && matches.first.start > 0) {
      String leadingSpace = text.substring(0, matches.first.start);
      list.add(ChordWord(chord: null, lyric: leadingSpace));
      lastMatchEnd = matches.first.start;
    }

    for (final m in matches) {
      // Double check for gaps (shouldn't happen with this regex if no leading space)
      if (m.start > lastMatchEnd) {
        String gap = text.substring(lastMatchEnd, m.start);
        list.add(ChordWord(chord: null, lyric: gap));
      }

      String word = m.group(1)!;
      String space = m.group(2) ?? '';
      list.add(ChordWord(chord: null, lyric: word + space));
      lastMatchEnd = m.end;
    }

    // Residuals
    if (lastMatchEnd < text.length) {
      list.add(ChordWord(chord: null, lyric: text.substring(lastMatchEnd)));
    }

    // If no matches (e.g. only whitespace "   "), handle it
    if (list.isEmpty && text.isNotEmpty) {
      list.add(ChordWord(chord: null, lyric: text));
    }

    return list;
  }
}

class ChordWord {
  final String? chord;
  final String lyric;

  ChordWord({this.chord, required this.lyric});
}
