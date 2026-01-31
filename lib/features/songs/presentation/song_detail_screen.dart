import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../songs/data/song_repository.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../common/providers/locale_provider.dart';
import '../domain/song_model.dart';
import 'widgets/audio_player_bar.dart';
import 'widgets/chord_renderer.dart';

class SongDetailScreen extends ConsumerStatefulWidget {
  final Song song;

  const SongDetailScreen({super.key, required this.song});

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Keep screen on while viewing a song
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _deleteSong() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('delete_song_title', ref)),
        content: Text(context.tr('delete_song_message', ref)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel', ref)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: Text(context.tr('delete', ref)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('deleting', ref))));
      }

      await ref.read(songRepositoryProvider).deleteSong(widget.song.id);

      // Refresh list
      ref.refresh(songsProvider);

      if (mounted) {
        context.pop(); // Go back
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = widget.song.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.tr('back_tooltip', ref),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.song.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isOwner) ...[
            if (widget.song.originalSongId == null)
              IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.primary),
                onPressed: () => context.push('/editor', extra: widget.song),
                tooltip: context.tr('edit_song_tooltip', ref),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: _deleteSong,
              tooltip: context.tr('delete_song_tooltip', ref),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ... rest of body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata Header
                  Text(
                    widget.song.artist,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (widget.song.key.isNotEmpty)
                        _MetaChip(
                          label:
                              '${context.tr('key', ref)}: ${widget.song.key}',
                        ),

                      if (widget.song.strummingPattern != null)
                        _MetaChip(
                          icon: Icons.waves,
                          label: '${widget.song.strummingPattern!['pattern']}',
                        ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Lyrics & Chords
                  ChordLyricsRenderer(content: widget.song.content),

                  // Bottom padding for scrolling
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Sticky Player Bar
          if (widget.song.audioUrl != null)
            AudioPlayerBar(audioUrl: widget.song.audioUrl!),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _MetaChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppTheme.secondary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
