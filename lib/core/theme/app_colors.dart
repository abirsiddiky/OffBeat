import 'package:flutter/material.dart';

/// App color tokens for OffBeat.
///
/// Exact palette:
/// - Navy: #171C26
/// - Slate: #6C7689
/// - Light Slate: #A4AAB7
/// - White: #FFFFFF
class AppColors {
  const AppColors._();

  // Core required color tokens
  static const Color navy = Color(0xFF171C26);
  static const Color slate = Color(0xFF6C7689);
  static const Color lightSlate = Color(0xFFA4AAB7);
  static const Color white = Color(0xFFFFFFFF);

  // Surface and container variations derived from core palette
  static const Color navySurface = Color(0xFF131720);
  static const Color navyElevated = Color(0xFF1F2533);
  static const Color navyContainer = Color(0xFF262D3D);

  static const Color lightSurface = Color(0xFFF7F8FA);
  static const Color lightCard = Color(0xFFEFF2F6);
  static const Color lightContainer = Color(0xFFE4E7ED);

  // Soft glow and shadow tokens
  static const Color darkGlow = Color(0x33FFFFFF);
  static const Color navyShadow = Color(0x33171C26);
  static const Color lightShadow = Color(0x14171C26);
}
