import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/motion.dart';

class BackgroundWaveform extends StatefulWidget {
  final String songId;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isDark;

  const BackgroundWaveform({
    super.key,
    required this.songId,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isDark,
  });

  @override
  State<BackgroundWaveform> createState() => _BackgroundWaveformState();
}

class _BackgroundWaveformState extends State<BackgroundWaveform> with WidgetsBindingObserver {
  late Float32List _cachedEnvelope;
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  int _lastThrottledMs = 0;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cachedEnvelope = _generateEnvelope(widget.songId);
    _updateProgress();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(BackgroundWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _cachedEnvelope = _generateEnvelope(widget.songId);
    }

    if (!_isAppActive) return;

    // Throttle progress updates to 30 fps (33ms) or 20 fps (50ms) in low-end mode
    final throttleLimitMs = Motion.isLowEnd ? 50 : 33;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastThrottledMs >= throttleLimitMs || widget.position == Duration.zero) {
      _lastThrottledMs = nowMs;
      _updateProgress();
    }
  }

  void _updateProgress() {
    final total = widget.duration.inMilliseconds;
    if (total > 0) {
      _progressNotifier.value = (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
    } else {
      _progressNotifier.value = 0.0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressNotifier.dispose();
    super.dispose();
  }

  static Float32List _generateEnvelope(String songId) {
    const int count = 80;
    final random = math.Random(songId.hashCode);
    final Float32List raw = Float32List(count);

    double prev = 0.3 + random.nextDouble() * 0.4;
    for (int i = 0; i < count; i++) {
      final step = (random.nextDouble() - 0.5) * 0.35;
      prev = (prev + step).clamp(0.15, 0.95);
      final window = math.sin(i / count * math.pi);
      raw[i] = (prev * (0.3 + 0.7 * window)).clamp(0.12, 1.0);
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BatchedWaveformPainter(
            envelope: _cachedEnvelope,
            progressNotifier: _progressNotifier,
            isDark: widget.isDark,
          ),
        ),
      ),
    );
  }
}

/// Highly optimized single-paint batch painter using drawPoints(PointMode.lines).
/// Zero per-bar allocations, no Path/saveLayer, runs smoothly at 60 fps.
class _BatchedWaveformPainter extends CustomPainter {
  final Float32List envelope;
  final ValueNotifier<double> progressNotifier;
  final bool isDark;

  _BatchedWaveformPainter({
    required this.envelope,
    required this.progressNotifier,
    required this.isDark,
  }) : super(repaint: progressNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final progress = progressNotifier.value;
    final yCenter = size.height / 2;
    final count = envelope.length;

    const double barWidth = 3.2;
    final double totalSpacing = size.width - (count * barWidth);
    final double spacing = totalSpacing / (count - 1);
    final int playheadIdx = (progress * (count - 1)).round();

    final List<Offset> pastPoints = [];
    final List<Offset> futurePoints = [];

    for (int i = 0; i < count; i++) {
      final x = i * (barWidth + spacing) + barWidth / 2;
      final barH = (envelope[i] * size.height * 0.88).clamp(6.0, size.height);
      final top = yCenter - barH / 2;
      final bottom = yCenter + barH / 2;

      if (i <= playheadIdx) {
        pastPoints.add(Offset(x, top));
        pastPoints.add(Offset(x, bottom));
      } else {
        futurePoints.add(Offset(x, top));
        futurePoints.add(Offset(x, bottom));
      }
    }

    final paint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final baseColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF171C26);

    // Draw future/upcoming bars in single call (~3.5% opacity)
    if (futurePoints.isNotEmpty) {
      paint.color = baseColor.withValues(alpha: 0.035);
      canvas.drawPoints(PointMode.lines, futurePoints, paint);
    }

    // Draw past/revealed bars in single call (~18% opacity)
    if (pastPoints.isNotEmpty) {
      paint.color = baseColor.withValues(alpha: 0.18);
      canvas.drawPoints(PointMode.lines, pastPoints, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BatchedWaveformPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.envelope != envelope;
  }
}
