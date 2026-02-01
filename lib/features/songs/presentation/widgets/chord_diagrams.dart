import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import 'chord_transposer.dart';

/// Extracts unique chords from song content and displays their diagrams
class ChordDiagramsSection extends StatelessWidget {
  final String content;
  final int transpose;

  const ChordDiagramsSection({
    super.key,
    required this.content,
    this.transpose = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Extract all chords from content
    final chords = _extractChords(content);
    if (chords.isEmpty) return const SizedBox.shrink();

    // Apply transpose
    final transposedChords = chords
        .map((c) => ChordTransposer.transpose(c, transpose))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Аккорды',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: transposedChords
              .map((chord) => _ChordDiagram(chord: chord))
              .toList(),
        ),
      ],
    );
  }

  /// Extract unique chords from ChordPro format text
  List<String> _extractChords(String text) {
    final regex = RegExp(
      r'\[([A-Ga-g][#b]?m?(?:aj|in)?(?:7|9|11|13|sus[24]?|add[29]?|dim|aug)?(?:/[A-Ga-g][#b]?)?)\]',
    );
    final matches = regex.allMatches(text);
    final chords = <String>{};
    for (final match in matches) {
      chords.add(match.group(1)!);
    }
    return chords.toList();
  }
}

/// Individual chord diagram widget
class _ChordDiagram extends StatelessWidget {
  final String chord;

  const _ChordDiagram({required this.chord});

  @override
  Widget build(BuildContext context) {
    final fingering = _getChordFingering(chord);

    return Container(
      width: 70,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Chord name
          Text(
            chord,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          // Fretboard diagram
          SizedBox(
            width: 50,
            height: 60,
            child: CustomPaint(
              painter: _FretboardPainter(fingering: fingering),
            ),
          ),
        ],
      ),
    );
  }

  /// Get fingering pattern for chord (6 strings, -1 = muted, 0 = open, 1+ = fret)
  List<int> _getChordFingering(String chord) {
    // Normalize chord name
    final normalized = chord.replaceAll('♯', '#').replaceAll('♭', 'b');

    // Common guitar chord fingerings (E A D G B e)
    final chordDb = <String, List<int>>{
      // Major chords
      'C': [-1, 3, 2, 0, 1, 0],
      'D': [-1, -1, 0, 2, 3, 2],
      'E': [0, 2, 2, 1, 0, 0],
      'F': [1, 3, 3, 2, 1, 1],
      'G': [3, 2, 0, 0, 0, 3],
      'A': [-1, 0, 2, 2, 2, 0],
      'B': [-1, 2, 4, 4, 4, 2],

      // Minor chords
      'Am': [-1, 0, 2, 2, 1, 0],
      'Bm': [-1, 2, 4, 4, 3, 2],
      'Cm': [-1, 3, 5, 5, 4, 3],
      'Dm': [-1, -1, 0, 2, 3, 1],
      'Em': [0, 2, 2, 0, 0, 0],
      'Fm': [1, 3, 3, 1, 1, 1],
      'Gm': [3, 5, 5, 3, 3, 3],

      // 7th chords
      'A7': [-1, 0, 2, 0, 2, 0],
      'B7': [-1, 2, 1, 2, 0, 2],
      'C7': [-1, 3, 2, 3, 1, 0],
      'D7': [-1, -1, 0, 2, 1, 2],
      'E7': [0, 2, 0, 1, 0, 0],
      'F7': [1, 3, 1, 2, 1, 1],
      'G7': [3, 2, 0, 0, 0, 1],

      // Sharp/flat variants
      'C#': [-1, 4, 3, 1, 2, 1],
      'Db': [-1, 4, 3, 1, 2, 1],
      'D#': [-1, -1, 1, 3, 4, 3],
      'Eb': [-1, -1, 1, 3, 4, 3],
      'F#': [2, 4, 4, 3, 2, 2],
      'Gb': [2, 4, 4, 3, 2, 2],
      'G#': [4, 6, 6, 5, 4, 4],
      'Ab': [4, 6, 6, 5, 4, 4],
      'A#': [-1, 1, 3, 3, 3, 1],
      'Bb': [-1, 1, 3, 3, 3, 1],

      'C#m': [-1, 4, 6, 6, 5, 4],
      'Dbm': [-1, 4, 6, 6, 5, 4],
      'D#m': [-1, -1, 1, 3, 4, 2],
      'Ebm': [-1, -1, 1, 3, 4, 2],
      'F#m': [2, 4, 4, 2, 2, 2],
      'Gbm': [2, 4, 4, 2, 2, 2],
      'G#m': [4, 6, 6, 4, 4, 4],
      'Abm': [4, 6, 6, 4, 4, 4],
      'A#m': [-1, 1, 3, 3, 2, 1],
      'Bbm': [-1, 1, 3, 3, 2, 1],

      // Sus chords
      'Asus2': [-1, 0, 2, 2, 0, 0],
      'Asus4': [-1, 0, 2, 2, 3, 0],
      'Dsus2': [-1, -1, 0, 2, 3, 0],
      'Dsus4': [-1, -1, 0, 2, 3, 3],
      'Esus4': [0, 2, 2, 2, 0, 0],
    };

    return chordDb[normalized] ?? [0, 0, 0, 0, 0, 0];
  }
}

/// Custom painter for guitar fretboard diagram
class _FretboardPainter extends CustomPainter {
  final List<int> fingering;

  _FretboardPainter({required this.fingering});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stringSpacing = w / 5;
    final fretSpacing = h / 4;

    // Find min fret to normalize (for barre chords on higher frets)
    final frettedPositions = fingering.where((f) => f > 0).toList();
    final minFret = frettedPositions.isEmpty
        ? 1
        : frettedPositions.reduce((a, b) => a < b ? a : b);
    final fretOffset = minFret > 1 ? minFret - 1 : 0;

    final linePaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1;

    final thickLinePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;

    // Draw nut (top bar) - only if starting from fret 1
    if (fretOffset == 0) {
      canvas.drawLine(Offset(0, 0), Offset(w, 0), thickLinePaint);
    } else {
      // Draw fret number indicator
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${fretOffset + 1}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-9, 2));
      canvas.drawLine(Offset(0, 0), Offset(w, 0), linePaint);
    }

    // Draw frets (horizontal lines)
    for (int i = 1; i <= 4; i++) {
      canvas.drawLine(
        Offset(0, i * fretSpacing),
        Offset(w, i * fretSpacing),
        linePaint,
      );
    }

    // Draw strings (vertical lines)
    for (int i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(i * stringSpacing, 0),
        Offset(i * stringSpacing, h),
        linePaint,
      );
    }

    // Draw finger positions
    for (int i = 0; i < 6; i++) {
      final fret = fingering[i];
      final x = i * stringSpacing;

      if (fret == -1) {
        // Muted string - draw X above nut
        final xPaint = Paint()
          ..color = Colors.grey.shade500
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(x - 3, -8), Offset(x + 3, -2), xPaint);
        canvas.drawLine(Offset(x - 3, -2), Offset(x + 3, -8), xPaint);
      } else if (fret == 0) {
        // Open string - draw O above nut
        final oPaint = Paint()
          ..color = Colors.grey.shade500
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(x, -5), 3, oPaint);
      } else {
        // Fretted note - draw filled circle (normalized position)
        final normalizedFret = fret - fretOffset;
        final y = (normalizedFret - 0.5) * fretSpacing;
        final dotPaint = Paint()
          ..color = AppTheme.primary
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(x, y),
          4,
          dotPaint,
        ); // Smaller radius: 4 instead of 5
      }
    }
  }

  @override
  bool shouldRepaint(_FretboardPainter oldDelegate) {
    return oldDelegate.fingering != fingering;
  }
}
