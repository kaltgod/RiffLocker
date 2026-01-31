import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../domain/song_model.dart';
import '../../auth/providers.dart';

final songRepositoryProvider = Provider((ref) => SongRepository());

final songsProvider = StreamProvider<List<Song>>((ref) {
  // Watch auth state to trigger refresh on login/logout
  ref.watch(authStateProvider);
  return ref.watch(songRepositoryProvider).getSongsStream();
});

class SongRepository {
  final _supabase = Supabase.instance.client;

  Stream<List<Song>> getSongsStream() {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('songs')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Song.fromJson(json)).toList());
  }

  Future<void> uploadSong({
    required String title,
    required String artist,
    required String content,
    required String key,
    required String? strummingPattern,
    required PlatformFile? audioFile,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    String? audioUrl;

    // 1. Upload Audio if exists
    if (audioFile != null) {
      final fileExt = audioFile.extension ?? 'mp3';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$fileName';

      // On Web, bytes are available. On Mobile/Desktop, path is available.
      // Supabase Flutter handles this via uploadBinary or upload.

      if (audioFile.bytes != null) {
        // Web or if bytes loaded
        await _supabase.storage
            .from('backing_tracks')
            .uploadBinary(
              filePath,
              audioFile.bytes!,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      } else if (audioFile.path != null) {
        // Mobile / Desktop
        final file = File(audioFile.path!);
        await _supabase.storage
            .from('backing_tracks')
            .upload(
              filePath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      }

      // 2. Get Public URL
      audioUrl = _supabase.storage
          .from('backing_tracks')
          .getPublicUrl(filePath);
    }

    // 3. Insert into Database
    final song = Song(
      id: '', // Supabase will auto-generate ID, but we need to send strict JSON usually or omit ID
      // Best practice: Let Supabase handle ID generation.
      // We'll construct a Map to send, excluding ID.
      userId: userId,
      title: title.trim(),
      artist: artist.trim(),
      content: content,
      key: key.trim(),
      strummingPattern: strummingPattern != null && strummingPattern.isNotEmpty
          ? {'pattern': strummingPattern.trim()}
          : null,
      audioUrl: audioUrl,
    );

    // We can't use song.toJson() if we want to omit ID for auto-gen (unless we make ID nullable in model or logic).
    // Let's just create the map manually here to be safe and simple.
    await _supabase.from('songs').insert({
      'user_id': song.userId,
      'title': song.title,
      'artist': song.artist,
      'content': song.content,
      'key': song.key,
      'strumming_pattern': song.strummingPattern,
      'audio_url': song.audioUrl,
    });
  }

  Future<void> updateSong({
    required String songId,
    required String title,
    required String artist,
    required String content,
    required String key,
    required String? strummingPattern,
    required PlatformFile? audioFile,
    required String? currentAudioUrl,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    String? audioUrl = currentAudioUrl;

    // 1. Upload New Audio if exists
    if (audioFile != null) {
      final fileExt = audioFile.extension ?? 'mp3';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$fileName';

      if (audioFile.bytes != null) {
        await _supabase.storage
            .from('backing_tracks')
            .uploadBinary(
              filePath,
              audioFile.bytes!,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      } else if (audioFile.path != null) {
        final file = File(audioFile.path!);
        await _supabase.storage
            .from('backing_tracks')
            .upload(
              filePath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      }
      audioUrl = _supabase.storage
          .from('backing_tracks')
          .getPublicUrl(filePath);
    }

    await _supabase
        .from('songs')
        .update({
          'title': title.trim(),
          'artist': artist.trim(),
          'content': content,
          'key': key.trim(),
          'strumming_pattern':
              strummingPattern != null && strummingPattern.isNotEmpty
              ? {'pattern': strummingPattern.trim()}
              : null,
          'audio_url': audioUrl,
        })
        .eq('id', songId)
        .eq('user_id', userId);
  }

  Future<List<Song>> getSongs() async {
    // Determine if we should filter by user (for "My Songs")
    final userId = _supabase.auth.currentUser?.id;

    // If we want ONLY my songs:
    final response = await _supabase
        .from('songs')
        .select()
        .eq('user_id', userId ?? '') // Strict filter
        .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((json) => Song.fromJson(json)).toList();
  }

  Future<List<Song>> searchSongs(String query) async {
    // If query is empty, just return the latest original songs
    var queryBuilder = _supabase
        .from('songs')
        .select()
        .filter(
          'original_song_id',
          'is',
          null,
        ); // Only show originals (not clones)

    if (query.isNotEmpty) {
      queryBuilder = queryBuilder.or(
        'title.ilike.%$query%,artist.ilike.%$query%',
      ); // Case insensitive search
    }

    final response = await queryBuilder
        .order('created_at', ascending: false) // Latest first
        .limit(50); // Limit results

    final data = response as List<dynamic>;
    return data.map((json) => Song.fromJson(json)).toList();
  }

  Future<void> duplicateSong(Song original) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Must be logged in to clone songs');

    // Check if I already have this song (either as a clone or I am the owner)
    // 1. Am I the owner?
    if (original.userId == userId) {
      throw Exception('You already own this song!');
    }

    // 2. Do I have a clone of this?
    // We check if I have a song where original_song_id == original.id
    final existingClone = await _supabase
        .from('songs')
        .select('id')
        .eq('user_id', userId)
        .eq('original_song_id', original.id)
        .maybeSingle();

    if (existingClone != null) {
      throw Exception('You have already added this song to your library!');
    }

    // Proceed to clone
    await _supabase.from('songs').insert({
      'user_id': userId,
      'title': original.title,
      'artist': original.artist,
      'content': original.content,
      'key': original.key,
      'strumming_pattern': original.strummingPattern,
      'audio_url':
          original.audioUrl, // Copy the reference (it's public read now)
      'original_song_id': original.id, // Mark as a clone
    });
  }

  Future<void> deleteSong(String songId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await _supabase
        .from('songs')
        .delete()
        .eq('id', songId)
        .eq('user_id', userId); // Security: only delete my own rows
  }
}
