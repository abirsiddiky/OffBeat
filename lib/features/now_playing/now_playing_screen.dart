import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/data.dart';
import '../../playback/playback.dart';
import '../../shared/widgets/marquee_text.dart';
import '../../shared/widgets/offbeat_artwork.dart';
import '../../shared/widgets/waveform_seek_bar.dart';
import 'widgets/up_next_sheet.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final musicTheme = theme.extension<MusicPlayerThemeExtension>();

    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final position = ref.watch(playbackPositionProvider);
    final duration = ref.watch(playbackDurationProvider);
    final shuffleEnabled = ref.watch(shuffleEnabledProvider);
    final repeatMode = ref.watch(repeatModeProvider);
    final audioQualityAsync = ref.watch(audioQualityProvider);

    final isFavAsync = currentSong != null
        ? ref.watch(isFavoriteSongProvider(currentSong.id))
        : const AsyncValue.data(false);
    final isFav = isFavAsync.value ?? false;

    final playBtnBg = musicTheme?.playButtonBackground ??
        (isDark ? AppColors.white : AppColors.navy);
    final playBtnFg = musicTheme?.playButtonForeground ??
        (isDark ? AppColors.navy : AppColors.white);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => context.pop(),
        ),
        title: const Text('Now Playing'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () => _showQueueBottomSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background waveform revealing as track plays (purely decorative)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.sizeOf(context).height * 0.54,
            child: _BackgroundWaveform(
              songId: currentSong?.id ?? 0,
              position: position,
              duration: duration,
              isPlaying: isPlaying,
              isDark: isDark,
            ),
          ),

          // Main Foreground Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Large square rounded album art with soft glow
                  Center(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: musicTheme?.albumArtGlow ??
                          BoxDecoration(
                            borderRadius: AppRadius.rounded32,
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? AppColors.white : AppColors.navy)
                                    .withValues(alpha: 0.16),
                                blurRadius: 36,
                                spreadRadius: 2,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                      child: currentSong != null
                          ? Hero(
                              tag: 'player-art-${currentSong.id}',
                              child: OffBeatArtwork(
                                id: currentSong.id,
                                size: 280,
                                borderRadius: AppRadius.rounded32,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.navyElevated
                                    : AppColors.lightCard,
                                borderRadius: AppRadius.rounded32,
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                size: 96,
                                color: AppColors.slate,
                              ),
                            ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Title, Artist, Quality chips, Heart toggle & overflow
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Auto-scrolling marquee song title
                            MarqueeText(
                              key: ValueKey('np-title-${currentSong?.id}'),
                              text: currentSong?.title ?? 'No Track Playing',
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentSong != null
                                  ? '${currentSong.artist} • ${currentSong.album}'
                                  : 'Select a song from your library',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.lightSlate
                                    : AppColors.slate,
                              ),
                            ),

                            // Audio quality metadata chips
                            if (audioQualityAsync.value != null &&
                                audioQualityAsync.value!.chips.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: audioQualityAsync.value!.chips.map((chip) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.slate
                                                .withValues(alpha: 0.4)
                                            : AppColors.lightSlate
                                                .withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      chip,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.lightSlate
                                            : AppColors.slate,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (currentSong != null) ...[
                        IconButton(
                          iconSize: 26,
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav
                                ? (isDark ? AppColors.white : AppColors.navy)
                                : AppColors.slate,
                          ),
                          onPressed: () {
                            ref
                                .read(musicRepositoryProvider)
                                .toggleFavorite(currentSong.id);
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.rounded24,
                          ),
                          onSelected: (val) {
                            if (val == 'goToAlbum' && currentSong.albumId != null) {
                              context.push('/album/${currentSong.albumId}');
                            }
                          },
                          itemBuilder: (context) => [
                            if (currentSong.albumId != null)
                              const PopupMenuItem(
                                value: 'goToAlbum',
                                child: Row(
                                  children: [
                                    Icon(Icons.album_rounded, size: 20),
                                    SizedBox(width: 12),
                                    Text('View Album'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Clean Slider SeekBar
                  WaveformSeekBar(
                    position: position,
                    duration: duration,
                    songId: currentSong?.id ?? 0,
                    onSeek: (newPos) {
                      ref.read(playerControllerProvider.notifier).seekTo(newPos);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Transport Row: Shuffle, Previous, Play/Pause, Next, Repeat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle Button
                      IconButton(
                        iconSize: 26,
                        color: shuffleEnabled
                            ? (isDark ? AppColors.white : AppColors.navy)
                            : (isDark ? AppColors.slate : AppColors.lightSlate),
                        icon: const Icon(Icons.shuffle_rounded),
                        onPressed: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .toggleShuffle();
                        },
                      ),

                      // Previous Button
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: () {
                          ref.read(playerControllerProvider.notifier).previous();
                        },
                      ),

                      // Large Filled Circular Play / Pause Button
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: playBtnBg,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: playBtnBg.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: IconButton(
                          iconSize: 40,
                          color: playBtnFg,
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          onPressed: () {
                            ref
                                .read(playerControllerProvider.notifier)
                                .togglePlayPause();
                          },
                        ),
                      ),

                      // Next Button
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: () {
                          ref.read(playerControllerProvider.notifier).next();
                        },
                      ),

                      // Repeat Button (OFF / ALL / ONE visibly different)
                      IconButton(
                        iconSize: 26,
                        color: repeatMode != AudioServiceRepeatMode.none
                            ? (isDark ? AppColors.white : AppColors.navy)
                            : (isDark ? AppColors.slate : AppColors.lightSlate),
                        icon: Icon(
                          repeatMode == AudioServiceRepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                        ),
                        onPressed: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .cycleRepeatMode();
                        },
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => const UpNextSheet(),
    );
  }
}

/// Decorative full-width background waveform revealed in sync with playback.
class _BackgroundWaveform extends StatefulWidget {
  final int songId;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isDark;

  const _BackgroundWaveform({
    required this.songId,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isDark,
  });

  @override
  State<_BackgroundWaveform> createState() => _BackgroundWaveformState();
}

class _BackgroundWaveformState extends State<_BackgroundWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  List<double>? _cachedHeights;
  int? _cachedSongId;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isPlaying) {
      _breatheController.repeat(reverse: true);
    }
    _ensureHeights(widget.songId);
  }

  @override
  void didUpdateWidget(covariant _BackgroundWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _ensureHeights(widget.songId);
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _breatheController.repeat(reverse: true);
      } else {
        _breatheController.stop();
      }
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  void _ensureHeights(int songId) {
    if (_cachedSongId == songId && _cachedHeights != null) return;
    _cachedSongId = songId;

    const totalBars = 80;
    final rand = math.Random(songId == 0 ? 98765 : songId);
    _cachedHeights = List.generate(totalBars, (i) {
      final t = i / totalBars;
      // Harmonic wave blend for aesthetic waveform look
      final wave = (math.sin(t * math.pi * 3.5).abs() * 0.45 +
              math.sin(t * math.pi).abs() * 0.45 +
              0.15)
          .clamp(0.18, 0.95);
      final jitter = (rand.nextDouble() - 0.5) * 0.25;
      return (wave + jitter).clamp(0.15, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration > Duration.zero
        ? (widget.position.inMilliseconds / widget.duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _breatheController,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _BackgroundWaveformPainter(
                progress: progress,
                heights: _cachedHeights ?? const [],
                breatheFactor: widget.isPlaying ? _breatheController.value : 0.0,
                isDark: widget.isDark,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BackgroundWaveformPainter extends CustomPainter {
  final double progress;
  final List<double> heights;
  final double breatheFactor;
  final bool isDark;

  _BackgroundWaveformPainter({
    required this.progress,
    required this.heights,
    required this.breatheFactor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || heights.isEmpty) return;

    final totalBars = heights.length;
    final step = size.width / totalBars;
    final barWidth = math.max(1.8, step * 0.55);

    final revealedBaseColor = isDark ? Colors.white : AppColors.navy;
    final revealedPaint = Paint()
      ..color = revealedBaseColor.withValues(alpha: isDark ? 0.16 : 0.14)
      ..style = PaintingStyle.fill;

    final playheadPaint = Paint()
      ..color = revealedBaseColor.withValues(alpha: isDark ? 0.42 : 0.38)
      ..style = PaintingStyle.fill;

    final hiddenPaint = Paint()
      ..color = revealedBaseColor.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    final activeIndex = (progress * (totalBars - 1)).round();
    final centerY = size.height / 2;

    for (int i = 0; i < totalBars; i++) {
      final x = i * step + step / 2;
      double h = heights[i] * size.height * 0.75;

      // Subtle breathing animation on bars near playhead
      final distanceToPlayhead = (i - activeIndex).abs();
      if (distanceToPlayhead <= 2 && breatheFactor > 0) {
        final breath = (1.0 - distanceToPlayhead * 0.3) * breatheFactor * 0.22;
        h *= (1.0 + breath);
      }

      final halfH = h / 2;
      final top = centerY - halfH;
      final bottom = centerY + halfH;

      Paint paint;
      if (i < activeIndex) {
        paint = revealedPaint;
      } else if (i == activeIndex) {
        paint = playheadPaint;
      } else {
        paint = hiddenPaint;
      }

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - barWidth / 2, top, x + barWidth / 2, bottom),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.breatheFactor != breatheFactor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.heights != heights;
  }
}
