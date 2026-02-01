/// Utility class for transposing musical chords.
///
/// Supports standard chord notation including:
/// - Natural notes: C, D, E, F, G, A, B
/// - Sharps: C#, F#, etc.
/// - Flats: Bb, Eb, etc.
/// - Modifiers: m (minor), 7, maj7, sus4, dim, aug, etc.
class ChordTransposer {
  // Chromatic scale using sharps
  static const List<String> _notesSharp = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  // Chromatic scale using flats
  static const List<String> _notesFlat = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  /// Transpose a chord by a given number of semitones.
  ///
  /// Examples:
  /// - transpose('Am', 2) -> 'Bm'
  /// - transpose('C', 1) -> 'C#'
  /// - transpose('F#m7', -2) -> 'Em7'
  static String transpose(String chord, int semitones) {
    if (semitones == 0 || chord.isEmpty) return chord;

    // Parse the root note
    final parseResult = _parseChord(chord);
    if (parseResult == null) return chord; // Can't parse, return as-is

    final rootNote = parseResult.root;
    final modifier = parseResult.modifier;
    final bassNote = parseResult.bass;

    // Determine if we should use flats or sharps based on original chord
    final useFlats =
        rootNote.contains('b') || (bassNote?.contains('b') ?? false);
    final scale = useFlats ? _notesFlat : _notesSharp;

    // Transpose root note
    final newRoot = _transposeNote(rootNote, semitones, scale);
    if (newRoot == null) return chord;

    // Transpose bass note if present (e.g., C/G)
    String? newBass;
    if (bassNote != null) {
      newBass = _transposeNote(bassNote, semitones, scale);
    }

    // Reconstruct chord
    String result = newRoot + modifier;
    if (newBass != null) {
      result += '/$newBass';
    }

    return result;
  }

  /// Parse a chord into root note, modifier, and optional bass note.
  static _ChordParts? _parseChord(String chord) {
    // Match root note (with optional # or b), then capture the rest
    // Also handle slash chords like C/G
    final regex = RegExp(r'^([A-Ga-g][#b]?)(.*)$');
    final match = regex.firstMatch(chord);
    if (match == null) return null;

    String root = match.group(1)!;
    String rest = match.group(2) ?? '';

    // Normalize root to uppercase
    root = root[0].toUpperCase() + root.substring(1);

    // Check for bass note (slash chord)
    String? bass;
    final slashIndex = rest.indexOf('/');
    if (slashIndex != -1) {
      bass = rest.substring(slashIndex + 1);
      rest = rest.substring(0, slashIndex);
      // Normalize bass
      if (bass.isNotEmpty) {
        bass = bass[0].toUpperCase() + bass.substring(1);
      }
    }

    return _ChordParts(root: root, modifier: rest, bass: bass);
  }

  /// Transpose a single note by semitones.
  static String? _transposeNote(
    String note,
    int semitones,
    List<String> scale,
  ) {
    // Find the note in the scale
    int index = -1;

    // Normalize the note
    String normalizedNote = note[0].toUpperCase() + note.substring(1);

    // Try to find in sharp scale first
    index = _notesSharp.indexOf(normalizedNote);
    if (index == -1) {
      // Try flat scale
      index = _notesFlat.indexOf(normalizedNote);
    }

    if (index == -1) return null;

    // Calculate new index with wrapping
    int newIndex = (index + semitones) % 12;
    if (newIndex < 0) newIndex += 12;

    return scale[newIndex];
  }
}

class _ChordParts {
  final String root;
  final String modifier;
  final String? bass;

  _ChordParts({required this.root, required this.modifier, this.bass});
}
