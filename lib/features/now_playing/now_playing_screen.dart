import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../data/artwork/artwork_service.dart';
import '../../data/models/song_model.dart';
import '../../data/repository/music_repository.dart';
import '../../playback/audio_controller.dart';
import '../../shared/widgets/action_menu_sheet.dart';
import '../../shared/widgets/background_waveform.dart';
import '../../shared/widgets/control_buttons.dart';
import '../../shared/widgets/marquee_text.dart';
import '../../shared/widgets/nav_bar.dart';
import '../../shared/widgets/pressable.dart';
import 'up_next_sheet.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;
  final NavTab? currentTab;
  final ValueChanged<NavTab>? onTabSelected;

  const NowPlayingScreen({
    super.key,
    required this.onDismiss,
    this.currentTab,
    this.onTabSelected,
  });

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  File? _largeArtFile;
  String? _loadedSongId;

  // Single controller for staggered entrance on open (Section 2b)
  late final AnimationController _staggerController;
  late final Animation<double> _artFade;
  late final Animation<double> _artScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _sliderFade;
  late final Animation<Offset> _sliderSlide;
  late final Animation<double> _controlsFade;
  late final Animation<Offset> _controlsSlide;

  bool _hasSubscribedToRoute = false;
  bool _hasTriggeredEntrance = false;

  @override
  void initState() {
    super.initState();
    // 350 ms total duration for staggered entrance
    _staggerController = AnimationController(
      vsync: this,
      duration: Motion.slow,
    );

    // Stagger intervals: each ~40ms later, 200ms each
    // 0ms - 200ms (0.0 -> 0.57)
    _artFade = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.57, curve: Motion.enter),
    );
    _artScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.0, 0.57, curve: Motion.enter),
      ),
    );

    // 40ms - 240ms (0.11 -> 0.68)
    _titleFade = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.11, 0.68, curve: Motion.enter),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.12), // 12 dp slide up
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.11, 0.68, curve: Motion.enter),
    ));

    // 80ms - 280ms (0.23 -> 0.80)
    _sliderFade = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.23, 0.80, curve: Motion.enter),
    );
    _sliderSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.23, 0.80, curve: Motion.enter),
    ));

    // 120ms - 350ms (0.34 -> 1.0)
    _controlsFade = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.34, 1.0, curve: Motion.enter),
    );
    _controlsSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.34, 1.0, curve: Motion.enter),
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasSubscribedToRoute) {
      _hasSubscribedToRoute = true;
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null && modalRoute.animation != null) {
        modalRoute.animation!.addStatusListener(_onRouteAnimationStatus);
      } else {
        _triggerEntranceOnce();
      }
    }
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Motion.isNowPlayingTransitioning.value = false;
      _triggerEntranceOnce();
    } else if (status == AnimationStatus.forward || status == AnimationStatus.reverse) {
      Motion.isNowPlayingTransitioning.value = true;
    } else if (status == AnimationStatus.dismissed) {
      Motion.isNowPlayingTransitioning.value = false;
    }
  }

  void _triggerEntranceOnce() {
    if (_hasTriggeredEntrance || !mounted) return;
    _hasTriggeredEntrance = true;
    if (Motion.of(context).disableAnimations || Motion.isLowEnd) {
      _staggerController.value = 1.0;
    } else {
      _staggerController.forward();
    }
  }

  @override
  void dispose() {
    Motion.isNowPlayingTransitioning.value = false;
    final modalRoute = ModalRoute.of(context);
    modalRoute?.animation?.removeStatusListener(_onRouteAnimationStatus);
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLowEnd = Motion.isLowEnd;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;

    final currentSong = ref.watch(currentSongProvider);
    if (currentSong == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDismiss();
      });
      return const Scaffold(backgroundColor: Colors.transparent);
    }
    final isPlaying = ref.watch(isPlayingProvider);
    final audioController = ref.watch(audioControllerProvider);

    final repeatMode = ref.watch(repeatModeProvider);
    final isShuffle = ref.watch(isShuffleEnabledProvider);

    final favoritesAsync = ref.watch(favoritesProvider);
    final isFav =
        favoritesAsync.value?.any((s) => s.id == currentSong.id) ?? false;

    // Large artwork loader
    if (currentSong.id != _loadedSongId) {
      _loadedSongId = currentSong.id;
      _loadLargeArtwork(currentSong);
    }

    // Audio specs
    final player = audioController.handler.player;
    final duration = ref.watch(currentDurationProvider).value ?? currentSong.duration;
    final audioSpecs = Formatters.buildAudioSpecs(
      filePath: currentSong.uri,
      bitrate: player.state.audioBitrate?.round(),
      sampleRate: player.state.audioParams.sampleRate,
      channels: player.state.audioParams.channelCount,
      format: player.state.audioParams.format,
      fileSize: currentSong.size,
      duration: duration,
    );

    final bottomInset = MediaQuery.of(context).padding.bottom;
    const double navH = 76.0;
    final double navPanelHeight = navH + bottomInset;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight - navPanelHeight;

            final isCompact = availableHeight < 560;
            final gapSmall = isCompact ? 4.0 : 8.0;
            final gapMedium = isCompact ? 6.0 : 12.0;
            final gapLarge = isCompact ? 8.0 : 16.0;

            final Widget contentColumn = Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // (a) Top Bar (fixed ~56 dp)
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PulseIconButton(
                          onPressed: widget.onDismiss,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 32,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          'Now Playing',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        PulseIconButton(
                          onPressed: () => UpNextSheet.show(context),
                          icon: Icon(
                            Icons.queue_music_rounded,
                            size: 26,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // (b) Flexible Artwork Area with staggered entrance
                Expanded(
                  flex: 1,
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, artConstraints) {
                        final maxSideByWidth = artConstraints.maxWidth * 0.78;
                        final maxSideByHeight = artConstraints.maxHeight - 8.0;
                        final rawSide = math.min(maxSideByWidth, maxSideByHeight);
                        final side = math.max(0.0, rawSide);

                        if (side <= 0) {
                          return const SizedBox.shrink();
                        }

                        final double artRadius = math.min(AppRadii.artwork, side * 0.16);

                        final artWidget = SizedBox(
                          width: side,
                          height: side,
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(artRadius),
                                boxShadow: isLowEnd
                                    ? null
                                    : [
                                        if (isDark)
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            blurRadius: math.min(24.0, side * 0.2),
                                            spreadRadius: 1,
                                          )
                                        else
                                          BoxShadow(
                                            color: AppColors.navy.withValues(alpha: 0.15),
                                            blurRadius: math.min(24.0, side * 0.15),
                                            offset: const Offset(0, 8),
                                          ),
                                      ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(artRadius),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(opacity: anim, child: child),
                                  child: AnimatedCrossFade(
                                    key: ValueKey(currentSong.id),
                                    duration: const Duration(milliseconds: 200),
                                    crossFadeState: _largeArtFile != null
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    firstChild: ArtworkService.getThumbWidget(
                                      id: int.tryParse(currentSong.id) ?? (currentSong.albumId ?? 0),
                                      songId: currentSong.id,
                                      albumId: currentSong.albumId,
                                      filePath: currentSong.uri,
                                      size: side,
                                      radius: artRadius,
                                    ),
                                    secondChild: _largeArtFile != null
                                        ? Image.file(
                                            _largeArtFile!,
                                            width: side,
                                            height: side,
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.high,
                                            gaplessPlayback: true,
                                            cacheWidth: (side * MediaQuery.of(context).devicePixelRatio)
                                                .toInt()
                                                .clamp(100, 1024),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );

                        return RepaintBoundary(
                          child: isLowEnd
                              ? FadeTransition(opacity: _artFade, child: artWidget)
                              : ScaleTransition(
                                  scale: _artScale,
                                  child: FadeTransition(opacity: _artFade, child: artWidget),
                                ),
                        );
                      },
                    ),
                  ),
                ),

                // (c) Staggered Title, Artist, & Chips (fade + 12 dp slide up)
                _wrapStagger(
                    slideAnim: _titleSlide,
                    fadeAnim: _titleFade,
                    isLowEnd: isLowEnd,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) {
                        if (isLowEnd) {
                          return FadeTransition(opacity: anim, child: child);
                        }
                        final slide = Tween<Offset>(
                          begin: const Offset(0.0, 0.15),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: anim, curve: Motion.enter));
                        return SlideTransition(
                          position: slide,
                          child: FadeTransition(opacity: anim, child: child),
                        );
                      },
                      child: Column(
                        key: ValueKey(currentSong.id),
                        children: [
                          // Title Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                            child: Row(
                              children: [
                                HeartPulseButton(
                                  isFav: isFav,
                                  size: isCompact ? 24 : 26,
                                  onPressed: () {
                                    ref.read(musicRepositoryProvider).toggleFavorite(currentSong.id);
                                  },
                                ),
                                Expanded(
                                  child: MarqueeText(
                                    text: currentSong.title,
                                    style: TextStyle(
                                      fontSize: isCompact ? 22 : 26,
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                      letterSpacing: -0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                PulseIconButton(
                                  onPressed: () => ActionMenuSheet.show(context, currentSong),
                                  icon: Icon(
                                    Icons.more_horiz_rounded,
                                    color: AppColors.slate,
                                    size: isCompact ? 24 : 26,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: gapSmall),

                          // Artist
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
                            child: Text(
                              currentSong.artist,
                              style: TextStyle(
                                fontSize: isCompact ? 14 : 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Audio specs chips (fade on song change)
                          if (audioSpecs.isNotEmpty) ...[
                            SizedBox(height: gapSmall),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: Padding(
                                key: ValueKey('${currentSong.id}_specs'),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: audioSpecs.map((spec) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: isCompact ? 2 : 3,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.slate.withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        spec,
                                        style: TextStyle(
                                          fontSize: isCompact ? 9.5 : 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: gapMedium),

                  // (d) Isolated Position Slider (does NOT rebuild page on every tick)
                  _wrapStagger(
                    slideAnim: _sliderSlide,
                    fadeAnim: _sliderFade,
                    isLowEnd: isLowEnd,
                    child: const _NowPlayingSliderSection(),
                  ),

                  SizedBox(height: gapMedium),

                  // (e) Controls Row with quick scale pulses (1 -> 0.92 -> 1, 120 ms)
                  _wrapStagger(
                    slideAnim: _controlsSlide,
                    fadeAnim: _controlsFade,
                    isLowEnd: isLowEnd,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenInset,
                        vertical: isCompact ? 4 : 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          PulseIconButton(
                            onPressed: () => audioController.toggleShuffle(),
                            icon: Icon(
                              Icons.shuffle_rounded,
                              size: isCompact ? 22 : 26,
                              color: isShuffle ? primaryTextColor : AppColors.slate,
                            ),
                          ),
                          PulseIconButton(
                            onPressed: () => audioController.skipToPrevious(),
                            icon: Icon(
                              Icons.skip_previous_rounded,
                              size: isCompact ? 32 : 38,
                              color: primaryTextColor,
                            ),
                          ),
                          // Big Play/Pause Button with AnimatedIcon + 120ms pulse
                          Pressable(
                            pressedScale: 0.92,
                            duration: const Duration(milliseconds: 120),
                            onTap: () => audioController.togglePlay(),
                            child: Container(
                              width: isCompact ? 68 : 76,
                              height: isCompact ? 68 : 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.white : AppColors.navy,
                                boxShadow: isLowEnd
                                    ? null
                                    : [
                                        if (isDark)
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            blurRadius: 24,
                                            spreadRadius: 1,
                                          )
                                        else
                                          BoxShadow(
                                            color: AppColors.navy.withValues(alpha: 0.28),
                                            blurRadius: 24,
                                            offset: const Offset(0, 6),
                                          ),
                                      ],
                              ),
                              child: Center(
                                child: _AnimatedPlayPauseIcon(
                                  isPlaying: isPlaying,
                                  size: isCompact ? 38 : 42,
                                  color: isDark ? AppColors.navy : AppColors.white,
                                ),
                              ),
                            ),
                          ),
                          PulseIconButton(
                            onPressed: () => audioController.skipToNext(),
                            icon: Icon(
                              Icons.skip_next_rounded,
                              size: isCompact ? 32 : 38,
                              color: primaryTextColor,
                            ),
                          ),
                          PulseIconButton(
                            onPressed: () => audioController.toggleRepeat(),
                            icon: _buildRepeatIcon(repeatMode, primaryTextColor, isCompact ? 22 : 26),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: gapLarge),
                ],
              );

            final Widget effectiveContent;
            if (availableHeight < 520) {
              effectiveContent = ClipRect(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: availableWidth,
                    height: 520,
                    child: contentColumn,
                  ),
                ),
              );
            } else {
              effectiveContent = SizedBox(
                width: availableWidth,
                height: availableHeight,
                child: contentColumn,
              );
            }

            return RepaintBoundary(
              child: Stack(
                children: [
                  // Background Waveform
                  Consumer(
                      builder: (context, ref, _) {
                        final pos = ref.watch(currentPositionProvider).value ?? Duration.zero;
                        return Positioned.fill(
                          child: IgnorePointer(
                            child: BackgroundWaveform(
                              songId: currentSong.id,
                              position: pos,
                              duration: duration,
                              isPlaying: isPlaying,
                              isDark: isDark,
                            ),
                          ),
                        );
                      },
                    ),

                  // Foreground Content
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: navPanelHeight,
                    child: effectiveContent,
                  ),

                  // Nav panel at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: navPanelHeight,
                    child: BottomNavPanel(
                      currentTab: widget.currentTab ?? NavTab.home,
                      onTabSelected: (tab) {
                        widget.onDismiss();
                        widget.onTabSelected?.call(tab);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _wrapStagger({
    required Animation<Offset> slideAnim,
    required Animation<double> fadeAnim,
    required bool isLowEnd,
    required Widget child,
  }) {
    if (isLowEnd) {
      return FadeTransition(opacity: fadeAnim, child: child);
    }
    return SlideTransition(
      position: slideAnim,
      child: FadeTransition(opacity: fadeAnim, child: child),
    );
  }

  Widget _buildRepeatIcon(AudioServiceRepeatMode mode, Color activeColor, double size) {
    switch (mode) {
      case AudioServiceRepeatMode.all:
        return Icon(Icons.repeat_rounded, size: size, color: activeColor);
      case AudioServiceRepeatMode.one:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.repeat_rounded, size: size, color: activeColor),
            Positioned(
              top: 5,
              child: Text(
                '1',
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                  color: activeColor,
                ),
              ),
            ),
          ],
        );
      case AudioServiceRepeatMode.none:
      default:
        return Icon(Icons.repeat_rounded, size: size, color: AppColors.slate);
    }
  }

  Future<void> _loadLargeArtwork(SongModel song) async {
    final file = await ArtworkService.getLargeArtworkFile(
      songId: song.id,
      filePath: song.uri,
      albumId: song.albumId,
    );
    if (mounted && _loadedSongId == song.id) {
      setState(() {
        _largeArtFile = file;
      });
    }
  }
}

/// Dedicated Slider section watching position stream isolated from parent
class _NowPlayingSliderSection extends ConsumerStatefulWidget {
  const _NowPlayingSliderSection();

  @override
  ConsumerState<_NowPlayingSliderSection> createState() => _NowPlayingSliderSectionState();
}

class _NowPlayingSliderSectionState extends ConsumerState<_NowPlayingSliderSection> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);
    final audioController = ref.watch(audioControllerProvider);
    final position = ref.watch(currentPositionProvider).value ?? Duration.zero;
    final duration = ref.watch(currentDurationProvider).value ??
        (currentSong?.duration ?? Duration.zero);

    final effectivePosition = _isDragging
        ? Duration(milliseconds: _dragValue.toInt())
        : position;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: effectivePosition.inMilliseconds
                  .toDouble()
                  .clamp(0.0, duration.inMilliseconds.toDouble()),
              min: 0.0,
              max: duration.inMilliseconds > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0,
              onChangeStart: (val) {
                setState(() {
                  _isDragging = true;
                  _dragValue = val;
                });
              },
              onChanged: (val) {
                setState(() {
                  _dragValue = val;
                });
              },
              onChangeEnd: (val) {
                audioController.seek(Duration(milliseconds: val.toInt()));
                setState(() {
                  _isDragging = false;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Formatters.formatDuration(effectivePosition),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate,
                  ),
                ),
                Text(
                  Formatters.formatDuration(duration),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated play/pause icon with smooth progress transition
class _AnimatedPlayPauseIcon extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final Color color;

  const _AnimatedPlayPauseIcon({
    required this.isPlaying,
    required this.size,
    required this.color,
  });

  @override
  State<_AnimatedPlayPauseIcon> createState() => _AnimatedPlayPauseIconState();
}

class _AnimatedPlayPauseIconState extends State<_AnimatedPlayPauseIcon>
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
  void didUpdateWidget(_AnimatedPlayPauseIcon oldWidget) {
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
