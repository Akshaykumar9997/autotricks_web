import 'package:flutter/material.dart';

/// AutoTricks automotive dark design palette.
///
/// Designed mobile-first with high contrast dark charcoal surfaces,
/// energetic automotive orange primary accents, and red attention cues.
class AppColors {
  AppColors._();

  // Surfaces & Backgrounds
  static const Color background = Color(0xFF0B0D0F);
  static const Color surface = Color(0xFF14171D);
  static const Color surfaceVariant = Color(0xFF1A1E26);
  static const Color surfaceElevated = Color(0xFF222834);
  static const Color card = Color(0xFF13161C);

  // Borders & Dividers
  static const Color border = Color(0xFF242A35);
  static const Color borderSubtle = Color(0xFF1B202A);
  static const Color divider = Color(0xFF1E242F);

  // Primary Accent — Automotive Orange
  static const Color orange = Color(0xFFFF6B00);
  static const Color orangeLight = Color(0xFFFF8533);
  static const Color orangeDark = Color(0xFFE05300);
  static const Color orangeGlow = Color(0x33FF6B00);
  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF7A1A),
      Color(0xFFFF5200),
    ],
  );

  // Secondary Accent — Automotive Attention / Danger Red
  static const Color red = Color(0xFFE63946);
  static const Color redDark = Color(0xFFC1121F);
  static const Color redGlow = Color(0x33E63946);

  // Status Badges & Indicators
  static const Color statusOpen = Color(0xFFFF6B00);
  static const Color statusOpenBg = Color(0x26FF6B00);

  static const Color statusInService = Color(0xFF2196F3);
  static const Color statusInServiceBg = Color(0x262196F3);

  static const Color statusPending = Color(0xFFFFB703);
  static const Color statusPendingBg = Color(0x26FFB703);

  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusCompletedBg = Color(0x2610B981);

  static const Color statusDraft = Color(0xFF94A3B8);
  static const Color statusDraftBg = Color(0x2694A3B8);

  // Typography Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Gradients for Visual Atmosphere
  static const LinearGradient heroOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x990B0D0F),
      Color(0xFF0B0D0F),
    ],
  );

  static const RadialGradient orangeBacklight = RadialGradient(
    center: Alignment(0.4, -0.3),
    radius: 0.9,
    colors: [
      Color(0x33FF6B00),
      Colors.transparent,
    ],
  );
}
