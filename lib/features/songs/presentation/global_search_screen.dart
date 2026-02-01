import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/theme.dart';
import '../../common/providers/locale_provider.dart';
import '../../home/presentation/widgets/main_drawer.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/domain/song_model.dart';
// Duplicate import removed

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  List<Song> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load all songs initially (empty query = all originals)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
  }

  Future<void> _search() async {
    // No empty check -> empty query means list all
    setState(() => _isLoading = true);
    try {
      final songs = await ref
          .read(songRepositoryProvider)
          .searchSongs(_searchController.text.trim());
      setState(() => _results = songs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cloneSong(Song song) async {
    // Show category selection dialog
    final category = await showDialog<SongCategory>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('select_category', ref)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CategoryOption(
              label: context.tr('want_to_learn', ref),
              icon: Icons.lightbulb_outline,
              onTap: () => Navigator.pop(context, SongCategory.wantToLearn),
            ),
            _CategoryOption(
              label: context.tr('learning', ref),
              icon: Icons.school_outlined,
              onTap: () => Navigator.pop(context, SongCategory.learning),
            ),
            _CategoryOption(
              label: context.tr('know', ref),
              icon: Icons.check_circle_outline,
              onTap: () => Navigator.pop(context, SongCategory.know),
            ),
          ],
        ),
      ),
    );

    if (category == null) return; // User cancelled

    try {
      await ref
          .read(songRepositoryProvider)
          .duplicateSong(song, category: category);

      // Refresh my list
      // ignore: unused_result
      ref.refresh(songsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('clone_success', ref))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MainDrawer(), // Use Drawer
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: context.tr('menu_tooltip', ref),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: TextField(
          controller: _searchController,
          // autofocus: true, // Remove autofocus so it doesn't pop keyboard immediately on drawer nav
          decoration: InputDecoration(
            hintText: context.tr('search_songs', ref),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: _search,
            ),
          ),
          onSubmitted: (_) => _search(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final song = _results[index];

                // Check if I already have this song
                final mySongs = ref.watch(songsProvider).asData?.value ?? [];
                // It's mine if:
                // 1. I am the creator (song.userId == myId) -- but in search we might see our own
                // 2. I have a clone of it (mySongs has item with originalSongId == song.id)
                // 3. I already have it (it is in mySongs list with same id - e.g. I am author)

                final isAlreadyAdded = mySongs.any(
                  (s) =>
                      s.id == song.id ||
                      s.originalSongId == song.id ||
                      (s.originalSongId == null && s.id == song.originalSongId),
                );
                // Also check if I am the author
                final isMySong =
                    song.userId ==
                    Supabase.instance.client.auth.currentUser?.id;

                final shouldShowAdd = !isAlreadyAdded && !isMySong;

                return _PremiumSearchCard(
                  song: song,
                  showAdd: shouldShowAdd,
                  onAdd: () => _cloneSong(song),
                );
              },
            ),
    );
  }
}

/// Option widget for category selection dialog
class _CategoryOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _PremiumSearchCard extends ConsumerStatefulWidget {
  final Song song;
  final bool showAdd;
  final VoidCallback onAdd;

  const _PremiumSearchCard({
    required this.song,
    required this.showAdd,
    required this.onAdd,
  });

  @override
  ConsumerState<_PremiumSearchCard> createState() => _PremiumSearchCardState();
}

class _PremiumSearchCardState extends ConsumerState<_PremiumSearchCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => context.push('/song', extra: widget.song),
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        curve: AppTheme.animCurve,
        margin: const EdgeInsets.only(bottom: 12),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: Colors.white.withOpacity(_isPressed ? 0.15 : 0.08),
          ),
          boxShadow: _isPressed ? [] : AppTheme.subtleShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.secondary.withOpacity(0.2),
                    AppTheme.primary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.library_music_rounded,
                color: AppTheme.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.song.artist,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.song.key.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  widget.song.key,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            widget.showAdd
                ? _AddButton(onPressed: widget.onAdd)
                : const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 28,
                  ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddButton({required this.onPressed});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
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
        transform: Matrix4.identity()..scale(_isPressed ? 0.88 : 1.0),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isPressed
              ? AppTheme.primary.withOpacity(0.2)
              : AppTheme.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 24),
      ),
    );
  }
}
