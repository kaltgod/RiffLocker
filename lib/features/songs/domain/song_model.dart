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
    };
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
    );
  }
}
