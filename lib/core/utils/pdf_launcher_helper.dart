import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';

/// Helper to reliably launch, view, or download PDF documents
/// across web, desktop, and mobile environments with popup-blocker fallbacks.
class PdfLauncherHelper {
  PdfLauncherHelper._();

  /// Opens the given authoritative [pdfUrl].
  ///
  /// On Web, opens with `LaunchMode.platformDefault` and `webOnlyWindowName: '_blank'`.
  /// On Desktop/Mobile, opens with `LaunchMode.externalApplication`.
  /// If the platform or browser pop-up blocker prevents opening, renders a fallback dialog.
  static Future<void> openPdf(
    BuildContext context, {
    required String pdfUrl,
    String title = 'Signed Quotation (PDF)',
  }) async {
    final cleanUrl = pdfUrl.trim();
    if (cleanUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document URL is not available.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(cleanUrl);

    bool launched = false;
    try {
      if (kIsWeb) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
      } else {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      launched = false;
    }

    if (!launched && context.mounted) {
      // Pop-up was blocked by browser or system launcher was unavailable.
      // Show user-friendly direct action dialog where user-click is guaranteed to work.
      await showDialog<void>(
        context: context,
        builder: (ctx) => _PdfViewerFallbackDialog(
          pdfUrl: cleanUrl,
          title: title,
        ),
      );
    }
  }
}

class _PdfViewerFallbackDialog extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const _PdfViewerFallbackDialog({
    required this.pdfUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.picture_as_pdf_rounded,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your browser or device prevented the PDF from opening in a new tab automatically. Please use the actions below to open or copy your document link:',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    pdfUrl,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: pdfUrl));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Document link copied to clipboard.'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy Link'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            // Direct click handler inside dialog is a direct user gesture
            await launchUrl(
              Uri.parse(pdfUrl),
              mode: LaunchMode.platformDefault,
              webOnlyWindowName: '_blank',
            );
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Open in New Tab'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
