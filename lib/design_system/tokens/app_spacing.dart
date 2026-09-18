import 'package:flutter/material.dart';

/// 8-point spacing grid from DESIGN.md.
class AppSpacing {
  AppSpacing._();

  static const double micro = 4.0;
  static const double small = 8.0;
  static const double compact = 12.0;
  static const double standard = 16.0;
  static const double section = 24.0;
  static const double large = 32.0;
  static const double major = 40.0;
  static const double hero = 48.0;
  static const double exceptional = 64.0;

  // Shortcuts
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Standard EdgeInsets
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(12.0);
}
