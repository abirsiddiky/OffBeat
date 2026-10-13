import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/motion.dart';
import '../../data/artwork/artwork_service.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import 'control_buttons.dart';
import 'marquee_text.dart';
import 'pressable.dart';

class MiniPlayerBar extends ConsumerWidget {
  static const double miniH = 100.0;
  static const double defaultOverlap = 28.0;

  final VoidCallback onTap;
  final double contentBottomPadding;

  const MiniPlayerBar({
    super.key,
    required this.onTap,
    this.contentBottomPadding = defaultOverlap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final audioController = ref.watch(audioControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLowEnd = Motion.isLowEnd;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final cardBg = isDark ? AppColors.white : AppColors.navy;
    final primaryTextColor = isDark ? AppColors.navy : AppColors.white;
    final secondaryTextColor = isDark ? const Color(0xFF6C7689) : AppColors.lightSlate;
    final buttonBg = isDark ? AppColors.navy : AppColors.white;
    final buttonIconColor = isDark ? AppColors.white : AppColors.navy;

    final favoritesAsync = ref.watch(favoritesProvider);
    final isFav = favoritesAsync.value?.any((s) => s.id == currentSong.id) ?? false;

    final visibleHeight = miniH - contentBottomPadding; // 72 dp

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: miniH,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                blurRadius: isLowEnd ? 12 : 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Artwork thumbnail fills full height (100 dp) of card at far left, width ~76 dp
              SizedBox(
                width: 76,
                height: miniH,
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: miniH,
                    height: miniH,
                    child: ArtworkService.getThumbWidget(
                      id: int.tryParse(currentSong.id) ?? (currentSong.albumId ?? 0),
                      songId: currentSong.id,
                      albumId: currentSong.albumId,
                      filePath: currentSong.uri,
                      size: miniH,
                      radius: 0,
                    ),
                  ),
                ),
              ),

              // All controls sit strictly inside the visible 72 dp area
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: contentBottomPadding),
                  child: SizedBox(
                    height: visibleHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 14),

                        // Title + Artist column
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MarqueeText(
                                text: currentSong.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                  letterSpacing: -0.2,
                                ),
                                textAlign: TextAlign.left,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentSong.artist,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: secondaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Heart favorite button with pulse and color cross-fade
                        HeartPulseButton(
                          isFav: isFav,
                          size: 24,
                          activeColor: AppColors.red,
                          inactiveColor: primaryTextColor,
                          onPressed: () {
                            ref.read(musicRepositoryProvider).toggleFavorite(currentSong.id);
                          },
                        ),

                        // 44 dp Play/Pause circular button with 120 ms pulse and AnimatedIcon
                        Padding(
                          padding: const EdgeInsets.only(right: 18, left: 2),
                          child: Pressable(
                            pressedScale: 0.92,
                            duration: const Duration(milliseconds: 120),
                            onTap: () => audioController.togglePlay(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: buttonBg,
                                shape: BoxShape.circle,
                                boxShadow: isLowEnd
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: buttonBg.withValues(alpha: isDark ? 0.35 : 0.25),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: MiniPlayPauseIcon(
                                  isPlaying: isPlaying,
                                  size: 24,
                                  color: buttonIconColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated play/pause icon with smooth progress transition
class MiniPlayPauseIcon extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final Color color;

  const MiniPlayPauseIcon({
    super.key,
    required this.isPlaying,
    required this.size,
    required this.color,
  });

  @override
  State<MiniPlayPauseIcon> createState() => _MiniPlayPauseIconState();
}

class _MiniPlayPauseIconState extends State<MiniPlayPauseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Motion.normal,
    );
    if (widget.isPlaying) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MiniPlayPauseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    return AnimatedIcon(
      icon: AnimatedIcons.play_pause,
      progress: _controller,
      size: widget.size,
      color: widget.color,
    );
  }
}

typedef MiniPlayer = MiniPlayerBar;
