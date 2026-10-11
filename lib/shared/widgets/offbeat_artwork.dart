import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Reusable artwork component with monochrome/silhouette styling and resilient fallback.
class OffBeatArtwork extends StatelessWidget {
  final int id;
  final ArtworkType type;
  final double size;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  const OffBeatArtwork({
    super.key,
    required this.id,
    this.type = ArtworkType.AUDIO,
    this.size = 48.0,
    this.borderRadius,
    this.fallbackIcon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? AppRadius.rounded16;

    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyElevated : AppColors.lightCard,
        borderRadius: radius,
        border: Border.all(
          color: isDark
              ? const Color(0x26FFFFFF)
              : const Color(0x19171C26),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: size * 0.45,
          color: isDark ? AppColors.lightSlate : AppColors.slate,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: QueryArtworkWidget(
          id: id,
          type: type,
          artworkWidth: size,
          artworkHeight: size,
          artworkFit: BoxFit.cover,
          artworkBorder: radius,
          keepOldArtwork: true,
          nullArtworkWidget: placeholder,
          errorBuilder: (context, exception, stackTrace) => placeholder,
        ),
      ),
    );
  }
}
