import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/artwork/artwork_service.dart';
import '../../playback/audio_controller.dart';

class UpNextSheet extends ConsumerWidget {
  const UpNextSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UpNextSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final raisedBg = isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface;

    final currentSong = ref.watch(currentSongProvider);
    final audioController = ref.watch(audioControllerProvider);
    final upcoming = audioController.upcomingQueue;

    // Calculate total duration
    final totalDuration = upcoming.fold<Duration>(
      Duration.zero,
      (prev, s) => prev + s.duration,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.slate.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: "Up Next", "N songs · duration", "Clear"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Up Next',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${upcoming.length} songs · ${Formatters.formatDuration(totalDuration)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.slate,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (upcoming.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          audioController.clearUpcomingQueue();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.slate,
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // List View
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
                  children: [
                    // Section: Now Playing
                    if (currentSong != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.slate.withOpacity(0.8),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: raisedBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            ArtworkService.getThumbWidget(
                              id: int.tryParse(currentSong.id) ?? (currentSong.albumId ?? 0),
                              songId: currentSong.id,
                              albumId: currentSong.albumId,
                              filePath: currentSong.uri,
                              size: 46,
                              radius: 12,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentSong.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentSong.artist,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.slate,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.volume_up_rounded,
                              color: AppColors.slate,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Section: Next in Queue
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 8),
                      child: Text(
                        'NEXT IN QUEUE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.slate.withOpacity(0.8),
                        ),
                      ),
                    ),

                    if (upcoming.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No upcoming songs',
                            style: TextStyle(
                              color: AppColors.slate,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: upcoming.length,
                        onReorder: (oldIndex, newIndex) {
                          // Note: queue offset is after current playing song
                          final full = audioController.handler.currentActiveQueue;
                          final currIdx = full.indexWhere((s) => s.id == currentSong?.id);
                          final startOffset = currIdx + 1;
                          audioController.reorderQueue(startOffset + oldIndex, startOffset + newIndex);
                        },
                        itemBuilder: (context, idx) {
                          final song = upcoming[idx];
                          return Dismissible(
                            key: ValueKey('queue_${song.id}_$idx'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              final full = audioController.handler.currentActiveQueue;
                              final currIdx = full.indexWhere((s) => s.id == currentSong?.id);
                              final realIdx = currIdx + 1 + idx;
                              audioController.removeFromQueue(realIdx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed "${song.title}"'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      audioController.addToQueue(song);
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: ArtworkService.getThumbWidget(
                                  id: int.tryParse(song.id) ?? (song.albumId ?? 0),
                                  songId: song.id,
                                  albumId: song.albumId,
                                  filePath: song.uri,
                                  size: 44,
                                  radius: 12,
                                ),
                                title: Text(
                                  song.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: primaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${song.artist} • ${Formatters.formatDuration(song.duration)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.slate,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: ReorderableDragStartListener(
                                  index: idx,
                                  child: const Icon(Icons.drag_handle_rounded, color: AppColors.slate),
                                ),
                                onTap: () {
                                  final full = audioController.handler.currentActiveQueue;
                                  final currIdx = full.indexWhere((s) => s.id == currentSong?.id);
                                  audioController.jumpToQueueItem(currIdx + 1 + idx);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
