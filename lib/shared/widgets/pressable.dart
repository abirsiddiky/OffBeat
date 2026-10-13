import 'package:flutter/material.dart';
import '../../core/motion.dart';

/// Lightweight press feedback widget applying a subtle scale (1.0 -> 0.97, 90 ms)
/// via Listener + AnimatedScale, avoiding expensive ink ripple clips and layer allocations.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration duration;
  final HitTestBehavior behavior;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 90),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _isPressed = false;

  void _setPressed(bool val) {
    if (_isPressed != val && mounted) {
      setState(() => _isPressed = val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final effectiveDuration = motion.disableAnimations
        ? Duration.zero
        : (motion.isLowEnd ? Duration(milliseconds: (widget.duration.inMilliseconds * 0.6).round()) : widget.duration);

    return Listener(
      behavior: widget.behavior,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isPressed ? widget.pressedScale : 1.0,
          duration: effectiveDuration,
          curve: Motion.enter,
          child: widget.child,
        ),
      ),
    );
  }
}
