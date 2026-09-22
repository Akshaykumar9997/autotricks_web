import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography definitions based on Manrope from DESIGN.md and Stitch.
class AppTypography {
  AppTypography._();

  static TextStyle get display => GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.64, // -0.02em
        color: AppColors.textPrimary,
        height: 1.25,
      );

  static TextStyle get headlineLarge => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.28,
        color: AppColors.textPrimary,
        height: 1.28,
      );

  static TextStyle get headlineMedium => GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.22,
        color: AppColors.textPrimary,
        height: 1.36,
      );

  static TextStyle get headlineSmall => GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: AppColors.textPrimary,
        height: 1.44,
      );

  static TextStyle get numericStat => GoogleFonts.manrope(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.52,
        color: AppColors.textPrimary,
        height: 1.23,
      );

  static TextStyle get bodyLarge => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyLargeEmphasis => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: AppColors.textSecondary,
        height: 1.42,
      );

  static TextStyle get bodyMediumEmphasis => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textPrimary,
        height: 1.42,
      );

  static TextStyle get labelMedium => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.14,
        color: AppColors.textPrimary,
        height: 1.28,
      );

  static TextStyle get labelSmall => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.24,
        color: AppColors.textSecondary,
        height: 1.33,
      );

  static TextStyle get caption => GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.33,
        color: AppColors.textMuted,
        height: 1.27,
      );

  static TextStyle get button => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  // Semantic heading aliases
  static TextStyle get h1 => headlineLarge;
  static TextStyle get h2 => headlineMedium;
  static TextStyle get h3 => headlineSmall;
}
