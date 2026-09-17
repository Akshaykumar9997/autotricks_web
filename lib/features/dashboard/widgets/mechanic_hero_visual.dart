import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/constants/app_assets.dart';

/// Cinematic automotive hero component.
///
/// Composes workshop garage background, hero car, and mechanic actively
/// repairing the engine with layered lighting and subtle ambient breathing.
class MechanicHeroVisual extends StatefulWidget {
  const MechanicHeroVisual({super.key});

  @override
  State<MechanicHeroVisual> createState() => _MechanicHeroVisualState();
}

class _MechanicHeroVisualState extends State<MechanicHeroVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: 0.0, end: -3.0).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Workshop Garage Background
            Image.asset(
              AppAssets.workshopGarage,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.surfaceVariant,
              ),
            ),

            // Layer 2: Ambient Orange Glow behind the car/mechanic
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.3, 0.1),
                      radius: 0.9,
                      colors: [
                        AppColors.orange.withAlpha((_glowAnimation.value * 255).round()),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),

            // Layer 3: Dark Vignette / Gradient overlays for contrast & depth
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x660B0D0F),
                    Color(0xE60B0D0F),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Layer 4: Car Hero
            Positioned(
              left: -10,
              bottom: 4,
              width: 250,
              height: 155,
              child: Image.asset(
                AppAssets.carHero,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),

            // Layer 5: Mechanic Actively Repairing Car (with subtle float/breathing)
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Positioned(
                  right: 16,
                  bottom: 8 + _floatAnimation.value,
                  width: 175,
                  height: 175,
                  child: child!,
                );
              },
              child: Image.asset(
                AppAssets.mechanicRepairingCar,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),

            // Layer 6: Atmospheric Badge / Automotive Motto (from reference board)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SERVICE TODAY',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 2,
                          margin: const EdgeInsets.only(right: 4),
                          color: AppColors.orange,
                        ),
                        const Text(
                          'A BETTER TOMORROW',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Layer 7: Subtle orange accent border indicator
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orange.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.orange.withAlpha(120), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.precision_manufacturing_rounded,
                        size: 13, color: AppColors.orange),
                    SizedBox(width: 5),
                    Text(
                      'LIVE BAY 01',
                      style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
