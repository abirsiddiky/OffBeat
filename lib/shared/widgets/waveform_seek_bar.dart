import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Formats a [Duration] into `m:ss` or `mm:ss`
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Normal audio seek bar slider with thin track, theme-adaptive styling,
/// expanding thumb during drag, and live/drag time labels.
class WaveformSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final int songId;
  final ValueChanged<Duration> onSeek;

  const WaveformSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.songId,
    required this.onSeek,
  });

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  double? _dragValue; // in seconds
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final maxSeconds = widget.duration.inMilliseconds > 0
        ? widget.duration.inMilliseconds / 1000.0
        : 1.0;
    final liveSeconds = widget.position.inMilliseconds > 0
        ? (widget.position.inMilliseconds / 1000.0).clamp(0.0, maxSeconds)
        : 0.0;
    final currentSeconds = _dragValue ?? liveSeconds;

    final displayPos = Duration(milliseconds: (currentSeconds * 1000).round());
    final remaining = widget.duration > displayPos
        ? widget.duration - displayPos
        : Duration.zero;

    final activeColor = isDark ? AppColors.white : AppColors.navy;
    final inactiveColor = AppColors.slate.withValues(alpha: 0.30);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            trackShape: const RoundedRectSliderTrackShape(),
            activeTrackColor: activeColor,
            inactiveTrackColor: inactiveColor,
            thumbColor: activeColor,
            overlayColor: activeColor.withValues(alpha: 0.15),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: _isDragging ? 9.0 : 6.5,
              elevation: 2,
              pressedElevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
          ),
          child: Slider(
            value: currentSeconds.clamp(0.0, maxSeconds),
            min: 0.0,
            max: maxSeconds,
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
              final targetMs = (val * 1000).round();
              widget.onSeek(Duration(milliseconds: targetMs));
              setState(() {
                _isDragging = false;
                _dragValue = null;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(displayPos),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isDark ? AppColors.lightSlate : AppColors.slate,
                ),
              ),
              Text(
                '-${formatDuration(remaining)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isDark ? AppColors.lightSlate : AppColors.slate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
