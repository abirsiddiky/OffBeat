import 'dart:async';
import 'package:flutter/material.dart';

/// Reusable auto-scrolling marquee text widget with soft fade edges.
/// Scrolls left-to-right/loop only when [text] exceeds available width.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double scrollSpeed; // pixels per second

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(milliseconds: 1500),
    this.scrollSpeed = 32.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopScroll();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopScroll();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopScroll() {
    _isScrolling = false;
  }

  Future<void> _checkAndStartScroll() async {
    if (_disposed || !mounted || _isScrolling) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _isScrolling = true;

    while (mounted && !_disposed && _isScrolling) {
      // 1. Initial pause at start
      await Future.delayed(widget.pauseDuration);
      if (!mounted || _disposed || !_isScrolling) break;
      if (!_scrollController.hasClients) break;

      final currentMax = _scrollController.position.maxScrollExtent;
      if (currentMax <= 0) break;

      // 2. Animate to end at constant speed
      final scrollDuration = Duration(
        milliseconds: ((currentMax / widget.scrollSpeed) * 1000).round(),
      );

      try {
        await _scrollController.animateTo(
          currentMax,
          duration: scrollDuration,
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }

      if (!mounted || _disposed || !_isScrolling) break;

      // 3. Pause at end
      await Future.delayed(widget.pauseDuration);
      if (!mounted || _disposed || !_isScrolling) break;
      if (!_scrollController.hasClients) break;

      // 4. Smoothly scroll back to start (or jump back)
      try {
        await _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      } catch (_) {
        break;
      }
    }

    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = widget.style ?? DefaultTextStyle.of(context).style;
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();

        final textWidth = textPainter.width;
        final availableWidth = constraints.maxWidth;

        // If text fits in available container, display static text
        if (textWidth <= availableWidth) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        // Needs marquee scrolling with soft edge fade
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isScrolling) {
            _checkAndStartScroll();
          }
        });

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.03, 0.97, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        );
      },
    );
  }
}
