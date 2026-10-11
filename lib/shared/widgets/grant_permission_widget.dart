import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Clean screen / placeholder widget shown when audio media permissions are denied.
class GrantPermissionWidget extends StatelessWidget {
  final VoidCallback onGrantPermission;
  final VoidCallback onOpenSettings;
  final bool isPermanentlyDenied;

  const GrantPermissionWidget({
    super.key,
    required this.onGrantPermission,
    required this.onOpenSettings,
    this.isPermanentlyDenied = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: isDark ? AppColors.navyElevated : AppColors.lightCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? const Color(0x26FFFFFF)
                      : const Color(0x1F171C26),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : AppColors.navy)
                        .withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.folder_shared_rounded,
                size: 44,
                color: isDark ? AppColors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Music Access Required',
              style: theme.textTheme.displayMedium?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'OffBeat needs permission to access your local audio files to scan tracks, albums, and artists stored on your device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!isPermanentlyDenied)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Grant Permission'),
                  onPressed: onGrantPermission,
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Open App Settings'),
                      onPressed: onOpenSettings,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Permission was permanently denied. Please enable storage or audio permissions in Settings.',
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
