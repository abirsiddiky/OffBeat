import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import '../../shared/widgets/fade_in_item.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/song_row_tile.dart';

class HotlistScreen extends ConsumerWidget {
  const HotlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final playBtnBg = isDark ? AppColors.white : AppColors.navy;
    final playBtnTextColor = isDark ? AppColors.navy : AppColors.white;

    final favoritesAsync = ref.watch(favoritesProvider);
    final audioController = ref.watch(audioControllerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          cacheExtent: 250.0,
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.screenInset,
                  right: AppSpacing.screenInset,
                  top: 20,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hotlist',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.red,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your favorite tracks in one place',
                      style: TextStyle(fontSize: 14, color: AppColors.slate),
                    ),
                    const SizedBox(height: 18),

                    // Play All & Shuffle Buttons
                    favoritesAsync.when(
                      data: (favs) {
                        if (favs.isEmpty) return const SizedBox.shrink();
                        return Row(
                          children: [
                            Expanded(
                              child: Pressable(
                                pressedScale: 0.96,
                                duration: const Duration(milliseconds: 90),
                                onTap: () => audioController.playQueue(favs, initialIndex: 0),
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: playBtnBg,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_arrow_rounded, color: playBtnTextColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Play All',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: playBtnTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Pressable(
                                pressedScale: 0.96,
                                duration: const Duration(milliseconds: 90),
                                onTap: () {
                                  audioController.playQueue(favs, initialIndex: 0);
                                  audioController.toggleShuffle();
                                },
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shuffle_rounded, color: primaryTextColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Shuffle',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Favorites List with fixed extent and FadeInItem
            favoritesAsync.when(
              data: (favs) {
                if (favs.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.favorite_border_rounded, size: 48, color: AppColors.slate),
                            SizedBox(height: 12),
                            Text(
                              'No favorites yet',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.slate),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap the heart icon on any song to add it here',
                              style: TextStyle(fontSize: 13, color: AppColors.slate),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                  sliver: SliverFixedExtentList(
                    itemExtent: 68.0,
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final song = favs[idx];
                        return FadeInItem(
                          key: ValueKey(song.id),
                          itemId: song.id,
                          child: SongRowTile(
                            song: song,
                            index: idx,
                            showThumbnail: true,
                            showHeart: true,
                            onTap: () => audioController.playQueue(favs, initialIndex: idx),
                          ),
                        );
                      },
                      childCount: favs.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.totalDockHeight + 20),
            ),
          ],
        ),
      ),
    );
  }
}
