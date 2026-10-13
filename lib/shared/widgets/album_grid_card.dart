import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/motion.dart';
import '../../data/artwork/artwork_service.dart';
import '../../data/models/album_model.dart';
import 'package:on_audio_query_forked/on_audio_query.dart' hide AlbumModel, SongModel;
import 'pressable.dart';

class AlbumGridCard extends StatelessWidget {
  final AlbumModel album;
  final VoidCallback onTap;

  const AlbumGridCard({
    super.key,
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLowEnd = Motion.isLowEnd;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;

    return Pressable(
      pressedScale: 0.96,
      duration: const Duration(milliseconds: 90),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AspectRatio(1) artwork (radius 24)
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: isLowEnd
                    ? null
                    : [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ArtworkService.getThumbWidget(
                  id: album.id,
                  type: ArtworkType.ALBUM,
                  size: 200,
                  radius: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Flexible(
            child: Text(
              album.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Subtitle
          Flexible(
            child: Text(
              '${album.artist} • ${album.songCount} songs',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: AppColors.slate,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
