import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_card.dart';

/// Screen shell for Vehicles inventory (Day 6 scope foundation).
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
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
                  hintText: 'Search vehicles by plate, make, or VIN...',
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
                  _buildVehicleTile(
                    makeModel: 'Toyota Innova Crysta',
                    plate: 'TN 37 AB 1234',
                    year: '2021',
                    owner: 'Rohit Sharma',
                    fuel: 'Diesel',
                  ),
                  _buildVehicleTile(
                    makeModel: 'Hyundai i20 Asta',
                    plate: 'KL 07 CD 4567',
                    year: '2020',
                    owner: 'Priya Menon',
                    fuel: 'Petrol',
                  ),
                  _buildVehicleTile(
                    makeModel: 'Maruti Suzuki Swift ZXi',
                    plate: 'TN 66 EF 7890',
                    year: '2022',
                    owner: 'Arjun Kumar',
                    fuel: 'Petrol',
                  ),
                  _buildVehicleTile(
                    makeModel: 'Honda City V',
                    plate: 'TN 10 GH 2345',
                    year: '2019',
                    owner: 'Nandini Raj',
                    fuel: 'Petrol',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTile({
    required String makeModel,
    required String plate,
    required String year,
    required String owner,
    required String fuel,
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
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.directions_car_filled_outlined,
              color: AppColors.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  makeModel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$plate • $year • $fuel',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Owner: $owner',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
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
