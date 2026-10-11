import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import 'offbeat_artwork.dart';

class AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  final double? width;

  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyElevated : AppColors.lightCard,
          borderRadius: AppRadius.rounded24,
          border: Border.all(
            color: isDark
                ? const Color(0x1FFFFFFF)
                : const Color(0x14171C26),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.navy)
                  .withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return OffBeatArtwork(
                    id: album.id,
                    size: constraints.maxWidth,
                    borderRadius: AppRadius.rounded16,
                    fallbackIcon: Icons.album_rounded,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                '${album.artist} • ${album.numberOfSongs} songs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: isDark ? AppColors.lightSlate : AppColors.slate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
