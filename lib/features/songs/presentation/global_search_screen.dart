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
    try {
      await ref.read(songRepositoryProvider).duplicateSong(song);

      // Refresh my list
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
            icon: const Icon(Icons.menu),
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
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
          ),
          onSubmitted: (_) => _search(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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

                return Card(
                  child: ListTile(
                    title: Text(
                      song.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${song.artist} • ${context.tr('key', ref)}: ${song.key}',
                    ),
                    onTap: () {
                      context.push('/song', extra: song);
                    },
                    trailing: shouldShowAdd
                        ? IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: AppTheme.primary,
                            ),
                            onPressed: () => _cloneSong(song),
                            tooltip: context.tr('add_to_library_tooltip', ref),
                          )
                        : const Icon(Icons.check, color: Colors.green),
                  ),
                );
              },
            ),
    );
  }
}
