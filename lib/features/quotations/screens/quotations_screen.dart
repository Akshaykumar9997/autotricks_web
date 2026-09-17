import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_badge.dart';
import 'package:autotricks/core/widgets/auto_card.dart';

/// Screen shell for Quotations (Day 7 scope foundation).
class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  int _selectedFilterIndex = 0;
  final _filterOptions = ['All (8)', 'Draft (2)', 'Sent (4)', 'Approved (2)'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quotations'),
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search quotations by ID, customer...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  fillColor: AppColors.surface,
                  filled: true,
                ),
              ),
            ),

            // Quotation Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _buildQuoteCard(
                    id: '#QT-1001',
                    customer: 'Rohit Sharma',
                    vehicle: 'Toyota Innova',
                    amount: '₹12,450',
                    badge: AutoBadge(
                      label: 'Sent',
                      color: AppColors.statusInService,
                      backgroundColor: AppColors.statusInServiceBg,
                    ),
                    date: '2 days ago',
                  ),
                  _buildQuoteCard(
                    id: '#QT-1002',
                    customer: 'Priya Menon',
                    vehicle: 'Hyundai i20',
                    amount: '₹8,900',
                    badge: AutoBadge.completed(label: 'Approved'),
                    date: '4 days ago',
                  ),
                  _buildQuoteCard(
                    id: '#QT-1003',
                    customer: 'Arjun Kumar',
                    vehicle: 'Maruti Swift',
                    amount: '₹6,300',
                    badge: AutoBadge.draft(),
                    date: '1 day ago',
                  ),
                  _buildQuoteCard(
                    id: '#QT-1004',
                    customer: 'Nandini Raj',
                    vehicle: 'Honda City',
                    amount: '₹15,200',
                    badge: AutoBadge(
                      label: 'Sent',
                      color: AppColors.statusInService,
                      backgroundColor: AppColors.statusInServiceBg,
                    ),
                    date: '3 days ago',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard({
    required String id,
    required String customer,
    required String vehicle,
    required String amount,
    required Widget badge,
    required String date,
  }) {
    return AutoCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                amount,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      vehicle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
