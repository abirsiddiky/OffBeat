import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../playback/playback.dart';
import '../../../shared/widgets/offbeat_artwork.dart';

/// Modal Bottom Sheet displaying "Up Next" playback queue.
/// Supports jumping, reordering, swipe-to-delete with undo, and clearing upcoming tracks.
class UpNextSheet extends ConsumerStatefulWidget {
  const UpNextSheet({super.key});

  @override
  ConsumerState<UpNextSheet> createState() => _UpNextSheetState();
}

class _UpNextSheetState extends ConsumerState<UpNextSheet> {
  final ScrollController _scrollController = ScrollController();
  int? _lastCurrentIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      return '$hours hr $minutes min';
    }
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentSong = ref.watch(currentSongProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final fullQueue = ref.watch(queueProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    // Filter to ONLY songs that will play after current song, in actual playback order
    final upcomingSongs = (currentIndex >= 0 && currentIndex < fullQueue.length - 1)
        ? fullQueue.sublist(currentIndex + 1)
        : <Song>[];

    // Auto-scroll to top when current track changes
    if (_lastCurrentIndex != currentIndex) {
      _lastCurrentIndex = currentIndex;
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }

    // Calculate total duration of upcoming songs
    final totalDuration = upcomingSongs.fold<Duration>(
      Duration.zero,
      (total, s) => total + s.duration,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, sheetScrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.slate.withValues(alpha: 0.4)
                        : AppColors.lightSlate.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Sheet Title Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Up Next',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (upcomingSongs.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .clearUpcoming();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.lightSlate
                              : AppColors.slate,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Section 1: "Now Playing"
              if (currentSong != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Now Playing',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.lightSlate : AppColors.slate,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.navyElevated.withValues(alpha: 0.75)
                          : AppColors.lightCard.withValues(alpha: 0.8),
                      borderRadius: AppRadius.rounded24,
                      border: Border.all(
                        color: isDark
                            ? AppColors.white.withValues(alpha: 0.12)
                            : AppColors.navy.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        OffBeatArtwork(
                          id: currentSong.id,
                          size: 48,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentSong.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${currentSong.artist} • ${_formatDuration(currentSong.duration)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? AppColors.lightSlate
                                      : AppColors.slate,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AnimatedMiniWaveform(isPlaying: isPlaying, isDark: isDark),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Section 2: "Next in queue" Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Next in queue',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.lightSlate : AppColors.slate,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${upcomingSongs.length} songs · ${_formatTotalDuration(totalDuration)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.lightSlate : AppColors.slate,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, indent: 20, endIndent: 20),

              // Section 2: Upcoming Songs List
              Expanded(
                child: upcomingSongs.isEmpty
                    ? Center(
                        child: Text(
                          'No upcoming songs',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.lightSlate.withValues(alpha: 0.7)
                                : AppColors.slate.withValues(alpha: 0.7),
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        scrollController: sheetScrollController,
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.only(
                          top: 6,
                          bottom: 40,
                          left: 0,
                          right: 0,
                        ),
                        itemCount: upcomingSongs.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          // Map relative indices to real indices in queue
                          final realOldIndex = currentIndex + 1 + oldIndex;
                          final realNewIndex = currentIndex + 1 + newIndex;
                          ref
                              .read(playerControllerProvider.notifier)
                              .reorderQueue(realOldIndex, realNewIndex);
                        },
                        itemBuilder: (context, i) {
                          final song = upcomingSongs[i];
                          final realIndex = currentIndex + 1 + i;

                          return RepaintBoundary(
                            key: ValueKey('upnext-${song.id}-$realIndex'),
                            child: Dismissible(
                              key: ValueKey('dismiss-${song.id}-$realIndex'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                color: Colors.redAccent.withValues(alpha: 0.85),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              onDismissed: (_) {
                                final removedSong = song;
                                ref
                                    .read(playerControllerProvider.notifier)
                                    .removeFromQueue(realIndex);

                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Removed "${removedSong.title}"'),
                                    behavior: SnackBarBehavior.floating,
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () {
                                        ref
                                            .read(playerControllerProvider.notifier)
                                            .insertSongAt(realIndex, removedSong);
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: InkWell(
                                onTap: () {
                                  // Jump to that song while keeping bottom sheet open
                                  ref
                                      .read(playerControllerProvider.notifier)
                                      .skipToQueueIndex(realIndex);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 7,
                                  ),
                                  child: Row(
                                    children: [
                                      // 1-based index in upcoming queue
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          '${i + 1}',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: isDark
                                                ? AppColors.lightSlate
                                                : AppColors.slate,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Artwork thumbnail
                                      OffBeatArtwork(
                                        id: song.id,
                                        size: 44,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      const SizedBox(width: 12),

                                      // Title & Artist • Duration
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${song.artist} • ${_formatDuration(song.duration)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: isDark
                                                    ? AppColors.lightSlate
                                                    : AppColors.slate,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Drag handle on right
                                      ReorderableDragStartListener(
                                        index: i,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          child: Icon(
                                            Icons.drag_handle_rounded,
                                            size: 22,
                                            color: isDark
                                                ? AppColors.slate
                                                : AppColors.lightSlate,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Animated 4-bar mini-waveform icon indicating actively playing status.
class _AnimatedMiniWaveform extends StatefulWidget {
  final bool isPlaying;
  final bool isDark;

  const _AnimatedMiniWaveform({
    required this.isPlaying,
    required this.isDark,
  });

  @override
  State<_AnimatedMiniWaveform> createState() => _AnimatedMiniWaveformState();
}

class _AnimatedMiniWaveformState extends State<_AnimatedMiniWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedMiniWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.isDark ? AppColors.white : AppColors.navy;

    return SizedBox(
      width: 22,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final h1 = (4.0 + (t * 12.0)).clamp(4.0, 16.0);
          final h2 = (16.0 - (t * 10.0)).clamp(4.0, 16.0);
          final h3 = (6.0 + ((1.0 - t) * 10.0)).clamp(4.0, 16.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(widget.isPlaying ? h1 : 6.0, barColor),
              _buildBar(widget.isPlaying ? h2 : 12.0, barColor),
              _buildBar(widget.isPlaying ? h3 : 8.0, barColor),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBar(double height, Color color) {
    return Container(
      width: 3.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
