import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_empty_state.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/models/client_model.dart';
import '../providers/clients_provider.dart';

/// A06 — Client List Screen conforming to approved Stitch A06.
class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  late final TextEditingController _searchController;
  String _selectedFilter = 'ALL'; // ALL, ACTIVE, INACTIVE
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

  List<ClientModel> _filterClients(List<ClientModel> clients) {
    return clients.where((c) {
      if (_selectedFilter == 'ACTIVE' && !c.isActive) return false;
      if (_selectedFilter == 'INACTIVE' && c.isActive) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = c.fullName.toLowerCase().contains(query);
        final matchesPhone = c.phone.toLowerCase().contains(query);
        final matchesEmail = (c.email ?? '').toLowerCase().contains(query);
        final matchesCity = (c.city ?? '').toLowerCase().contains(query);
        return matchesName || matchesPhone || matchesEmail || matchesCity;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Clients',
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
            onPressed: () => ref.invalidate(clientsListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(
          'New Client',
          style: AppTypography.bodyMediumEmphasis.copyWith(color: Colors.white),
        ),
        onPressed: () => context.push('/admin/clients/create'),
      ),
      body: Column(
        children: [
          // Search & Filters Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface1,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.trim()),
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by client name, phone, email...',
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
                const SizedBox(height: 10),
                // Filter Tabs: ALL, ACTIVE, INACTIVE
                Row(
                  children: [
                    _buildFilterChip('ALL', 'All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('ACTIVE', 'Active'),
                    const SizedBox(width: 8),
                    _buildFilterChip('INACTIVE', 'Inactive'),
                  ],
                ),
              ],
            ),
          ),

          // Clients List Content
          Expanded(
            child: clientsAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => const AutoSkeleton(
                  height: 100,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                ),
              ),
              error: (err, stack) => Center(
                child: AutoErrorState(
                  title: 'Unable to Load Clients',
                  message: err.toString().replaceAll('Exception: ', ''),
                  onRetry: () => ref.invalidate(clientsListProvider),
                ),
              ),
              data: (clients) {
                final filtered = _filterClients(clients);

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(clientsListProvider),
                    color: AppColors.primary,
                    child: ListView(
                      children: [
                        const SizedBox(height: 60),
                        AutoEmptyState(
                          icon: Icons.people_outline,
                          title: _searchQuery.isNotEmpty ? 'No clients match "$_searchQuery"' : 'No clients found',
                          message: _searchQuery.isNotEmpty
                              ? 'Try refining your search terms or filter.'
                              : 'Add your first client to start managing vehicle service requests.',
                          actionLabel: _searchQuery.isEmpty ? 'Create First Client' : null,
                          onAction: _searchQuery.isEmpty ? () => context.push('/admin/clients/create') : null,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(clientsListProvider),
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88), // Space for FAB
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      return _buildClientCard(client);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
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
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildClientCard(ClientModel client) {
    final initials = client.fullName.trim().isNotEmpty
        ? client.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join()
        : 'C';

    return AutoCard(
      onTap: () => context.push('/admin/clients/${client.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Initials Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Center(
              child: Text(
                initials,
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Client Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.fullName,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AutoBadge(
                      label: client.isActive ? 'ACTIVE' : 'INACTIVE',
                      color: client.isActive ? AppColors.success : AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Phone Row
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        client.phone,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Email Row if present
                if (client.email != null && client.email!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          client.email!,
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Vehicles / City snippet
                if (client.city != null && client.city!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        client.city!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
