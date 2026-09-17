import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_card.dart';

/// Screen shell for Clients directory (Day 6 scope foundation).
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search clients by name, phone, or vehicle...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  fillColor: AppColors.surface,
                  filled: true,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _buildClientTile(
                    initials: 'RS',
                    name: 'Rohit Sharma',
                    stats: '2 vehicles • 5 services',
                    phone: '+91 98765 43210',
                  ),
                  _buildClientTile(
                    initials: 'PM',
                    name: 'Priya Menon',
                    stats: '1 vehicle • 3 services',
                    phone: '+91 98765 43211',
                  ),
                  _buildClientTile(
                    initials: 'AK',
                    name: 'Arjun Kumar',
                    stats: '1 vehicle • 2 services',
                    phone: '+91 98765 43212',
                  ),
                  _buildClientTile(
                    initials: 'NR',
                    name: 'Nandini Raj',
                    stats: '1 vehicle • 4 services',
                    phone: '+91 98765 43213',
                  ),
                  _buildClientTile(
                    initials: 'VS',
                    name: 'Vikram S',
                    stats: '3 vehicles • 6 services',
                    phone: '+91 98765 43214',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientTile({
    required String initials,
    required String name,
    required String stats,
    required String phone,
  }) {
    return AutoCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stats,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
