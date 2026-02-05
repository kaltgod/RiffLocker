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
  /// Now supports position notation like Dm(V), C(III), etc.
  List<String> _extractChords(String text) {
    // Updated regex to support optional position in Roman numerals: (I), (II), ..., (XII)
    final regex = RegExp(
      r'\[([A-Ga-g][#b]?m?(?:aj|in)?(?:7|9|11|13|sus[24]?|add[29]?|dim|aug)?(?:\([IVX]+\))?(?:/[A-Ga-g][#b]?)?)\]',
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

  /// Parse Roman numeral to integer (I=1, II=2, ..., XII=12)
  static int? _parseRomanNumeral(String roman) {
    const romanMap = {
      'I': 1,
      'II': 2,
      'III': 3,
      'IV': 4,
      'V': 5,
      'VI': 6,
      'VII': 7,
      'VIII': 8,
      'IX': 9,
      'X': 10,
      'XI': 11,
      'XII': 12,
    };
    return romanMap[roman.toUpperCase()];
  }

  /// Parse chord with optional position notation like Dm(V)
  /// Returns (baseChord, position) where position is the fret number or null
  static (String, int?) _parseChordWithPosition(String chord) {
    final positionRegex = RegExp(r'^(.+?)\(([IVX]+)\)(.*)$');
    final match = positionRegex.firstMatch(chord);

    if (match != null) {
      final baseChord = match.group(1)! + (match.group(3) ?? '');
      final romanPosition = match.group(2)!;
      final position = _parseRomanNumeral(romanPosition);
      return (baseChord, position);
    }

    return (chord, null);
  }

  @override
  Widget build(BuildContext context) {
    final (baseChord, position) = _parseChordWithPosition(chord);
    final fingering = _getChordFingering(baseChord, position);

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
            textAlign: TextAlign.center,
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

  /// Base barre chord shapes that can be shifted up the neck
  /// Format: [6E, 5A, 4D, 3G, 2B, 1e] where -1=muted, 0=open, 1+=fret relative to barre
  static const _barreShapes = {
    // E-shape barre (root on 6th string) - full barre
    'E': [0, 2, 2, 1, 0, 0], // Major
    'Em': [0, 2, 2, 0, 0, 0], // Minor
    'E7': [0, 2, 0, 1, 0, 0], // Dominant 7
    'Em7': [0, 2, 0, 0, 0, 0], // Minor 7
    // A-shape barre (root on 5th string) - 6th string muted
    'A': [-1, 0, 2, 2, 2, 0], // Major
    'Am': [-1, 0, 2, 2, 1, 0], // Minor
    'A7': [-1, 0, 2, 0, 2, 0], // Dominant 7
    'Am7': [-1, 0, 2, 0, 1, 0], // Minor 7
  };

  /// Notes in chromatic order starting from E (6th string open)
  static const _eShapeNotes = [
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
    'C',
    'C#',
    'D',
    'D#',
  ];

  /// Notes in chromatic order starting from A (5th string open)
  static const _aShapeNotes = [
    'A',
    'A#',
    'B',
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
  ];

  /// Alternate note names (flats)
  static const _flatToSharp = {
    'Bb': 'A#',
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
  };

  /// Get root note from chord (e.g., "Am7" -> "A", "F#m" -> "F#")
  static String _getRootNote(String chord) {
    if (chord.length >= 2 && (chord[1] == '#' || chord[1] == 'b')) {
      return chord.substring(0, 2);
    }
    return chord.substring(0, 1);
  }

  /// Normalize note name (convert flats to sharps)
  static String _normalizeNote(String note) {
    return _flatToSharp[note] ?? note;
  }

  /// Determine which barre shape to use based on note and position
  /// Returns true for E-shape, false for A-shape
  static bool _shouldUseEShape(String baseChord, int position) {
    final rootNote = _normalizeNote(_getRootNote(baseChord));

    // Check if E-shape at this position gives us the correct note
    if (position < _eShapeNotes.length) {
      final eShapeNote = _eShapeNotes[position % 12];
      if (eShapeNote == rootNote) {
        return true; // E-shape matches
      }
    }

    // Check if A-shape at this position gives us the correct note
    if (position < _aShapeNotes.length) {
      final aShapeNote = _aShapeNotes[position % 12];
      if (aShapeNote == rootNote) {
        return false; // A-shape matches
      }
    }

    // Default: use E-shape for lower positions, A-shape for higher
    return position <= 5;
  }

  /// Get the barre shape form for a chord quality
  static String? _getBarreShapeForm(String baseChord, bool useEShape) {
    // Determine chord quality
    final isMinor = baseChord.contains('m') && !baseChord.contains('maj');
    final is7 = baseChord.contains('7');

    if (useEShape) {
      if (isMinor && is7) return 'Em7';
      if (isMinor) return 'Em';
      if (is7) return 'E7';
      return 'E';
    } else {
      if (isMinor && is7) return 'Am7';
      if (isMinor) return 'Am';
      if (is7) return 'A7';
      return 'A';
    }
  }

  /// Apply barre offset to a shape
  static List<int> _applyBarreOffset(List<int> shape, int offset) {
    return shape.map((fret) {
      if (fret == -1) return -1; // Keep muted
      return fret + offset; // Add offset to all positions
    }).toList();
  }

  /// Get fingering pattern for chord (6 strings, -1 = muted, 0 = open, 1+ = fret)
  List<int> _getChordFingering(String baseChord, int? position) {
    // Normalize chord name
    final normalized = baseChord.replaceAll('♯', '#').replaceAll('♭', 'b');

    // If position is specified, calculate barre chord
    if (position != null) {
      // Determine which shape to use based on note and position
      final useEShape = _shouldUseEShape(normalized, position);
      final shapeForm = _getBarreShapeForm(normalized, useEShape);

      if (shapeForm != null && _barreShapes.containsKey(shapeForm)) {
        final shape = _barreShapes[shapeForm]!;
        return _applyBarreOffset(shape, position);
      }
    }

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

    // Detect barre: find the lowest fret that spans multiple consecutive strings
    final (barreStartString, barreEndString, barreFret) = _detectBarre(
      fingering,
      fretOffset,
    );

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

    // Draw barre if detected
    if (barreFret != null &&
        barreStartString != null &&
        barreEndString != null) {
      final normalizedFret = barreFret - fretOffset;
      final y = (normalizedFret - 0.5) * fretSpacing;
      final startX = barreStartString * stringSpacing;
      final endX = barreEndString * stringSpacing;

      final barrePaint = Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.fill;

      // Draw rounded rectangle for barre
      final barreRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(startX - 4, y - 4, endX + 4, y + 4),
        const Radius.circular(4),
      );
      canvas.drawRRect(barreRect, barrePaint);
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
        // Skip barre strings - they're already drawn as a bar
        if (barreFret != null &&
            barreStartString != null &&
            barreEndString != null &&
            fret == barreFret &&
            i >= barreStartString &&
            i <= barreEndString) {
          continue;
        }

        // Fretted note - draw filled circle (normalized position)
        final normalizedFret = fret - fretOffset;
        final y = (normalizedFret - 0.5) * fretSpacing;
        final dotPaint = Paint()
          ..color = AppTheme.primary
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
      }
    }
  }

  /// Detect barre chord pattern
  /// Returns (startString, endString, fret) or (null, null, null) if no barre
  (int?, int?, int?) _detectBarre(List<int> fingering, int fretOffset) {
    // Find the minimum fret (excluding open/muted)
    final frettedPositions = fingering.where((f) => f > 0).toList();
    if (frettedPositions.isEmpty) return (null, null, null);

    final minFret = frettedPositions.reduce((a, b) => a < b ? a : b);

    // Count how many strings have this minimum fret
    int firstString = -1;
    int lastString = -1;
    int count = 0;

    for (int i = 0; i < 6; i++) {
      if (fingering[i] == minFret) {
        if (firstString == -1) firstString = i;
        lastString = i;
        count++;
      }
    }

    // Barre must span at least 2 strings and be on a fret > 0
    if (count >= 2 && minFret > 0 && lastString - firstString >= 1) {
      return (firstString, lastString, minFret);
    }

    return (null, null, null);
  }

  @override
  bool shouldRepaint(_FretboardPainter oldDelegate) {
    return oldDelegate.fingering != fingering;
  }
}
