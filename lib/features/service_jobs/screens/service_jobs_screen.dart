import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_badge.dart';
import 'package:autotricks/core/widgets/auto_card.dart';

/// Screen shell for Service Jobs (Day 8 scope foundation).
class ServiceJobsScreen extends StatefulWidget {
  const ServiceJobsScreen({super.key});

  @override
  State<ServiceJobsScreen> createState() => _ServiceJobsScreenState();
}

class _ServiceJobsScreenState extends State<ServiceJobsScreen> {
  int _selectedFilterIndex = 0;
  final _filterOptions = ['In Progress (4)', 'Ready (2)', 'Completed (8)'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Service Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: List.generate(_filterOptions.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filterOptions[index]),
                      selected: isSelected,
                      selectedColor: AppColors.orange,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.orange : AppColors.border,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedFilterIndex = index);
                        }
                      },
                    ),
                  );
                }),
              ),
            ),

            // Job Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _buildJobCard(
                    jobId: '#JOB-1001',
                    vehicle: 'Toyota Innova',
                    service: 'Oil Change + Brake Pad Service',
                    progress: 0.70,
                    percentText: '70%',
                    badge: AutoBadge.inService(),
                  ),
                  _buildJobCard(
                    jobId: '#JOB-1002',
                    vehicle: 'Hyundai i20',
                    service: 'Engine Tuning & Brake Check',
                    progress: 0.40,
                    percentText: '40%',
                    badge: AutoBadge.inService(),
                  ),
                  _buildJobCard(
                    jobId: '#JOB-1003',
                    vehicle: 'Maruti Swift',
                    service: 'AC Evaporator Service & Filter',
                    progress: 0.90,
                    percentText: '90%',
                    badge: AutoBadge(
                      label: 'Almost Done',
                      color: AppColors.statusPending,
                      backgroundColor: AppColors.statusPendingBg,
                    ),
                  ),
                  _buildJobCard(
                    jobId: '#JOB-1004',
                    vehicle: 'Honda City',
                    service: 'General Service & Quality Check',
                    progress: 1.0,
                    percentText: '100%',
                    badge: AutoBadge.ready(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard({
    required String jobId,
    required String vehicle,
    required String service,
    required double progress,
    required String percentText,
    required Widget badge,
  }) {
    return AutoCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                jobId,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vehicle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            service,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),

          // Progress Bar with Percentage
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0
                          ? AppColors.statusCompleted
                          : AppColors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                percentText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
