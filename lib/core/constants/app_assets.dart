/// Approved AutoTricks branding assets and design tokens.
class AppAssets {
  AppAssets._();

  // Final Approved Branding Assets (Official)
  /// Full AutoTricks brand logo: Contains the white A symbol + "AutoTricks" wordmark.
  /// Used for quotations, customer-facing PDF documents, signed quotation PDFs, and formal business documents.
  static const String logoFull = 'assets/brand/AT LOGO(2).png';

  /// Symbol-only version: Contains ONLY the white A symbol (NO AutoTricks text).
  /// Used for in-app headers, navigation bars, app icon, compact UI branding, and startup loader.
  static const String logoSymbol = 'assets/brand/AT.png';

  // Canonical compatibility aliases for existing screens
  static const String logoMaster = logoSymbol;
  static const String logoOriginal = logoFull;

  // Approved Branded Visuals
  static const String loadingVisual = 'assets/brand/autotricks_loading_visual_approved.png';
  static const String genericEmptyState = 'assets/illustrations/autotricks_generic_empty_state_approved.png';
  static const String serviceProgressVisual = 'assets/illustrations/autotricks_service_progress_visual_approved.png';
  static const String heroGarage = 'assets/backgrounds/autotricks_hero_garage_approved.png';
}
