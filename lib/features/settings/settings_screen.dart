import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/crash_logger.dart';
import '../../core/permission_service.dart';
import '../../core/theme_provider.dart';
import '../../data/scanner/rescan_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;
    final currentTheme = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 30, color: primaryTextColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenInset, vertical: 12),
        children: [
          // Section: Appearance
          _buildSectionHeader('APPEARANCE'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.palette_outlined, color: AppColors.slate),
            title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              switch (currentTheme) {
                ThemeMode.dark => 'Dark Navy (#171C26)',
                ThemeMode.light => 'Light Clean (#FFFFFF)',
                _ => 'System Default',
              },
              style: const TextStyle(color: AppColors.slate),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            onTap: () => _showThemePicker(context, ref, currentTheme),
          ),

          const SizedBox(height: 20),

          // Section: Library
          _buildSectionHeader('LIBRARY'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.refresh_rounded, color: AppColors.slate),
            title: const Text('Rescan Music Library', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Scan MediaStore for new or updated files', style: TextStyle(color: AppColors.slate)),
            onTap: () {
              ref.read(isRescanningProvider.notifier).triggerRescan(context);
            },
          ),

          const SizedBox(height: 20),

          // Section: Playback & System
          _buildSectionHeader('PLAYBACK & SYSTEM RELIABILITY'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.battery_charging_full_rounded, color: AppColors.slate),
            title: const Text('Disable Battery Optimization', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Prevents Android 10/11 & OEM task killers from killing the background playback notification',
              style: TextStyle(color: AppColors.slate, fontSize: 12.5),
            ),
            onTap: () async {
              final granted = await PermissionService.requestIgnoreBatteryOptimizations();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? 'Battery optimization disabled for OffBeat'
                          : 'Battery optimization setting opened or already requested',
                    ),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 20),

          // Section: Diagnostics
          _buildSectionHeader('DIAGNOSTICS'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined, color: AppColors.slate),
            title: const Text('Export Crash Log', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('View and copy unhandled crash reports', style: TextStyle(color: AppColors.slate)),
            onTap: () async {
              final logs = await CrashLogger.readLogs();
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Crash Log'),
                    content: SingleChildScrollView(
                      child: SelectableText(
                        logs,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: logs));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Crash logs copied to clipboard')),
                          );
                        },
                        child: const Text('Copy to Clipboard'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await CrashLogger.clearLogs();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Clear Logs'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 30),

          // About Card
          Center(
            child: Column(
              children: [
                Text(
                  'OffBeat v1.0.0',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryTextColor),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Production-quality Android local music player',
                  style: TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.slate.withOpacity(0.8),
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkRaisedSurface : AppColors.lightRaisedSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: currentMode,
                title: const Text('System Default'),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: currentMode,
                title: const Text('Dark Navy (#171C26)'),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: currentMode,
                title: const Text('Light Clean (#FFFFFF)'),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
