import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/permission_service.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onPermissionGranted;

  const PermissionScreen({super.key, this.onPermissionGranted});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen>
    with WidgetsBindingObserver {
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh status when screen mounts to ensure fresh state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[PermissionScreen] App resumed -> re-checking storage permission status');
      ref.read(permissionProvider.notifier).refresh();
    }
  }

  Future<void> _handleButtonPress(bool isPermanentlyDenied) async {
    if (isPermanentlyDenied) {
      debugPrint('[PermissionScreen] Storage permanently denied -> opening app settings');
      await PermissionService.openSettings();
      return;
    }

    setState(() => _isRequesting = true);
    try {
      debugPrint('[PermissionScreen] Requesting storage permission');
      await ref.read(permissionProvider.notifier).request();
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Permission state is single source of truth from permissionProvider
    final status = ref.watch(permissionProvider);
    final isPermanentlyDenied =
        status.isPermanentlyDenied || status.isRestricted;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.navy;

    final String? inlineMessage = isPermanentlyDenied
        ? 'Storage permission is permanently denied. Tap "Open Settings" to enable it.'
        : (status.isDenied
            ? 'Storage permission is required to scan your music files.'
            : null);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.screenInset,
            right: AppSpacing.screenInset,
            top: 24,
            bottom: 24, // 24 dp bottom safe-area padding
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Icon Circle
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkRaisedSurface
                          : AppColors.lightRaisedSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.music_note_rounded,
                          size: 52, color: AppColors.slate),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  Text(
                    'Access Your Music',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'OffBeat needs permission to read audio files from your device storage so you can listen to your local library.',
                      style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.slate,
                          height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Centered Button right under description
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isRequesting
                          ? null
                          : () => _handleButtonPress(isPermanentlyDenied),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? AppColors.white : AppColors.navy,
                        foregroundColor:
                            isDark ? AppColors.navy : AppColors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isRequesting
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color:
                                    isDark ? AppColors.navy : AppColors.white,
                              ),
                            )
                          : Text(
                              isPermanentlyDenied
                                  ? 'Open Settings'
                                  : 'Grant Storage Access',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),

                  // Small inline message under button (NOT a SnackBar)
                  if (inlineMessage != null) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        inlineMessage,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isPermanentlyDenied
                              ? AppColors.red
                              : AppColors.slate,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
