import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

class AutoTimelineStep {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;

  const AutoTimelineStep({
    required this.title,
    this.subtitle,
    required this.icon,
    this.isCompleted = false,
    this.isCurrent = false,
  });
}

/// Reusable timeline component conforming to DESIGN.md Section 29 and Stitch A04.
class AutoTimeline extends StatelessWidget {
  final List<AutoTimelineStep> steps;

  const AutoTimeline({
    super.key,
    required this.steps,
  });

  factory AutoTimeline.forServiceRequest({
    required String currentStatus,
    String? timestamp,
  }) {
    final statusList = [
      'NEW',
      'UNDER_REVIEW',
      'QUOTATION_CREATED',
      'QUOTATION_SENT',
      'APPROVED',
      'CONVERTED_TO_JOB',
    ];

    final currentIndex = statusList.indexOf(currentStatus.toUpperCase());
    final effectiveIndex = currentIndex >= 0 ? currentIndex : 0;

    final icons = [
      Icons.fiber_manual_record,
      Icons.rate_review_outlined,
      Icons.request_quote_outlined,
      Icons.send_outlined,
      Icons.check_circle_outline,
      Icons.build_circle_outlined,
    ];

    final labels = [
      'NEW',
      'UNDER REVIEW',
      'QUOTATION CREATED',
      'QUOTATION SENT',
      'APPROVED',
      'CONVERTED TO JOB',
    ];

    final subLabels = [
      'Request received${timestamp != null ? ' · $timestamp' : ''}',
      'Triage & review in progress',
      'Quotation drafted',
      'Quotation delivered to client',
      'Client approved & signed quote',
      'Work order scheduled in workshop',
    ];

    return AutoTimeline(
      steps: List.generate(statusList.length, (i) {
        final isCompleted = i < effectiveIndex;
        final isCurrent = i == effectiveIndex;
        return AutoTimelineStep(
          title: labels[i],
          subtitle: (isCompleted || isCurrent) ? subLabels[i] : null,
          icon: isCompleted ? Icons.check : icons[i],
          isCompleted: isCompleted,
          isCurrent: isCurrent,
        );
      }),
    );
  }

  factory AutoTimeline.forQuotation({
    required String currentStatus,
    String? timestamp,
  }) {
    final statusList = [
      'DRAFT',
      'SENT',
      'APPROVED',
    ];

    final upper = currentStatus.toUpperCase();
    final effectiveIndex = upper == 'REJECTED' || upper == 'SUPERSEDED'
        ? 1
        : (statusList.contains(upper) ? statusList.indexOf(upper) : 0);

    final icons = [
      Icons.edit_note_outlined,
      Icons.send_outlined,
      Icons.check_circle_outline,
    ];

    final labels = [
      'DRAFT CREATED',
      'SENT TO CLIENT',
      upper == 'REJECTED'
          ? 'REJECTED'
          : (upper == 'SUPERSEDED' ? 'SUPERSEDED' : 'APPROVED'),
    ];

    final subLabels = [
      'Quotation revision 1 drafted${timestamp != null ? ' · $timestamp' : ''}',
      'Awaiting client review',
      upper == 'REJECTED'
          ? 'Quotation was rejected'
          : (upper == 'SUPERSEDED'
              ? 'Superseded by new revision'
              : 'Quotation approved by client'),
    ];

    return AutoTimeline(
      steps: List.generate(statusList.length, (i) {
        final isCompleted = i < effectiveIndex;
        final isCurrent = i == effectiveIndex;
        return AutoTimelineStep(
          title: labels[i],
          subtitle: (isCompleted || isCurrent) ? subLabels[i] : null,
          icon: isCompleted ? Icons.check : icons[i],
          isCompleted: isCompleted,
          isCurrent: isCurrent,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line & Node
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  _buildNode(step),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 36,
                      color: step.isCompleted
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: step.isCurrent
                                  ? AppColors.primary
                                  : (step.isCompleted
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted),
                              fontWeight: step.isCurrent || step.isCompleted
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (step.isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CURRENT',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (step.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildNode(AutoTimelineStep step) {
    if (step.isCurrent) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    if (step.isCompleted) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Icon(step.icon, size: 12, color: AppColors.textMuted),
    );
  }
}
