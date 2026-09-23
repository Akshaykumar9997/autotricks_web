import 'package:flutter/material.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/quotation_model.dart';
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

  factory AutoTimeline.forRevision({
    required QuotationRevisionModel revision,
  }) {
    final status = revision.status.toUpperCase();
    final revNum = revision.revisionNumber;
    final createdStr = DateFormatter.formatDateTime(revision.createdAt);
    final sentStr = revision.sentAt != null ? DateFormatter.formatDateTime(revision.sentAt!) : null;
    final acceptedDate = revision.signature?.signedAt ?? revision.acceptedAt;
    final acceptedStr = acceptedDate != null ? DateFormatter.formatDateTime(acceptedDate) : null;
    final rejectedStr = revision.rejectedAt != null ? DateFormatter.formatDateTime(revision.rejectedAt!) : null;

    final List<AutoTimelineStep> steps;

    switch (status) {
      case 'DRAFT':
        steps = [
          AutoTimelineStep(
            title: 'DRAFT CREATED',
            subtitle: 'Revision $revNum drafted · $createdStr',
            icon: Icons.edit_note_outlined,
            isCompleted: false,
            isCurrent: true,
          ),
          const AutoTimelineStep(
            title: 'SENT TO CLIENT',
            subtitle: 'Pending delivery to client',
            icon: Icons.send_outlined,
            isCompleted: false,
            isCurrent: false,
          ),
          const AutoTimelineStep(
            title: 'AWAITING SIGNATURE',
            subtitle: 'Pending client decision',
            icon: Icons.check_circle_outline,
            isCompleted: false,
            isCurrent: false,
          ),
        ];
        break;

      case 'SENT':
        steps = [
          AutoTimelineStep(
            title: 'DRAFT CREATED',
            subtitle: 'Revision $revNum drafted · $createdStr',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'SENT TO CLIENT',
            subtitle: 'Delivered to client · ${sentStr ?? createdStr}',
            icon: Icons.send_outlined,
            isCompleted: false,
            isCurrent: true,
          ),
          const AutoTimelineStep(
            title: 'AWAITING SIGNATURE',
            subtitle: 'Awaiting client review & signature',
            icon: Icons.check_circle_outline,
            isCompleted: false,
            isCurrent: false,
          ),
        ];
        break;

      case 'VIEWED':
        steps = [
          AutoTimelineStep(
            title: 'DRAFT CREATED',
            subtitle: 'Revision $revNum drafted · $createdStr',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'SENT TO CLIENT',
            subtitle: 'Delivered to client · ${sentStr ?? createdStr}',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'VIEWED BY CLIENT',
            subtitle: 'Opened by client${revision.viewedAt != null ? ' · ${DateFormatter.formatDateTime(revision.viewedAt!)}' : ''} · Awaiting signature',
            icon: Icons.visibility_outlined,
            isCompleted: false,
            isCurrent: true,
          ),
        ];
        break;

      case 'CHANGE_REQUESTED':
        final crTime = revision.changeRequests.isNotEmpty
            ? DateFormatter.formatDateTime(revision.changeRequests.first.createdAt)
            : null;
        steps = [
          AutoTimelineStep(
            title: 'DRAFT CREATED',
            subtitle: 'Revision $revNum drafted · $createdStr',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'SENT TO CLIENT',
            subtitle: 'Delivered to client · ${sentStr ?? createdStr}',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'CHANGE REQUESTED',
            subtitle: 'Client requested changes${crTime != null ? ' · $crTime' : ''}',
            icon: Icons.feedback_outlined,
            isCompleted: false,
            isCurrent: true,
          ),
        ];
        break;

      case 'ACCEPTED':
        steps = [
          AutoTimelineStep(
            title: 'DRAFT CREATED',
            subtitle: 'Revision $revNum drafted · $createdStr',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'SENT TO CLIENT',
            subtitle: 'Delivered to client · ${sentStr ?? createdStr}',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'ACCEPTED / SIGNED',
            subtitle: 'Client signed & accepted · ${acceptedStr ?? 'Digitally verified'}',
            icon: Icons.verified_rounded,
            isCompleted: false,
            isCurrent: true,
          ),
        ];
        break;

      case 'SUPERSEDED':
        steps = [
          AutoTimelineStep(
            title: 'DRAFT CREATED',
            subtitle: 'Revision $revNum drafted · $createdStr',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'SENT TO CLIENT',
            subtitle: 'Delivered to client · ${sentStr ?? createdStr}',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'SUPERSEDED',
            subtitle: 'Superseded by Revision ${revNum + 1}',
            icon: Icons.history_toggle_off,
            isCompleted: false,
            isCurrent: true,
          ),
        ];
        break;

      case 'REJECTED':
        steps = [
          AutoTimelineStep(
            title: 'DRAFT CREATED',
            subtitle: 'Revision $revNum drafted · $createdStr',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'SENT TO CLIENT',
            subtitle: 'Delivered to client · ${sentStr ?? createdStr}',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: 'REJECTED',
            subtitle: 'Quotation rejected by client${rejectedStr != null ? ' · $rejectedStr' : ''}',
            icon: Icons.cancel_outlined,
            isCompleted: false,
            isCurrent: true,
          ),
        ];
        break;

      default:
        steps = [
          AutoTimelineStep(
            title: 'DRAFT CREATED',
            subtitle: 'Revision $revNum drafted · $createdStr',
            icon: Icons.check,
            isCompleted: true,
            isCurrent: false,
          ),
          AutoTimelineStep(
            title: status,
            subtitle: 'Status: $status',
            icon: Icons.info_outline,
            isCompleted: false,
            isCurrent: true,
          ),
        ];
    }

    return AutoTimeline(steps: steps);
  }

  factory AutoTimeline.forQuotation({
    required String currentStatus,
    String? timestamp,
  }) {
    final upper = currentStatus.toUpperCase();
    final isAccepted = upper == 'ACCEPTED' || upper == 'APPROVED';
    final isTerminal = isAccepted || upper == 'REJECTED' || upper == 'SUPERSEDED';

    final effectiveIndex = isTerminal ? 2 : (upper == 'SENT' || upper == 'VIEWED' ? 1 : 0);

    final terminalLabel = isAccepted
        ? 'ACCEPTED / SIGNED'
        : (upper == 'REJECTED' ? 'REJECTED' : (upper == 'SUPERSEDED' ? 'SUPERSEDED' : 'AWAITING SIGNATURE'));

    final terminalSub = isAccepted
        ? 'Client signed & accepted${timestamp != null ? ' · $timestamp' : ''}'
        : (upper == 'REJECTED'
            ? 'Quotation was rejected'
            : (upper == 'SUPERSEDED'
                ? 'Superseded by new revision'
                : 'Pending client decision'));

    final steps = [
      AutoTimelineStep(
        title: 'DRAFT CREATED',
        subtitle: 'Quotation drafted${effectiveIndex == 0 && timestamp != null ? ' · $timestamp' : ''}',
        icon: effectiveIndex > 0 ? Icons.check : Icons.edit_note_outlined,
        isCompleted: effectiveIndex > 0,
        isCurrent: effectiveIndex == 0,
      ),
      AutoTimelineStep(
        title: 'SENT TO CLIENT',
        subtitle: effectiveIndex >= 1 ? 'Quotation delivered to client' : null,
        icon: effectiveIndex > 1 ? Icons.check : Icons.send_outlined,
        isCompleted: effectiveIndex > 1,
        isCurrent: effectiveIndex == 1,
      ),
      AutoTimelineStep(
        title: terminalLabel,
        subtitle: effectiveIndex == 2 ? terminalSub : null,
        icon: isAccepted ? Icons.verified_rounded : Icons.check_circle_outline,
        isCompleted: false,
        isCurrent: effectiveIndex == 2,
      ),
    ];

    return AutoTimeline(steps: steps);
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
