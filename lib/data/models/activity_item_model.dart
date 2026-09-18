import 'package:flutter/material.dart';
import '../../design_system/tokens/app_colors.dart';

class ActivityItemModel {
  final String id;
  final String title;
  final String subtitle;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;

  const ActivityItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.icon,
    this.iconColor = AppColors.primary,
  });
}
