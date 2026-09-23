import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/pdf_launcher_helper.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_signature_canvas.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/client_portal_provider.dart';

enum _SigningStep {
  reviewAndSign,
  confirmDetails,
  success,
}

/// C10 / C11 — Accept Quote + Digital Signature + PDF Generation Screen
/// Conforming to approved Day 11 specifications.
class ClientAcceptQuoteScreen extends ConsumerStatefulWidget {
  final String quotationId;

  const ClientAcceptQuoteScreen({
    super.key,
    required this.quotationId,
  });

  @override
  ConsumerState<ClientAcceptQuoteScreen> createState() =>
      _ClientAcceptQuoteScreenState();
}

class _ClientAcceptQuoteScreenState
    extends ConsumerState<ClientAcceptQuoteScreen> {
  _SigningStep _currentStep = _SigningStep.reviewAndSign;
  bool _consentGiven = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  late final AutoSignatureController _signatureController;
  Uint8List? _signatureBytes;
  String? _signedPdfUrl;
  DateTime? _signedAt;

  @override
  void initState() {
    super.initState();
    _signatureController = AutoSignatureController();
    _signatureController.addListener(_onSignatureChanged);
  }

  void _onSignatureChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _signatureController.removeListener(_onSignatureChanged);
    _signatureController.dispose();
    super.dispose();
  }

  String _buildConsentText(QuotationModel quote, QuotationRevisionModel rev) {
    return 'I confirm that I have reviewed Revision ${rev.revisionNumber} of quotation ${quote.quotationNumber} and agree to the quoted scope, pricing, and terms. I understand that digital signature authorization in the next step is required before workshop service execution can begin.';
  }

  Future<void> _handleProceedToConfirmation(
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) async {
    if (!_consentGiven) {
      setState(() {
        _errorMessage = 'Please review and accept the terms of the quotation.';
      });
      return;
    }

    if (_signatureController.isEmpty) {
      setState(() {
        _errorMessage = 'A drawn digital signature is required to accept this quotation.';
      });
      return;
    }

    try {
      final bytes = await _signatureController.toPngBytes(
        width: 600,
        height: 240,
        penColor: const Color(0xFF0F172A),
      );

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _errorMessage = 'Failed to capture signature. Please draw your signature.';
        });
        return;
      }

      setState(() {
        _signatureBytes = bytes;
        _currentStep = _SigningStep.confirmDetails;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error capturing signature: $e';
      });
    }
  }

  /// Day 11 Authoritative digital signing and PDF generation
  Future<void> _handleConfirmAndSign(
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) async {
    if (_signatureBytes == null || _signatureBytes!.isEmpty) {
      setState(() => _errorMessage = 'Signature is required to sign.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final consentText = _buildConsentText(quote, rev);
      final repo = ref.read(clientPortalRepositoryProvider);

      final result = await repo.signQuotationRevision(
        revisionId: rev.id,
        consentText: consentText,
        signatureBytes: _signatureBytes!,
      );

      final signedUrl = result['signed_pdf_url'] as String?;
      final now = DateTime.now();

      ref.invalidate(clientQuotationDetailProvider(widget.quotationId));
      ref.invalidate(clientQuotationsProvider);
      ref.invalidate(clientServiceRequestsProvider);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _signedPdfUrl = signedUrl;
          _signedAt = now;
          _currentStep = _SigningStep.success;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Signing failed: $err';
        });
      }
    }
  }

  Future<void> _openPdf(String? url, QuotationRevisionModel rev) async {
    String? targetUrl = url;

    if (targetUrl == null || targetUrl.isEmpty) {
      try {
        final repo = ref.read(clientPortalRepositoryProvider);
        final storagePath = rev.signedDocument?.storagePath ?? '';
        targetUrl = await repo.getSignedQuotationPdfUrl(
          revisionId: rev.id,
          storagePath: storagePath,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to retrieve PDF URL: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }
    }

    if (targetUrl != null && targetUrl.isNotEmpty && mounted) {
      await PdfLauncherHelper.openPdf(
        context,
        pdfUrl: targetUrl,
        title: 'Signed Quotation PDF',
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed PDF document not available.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync =
        ref.watch(clientQuotationDetailProvider(widget.quotationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (_currentStep == _SigningStep.confirmDetails) {
              setState(() => _currentStep = _SigningStep.reviewAndSign);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _currentStep == _SigningStep.success
              ? 'Quotation Accepted'
              : _currentStep == _SigningStep.confirmDetails
                  ? 'Confirm Signature'
                  : 'Accept Quotation',
          style: AppTypography.headlineSm.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: quoteAsync.when(
        data: (quote) {
          final rev = quote.latestRevision;
          if (rev == null) {
            return const Center(child: Text('No revision available.'));
          }

          switch (_currentStep) {
            case _SigningStep.reviewAndSign:
              return _buildReviewAndSignStep(quote, rev);
            case _SigningStep.confirmDetails:
              return _buildConfirmDetailsStep(quote, rev);
            case _SigningStep.success:
              return _buildSuccessStep(quote, rev);
          }
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.margin),
          child: Column(
            children: [
              AutoSkeleton(height: 120),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 180),
            ],
          ),
        ),
        error: (err, _) => AutoErrorState(
          title: 'Unable to Load Details',
          message: 'Unable to load quotation details.',
          onRetry: () => ref.invalidate(
            clientQuotationDetailProvider(widget.quotationId),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1: REVIEW SCOPE, CONSENT & SIGN
  // ==========================================
  Widget _buildReviewAndSignStep(
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Quotation Summary Card
                _buildQuotationSummaryCard(quote, rev),
                const SizedBox(height: AppSpacing.lg),

                // 2. Consent Agreement Checkbox Card
                _buildConsentAgreementCard(quote, rev),
                const SizedBox(height: AppSpacing.md),

                // 3. Digital Signature Canvas Card
                _buildSignatureCanvasCard(),
                const SizedBox(height: AppSpacing.md),

                // Error Message if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 4. Legal Disclaimer
                _buildLegalDisclaimer(),
              ],
            ),
          ),
        ),

        // Bottom Actions
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface1,
            border: Border(
              top: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(
                        color: AppColors.borderSubtle,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (!_consentGiven || _signatureController.isEmpty || _isSubmitting)
                        ? null
                        : () => _handleProceedToConfirmation(quote, rev),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.3),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Review & Confirm',
                            style: AppTypography.labelMd.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2: DELIBERATE FINAL CONFIRMATION
  // ==========================================
  Widget _buildConfirmDetailsStep(
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deliberate Confirmation',
                              style: AppTypography.bodyMdEmphasis.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Please review your signature authorization before finalizing acceptance.',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Authorization Summary Card
                AutoCard(
                  backgroundColor: AppColors.surface1,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUOTATION DETAILS',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            quote.quotationNumber,
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Revision ${rev.revisionNumber}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quote.vehicleTitle,
                        style: AppTypography.bodyMdEmphasis.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(color: AppColors.borderSubtle, height: 1),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Agreed Value',
                            style: AppTypography.bodyMdEmphasis.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '₹${rev.total.toStringAsFixed(0)}',
                            style: AppTypography.headlineSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Consent Statement Card
                AutoCard(
                  backgroundColor: AppColors.surface1,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CONFIRMED CONSENT STATEMENT',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '“${_buildConsentText(quote, rev)}”',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Drawn Signature Preview Card
                AutoCard(
                  backgroundColor: AppColors.surface1,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'AUTHORIZED SIGNATURE',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                              fontSize: 12,
                            ),
                          ),
                          const AutoBadge(
                            label: 'DRAWN',
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        height: 130,
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: _signatureBytes != null
                            ? Image.memory(
                                _signatureBytes!,
                                fit: BoxFit.contain,
                              )
                            : const Center(
                                child: Text('No signature captured'),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Error Message if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Final legal notice
                Text(
                  'By confirming below, you legally authorize this estimate. An official PDF document with this signature snapshot will be permanently generated and archived.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Bottom Actions: Edit Signature vs Confirm & Sign
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface1,
            border: Border(
              top: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _currentStep = _SigningStep.reviewAndSign;
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(
                        color: AppColors.borderSubtle,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      'Edit Signature',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _handleConfirmAndSign(quote, rev),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Confirm & Sign',
                            style: AppTypography.labelMd.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: SUCCESS STATE
  // ==========================================
  Widget _buildSuccessStep(
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) {
    final signedTimeStr = _signedAt != null
        ? DateFormatter.formatDateTime(_signedAt!)
        : 'Just now';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),

          // Success Icon
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.success, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 48,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Quotation Accepted & Signed!',
            style: AppTypography.headlineSm.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your digital signature has been recorded and an official signed PDF document has been archived.',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Details Card
          AutoCard(
            backgroundColor: AppColors.surface1,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      quote.quotationNumber,
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                    const AutoBadge(
                      label: 'ACCEPTED',
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  quote.vehicleTitle,
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Signed On',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      signedTimeStr,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Agreed Total Value',
                      style: AppTypography.bodyMdEmphasis.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${rev.total.toStringAsFixed(0)}',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Primary Action: View Signed PDF
          ElevatedButton.icon(
            onPressed: () => _openPdf(_signedPdfUrl, rev),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            label: const Text('View Signed Quotation (PDF)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Secondary Action: Return to Quotes
          OutlinedButton(
            onPressed: () => context.go('/client/quotes'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.borderSubtle),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Back to My Quotes'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED COMPONENTS
  // ==========================================
  Widget _buildQuotationSummaryCard(
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) {
    return AutoCard(
      backgroundColor: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  quote.quotationNumber,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'Revision ${rev.revisionNumber}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quote.vehicleTitle,
            style: AppTypography.headlineSm.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(
            color: AppColors.borderSubtle,
            height: 1,
          ),
          const SizedBox(height: AppSpacing.md),

          // Scope of Work count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Scope of Work',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${rev.items.length} ${rev.items.length == 1 ? 'item' : 'items'}',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Subtotal',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '₹${rev.subtotal.toStringAsFixed(0)}',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (rev.discount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Discount',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ),
                Text(
                  '-₹${rev.discount.toStringAsFixed(0)}',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Tax',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '₹${rev.tax.toStringAsFixed(0)}',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(
            color: AppColors.borderSubtle,
            height: 1,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Agreed Value',
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '₹${rev.total.toStringAsFixed(0)}',
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsentAgreementCard(
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) {
    return AutoCard(
      backgroundColor: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLIENT ACCEPTANCE & CONSENT',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.0,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Interactive Checkbox
          InkWell(
            onTap: () {
              setState(() {
                _consentGiven = !_consentGiven;
              });
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _consentGiven,
                  onChanged: (val) {
                    setState(() {
                      _consentGiven = val ?? false;
                    });
                  },
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'I confirm that I have reviewed Revision ${rev.revisionNumber} of quotation ${quote.quotationNumber} and agree to the quoted scope, pricing, and terms.',
                      style: AppTypography.bodyMdEmphasis.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCanvasCard() {
    return AutoCard(
      backgroundColor: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DIGITAL SIGNATURE',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                  fontSize: 12,
                ),
              ),
              if (_signatureController.isNotEmpty)
                Text(
                  '${_signatureController.strokeCount} strokes',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Draw your signature below using finger, stylus, or mouse pointer.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Interactive Signature Pad
          AutoSignatureCanvas(
            controller: _signatureController,
            height: 180,
            onSigned: () => setState(() {}),
            onCleared: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'By accepting this quotation, you agree to the quoted scope, pricing, and terms. Please note: Digital signature authorization in the next step is required before workshop service execution can begin. Accepting this quotation does not automatically schedule, authorize, or start workshop service work.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
