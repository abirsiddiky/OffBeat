import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/album_model.dart';
import '../../data/models/song_model.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import '../../shared/widgets/album_grid_card.dart';
import '../../shared/widgets/fade_in_item.dart';
import '../../shared/widgets/song_row_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final Function(AlbumModel album) onAlbumSelected;

  const SearchScreen({
    super.key,
    required this.onAlbumSelected,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.trim().toLowerCase();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final searchBg = isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface;

    final allSongs = ref.watch(allSongsProvider).value ?? [];
    final allAlbums = ref.watch(allAlbumsProvider).value ?? [];
    final allArtists = ref.watch(allArtistsProvider).value ?? [];
    final audioController = ref.watch(audioControllerProvider);

    // Filtered lists
    final filteredSongs = _searchQuery.isEmpty
        ? <SongModel>[]
        : allSongs.where((s) {
            return s.title.toLowerCase().contains(_searchQuery) ||
                s.artist.toLowerCase().contains(_searchQuery) ||
                s.album.toLowerCase().contains(_searchQuery);
          }).toList();

    final filteredAlbums = _searchQuery.isEmpty
        ? <AlbumModel>[]
        : allAlbums.where((a) {
            return a.title.toLowerCase().contains(_searchQuery) ||
                a.artist.toLowerCase().contains(_searchQuery);
          }).toList();

    final filteredArtists = _searchQuery.isEmpty
        ? []
        : allArtists.where((ar) {
            return ar.name.toLowerCase().contains(_searchQuery);
          }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          cacheExtent: 250.0,
          slivers: [
            // Search Header: "Search"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.screenInset,
                  right: AppSpacing.screenInset,
                  top: 20,
                  bottom: 14,
                ),
                child: Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            // Search Bar Input
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _controller,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: primaryTextColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Songs, artists, or albums',
                      hintStyle: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.slate,
                        size: 24,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.slate, size: 20),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // Empty state before typing
            if (_searchQuery.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_rounded, size: 48, color: AppColors.slate.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'Find your favorite music',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filteredSongs.isEmpty && filteredAlbums.isEmpty && filteredArtists.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(fontSize: 16, color: AppColors.slate),
                    ),
                  ),
                ),
              )
            else ...[
              // Songs section
              if (filteredSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.screenInset,
                      right: AppSpacing.screenInset,
                      bottom: 8,
                    ),
                    child: Text(
                      'SONGS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.slate.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                  sliver: SliverFixedExtentList(
                    itemExtent: 68.0,
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final song = filteredSongs[idx];
                        return FadeInItem(
                          key: ValueKey(song.id),
                          itemId: song.id,
                          child: SongRowTile(
                            song: song,
                            index: idx,
                            showThumbnail: true,
                            showHeart: true,
                            onTap: () => audioController.playSong(song),
                          ),
                        );
                      },
                      childCount: filteredSongs.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // Albums section
              if (filteredAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.screenInset,
                      right: AppSpacing.screenInset,
                      bottom: 8,
                    ),
                    child: Text(
                      'ALBUMS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.slate.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      mainAxisExtent: 224,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final album = filteredAlbums[idx];
                        return FadeInItem(
                          key: ValueKey(album.id),
                          itemId: album.id,
                          child: AlbumGridCard(
                            album: album,
                            onTap: () => widget.onAlbumSelected(album),
                          ),
                        );
                      },
                      childCount: filteredAlbums.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ],

            // Bottom safe inset for dock
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.totalDockHeight + 20),
            ),
          ],
        ),
      ),
    );
  }
}
