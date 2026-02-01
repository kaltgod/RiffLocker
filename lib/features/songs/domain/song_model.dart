/// Song learning category
enum SongCategory {
  wantToLearn,
  learning,
  know;

  String get value {
    switch (this) {
      case SongCategory.wantToLearn:
        return 'want_to_learn';
      case SongCategory.learning:
        return 'learning';
      case SongCategory.know:
        return 'know';
    }
  }

  static SongCategory fromString(String? value) {
    switch (value) {
      case 'learning':
        return SongCategory.learning;
      case 'know':
        return SongCategory.know;
      case 'want_to_learn':
      default:
        return SongCategory.wantToLearn;
    }
  }
}

class Song {
  final String id;
  final String userId;
  final String title;
  final String artist;
  final String content;
  final Map<String, dynamic>? strummingPattern;
  final String? audioUrl;
  final String key;
  final String? originalSongId;
  final DateTime? createdAt;
  final SongCategory category;

  Song({
    required this.id,
    required this.userId,
    required this.title,
    required this.artist,
    required this.content,
    this.strummingPattern,
    this.audioUrl,
    required this.key,
    this.originalSongId,
    this.createdAt,
    this.category = SongCategory.wantToLearn,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      content: json['content'] as String,
      strummingPattern: (json['strumming_pattern'] as Map<String, dynamic>?),
      audioUrl: json['audio_url'] as String?,
      key: json['key'] as String,
      originalSongId: json['original_song_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      category: SongCategory.fromString(json['category'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'artist': artist,
      'content': content,
      'strumming_pattern': strummingPattern,
      'audio_url': audioUrl,
      'key': key,
      'original_song_id': originalSongId,
      'created_at': createdAt?.toIso8601String(),
      'category': category.value,
    };
  }

  /// Create a copy with modified fields
  Song copyWith({
    String? id,
    String? userId,
    String? title,
    String? artist,
    String? content,
    Map<String, dynamic>? strummingPattern,
    String? audioUrl,
    String? key,
    String? originalSongId,
    DateTime? createdAt,
    SongCategory? category,
  }) {
    return Song(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      content: content ?? this.content,
      strummingPattern: strummingPattern ?? this.strummingPattern,
      audioUrl: audioUrl ?? this.audioUrl,
      key: key ?? this.key,
      originalSongId: originalSongId ?? this.originalSongId,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
    );
  }

  // Helper to create a dummy song for testing
  factory Song.dummy() {
    return Song(
      id: '1',
      userId: 'user_1',
      title: 'Wonderwall',
      artist: 'Oasis',
      content:
          "Today is [Em]gonna be the day that they're [G]gonna throw it back to [D]you\n"
          "By now you [Em]should've somehow rea[G]lized what you gotta [D]do\n"
          "I don't believe that [C]anybody [D]feels the way I [A7]do about you [C]now [D] [A7] [C] [D]",
      key: 'Em',
      strummingPattern: {'pattern': 'D-D-U-U-D-U'},
      category: SongCategory.wantToLearn,
    );
  }
}
