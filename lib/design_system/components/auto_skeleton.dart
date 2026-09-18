import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';

/// Content loading placeholder preserving layout structure (DESIGN.md Section 32).
class AutoSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const AutoSkeleton({
    super.key,
    this.width,
    this.height = 16.0,
    this.borderRadius,
    this.shape,
  });

  const AutoSkeleton.card({
    super.key,
    this.width = double.infinity,
    this.height = 120.0,
    this.borderRadius = AppRadius.radiusLg,
  }) : shape = null;

  const AutoSkeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = const CircleBorder();

  @override
  State<AutoSkeleton> createState() => _AutoSkeletonState();
}

class _AutoSkeletonState extends State<AutoSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surface2.withValues(alpha: _animation.value),
            borderRadius: widget.shape == null
                ? (widget.borderRadius ?? AppRadius.radiusSm)
                : null,
            shape: widget.shape is CircleBorder
                ? BoxShape.circle
                : BoxShape.rectangle,
          ),
        );
      },
    );
  }
}
