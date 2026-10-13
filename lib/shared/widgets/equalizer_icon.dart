import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Single shared AnimationController driving all equalizer icons simultaneously,
/// running only while a song is actually playing and at least one equalizer icon is visible.
class SharedEqualizerController {
  SharedEqualizerController._();

  static AnimationController? _controller;
  static int _activePlayingCount = 0;

  static void register(TickerProvider vsync, bool isPlaying) {
    _controller ??= AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 650),
    );
    if (isPlaying) {
      _activePlayingCount++;
      _sync();
    }
  }

  static void unregister(bool isPlaying) {
    if (isPlaying) {
      _activePlayingCount = math.max(0, _activePlayingCount - 1);
      _sync();
    }
  }

  static void updatePlaying(bool oldPlaying, bool newPlaying) {
    if (oldPlaying && !newPlaying) {
      _activePlayingCount = math.max(0, _activePlayingCount - 1);
    } else if (!oldPlaying && newPlaying) {
      _activePlayingCount++;
    }
    _sync();
  }

  static void _sync() {
    if (_controller == null) return;
    if (_activePlayingCount > 0) {
      if (!_controller!.isAnimating) {
        _controller!.repeat(reverse: true);
      }
    } else {
      if (_controller!.isAnimating) {
        _controller!.stop();
      }
    }
  }

  static Animation<double>? get animation => _controller?.view;
}

/// Standalone vsync provider for the shared equalizer AnimationController.
class _EqualizerVsync implements TickerProvider {
  const _EqualizerVsync();
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick, debugLabel: 'SharedEqualizerTicker');
  }
}

class EqualizerIcon extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const EqualizerIcon({
    super.key,
    required this.isPlaying,
    required this.color,
    this.size = 20,
  });

  @override
  State<EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<EqualizerIcon> {
  static const _vsync = _EqualizerVsync();

  @override
  void initState() {
    super.initState();
    SharedEqualizerController.register(_vsync, widget.isPlaying);
  }

  @override
  void didUpdateWidget(EqualizerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      SharedEqualizerController.updatePlaying(oldWidget.isPlaying, widget.isPlaying);
    }
  }

  @override
  void dispose() {
    SharedEqualizerController.unregister(widget.isPlaying);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = SharedEqualizerController.animation;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: anim != null
            ? AnimatedBuilder(
                animation: anim,
                builder: (context, _) => _buildBars(widget.isPlaying ? anim.value : 0.3),
              )
            : _buildBars(0.3),
      ),
    );
  }

  Widget _buildBars(double t) {
    final h1 = 0.3 + 0.7 * t;
    final h2 = 0.2 + 0.8 * (1.0 - t);
    final h3 = 0.4 + 0.6 * ((t + 0.5) % 1.0);

    final barWidth = widget.size * 0.22;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildBar(barWidth, h1),
        _buildBar(barWidth, h2),
        _buildBar(barWidth, h3),
      ],
    );
  }

  Widget _buildBar(double barWidth, double factor) {
    return Container(
      width: barWidth,
      height: widget.size * factor.clamp(0.2, 1.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(barWidth / 2),
      ),
    );
  }
}
