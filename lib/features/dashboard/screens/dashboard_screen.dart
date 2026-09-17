import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_feedback_states.dart';
import 'package:autotricks/core/widgets/auto_skeleton.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/dashboard/providers/dashboard_provider.dart';
import 'package:autotricks/features/dashboard/widgets/mechanic_hero_visual.dart';
import 'package:autotricks/features/dashboard/widgets/workshop_progress_card.dart';

/// The central Admin Dashboard for AutoTricks.
///
/// Mobile-first, answers "What is happening in the workshop right now?"
/// with cinematic automotive visuals, zero spreadsheet clutter, and high contrast.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final displayName = authState.profile?.fullName ?? 'Admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.orange,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await ref.read(dashboardMetricsProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Contextual Greeting Bar
                _buildGreetingBar(context, displayName),
                const SizedBox(height: 20),

                // 2. Cinematic Automotive Visual (Mechanic repairing car)
                const MechanicHeroVisual(),
                const SizedBox(height: 24),

                // 3. Workshop Progress Card & 3 Essential Metrics
                metricsAsync.when(
                  data: (metrics) => WorkshopProgressCard(metrics: metrics),
                  loading: () => _buildLoadingSkeleton(),
                  error: (error, _) => AutoErrorState(
                    title: 'Unable to load workshop metrics',
                    message: error.toString(),
                    onRetry: () =>
                        ref.read(dashboardMetricsProvider.notifier).refresh(),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingBar(BuildContext context, String displayName) {
    final hour = DateTime.now().hour;
    final String timeGreeting;
    if (hour < 12) {
      timeGreeting = 'Good morning,';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon,';
    } else {
      timeGreeting = 'Good evening,';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Name & Welcome
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeGreeting,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('👋', style: TextStyle(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Great to see you back.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Action Icons: Notifications & Profile
        Row(
          children: [
            // Notifications Bell with unread indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => context.push('/notifications'),
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Profile Avatar
            GestureDetector(
              onTap: () => context.push('/settings'),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.orange.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orange.withAlpha(120)),
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoSkeleton(width: 180, height: 16),
          SizedBox(height: 20),
          Row(
            children: [
              AutoSkeleton(width: 76, height: 76, borderRadius: 38),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSkeleton(width: 100, height: 16),
                    SizedBox(height: 8),
                    AutoSkeleton(width: 140, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              AutoSkeleton(width: 60, height: 36),
              AutoSkeleton(width: 60, height: 36),
              AutoSkeleton(width: 60, height: 36),
            ],
          ),
        ],
      ),
    );
  }
}
