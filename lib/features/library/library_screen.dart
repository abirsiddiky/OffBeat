import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/motion.dart';
import '../../data/models/album_model.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import '../../shared/widgets/album_grid_card.dart';
import '../../shared/widgets/fade_in_item.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/song_row_tile.dart';
import '../playlists/playlist_detail_screen.dart';
import '../playlists/playlist_dialogs.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final Function(AlbumModel album) onAlbumSelected;

  const LibraryScreen({
    super.key,
    required this.onAlbumSelected,
  });

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['Songs', 'Albums', 'Artists', 'Playlists'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final audioController = ref.watch(audioControllerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Title: "Library"
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.screenInset,
                right: AppSpacing.screenInset,
                top: 20,
                bottom: 16,
              ),
              child: Text(
                'Library',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Horizontal Tab Chips: Selected pill slides/fades (AnimatedContainer color + text style, 200 ms)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                itemCount: _tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final isSelected = _selectedTabIndex == idx;
                  final activeFill = isDark ? AppColors.white : AppColors.navy;
                  final activeText = isDark ? AppColors.navy : AppColors.white;

                  return Pressable(
                    pressedScale: 0.95,
                    duration: const Duration(milliseconds: 90),
                    onTap: () {
                      if (_selectedTabIndex != idx) {
                        setState(() => _selectedTabIndex = idx);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Motion.enter,
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: isSelected ? activeFill : Colors.transparent,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Motion.enter,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            color: isSelected ? activeText : AppColors.slate,
                          ),
                          child: Text(_tabs[idx]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Tab Content Switch using cheap fade-only transition (200 ms)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_selectedTabIndex),
                  child: _buildTabContent(audioController),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(AudioController audioController) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildSongsTab(audioController);
      case 1:
        return _buildAlbumsTab();
      case 2:
        return _buildArtistsTab();
      case 3:
        return _buildPlaylistsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSongsTab(AudioController audioController) {
    final allSongsAsync = ref.watch(allSongsProvider);

    return allSongsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return const Center(child: Text('No songs found', style: TextStyle(color: AppColors.slate)));
        }
        return ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
          itemExtent: 68.0, // Fixed height rows for steady 60 fps
          cacheExtent: 250.0,
          addAutomaticKeepAlives: false,
          itemCount: songs.length,
          itemBuilder: (context, idx) {
            final song = songs[idx];
            return FadeInItem(
              key: ValueKey(song.id),
              itemId: song.id,
              child: SongRowTile(
                song: song,
                index: idx,
                showThumbnail: true,
                showHeart: true,
                onTap: () => audioController.playQueue(songs, initialIndex: idx),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildAlbumsTab() {
    final allAlbumsAsync = ref.watch(allAlbumsProvider);

    return allAlbumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return const Center(child: Text('No albums found', style: TextStyle(color: AppColors.slate)));
        }
        return GridView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            mainAxisExtent: 224,
          ),
          cacheExtent: 250.0,
          addAutomaticKeepAlives: false,
          itemCount: albums.length,
          itemBuilder: (context, idx) {
            final album = albums[idx];
            return FadeInItem(
              key: ValueKey(album.id),
              itemId: album.id,
              child: AlbumGridCard(
                album: album,
                onTap: () => widget.onAlbumSelected(album),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildArtistsTab() {
    final allArtistsAsync = ref.watch(allArtistsProvider);

    return allArtistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const Center(child: Text('No artists found', style: TextStyle(color: AppColors.slate)));
        }
        return ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
          itemExtent: 68.0,
          cacheExtent: 250.0,
          addAutomaticKeepAlives: false,
          itemCount: artists.length,
          itemBuilder: (context, idx) {
            final artist = artists[idx];
            return FadeInItem(
              key: ValueKey(artist.id),
              itemId: artist.id,
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF222836),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.person_rounded, color: AppColors.slate, size: 24),
                  ),
                ),
                title: Text(
                  artist.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  '${artist.trackCount} songs',
                  style: const TextStyle(color: AppColors.slate, fontSize: 13),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPlaylistsTab() {
    final playlistsAsync = ref.watch(playlistsProvider);

    return playlistsAsync.when(
      data: (playlists) {
        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
          children: [
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.slate.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.slate, size: 28),
              ),
              title: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => PlaylistDialogs.showCreateDialog(context, ref),
            ),
            ...playlists.map((pl) => ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF222836),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.queue_music_rounded, color: AppColors.slate, size: 24),
                  ),
                  title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${pl.songCount} songs', style: const TextStyle(color: AppColors.slate, fontSize: 13)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(
                          playlist: pl,
                          onBack: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
