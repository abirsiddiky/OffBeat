import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final interFont = GoogleFonts.inter().fontFamily;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: interFont,
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.white,
        onPrimary: AppColors.navy,
        surface: AppColors.darkBackground,
        onSurface: AppColors.white,
        surfaceContainerHighest: AppColors.darkRaisedSurface,
        outline: AppColors.slate,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.slate,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.slate,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.white,
        size: 24,
      ),
      dividerColor: AppColors.darkDivider,
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.white,
        inactiveTrackColor: AppColors.slate.withOpacity(0.30),
        thumbColor: AppColors.white,
        overlayColor: AppColors.white.withOpacity(0.12),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6.0,
          pressedElevation: 6.0,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final interFont = GoogleFonts.inter().fontFamily;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: interFont,
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: AppColors.white,
        surface: AppColors.lightBackground,
        onSurface: AppColors.navy,
        surfaceContainerHighest: AppColors.lightRaisedSurface,
        outline: AppColors.slate,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.navy,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.slate,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.slate,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.navy,
        size: 24,
      ),
      dividerColor: AppColors.lightDivider,
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.navy,
        inactiveTrackColor: AppColors.slate.withOpacity(0.30),
        thumbColor: AppColors.navy,
        overlayColor: AppColors.navy.withOpacity(0.12),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6.0,
          pressedElevation: 6.0,
        ),
      ),
    );
  }
}
