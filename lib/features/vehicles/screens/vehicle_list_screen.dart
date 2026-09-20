import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_empty_state.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/models/vehicle_model.dart';
import '../providers/vehicles_provider.dart';

/// A09 — Vehicle List Screen conforming to approved Stitch A09.
class VehicleListScreen extends ConsumerStatefulWidget {
  const VehicleListScreen({super.key});

  @override
  ConsumerState<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends ConsumerState<VehicleListScreen> {
  late final TextEditingController _searchController;
  String _selectedMake = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VehicleModel> _filterVehicles(List<VehicleModel> vehicles) {
    return vehicles.where((v) {
      if (_selectedMake != 'ALL' && v.make.toUpperCase() != _selectedMake.toUpperCase()) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesMake = v.make.toLowerCase().contains(query);
        final matchesModel = v.model.toLowerCase().contains(query);
        final matchesPlate = (v.registrationNumber ?? '').toLowerCase().contains(query);
        final matchesVin = (v.chassisNumber ?? '').toLowerCase().contains(query);
        final matchesOwner = (v.client?.fullName ?? '').toLowerCase().contains(query);
        return matchesMake || matchesModel || matchesPlate || matchesVin || matchesOwner;
      }
      return true;
    }).toList();
  }

  List<String> _extractUniqueMakes(List<VehicleModel> vehicles) {
    final set = <String>{};
    for (final v in vehicles) {
      if (v.make.trim().isNotEmpty) {
        set.add(v.make.trim());
      }
    }
    final list = set.toList()..sort();
    return ['ALL', ...list];
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Vehicles',
        showBack: Navigator.canPop(context),
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin');
          }
        },
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () => ref.invalidate(vehiclesListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: Text(
          'Add Vehicle',
          style: AppTypography.bodyMediumEmphasis.copyWith(color: Colors.white),
        ),
        onPressed: () => context.push('/admin/vehicles/create'),
      ),
      body: vehiclesAsync.when(
        loading: () => Column(
          children: [
            Container(
              height: 100,
              padding: const EdgeInsets.all(16),
              color: AppColors.surface1,
              child: const AutoSkeleton(height: 48),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => const AutoSkeleton(
                  height: 110,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                ),
              ),
            ),
          ],
        ),
        error: (err, _) => Center(
          child: AutoErrorState(
            title: 'Unable to Load Vehicles',
            message: err.toString().replaceAll('Exception: ', ''),
            onRetry: () => ref.invalidate(vehiclesListProvider),
          ),
        ),
        data: (vehicles) {
          final makes = _extractUniqueMakes(vehicles);
          final filtered = _filterVehicles(vehicles);

          return Column(
            children: [
              // Search & Make Filter Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface1,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value.trim()),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by make, model, plate, VIN, owner...',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    if (makes.length > 1) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: makes.map((m) {
                            final isSelected = _selectedMake.toUpperCase() == m.toUpperCase();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(() => _selectedMake = m),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.surface2,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    m == 'ALL' ? 'All Makes' : m,
                                    style: AppTypography.caption.copyWith(
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Vehicle List
              Expanded(
                child: filtered.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () async => ref.invalidate(vehiclesListProvider),
                        color: AppColors.primary,
                        child: ListView(
                          children: [
                            const SizedBox(height: 60),
                            AutoEmptyState(
                              icon: Icons.directions_car_outlined,
                              title: _searchQuery.isNotEmpty || _selectedMake != 'ALL'
                                  ? 'No matching vehicles'
                                  : 'No vehicles registered',
                              message: _searchQuery.isNotEmpty || _selectedMake != 'ALL'
                                  ? 'Try changing your search terms or make filter.'
                                  : 'Add a vehicle to associate it with clients and service requests.',
                              actionLabel: _searchQuery.isEmpty && _selectedMake == 'ALL' ? 'Register First Vehicle' : null,
                              onAction: _searchQuery.isEmpty && _selectedMake == 'ALL'
                                  ? () => context.push('/admin/vehicles/create')
                                  : null,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(vehiclesListProvider),
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88), // Space for FAB
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final vehicle = filtered[index];
                            return _buildVehicleCard(vehicle);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    final plate = vehicle.registrationNumber ?? '';
    final vin = vehicle.chassisNumber ?? '';

    return AutoCard(
      onTap: () => context.push('/admin/vehicles/${vehicle.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.directions_car, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${vehicle.make} ${vehicle.model}',
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vehicle.manufacturingYear != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${vehicle.manufacturingYear}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (plate.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildPlateBadge(plate),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

          // Owner & VIN Footer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Owner
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        vehicle.client?.fullName ?? 'Owner: N/A',
                        style: AppTypography.caption.copyWith(
                          color: vehicle.client != null ? AppColors.textSecondary : AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Monospace VIN
              if (vin.isNotEmpty)
                Text(
                  'VIN: $vin',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlateBadge(String registrationNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text(
              'IND',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            registrationNumber,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
