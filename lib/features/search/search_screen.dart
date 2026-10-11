import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data.dart';
import '../../playback/playback.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/track_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  String _selectedFilter = 'All'; // 'All', 'Songs', 'Albums', 'Artists'

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _query = value.trim().toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allSongs = ref.watch(allSongsProvider).value ?? [];
    final allAlbums = ref.watch(albumsProvider).value ?? [];
    final allArtists = ref.watch(artistsProvider).value ?? [];

    final filteredSongs = _query.isEmpty
        ? <Song>[]
        : allSongs.where((s) {
            return s.title.toLowerCase().contains(_query) ||
                s.artist.toLowerCase().contains(_query) ||
                s.album.toLowerCase().contains(_query);
          }).toList();

    final filteredAlbums = _query.isEmpty
        ? <Album>[]
        : allAlbums.where((a) {
            return a.title.toLowerCase().contains(_query) ||
                a.artist.toLowerCase().contains(_query);
          }).toList();

    final filteredArtists = _query.isEmpty
        ? <Artist>[]
        : allArtists.where((a) {
            return a.name.toLowerCase().contains(_query);
          }).toList();

    final hasResults = filteredSongs.isNotEmpty ||
        filteredAlbums.isNotEmpty ||
        filteredArtists.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Filter chips row
          if (_query.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: ['All', 'Songs', 'Albums', 'Artists'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.rounded32,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 8),

          // Search results or empty state
          Expanded(
            child: _query.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.travel_explore_rounded,
                          size: 64,
                          color: isDark ? AppColors.slate : AppColors.lightSlate,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search Your Library',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Type track titles, artist names, or albums',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : !hasResults
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: isDark ? AppColors.slate : AppColors.lightSlate,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matches found for "$_query"',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 180),
                        children: [
                          // Songs section
                          if ((_selectedFilter == 'All' ||
                                  _selectedFilter == 'Songs') &&
                              filteredSongs.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Text(
                                'Songs (${filteredSongs.length})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ...List.generate(
                              filteredSongs.length > 20
                                  ? 20
                                  : filteredSongs.length,
                              (i) {
                                final song = filteredSongs[i];
                                return TrackTile(
                                  song: song,
                                  onTap: () {
                                    ref
                                        .read(playerControllerProvider.notifier)
                                        .playSongs(filteredSongs, i);
                                  },
                                );
                              },
                            ),
                          ],

                          // Albums section
                          if ((_selectedFilter == 'All' ||
                                  _selectedFilter == 'Albums') &&
                              filteredAlbums.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                              child: Text(
                                'Albums (${filteredAlbums.length})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 180,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: filteredAlbums.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 14),
                                itemBuilder: (context, i) {
                                  final album = filteredAlbums[i];
                                  return AlbumCard(
                                    album: album,
                                    width: 140,
                                    onTap: () =>
                                        context.push('/album/${album.id}'),
                                  );
                                },
                              ),
                            ),
                          ],

                          // Artists section
                          if ((_selectedFilter == 'All' ||
                                  _selectedFilter == 'Artists') &&
                              filteredArtists.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                              child: Text(
                                'Artists (${filteredArtists.length})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ...List.generate(filteredArtists.length, (i) {
                              final artist = filteredArtists[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.navyElevated
                                        : AppColors.lightCard,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_rounded),
                                ),
                                title: Text(artist.name),
                                subtitle: Text(
                                  '${artist.numberOfTracks ?? 0} tracks',
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: AppRadius.rounded16,
                                ),
                                onTap: () {
                                  // Filters to this artist
                                  setState(() {
                                    _searchController.text = artist.name;
                                    _query = artist.name.toLowerCase();
                                    _selectedFilter = 'Songs';
                                  });
                                },
                              );
                            }),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
