import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/design_system/tokens/app_colors.dart';
import 'package:autotricks/design_system/tokens/app_radius.dart';
import 'package:autotricks/design_system/tokens/app_spacing.dart';
import 'package:autotricks/design_system/tokens/app_typography.dart';
import 'package:autotricks/design_system/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Design System Tokens', () {
    test('AppColors matches AutoTricks approved color palette', () {
      expect(AppColors.background, const Color(0xFF0B0D0F));
      expect(AppColors.surface1, const Color(0xFF14171D));
      expect(AppColors.surface2, const Color(0xFF1C2129));
      expect(AppColors.border, const Color(0xFF242A35));
      expect(AppColors.primary, const Color(0xFFFF6B00));
      expect(AppColors.primaryStrong, const Color(0xFFFF5200));
      expect(AppColors.textPrimary, const Color(0xFFF5F5F5));
      expect(AppColors.textSecondary, const Color(0xFFA7ADB7));
      expect(AppColors.textMuted, const Color(0xFF6F7682));
      expect(AppColors.success, const Color(0xFF10B981));
      expect(AppColors.warning, const Color(0xFFFFB703));
      expect(AppColors.danger, const Color(0xFFE63946));
      expect(AppColors.info, const Color(0xFF2196F3));
    });

    test('AppSpacing implements 8-point spacing tokens', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 24.0);
      expect(AppSpacing.xxl, 32.0);
      expect(AppSpacing.hero, 48.0);
      expect(AppSpacing.exceptional, 64.0);
    });

    test('AppRadius implements standard border radius tokens', () {
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 20.0);
      expect(AppRadius.pill, 999.0);
    });

    test('AppTypography provides standard Manrope hierarchy', () {
      expect(AppTypography.headlineMedium.fontWeight, FontWeight.w700);
      expect(AppTypography.bodyMedium.fontWeight, FontWeight.w400);
      expect(AppTypography.button.fontWeight, FontWeight.w700);
    });

    test('AppTheme builds dark-first ThemeData without errors', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.surface, AppColors.surface1);
    });
  });
}
