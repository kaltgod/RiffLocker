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
  int _transpose = 0;
  late SongCategory _currentCategory;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.song.category;
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

  Future<void> _showCategoryDialog() async {
    final selected = await showDialog<SongCategory>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('change_category', ref)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SongCategory.values.map((cat) {
            final label = _getCategoryLabel(cat);
            return RadioListTile<SongCategory>(
              title: Text(label),
              value: cat,
              groupValue: _currentCategory,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null && selected != _currentCategory) {
      try {
        await ref
            .read(songRepositoryProvider)
            .updateSongCategory(widget.song.id, selected);
        setState(() => _currentCategory = selected);
        // ignore: unused_result
        ref.refresh(songsProvider);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_getCategoryLabel(selected))));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  String _getCategoryLabel(SongCategory cat) {
    switch (cat) {
      case SongCategory.wantToLearn:
        return context.tr('want_to_learn', ref);
      case SongCategory.learning:
        return context.tr('learning', ref);
      case SongCategory.know:
        return context.tr('know', ref);
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
                    crossAxisAlignment: WrapCrossAlignment.center,
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

                      _TransposeControls(
                        value: _transpose,
                        onChanged: (value) =>
                            setState(() => _transpose = value),
                      ),

                      // Category chip (clickable to change)
                      GestureDetector(
                        onTap: _showCategoryDialog,
                        child: _MetaChip(
                          icon: Icons.folder_outlined,
                          label: _getCategoryLabel(_currentCategory),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Lyrics & Chords
                  ChordLyricsRenderer(
                    content: widget.song.content,
                    transpose: _transpose,
                  ),

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

/// Widget for transpose controls (+/-)
class _TransposeControls extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _TransposeControls({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button
          InkWell(
            onTap: () => onChanged(value - 1),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.remove, size: 18, color: AppTheme.secondary),
            ),
          ),

          // Value display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              value == 0 ? '0' : (value > 0 ? '+$value' : '$value'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: value == 0 ? Colors.grey : AppTheme.primary,
              ),
            ),
          ),

          // Plus button
          InkWell(
            onTap: () => onChanged(value + 1),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.add, size: 18, color: AppTheme.secondary),
            ),
          ),
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
