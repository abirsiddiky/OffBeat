import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/motion.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final double pauseDurationSeconds;
  final double scrollSpeed; // pixels per second

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.center,
    this.pauseDurationSeconds = 1.5,
    this.scrollSpeed = 35.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _loopTimer;
  bool _isOverflowing = false;
  bool _tickerActive = true;

  @override
  void initState() {
    super.initState();
    Motion.isNowPlayingTransitioning.addListener(_onTransitionChanged);
  }

  void _onTransitionChanged() {
    if (Motion.isNowPlayingTransitioning.value) {
      _stopLoop();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflowAndStart());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTickerActive = TickerMode.valuesOf(context).enabled;
    if (isTickerActive != _tickerActive) {
      _tickerActive = isTickerActive;
      if (!_tickerActive) {
        _stopLoop();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflowAndStart());
      }
    }
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopLoop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflowAndStart());
    }
  }

  @override
  void dispose() {
    Motion.isNowPlayingTransitioning.removeListener(_onTransitionChanged);
    _stopLoop();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopLoop() {
    _loopTimer?.cancel();
    _loopTimer = null;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _checkOverflowAndStart() {
    if (!mounted || !_scrollController.hasClients || !_tickerActive || Motion.isNowPlayingTransitioning.value) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 1.0) {
      if (!_isOverflowing) {
        setState(() => _isOverflowing = true);
      }
      _startLoop(maxScroll);
    } else {
      if (_isOverflowing) {
        setState(() => _isOverflowing = false);
      }
    }
  }

  void _startLoop(double maxScroll) {
    if (!_tickerActive || Motion.isNowPlayingTransitioning.value) return;
    _loopTimer?.cancel();
    _loopTimer = Timer(Duration(milliseconds: (widget.pauseDurationSeconds * 1000).toInt()), () async {
      if (!mounted || !_scrollController.hasClients || !_tickerActive || Motion.isNowPlayingTransitioning.value) return;

      final distance = maxScroll;
      final durationMs = (distance / widget.scrollSpeed * 1000).toInt();

      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );

        if (!mounted || !_scrollController.hasClients || !_tickerActive || Motion.isNowPlayingTransitioning.value) return;
        await Future.delayed(Duration(milliseconds: (widget.pauseDurationSeconds * 1000).toInt()));

        if (!mounted || !_scrollController.hasClients || !_tickerActive || Motion.isNowPlayingTransitioning.value) return;
        await _scrollController.animateTo(
          0.0,
          duration: Duration(milliseconds: (durationMs * 0.7).toInt()),
          curve: Curves.linear,
        );

        if (!mounted || !_scrollController.hasClients || !_tickerActive || Motion.isNowPlayingTransitioning.value) return;
        _startLoop(maxScroll);
      } catch (e) {
        // Safe catch on cancel/scroll dispose
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Text(
              widget.text,
              style: widget.style,
              textAlign: widget.textAlign,
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}
