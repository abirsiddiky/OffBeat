import 'package:flutter/material.dart';

/// Design tokens and palette for OffBeat
class AppColors {
  AppColors._();

  // Core palette
  static const Color navy = Color(0xFF171C26);
  static const Color slate = Color(0xFF6C7689);
  static const Color lightSlate = Color(0xFFA4AAB7);
  static const Color white = Color(0xFFFFFFFF);

  // Dark Theme surfaces
  static const Color darkBackground = Color(0xFF171C26);
  static const Color darkRaisedSurface = Color(0xFF222836);
  static const Color darkCard = Color(0xFF1E2430);
  static const Color darkDivider = Color(0xFF262C3A);
  static const Color darkActiveBadge = Color(0xFF2B3345);

  // Light Theme surfaces
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightRaisedSurface = Color(0xFFF2F4F7);
  static const Color lightCard = Color(0xFFF8F9FA);
  static const Color lightDivider = Color(0xFFE5E7EB);
  static const Color lightActiveBadge = Color(0xFF171C26);

  // Accents
  static const Color red = Color(0xFFE53935);
}

class AppRadii {
  AppRadii._();

  static const double artwork = 38.0;
  static const double artworkSmall = 24.0;
  static const double artworkThumb = 14.0;
  static const double card = 22.0;
  static const double button = 20.0;
  static const double dock = 32.0;
  static const double badge = 12.0;
  static const double pill = 999.0;
}

class AppSpacing {
  AppSpacing._();

  static const double screenInset = 20.0;
  static const double dockHeight = 76.0;
  static const double miniPlayerHeight = 72.0;
  static const double totalDockHeight = 148.0;
}
