import 'package:flutter/material.dart';
import '../../core/motion.dart';

/// Icon button with a scale pulse (1.0 -> 0.92 -> 1.0, 120 ms) on tap.
class PulseIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final double iconSize;
  final double splashRadius;
  final double targetScale;
  final Duration duration;

  const PulseIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconSize = 24,
    this.splashRadius = 24,
    this.targetScale = 0.92,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<PulseIconButton> createState() => _PulseIconButtonState();
}

class _PulseIconButtonState extends State<PulseIconButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: widget.targetScale), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: widget.targetScale, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Motion.standard));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (Motion.isLowEnd) {
      widget.onPressed?.call();
    } else {
      _controller.forward(from: 0.0);
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.splashRadius * 2,
          height: widget.splashRadius * 2,
          child: Center(child: widget.icon),
        ),
      ),
    );
  }
}

/// Heart button with scale pulse (1.0 -> 1.25 -> 1.0) and smooth color cross-fade (200 ms).
class HeartPulseButton extends StatefulWidget {
  final bool isFav;
  final VoidCallback? onPressed;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const HeartPulseButton({
    super.key,
    required this.isFav,
    this.onPressed,
    this.size = 24,
    this.activeColor = const Color(0xFFE53935),
    this.inactiveColor = const Color(0xFF6C7689),
  });

  @override
  State<HeartPulseButton> createState() => _HeartPulseButtonState();
}

class _HeartPulseButtonState extends State<HeartPulseButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.25), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Motion.enter));
  }

  @override
  void didUpdateWidget(HeartPulseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFav != widget.isFav && widget.isFav && !Motion.isLowEnd) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!Motion.isLowEnd) {
      _controller.forward(from: 0.0);
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.size + 18,
          height: widget.size + 18,
          child: Center(
            child: TweenAnimationBuilder<Color?>(
              duration: const Duration(milliseconds: 200),
              curve: Motion.enter,
              tween: ColorTween(
                end: widget.isFav ? widget.activeColor : widget.inactiveColor,
              ),
              builder: (context, color, _) {
                return Icon(
                  widget.isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: color,
                  size: widget.size,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
