import 'package:flutter/material.dart';
import '../../core/motion.dart';

/// Wraps list/grid items so they smoothly fade in once (200 ms) on initial appearance.
/// Uses a static cache so scrolling down and back never re-triggers the animation.
class FadeInItem extends StatefulWidget {
  final Object itemId;
  final Widget child;
  final Duration duration;

  const FadeInItem({
    super.key,
    required this.itemId,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });

  static final Set<Object> _alreadyAnimated = {};

  static void reset() {
    _alreadyAnimated.clear();
  }

  @override
  State<FadeInItem> createState() => _FadeInItemState();
}

class _FadeInItemState extends State<FadeInItem> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final bool _animate;

  @override
  void initState() {
    super.initState();
    final isLowEnd = Motion.isLowEnd;
    final already = FadeInItem._alreadyAnimated.contains(widget.itemId);

    // Skip animation entirely on low-end devices or if already animated
    if (already || isLowEnd) {
      _animate = false;
      FadeInItem._alreadyAnimated.add(widget.itemId);
    } else {
      _animate = true;
      FadeInItem._alreadyAnimated.add(widget.itemId);
      _controller = AnimationController(
        vsync: this,
        duration: widget.duration,
      )..forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate || _controller == null) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _controller!,
      child: widget.child,
    );
  }
}
