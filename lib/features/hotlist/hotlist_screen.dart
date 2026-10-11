import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data.dart';
import '../../playback/playback.dart';
import '../../shared/widgets/track_tile.dart';

class HotlistScreen extends ConsumerWidget {
  const HotlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hotlistAsync = ref.watch(hotlistProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.white : AppColors.navy,
                borderRadius: AppRadius.rounded16,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: isDark ? AppColors.navy : AppColors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Hotlist'),
          ],
        ),
      ),
      body: hotlistAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.navyElevated
                            : AppColors.lightCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0x26FFFFFF)
                              : const Color(0x19171C26),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.local_fire_department_outlined,
                        size: 44,
                        color: isDark ? AppColors.lightSlate : AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your Hotlist is Empty',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart icon on any song to add it to your heavy rotation list.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 180),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text('Play Hotlist'),
                        style: ElevatedButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.rounded32,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .playSongs(songs, 0);
                          context.push('/now-playing');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.shuffle_rounded, size: 22),
                        label: const Text('Shuffle'),
                        style: OutlinedButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.rounded32,
                          ),
                          side: BorderSide(
                            color: isDark ? AppColors.white : AppColors.navy,
                            width: 1.5,
                          ),
                          foregroundColor:
                              isDark ? AppColors.white : AppColors.navy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () {
                          final shuffled = List<Song>.from(songs)
                            ..shuffle(Random());
                          ref
                              .read(playerControllerProvider.notifier)
                              .playSongs(shuffled, 0);
                          context.push('/now-playing');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  '${songs.length} Tracks In Heavy Rotation',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...List.generate(songs.length, (i) {
                final song = songs[i];
                return TrackTile(
                  song: song,
                  index: i,
                  onTap: () {
                    // Tapping plays the whole hotlist as queue starting at this track
                    ref
                        .read(playerControllerProvider.notifier)
                        .playSongs(songs, i);
                  },
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading Hotlist: $e')),
      ),
    );
  }
}
