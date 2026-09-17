import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_card.dart';

/// Screen shell for Notifications.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Mark All Read',
              style: TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            _buildNotificationItem(
              title: 'New Service Request #SR-1005',
              description: 'Customer logged a brake inspection request from website',
              time: '10m ago',
              isUnread: true,
              icon: Icons.assignment_turned_in_outlined,
              iconColor: AppColors.orange,
            ),
            _buildNotificationItem(
              title: 'Quotation #QT-1002 Accepted',
              description: 'Priya Menon approved the quotation revision v1 with digital signature',
              time: '1h ago',
              isUnread: true,
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.statusCompleted,
            ),
            _buildNotificationItem(
              title: 'Service Job #JOB-1003 Completed',
              description: 'AC Service for Maruti Swift ready for final quality inspection',
              time: '3h ago',
              isUnread: false,
              icon: Icons.build_circle_outlined,
              iconColor: AppColors.statusInService,
            ),
            _buildNotificationItem(
              title: 'Vehicle Received #JOB-1001',
              description: 'Toyota Innova checked into Bay 01 for scheduled service',
              time: '5h ago',
              isUnread: false,
              icon: Icons.directions_car_outlined,
              iconColor: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String description,
    required String time,
    required bool isUnread,
    required IconData icon,
    required Color iconColor,
  }) {
    return AutoCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      backgroundColor: isUnread ? AppColors.surfaceVariant : AppColors.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
                        title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight:
                              isUnread ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
