import 'dart:async';
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
import 'widgets/chord_diagrams.dart';

class SongDetailScreen extends ConsumerStatefulWidget {
  final Song song;

  const SongDetailScreen({super.key, required this.song});

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen>
    with SingleTickerProviderStateMixin {
  int _transpose = 0;
  late SongCategory _currentCategory;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Auto-scroll state
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScrolling = false;
  int _scrollSpeedIndex = 0; // 0=Speed 1 (slowest), 3=Speed 4 (fastest)
  Timer? _scrollTimer;

  // Speed presets: 1=very slow, 2=slow, 3=medium, 4=fast
  static const List<double> _scrollSpeeds = [
    0.15,
    0.2,
    0.25,
    0.3,
  ]; // 9, 12, 15, 18 px/sec at 60fps

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.song.category;
    WakelockPlus.enable();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollController.dispose();
    _animController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
    } else {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    setState(() => _isAutoScrolling = true);
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (currentScroll >= maxScroll) {
        _stopAutoScroll();
        return;
      }

      _scrollController.jumpTo(
        currentScroll + _scrollSpeeds[_scrollSpeedIndex],
      );
    });
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    if (mounted) {
      setState(() => _isAutoScrolling = false);
    }
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

      ref.refresh(songsProvider);

      if (mounted) {
        context.pop();
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
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: RadioListTile<SongCategory>(
                title: Text(label),
                value: cat,
                groupValue: _currentCategory,
                onChanged: (value) => Navigator.pop(context, value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
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
          icon: const Icon(Icons.arrow_back_ios_rounded),
          tooltip: context.tr('back_tooltip', ref),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.song.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Auto-scroll button with speed menu
          _AutoScrollAppBarButton(
            isScrolling: _isAutoScrolling,
            speedIndex: _scrollSpeedIndex,
            onToggle: _toggleAutoScroll,
            onSpeedChanged: (index) =>
                setState(() => _scrollSpeedIndex = index),
          ),
          if (isOwner) ...[
            if (widget.song.originalSongId == null)
              _AnimatedIconButton(
                icon: Icons.edit_rounded,
                color: AppTheme.primary,
                onPressed: () => context.push('/editor', extra: widget.song),
                tooltip: context.tr('edit_song_tooltip', ref),
              ),
            _AnimatedIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.error,
              onPressed: _deleteSong,
              tooltip: context.tr('delete_song_tooltip', ref),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Artist name
                        Text(
                          widget.song.artist,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Meta chips
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (widget.song.key.isNotEmpty)
                              _PremiumChip(
                                label:
                                    '${context.tr('key', ref)}: ${widget.song.key}',
                              ),

                            if (widget.song.strummingPattern != null)
                              _PremiumChip(
                                icon: Icons.waves_rounded,
                                label:
                                    '${widget.song.strummingPattern!['pattern']}',
                              ),

                            _PremiumTransposeControls(
                              value: _transpose,
                              onChanged: (value) =>
                                  setState(() => _transpose = value),
                            ),

                            GestureDetector(
                              onTap: _showCategoryDialog,
                              child: _PremiumChip(
                                icon: Icons.folder_outlined,
                                label: _getCategoryLabel(_currentCategory),
                                showArrow: true,
                              ),
                            ),
                          ],
                        ),

                        // Premium gradient divider
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        // Lyrics & Chords
                        ChordLyricsRenderer(
                          content: widget.song.content,
                          transpose: _transpose,
                        ),

                        // Chord diagrams section
                        ChordDiagramsSection(
                          content: widget.song.content,
                          transpose: _transpose,
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),

              // Sticky Player Bar
              if (widget.song.audioUrl != null)
                AudioPlayerBar(audioUrl: widget.song.audioUrl!),
            ],
          ),
        ],
      ),
    );
  }
}

/// Auto-scroll button for AppBar with speed selection popup
class _AutoScrollAppBarButton extends StatefulWidget {
  final bool isScrolling;
  final int speedIndex;
  final VoidCallback onToggle;
  final ValueChanged<int> onSpeedChanged;

  const _AutoScrollAppBarButton({
    required this.isScrolling,
    required this.speedIndex,
    required this.onToggle,
    required this.onSpeedChanged,
  });

  @override
  State<_AutoScrollAppBarButton> createState() =>
      _AutoScrollAppBarButtonState();
}

class _AutoScrollAppBarButtonState extends State<_AutoScrollAppBarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didUpdateWidget(_AutoScrollAppBarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScrolling && !oldWidget.isScrolling) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isScrolling && oldWidget.isScrolling) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return IconButton(
              icon: AnimatedContainer(
                duration: AppTheme.animFast,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isScrolling
                      ? AppTheme.primary.withOpacity(
                          0.2 + _pulseController.value * 0.1,
                        )
                      : Colors.transparent,
                  border: widget.isScrolling
                      ? Border.all(color: AppTheme.primary.withOpacity(0.5))
                      : null,
                ),
                child: Icon(
                  widget.isScrolling
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: widget.isScrolling ? AppTheme.primary : Colors.white,
                ),
              ),
              onPressed: widget.onToggle,
              tooltip: widget.isScrolling ? 'Stop scroll' : 'Auto scroll',
            );
          },
        ),
        // Speed selector popup
        PopupMenuButton<int>(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.speedIndex + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
          ),
          tooltip: 'Scroll speed',
          color: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          itemBuilder: (context) => List.generate(4, (index) {
            final isSelected = index == widget.speedIndex;
            return PopupMenuItem<int>(
              value: index,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Speed ${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppTheme.primary : Colors.white,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
          onSelected: widget.onSpeedChanged,
        ),
      ],
    );
  }
}

class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  const _AnimatedIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        curve: AppTheme.animCurve,
        transform: Matrix4.identity()..scale(_isPressed ? 0.85 : 1.0),
        child: Tooltip(
          message: widget.tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(widget.icon, color: widget.color),
          ),
        ),
      ),
    );
  }
}

/// Premium transpose controls
class _PremiumTransposeControls extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PremiumTransposeControls({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TransposeButton(
            icon: Icons.remove_rounded,
            onTap: () => onChanged(value - 1),
          ),
          AnimatedContainer(
            duration: AppTheme.animFast,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              value == 0 ? '0' : (value > 0 ? '+$value' : '$value'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: value == 0 ? Colors.grey : AppTheme.primary,
              ),
            ),
          ),
          _TransposeButton(
            icon: Icons.add_rounded,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _TransposeButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TransposeButton({required this.icon, required this.onTap});

  @override
  State<_TransposeButton> createState() => _TransposeButtonState();
}

class _TransposeButtonState extends State<_TransposeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        curve: AppTheme.animCurve,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isPressed
              ? AppTheme.secondary.withOpacity(0.2)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, size: 20, color: AppTheme.secondary),
      ),
    );
  }
}

class _PremiumChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool showArrow;

  const _PremiumChip({required this.label, this.icon, this.showArrow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.secondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (showArrow) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.white.withOpacity(0.5),
            ),
          ],
        ],
      ),
    );
  }
}
