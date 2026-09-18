import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_section_header.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/home_provider.dart';

/// A02 — Admin Home Screen conforming to approved Stitch A02.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final homeAsync = ref.watch(homeDataProvider);
    final userName = authState.profile?.fullName ?? 'Vikram';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Home',
        subtitle: 'Admin Operations',
        showLogo: true,
        hasUnreadNotifications: true,
        onNotificationTap: () {
          AutoToast.showInfo(context, 'Notifications are up to date.');
        },
        onProfileTap: () {
          _showProfileSheet(context, ref);
        },
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface1,
        onRefresh: () async {
          ref.invalidate(homeDataProvider);
        },
        child: homeAsync.when(
          data: (data) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Admin Greeter
                _buildGreeterCard(userName),
                const SizedBox(height: 16),

                // 2. Operational Action Strip
                _buildQuickActionStrip(context),
                const SizedBox(height: 24),

                // 3. Operational Core: Needs Immediate Attention
                _buildNeedsAttentionSection(context, data),
                const SizedBox(height: 24),

                // 4. Active Service Jobs
                _buildActiveJobsSection(context, data),
                const SizedBox(height: 24),

                // 5. Operational Event Log (Recent Activity)
                _buildRecentActivitySection(context, data),
                const SizedBox(height: 24),
              ],
            ),
          ),
          loading: () => _buildLoadingSkeleton(),
          error: (err, _) => AutoErrorState(
            title: 'Unable to load operational status',
            message: err.toString(),
            onRetry: () => ref.invalidate(homeDataProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeterCard(String userName) {
    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadius.radiusMd,
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, $userName',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Admin Portal',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionStrip(BuildContext context) {
    return Row(
      children: [
        // Create Request (Prominent Orange)
        Expanded(
          child: InkWell(
            onTap: () => context.push('/admin/requests/create'),
            borderRadius: AppRadius.radiusMd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.radiusMd,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33FF6B00),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_circle, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create Request',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Create Client
        Expanded(
          child: InkWell(
            onTap: () {
              AutoToast.showInfo(context, 'Client management available in CRM batch.');
            },
            borderRadius: AppRadius.radiusMd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create Client',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Create Vehicle
        Expanded(
          child: InkWell(
            onTap: () {
              AutoToast.showInfo(context, 'Vehicle registration available in CRM batch.');
            },
            borderRadius: AppRadius.radiusMd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_car, color: Color(0xFFFFB59D), size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create Vehicle',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeedsAttentionSection(BuildContext context, dynamic data) {
    final pendingCount = data.pendingRequestsCount as int;
    final awaitingCount = data.awaitingQuotesCount as int;
    final approvedCount = data.approvedQuotesCount as int;
    final totalActionItems = pendingCount + awaitingCount + approvedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSectionHeader(
          title: 'Needs Attention',
          icon: Icons.fmd_bad_rounded,
          iconColor: AppColors.danger,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadius.radiusPill,
            ),
            child: Text(
              '$totalActionItems Action Items',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            // Alert 1: Pending Requests
            AutoCard(
              padding: const EdgeInsets.all(14),
              onTap: () => context.push('/admin/requests?filter=new'),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: const Icon(Icons.inbox_rounded, color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$pendingCount New Requests Pending Review',
                                style: AppTypography.bodyMediumEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Requests awaiting admin review',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Alert 2: Quotations Awaiting Response
            AutoCard(
              padding: const EdgeInsets.all(14),
              onTap: () {
                AutoToast.showInfo(context, 'Quotes batch implementation active in next milestone.');
              },
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded, color: AppColors.info, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$awaitingCount Quotations Awaiting Client Response',
                          style: AppTypography.bodyMediumEmphasis.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Client review and digital signature required',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Alert 3: Approved Quote Ready for Job
            AutoCard(
              padding: const EdgeInsets.all(14),
              onTap: () {
                AutoToast.showInfo(context, 'Service jobs batch implementation active in next milestone.');
              },
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$approvedCount Approved Quote Ready for Job Creation',
                                style: AppTypography.bodyMediumEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.successSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTION READY',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ready to convert to active workshop job',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveJobsSection(BuildContext context, dynamic data) {
    final jobs = data.activeJobs as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSectionHeader(
          title: 'Active Service Jobs',
          icon: Icons.build_circle_outlined,
          iconColor: AppColors.primary,
          trailing: Text(
            '${jobs.length} Active',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: jobs.map((job) {
            return AutoCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              onTap: () {
                AutoToast.showInfo(context, 'Job ${job.jobNumber} details.');
              },
              child: Column(
                children: [
                  // Row 1: Job Number & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: Text(
                            job.jobNumber,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.infoSoft,
                            borderRadius: AppRadius.radiusPill,
                          ),
                          child: Text(
                            job.status,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 2: Vehicle Title
                  Row(
                    children: [
                      const Icon(Icons.directions_car, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          job.vehicleTitle,
                          style: AppTypography.bodyMediumEmphasis.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface2.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Client: ${job.clientName}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Work Items: ${job.workItemsCompleted}/${job.workItemsTotal > 0 ? job.workItemsTotal : 4}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, dynamic data) {
    final activities = data.recentActivities as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSectionHeader(
          title: 'Recent Activity',
          icon: Icons.history_rounded,
          iconColor: AppColors.textSecondary,
          trailing: Text(
            'VIEW FULL LOG',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTrailingTap: () {
            AutoToast.showInfo(context, 'Audit logs viewing is active.');
          },
        ),
        const SizedBox(height: 12),
        AutoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(activities.length, (index) {
              final act = activities[index];
              final isLast = index == activities.length - 1;

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(act.icon, color: act.iconColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    act.title,
                                    style: AppTypography.bodyMediumEmphasis.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  act.timeAgo,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              act.subtitle,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          AutoSkeleton.card(height: 80),
          SizedBox(height: 16),
          AutoSkeleton.card(height: 90),
          SizedBox(height: 24),
          AutoSkeleton.card(height: 180),
          SizedBox(height: 24),
          AutoSkeleton.card(height: 220),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.paddingOf(ctx).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Account',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Color(0xFF0B0D0F)),
              ),
              title: Text(
                ref.read(authProvider).profile?.fullName ?? 'Admin User',
                style: AppTypography.bodyMediumEmphasis.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                ref.read(authProvider).profile?.email ?? 'admin@autotricks.in',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerSoft,
                foregroundColor: AppColors.danger,
                minimumSize: const Size.fromHeight(46),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMd,
                  side: const BorderSide(color: AppColors.danger, width: 1),
                ),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
