import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Corner radius tokens for OffBeat
class AppRadius {
  const AppRadius._();

  static const double r16 = 16.0;
  static const double r24 = 24.0;
  static const double r32 = 32.0;

  static const BorderRadius rounded16 = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius rounded24 = BorderRadius.all(Radius.circular(r24));
  static const BorderRadius rounded32 = BorderRadius.all(Radius.circular(r32));
}

/// Custom theme extension for music player-specific styling such as glows and surface tokens.
class MusicPlayerThemeExtension extends ThemeExtension<MusicPlayerThemeExtension> {
  final BoxDecoration albumArtGlow;
  final Color miniPlayerBackground;
  final Color miniPlayerForeground;
  final Color playButtonBackground;
  final Color playButtonForeground;

  const MusicPlayerThemeExtension({
    required this.albumArtGlow,
    required this.miniPlayerBackground,
    required this.miniPlayerForeground,
    required this.playButtonBackground,
    required this.playButtonForeground,
  });

  @override
  MusicPlayerThemeExtension copyWith({
    BoxDecoration? albumArtGlow,
    Color? miniPlayerBackground,
    Color? miniPlayerForeground,
    Color? playButtonBackground,
    Color? playButtonForeground,
  }) {
    return MusicPlayerThemeExtension(
      albumArtGlow: albumArtGlow ?? this.albumArtGlow,
      miniPlayerBackground: miniPlayerBackground ?? this.miniPlayerBackground,
      miniPlayerForeground: miniPlayerForeground ?? this.miniPlayerForeground,
      playButtonBackground: playButtonBackground ?? this.playButtonBackground,
      playButtonForeground: playButtonForeground ?? this.playButtonForeground,
    );
  }

  @override
  MusicPlayerThemeExtension lerp(ThemeExtension<MusicPlayerThemeExtension>? other, double t) {
    if (other is! MusicPlayerThemeExtension) return this;
    return MusicPlayerThemeExtension(
      albumArtGlow: BoxDecoration.lerp(albumArtGlow, other.albumArtGlow, t) ?? albumArtGlow,
      miniPlayerBackground: Color.lerp(miniPlayerBackground, other.miniPlayerBackground, t) ?? miniPlayerBackground,
      miniPlayerForeground: Color.lerp(miniPlayerForeground, other.miniPlayerForeground, t) ?? miniPlayerForeground,
      playButtonBackground: Color.lerp(playButtonBackground, other.playButtonBackground, t) ?? playButtonBackground,
      playButtonForeground: Color.lerp(playButtonForeground, other.playButtonForeground, t) ?? playButtonForeground,
    );
  }
}

class AppTheme {
  const AppTheme._();

  /// Dark Theme
  /// - Navy background (#171C26)
  /// - White text (#FFFFFF)
  /// - White accent buttons
  /// - Soft glow behind album art
  /// - Large rounded corners (16 / 24 / 32)
  /// - Modern custom appearance, free of default Material styling
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.navy,
      canvasColor: AppColors.navy,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.white,
        onPrimary: AppColors.navy,
        primaryContainer: AppColors.navyContainer,
        onPrimaryContainer: AppColors.white,
        secondary: AppColors.lightSlate,
        onSecondary: AppColors.navy,
        secondaryContainer: AppColors.navyElevated,
        onSecondaryContainer: AppColors.white,
        surface: AppColors.navy,
        onSurface: AppColors.white,
        surfaceContainer: AppColors.navyElevated,
        surfaceContainerHigh: AppColors.navyContainer,
        error: Color(0xFFEF5350),
        onError: AppColors.white,
        outline: AppColors.slate,
        outlineVariant: Color(0x336C7689),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.lightSlate,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          color: AppColors.slate,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.navyElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rounded24,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.navy,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.rounded32,
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.navy,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.rounded32,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightSlate,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.rounded16,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.rounded16,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.navyElevated,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rounded32,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.navy,
        modalBackgroundColor: AppColors.navy,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r32)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navyElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.inter(color: AppColors.slate),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.rounded24,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rounded24,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rounded24,
          borderSide: BorderSide(color: AppColors.lightSlate, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.white,
        inactiveTrackColor: AppColors.slate.withValues(alpha: 0.3),
        thumbColor: AppColors.white,
        overlayColor: AppColors.white.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1FA4AAB7),
        thickness: 1,
        space: 1,
      ),
      extensions: [
        MusicPlayerThemeExtension(
          albumArtGlow: BoxDecoration(
            borderRadius: AppRadius.rounded32,
            boxShadow: [
              BoxShadow(
                color: AppColors.white.withValues(alpha: 0.16),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          miniPlayerBackground: AppColors.navyElevated,
          miniPlayerForeground: AppColors.white,
          playButtonBackground: AppColors.white,
          playButtonForeground: AppColors.navy,
        ),
      ],
    );
  }

  /// Light Theme
  /// - White background (#FFFFFF)
  /// - Navy text (#171C26)
  /// - Navy/black play button and mini-player
  /// - Large rounded corners (16 / 24 / 32)
  /// - Clean modern look with custom pill elements
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.white,
      canvasColor: AppColors.white,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.navy,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.lightContainer,
        onPrimaryContainer: AppColors.navy,
        secondary: AppColors.slate,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.lightCard,
        onSecondaryContainer: AppColors.navy,
        surface: AppColors.white,
        onSurface: AppColors.navy,
        surfaceContainer: AppColors.lightCard,
        surfaceContainerHigh: AppColors.lightContainer,
        error: Color(0xFFD32F2F),
        onError: AppColors.white,
        outline: AppColors.lightSlate,
        outlineVariant: Color(0x266C7689),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.slate,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          color: AppColors.slate,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.navy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.navy),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rounded24,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.rounded32,
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.rounded32,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.slate,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.rounded16,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.navy,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.rounded16,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rounded32,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        modalBackgroundColor: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r32)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.inter(color: AppColors.slate),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.rounded24,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rounded24,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.rounded24,
          borderSide: BorderSide(color: AppColors.navy, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.navy,
        inactiveTrackColor: AppColors.lightSlate.withValues(alpha: 0.4),
        thumbColor: AppColors.navy,
        overlayColor: AppColors.navy.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x19171C26),
        thickness: 1,
        space: 1,
      ),
      extensions: [
        MusicPlayerThemeExtension(
          albumArtGlow: BoxDecoration(
            borderRadius: AppRadius.rounded32,
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          miniPlayerBackground: AppColors.navy,
          miniPlayerForeground: AppColors.white,
          playButtonBackground: AppColors.navy,
          playButtonForeground: AppColors.white,
        ),
      ],
    );
  }
}
