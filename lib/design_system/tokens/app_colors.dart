import 'package:flutter/material.dart';

/// Canonical color tokens defined in DESIGN.md and approved in Stitch.
class AppColors {
  AppColors._();

  // Base Surfaces & Canvas
  static const Color background = Color(0xFF0B0D0F);
  static const Color surface1 = Color(0xFF14171D);
  static const Color surface2 = Color(0xFF1C2129);
  static const Color surfaceContainer = Color(0xFF1E2022);
  static const Color surfaceContainerHigh = Color(0xFF282A2C);
  static const Color border = Color(0xFF242A35);
  static const Color borderSubtle = Color(0xFF242A35);

  // Typography
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA7ADB7);
  static const Color textMuted = Color(0xFF6F7682);

  // Brand
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryStrong = Color(0xFFFF5200);
  static const Color primarySoft = Color(0x1AFF6B00); // 10% opacity
  static const Color primaryContainer = Color(0xFFFF6B00);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFFB703);
  static const Color danger = Color(0xFFE63946);
  static const Color info = Color(0xFF2196F3);

  // Semantic soft container fills (12-15% opacity)
  static const Color successSoft = Color(0x2610B981);
  static const Color warningSoft = Color(0x26FFB703);
  static const Color dangerSoft = Color(0x26E63946);
  static const Color infoSoft = Color(0x262196F3);
}
