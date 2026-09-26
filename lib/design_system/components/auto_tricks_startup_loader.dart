import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

/// Professional, automotive-grade startup loader conforming to AutoTricks branding
/// and reproducing the reference staggered vertical loading bars animation.
///
/// Hierarchy:
/// 1. Orange Native Background (#FE6603)
/// 2. White Loader Area (155.5dp matching native Android splash icon window)
/// 3. AutoTricks Branding (canonical AT symbol)
/// 4. Animated Orange Loading Bars (staggered continuous wave, 1s cycle)
class AutoTricksStartupLoader extends StatelessWidget {
  const AutoTricksStartupLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // Exact AutoTricks brand orange matching native splash
    const brandOrange = Color(0xFFFE6603);

    // Matching dimensions with native Android splash screen:
    // Native splash icon circle is 155.5dp (408-414px on high-DPI displays)
    const double containerSize = 155.5;
    const double logoSize = 62.0;

    return Material(
      color: brandOrange,
      child: Center(
        child: Container(
          width: containerSize,
          height: containerSize,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // AutoTricks Approved Branding (Canonical Symbol)
              SizedBox(
                width: logoSize,
                height: logoSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    AppAssets.logoSymbol,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(
                      Icons.directions_car,
                      color: brandOrange,
                      size: 48,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12.0),

              // Animated Orange Loading Bars (Native Flutter implementation of loading-bars-loader.html)
              const AutoLoadingBars(
                color: brandOrange,
                barWidth: 4.0,
                normalHeight: 18.0,
                animatedHeight: 34.0,
                spacing: 4.0,
                barCount: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Native Flutter implementation of the reference loading-bars loader animation.
///
/// Specifications from reference (loading-bars-loader.html):
/// - 4px bar width
/// - ~18-24px normal resting height
/// - ~34-48px animated peak height
/// - 4px horizontal spacing between bars
/// - 1-second continuous animation cycle
/// - Staggered phase delays across bars
/// - Bottom baseline alignment (flex-end / CrossAxisAlignment.end)
class AutoLoadingBars extends StatefulWidget {
  final Color color;
  final double barWidth;
  final double normalHeight;
  final double animatedHeight;
  final double spacing;
  final int barCount;

  const AutoLoadingBars({
    super.key,
    this.color = const Color(0xFFFE6603),
    this.barWidth = 4.0,
    this.normalHeight = 18.0,
    this.animatedHeight = 34.0,
    this.spacing = 4.0,
    this.barCount = 4,
  });

  @override
  State<AutoLoadingBars> createState() => _AutoLoadingBarsState();
}

class _AutoLoadingBarsState extends State<AutoLoadingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getBarHeight(double progress, int index) {
    // Stagger delay between bars (0.14s per bar in a 1-second period)
    final delay = index * 0.14;
    final adjusted = (progress - delay) % 1.0;

    // Keyframe timing matching reference CSS @keyframes:
    // 0.0 -> 0.20 (0 - 200ms): smooth increase from normal to animated height
    // 0.20 -> 0.40 (200 - 400ms): smooth decrease from animated to normal height
    // 0.40 -> 1.00 (400 - 1000ms): resting state at normal height
    if (adjusted < 0.20) {
      final t = adjusted / 0.20;
      final curved = Curves.easeInOutCubic.transform(t);
      return widget.normalHeight +
          (widget.animatedHeight - widget.normalHeight) * curved;
    } else if (adjusted < 0.40) {
      final t = (adjusted - 0.20) / 0.20;
      final curved = Curves.easeInOutCubic.transform(t);
      return widget.animatedHeight -
          (widget.animatedHeight - widget.normalHeight) * curved;
    } else {
      return widget.normalHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          height: widget.animatedHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (index) {
              final height = _getBarHeight(_controller.value, index);
              return Container(
                margin: EdgeInsets.only(
                  right: index < widget.barCount - 1 ? widget.spacing : 0,
                ),
                width: widget.barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.barWidth / 2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
