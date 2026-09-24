import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/service_job_model.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/service_jobs_provider.dart';

/// Admin Service Job Detail Screen conforming to Day 12 specifications.
class ServiceJobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const ServiceJobDetailScreen({
    super.key,
    required this.jobId,
  });

  @override
  ConsumerState<ServiceJobDetailScreen> createState() => _ServiceJobDetailScreenState();
}

class _ServiceJobDetailScreenState extends ConsumerState<ServiceJobDetailScreen> {
  bool _isProcessing = false;

  static const List<String> _orderedStatuses = [
    'SCHEDULED',
    'VEHICLE_RECEIVED',
    'INSPECTION',
    'WORK_IN_PROGRESS',
    'QUALITY_CHECK',
    'READY_FOR_DELIVERY',
    'COMPLETED',
  ];

  static const Map<String, String> _statusDisplayNames = {
    'SCHEDULED': 'Scheduled',
    'VEHICLE_RECEIVED': 'Vehicle Received',
    'INSPECTION': 'Inspection',
    'WORK_IN_PROGRESS': 'Work In Progress',
    'QUALITY_CHECK': 'Quality Check',
    'READY_FOR_DELIVERY': 'Ready for Delivery',
    'COMPLETED': 'Completed',
    'CANCELLED': 'Cancelled',
  };

  String? _getNextStatus(String currentStatus) {
    switch (currentStatus.toUpperCase()) {
      case 'SCHEDULED':
        return 'VEHICLE_RECEIVED';
      case 'VEHICLE_RECEIVED':
        return 'INSPECTION';
      case 'INSPECTION':
        return 'WORK_IN_PROGRESS';
      case 'WORK_IN_PROGRESS':
        return 'QUALITY_CHECK';
      case 'QUALITY_CHECK':
        return 'READY_FOR_DELIVERY';
      case 'READY_FOR_DELIVERY':
        return 'COMPLETED';
      default:
        return null;
    }
  }

  String _getNextActionLabel(String currentStatus) {
    switch (currentStatus.toUpperCase()) {
      case 'SCHEDULED':
        return 'Mark Vehicle Received';
      case 'VEHICLE_RECEIVED':
        return 'Start Inspection';
      case 'INSPECTION':
        return 'Start Work';
      case 'WORK_IN_PROGRESS':
        return 'Send for Quality Check';
      case 'QUALITY_CHECK':
        return 'Mark Ready for Delivery';
      case 'READY_FOR_DELIVERY':
        return 'Mark Completed';
      default:
        return 'Update Status';
    }
  }

  IconData _getNextActionIcon(String currentStatus) {
    switch (currentStatus.toUpperCase()) {
      case 'SCHEDULED':
        return Icons.car_rental_rounded;
      case 'VEHICLE_RECEIVED':
        return Icons.fact_check_outlined;
      case 'INSPECTION':
        return Icons.build_outlined;
      case 'WORK_IN_PROGRESS':
        return Icons.verified_outlined;
      case 'QUALITY_CHECK':
        return Icons.local_shipping_outlined;
      case 'READY_FOR_DELIVERY':
        return Icons.task_alt_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return AppColors.info;
      case 'VEHICLE_RECEIVED':
        return AppColors.primary;
      case 'INSPECTION':
        return const Color(0xFF6366F1);
      case 'WORK_IN_PROGRESS':
        return const Color(0xFF8B5CF6);
      case 'QUALITY_CHECK':
        return AppColors.warning;
      case 'READY_FOR_DELIVERY':
        return const Color(0xFF10B981);
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _handleTransition(ServiceJobModel job, String nextStatus) async {
    // If completing job and pending additional work exists, block transition
    if (nextStatus == 'COMPLETED' && job.hasPendingAdditionalWork) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          title: Row(
            children: [
              const Icon(Icons.block_rounded, color: AppColors.warning, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Pending Additional Work',
                  style: AppTypography.headlineSm.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: Text(
            'Cannot complete the service job while additional work is awaiting client approval. All additional work items must be resolved (approved or rejected) before the job can be completed.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
              ),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final noteController = TextEditingController();
    bool completeOpenItems = true;

    // Check if moving to COMPLETED and has open work items
    final hasOpenWorkItems = nextStatus == 'COMPLETED' &&
        job.workItems.any((w) => (w.isQuotation || w.isApproved) && w.status != 'COMPLETED' && w.status != 'CANCELLED');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface1,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              title: Row(
                children: [
                  Icon(_getNextActionIcon(job.status), color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Confirm Status Update',
                      style: AppTypography.headlineSm.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _buildMiniBadge(job.status),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textMuted),
                            _buildMiniBadge(nextStatus),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (hasOpenWorkItems) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: AppRadius.radiusSm,
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Open Work Items Detected',
                                    style: AppTypography.bodyMdEmphasis.copyWith(color: AppColors.warning),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'All work items will be marked COMPLETED upon completing the service job.',
                                    style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      'Optional Note / Remarks:',
                      style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Vehicle arrived, customer handed over key...',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.radiusMd,
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                  ),
                  child: const Text('Update Status'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        final repo = ref.read(serviceJobsRepositoryProvider);

        // If completing and there were open items, complete them first
        if (hasOpenWorkItems && completeOpenItems) {
          await repo.completeAllWorkItems(job.id);
        }

        await repo.updateJobStatus(
          jobId: job.id,
          status: nextStatus,
          note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
        );

        ref.invalidate(serviceJobDetailProvider(widget.jobId));
        ref.invalidate(serviceJobsListProvider);

        if (mounted) {
          AutoToast.showSuccess(
            context,
            'Job status moved to ${_statusDisplayNames[nextStatus] ?? nextStatus}',
          );
        }
      } catch (e) {
        if (mounted) {
          AutoToast.showError(context, 'Failed to update status: $e');
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleCancelJob(ServiceJobModel job) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          title: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Cancel Service Job',
                style: AppTypography.headlineSm.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel Job #${job.jobNumber}? This will mark the job as cancelled and cannot be undone.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Cancellation Reason (required):',
                style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                maxLines: 2,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter reason for cancellation...',
                  hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Go Back', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (noteController.text.trim().isEmpty) {
                  AutoToast.showError(ctx, 'Please enter a cancellation reason.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
              ),
              child: const Text('Confirm Cancellation'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        final repo = ref.read(serviceJobsRepositoryProvider);
        await repo.updateJobStatus(
          jobId: job.id,
          status: 'CANCELLED',
          note: noteController.text.trim(),
        );

        ref.invalidate(serviceJobDetailProvider(widget.jobId));
        ref.invalidate(serviceJobsListProvider);

        if (mounted) {
          AutoToast.showSuccess(context, 'Service Job cancelled.');
        }
      } catch (e) {
        if (mounted) {
          AutoToast.showError(context, 'Failed to cancel job: $e');
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleToggleWorkItem(ServiceWorkItemModel item) async {
    if (item.isAdditional && !item.isApproved) {
      AutoToast.showError(context, 'Additional work cannot be executed until approved by client.');
      return;
    }
    final nextStatus = item.status == 'COMPLETED' ? 'PENDING' : 'COMPLETED';
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(serviceJobsRepositoryProvider);
      await repo.updateWorkItemStatus(itemId: item.id, status: nextStatus);
      ref.invalidate(serviceJobDetailProvider(widget.jobId));
      if (mounted) {
        AutoToast.showSuccess(context, 'Work item marked as $nextStatus.');
      }
    } catch (e) {
      if (mounted) {
        AutoToast.showError(context, 'Failed to update work item: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showAddAdditionalWorkDialog(ServiceJobModel job) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final approxValueController = TextEditingController();
    final finalValueController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface1,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              title: Row(
                children: [
                  const Icon(Icons.add_task_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Add Additional Work',
                      style: AppTypography.headlineSm.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: AppRadius.radiusSm,
                            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Additional work requires explicit client authorization before technicians can begin work.',
                                  style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Work / Part Name *', style: AppTypography.labelSm.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: nameController,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'e.g. Rear Brake Disc Replacement',
                            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.surface2,
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.radiusMd,
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Description / Justification *', style: AppTypography.labelSm.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 2,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Discovered during inspection; describe reason & scope...',
                            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.surface2,
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.radiusMd,
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter description / reason' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Quantity *', style: AppTypography.labelSm.copyWith(color: AppColors.textMuted)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: quantityController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                                    decoration: InputDecoration(
                                      hintText: '1',
                                      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                                      filled: true,
                                      fillColor: AppColors.surface2,
                                      border: OutlineInputBorder(
                                        borderRadius: AppRadius.radiusMd,
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      final val = num.tryParse(v.trim());
                                      if (val == null || val <= 0) return '> 0';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Approx Value (₹)', style: AppTypography.labelSm.copyWith(color: AppColors.textMuted)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: approxValueController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                                    decoration: InputDecoration(
                                      hintText: 'Optional',
                                      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                                      filled: true,
                                      fillColor: AppColors.surface2,
                                      border: OutlineInputBorder(
                                        borderRadius: AppRadius.radiusMd,
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v != null && v.trim().isNotEmpty) {
                                        final val = num.tryParse(v.trim());
                                        if (val == null || val < 0) return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Quoted / Final Value (₹) *', style: AppTypography.labelSm.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: finalValueController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Final price presented to client for approval',
                            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.surface2,
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.radiusMd,
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter quoted amount';
                            final val = num.tryParse(v.trim());
                            if (val == null || val < 0) return 'Must be >= 0';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.of(ctx).pop(true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                  ),
                  child: const Text('Add Work Item'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        final repo = ref.read(serviceJobsRepositoryProvider);
        final qty = num.parse(quantityController.text.trim());
        final fVal = num.parse(finalValueController.text.trim());
        final aVal = approxValueController.text.trim().isNotEmpty
            ? num.tryParse(approxValueController.text.trim())
            : null;

        await repo.addAdditionalWork(
          serviceJobId: job.id,
          name: nameController.text.trim(),
          description: descriptionController.text.trim(),
          quantity: qty,
          finalValue: fVal,
          approximateValue: aVal,
        );

        ref.invalidate(serviceJobDetailProvider(widget.jobId));
        ref.invalidate(serviceJobsListProvider);

        if (mounted) {
          AutoToast.showSuccess(
            context,
            'Additional work created. Awaiting client authorization.',
          );
        }
      } catch (e) {
        if (mounted) {
          AutoToast.showError(context, 'Failed to add additional work: $e');
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildMiniBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _statusDisplayNames[status] ?? status,
        style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(serviceJobDetailProvider(widget.jobId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Service Job',
        showBack: true,
        showLogo: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(serviceJobDetailProvider(widget.jobId)),
          ),
        ],
      ),
      body: jobAsync.when(
        data: (job) => _buildBody(job),
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.margin),
          child: Column(
            children: [
              AutoSkeleton(height: 140),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 220),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 180),
            ],
          ),
        ),
        error: (err, _) => AutoErrorState(
          title: 'Unable to Load Job',
          message: err.toString(),
          onRetry: () => ref.invalidate(serviceJobDetailProvider(widget.jobId)),
        ),
      ),
    );
  }

  Widget _buildBody(ServiceJobModel job) {
    final nextStatus = _getNextStatus(job.status);
    final isClosed = job.isCompleted || job.isCancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.margin,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Card
          _buildJobHeaderCard(job),
          const SizedBox(height: AppSpacing.md),

          // 2. Visual Service Progress Timeline
          _buildProgressStepper(job),
          const SizedBox(height: AppSpacing.md),

          // 3. Status Action Button
          if (!isClosed && nextStatus != null) ...[
            _buildStatusActionCard(job, nextStatus),
            const SizedBox(height: AppSpacing.md),
          ] else if (job.isCompleted) ...[
            _buildCompletedBanner(),
            const SizedBox(height: AppSpacing.md),
          ] else if (job.isCancelled) ...[
            _buildCancelledBanner(),
            const SizedBox(height: AppSpacing.md),
          ],

          // 4. Customer & Vehicle Context (Required by Section 5)
          _buildCustomerVehicleCard(job),
          const SizedBox(height: AppSpacing.md),

          // 5. Service Request & Quotation Context
          _buildServiceRequestQuotationCard(job),
          const SizedBox(height: AppSpacing.md),

          // 6. Work Items Card
          _buildWorkItemsCard(job),
          const SizedBox(height: AppSpacing.md),

          // 7. Status History Card
          _buildStatusHistoryCard(job),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildJobHeaderCard(ServiceJobModel job) {
    return AutoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JOB #${job.jobNumber}',
                      style: AppTypography.headlineMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.vehicleTitle,
                      style: AppTypography.bodyMediumEmphasis.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      job.vehiclePlate,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildMiniBadge(job.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer: ${job.customerName}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (job.startedAt != null)
                Text(
                  'Started: ${DateFormatter.timeAgo(job.startedAt!)}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper(ServiceJobModel job) {
    final currentStatus = job.status.toUpperCase();
    final currentIndex = _orderedStatuses.indexOf(currentStatus);

    return AutoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'SERVICE PROGRESS',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (currentStatus == 'CANCELLED')
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'This Service Job has been cancelled.',
                    style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.danger),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orderedStatuses.length,
              itemBuilder: (context, index) {
                final status = _orderedStatuses[index];
                final isPast = currentIndex > index;
                final isCurrent = currentIndex == index;
                final isLast = index == _orderedStatuses.length - 1;

                Color iconColor = AppColors.textMuted;
                Widget indicator;

                if (isPast) {
                  iconColor = AppColors.success;
                  indicator = const CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.success,
                    child: Icon(Icons.check, size: 14, color: Colors.white),
                  );
                } else if (isCurrent) {
                  iconColor = _getStatusColor(status);
                  indicator = CircleAvatar(
                    radius: 12,
                    backgroundColor: iconColor,
                    child: const CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.white,
                    ),
                  );
                } else {
                  indicator = Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                      color: AppColors.surface2,
                    ),
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          indicator,
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isPast ? AppColors.success : AppColors.border,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusDisplayNames[status] ?? status,
                                style: AppTypography.bodyMediumEmphasis.copyWith(
                                  color: isCurrent
                                      ? AppColors.textPrimary
                                      : isPast
                                          ? AppColors.textSecondary
                                          : AppColors.textMuted,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Current Stage',
                                  style: AppTypography.caption.copyWith(
                                    color: iconColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusActionCard(ServiceJobModel job, String nextStatus) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Next Step:',
                style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: 6),
              Text(
                _statusDisplayNames[nextStatus] ?? nextStatus,
                style: AppTypography.bodyMdEmphasis.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AutoButton(
            label: _getNextActionLabel(job.status),
            icon: Icon(_getNextActionIcon(job.status), size: 18),
            isLoading: _isProcessing,
            onPressed: () => _handleTransition(job, nextStatus),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: _isProcessing ? null : () => _handleCancelJob(job),
            icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
            label: Text(
              'Cancel Service Job',
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
          const SizedBox(width: 10),
          Text(
            'SERVICE COMPLETED · JOB CLOSED',
            style: AppTypography.bodyMediumEmphasis.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 22),
          const SizedBox(width: 10),
          Text(
            'SERVICE JOB CANCELLED',
            style: AppTypography.bodyMediumEmphasis.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerVehicleCard(ServiceJobModel job) {
    return AutoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CUSTOMER & VEHICLE DETAILS',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.0,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow('Customer Name', job.customerName),
          if (job.client?.phone != null) _buildInfoRow('Phone', job.client!.phone),
          if (job.client?.email != null) _buildInfoRow('Email', job.client!.email!),
          const Divider(color: AppColors.borderSubtle, height: AppSpacing.md),
          _buildInfoRow('Make & Model', '${job.vehicle?.make ?? ""} ${job.vehicle?.model ?? ""}'),
          if (job.vehicle?.manufacturingYear != null)
            _buildInfoRow('Year', job.vehicle!.manufacturingYear.toString()),
          _buildInfoRow('Registration', job.vehiclePlate),
          if (job.vehicle?.chassisNumber != null)
            _buildInfoRow('VIN / Chassis', job.vehicle!.chassisNumber!),
        ],
      ),
    );
  }

  Widget _buildServiceRequestQuotationCard(ServiceJobModel job) {
    return AutoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REQUEST & QUOTATION REFERENCE',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.0,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (job.serviceRequest != null) ...[
            _buildInfoRow('Service Request', '#${job.serviceRequest!.requestNumber}'),
            _buildInfoRow('Requirement', job.serviceRequest!.serviceDescription),
            _buildInfoRow(
              'Request Date',
              DateFormatter.formatDate(job.serviceRequest!.createdAt),
            ),
            const Divider(color: AppColors.borderSubtle, height: AppSpacing.md),
          ],
          _buildInfoRow('Accepted Revision ID', job.quotationRevisionId),
          if (job.scheduledAt != null)
            _buildInfoRow('Scheduled At', DateFormatter.formatDateTime(job.scheduledAt!)),
          if (job.completedAt != null)
            _buildInfoRow('Completed At', DateFormatter.formatDateTime(job.completedAt!)),
        ],
      ),
    );
  }

  Widget _buildQuotationWorkItem(ServiceJobModel job, ServiceWorkItemModel item, bool isClosed) {
    final isDone = item.status == 'COMPLETED';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        icon: Icon(
          isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
          color: isDone ? AppColors.success : AppColors.textMuted,
        ),
        onPressed: isClosed || _isProcessing ? null : () => _handleToggleWorkItem(item),
      ),
      title: Text(
        item.name,
        style: AppTypography.bodyMediumEmphasis.copyWith(
          color: isDone ? AppColors.textMuted : AppColors.textPrimary,
          decoration: isDone ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        'Qty: ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)}${item.description != null && item.description!.isNotEmpty ? " · ${item.description}" : ""}${item.finalValue != null ? " · ₹${item.finalValue!.toStringAsFixed(2)}" : ""}',
        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (isDone ? AppColors.success : AppColors.info).withValues(alpha: 0.15),
          borderRadius: AppRadius.radiusXs,
        ),
        child: Text(
          item.status,
          style: AppTypography.caption.copyWith(
            color: isDone ? AppColors.success : AppColors.info,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalWorkItem(ServiceJobModel job, ServiceWorkItemModel item, bool isClosed) {
    final isDone = item.status == 'COMPLETED';
    final isPending = item.isApprovalPending;
    final isApproved = item.isApproved;
    final isRejected = item.isRejected;

    Widget leadingWidget;
    if (isPending) {
      leadingWidget = const Tooltip(
        message: 'Awaiting client approval',
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.lock_clock_outlined, color: AppColors.warning, size: 22),
        ),
      );
    } else if (isRejected) {
      leadingWidget = const Tooltip(
        message: 'Rejected by client',
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.block_rounded, color: AppColors.danger, size: 22),
        ),
      );
    } else {
      leadingWidget = IconButton(
        icon: Icon(
          isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
          color: isDone ? AppColors.success : AppColors.textMuted,
        ),
        onPressed: isClosed || _isProcessing ? null : () => _handleToggleWorkItem(item),
      );
    }

    Color approvalBadgeColor;
    String approvalBadgeText;
    if (isPending) {
      approvalBadgeColor = AppColors.warning;
      approvalBadgeText = 'PENDING CLIENT APPROVAL';
    } else if (isApproved) {
      approvalBadgeColor = AppColors.success;
      approvalBadgeText = 'APPROVED';
    } else {
      approvalBadgeColor = AppColors.danger;
      approvalBadgeText = 'REJECTED';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: isPending
              ? AppColors.warning.withValues(alpha: 0.3)
              : isRejected
                  ? AppColors.danger.withValues(alpha: 0.3)
                  : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leadingWidget,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTypography.bodyMediumEmphasis.copyWith(
                              color: isRejected
                                  ? AppColors.textMuted
                                  : isDone
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: approvalBadgeColor.withValues(alpha: 0.15),
                            borderRadius: AppRadius.radiusXs,
                            border: Border.all(color: approvalBadgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            approvalBadgeText,
                            style: AppTypography.caption.copyWith(
                              color: approvalBadgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description!,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Qty: ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)}',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        ),
                        if (item.approximateValue != null)
                          Text(
                            'Approx: ₹${item.approximateValue!.toStringAsFixed(2)}',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        Text(
                          'Quoted: ₹${item.finalValue?.toStringAsFixed(2) ?? '0.00'}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (item.approvalNote != null && item.approvalNote!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Client Note: "${item.approvalNote}"',
                        style: AppTypography.caption.copyWith(
                          color: isApproved ? AppColors.success : AppColors.danger,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (item.decisionAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Decided: ${DateFormatter.formatDateTime(item.decisionAt!)}',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkItemsCard(ServiceJobModel job) {
    final isClosed = job.isCompleted || job.isCancelled;
    final canAddAdditional = job.status == 'INSPECTION' || job.status == 'WORK_IN_PROGRESS';
    final quotationItems = job.quotationWorkItems;
    final additionalItems = job.additionalWorkItems;
    final hasEligibleOpenItems = job.workItems.any((w) => (w.isQuotation || w.isApproved) && w.status != 'COMPLETED');

    return AutoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  'WORK ITEMS (${job.workItems.length})',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (canAddAdditional)
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _showAddAdditionalWorkDialog(job),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Additional Work'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (!isClosed && hasEligibleOpenItems)
                      TextButton(
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                setState(() => _isProcessing = true);
                                try {
                                  final repo = ref.read(serviceJobsRepositoryProvider);
                                  await repo.completeAllWorkItems(job.id);
                                  ref.invalidate(serviceJobDetailProvider(widget.jobId));
                                  if (mounted) AutoToast.showSuccess(context, 'All authorized work items marked complete.');
                                } catch (e) {
                                  if (mounted) AutoToast.showError(context, e.toString());
                                } finally {
                                  if (mounted) setState(() => _isProcessing = false);
                                }
                              },
                        child: Text(
                          'Complete All',
                          style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (job.workItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'No work items recorded.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
                ),
              ),
            )
          else ...[
            if (quotationItems.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'ORIGINAL QUOTATION WORK (${quotationItems.length})',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quotationItems.length,
                separatorBuilder: (ctx, idx) => const Divider(color: AppColors.borderSubtle, height: 1),
                itemBuilder: (context, index) => _buildQuotationWorkItem(job, quotationItems[index], isClosed),
              ),
            ],
            if (additionalItems.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.add_alert_outlined, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'ADDITIONAL WORK (${additionalItems.length})',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: additionalItems.length,
                itemBuilder: (context, index) => _buildAdditionalWorkItem(job, additionalItems[index], isClosed),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatusHistoryCard(ServiceJobModel job) {
    return AutoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'STATUS HISTORY',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (job.statusHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: Text(
                  'No history entries recorded.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: job.statusHistory.length,
              separatorBuilder: (ctx, idx) => const Divider(color: AppColors.borderSubtle, height: 16),
              itemBuilder: (context, index) {
                final entry = job.statusHistory[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 5,
                      backgroundColor: _getStatusColor(entry.toStatus),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${entry.fromStatus != null ? "${_statusDisplayNames[entry.fromStatus] ?? entry.fromStatus} → " : ""}${_statusDisplayNames[entry.toStatus] ?? entry.toStatus}',
                                  style: AppTypography.bodyMdEmphasis.copyWith(color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                DateFormatter.formatDateTime(entry.createdAt),
                                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          if (entry.changedByName != null || entry.changedByProfileId != null)
                            Text(
                              'By: ${entry.changedByName ?? "Admin"}',
                              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          if (entry.note != null && entry.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              entry.note!,
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
