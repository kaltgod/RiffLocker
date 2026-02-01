import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/domain/song_model.dart';

import 'widgets/main_drawer.dart';
import '../../common/providers/locale_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: const MainDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: context.tr('menu_tooltip', ref),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(context.tr('app_title', ref)),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: context.tr('want_to_learn', ref)),
              Tab(text: context.tr('learning', ref)),
              Tab(text: context.tr('know', ref)),
            ],
          ),
        ),
        body: songsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (songs) {
            return TabBarView(
              children: [
                _SongListView(
                  songs: songs
                      .where((s) => s.category == SongCategory.wantToLearn)
                      .toList(),
                  emptyMessage: context.tr('no_songs_want_to_learn', ref),
                ),
                _SongListView(
                  songs: songs
                      .where((s) => s.category == SongCategory.learning)
                      .toList(),
                  emptyMessage: context.tr('no_songs_learning', ref),
                ),
                _SongListView(
                  songs: songs
                      .where((s) => s.category == SongCategory.know)
                      .toList(),
                  emptyMessage: context.tr('no_songs_know', ref),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await context.push('/editor');
            ref.refresh(songsProvider);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _SongListView extends ConsumerWidget {
  final List<Song> songs;
  final String emptyMessage;

  const _SongListView({required this.songs, required this.emptyMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('add_song_hint', ref),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(songsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                song.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${song.artist} • ${context.tr('key', ref)}: ${song.key}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/song', extra: song);
              },
            ),
          );
        },
      ),
    );
  }
}
