import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/constants/app_assets.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';

/// Automotive splash loading experience.
///
/// Features dark garage atmosphere, rear sports car with glowing taillights,
/// smooth progress bar, and intelligent auth-aware routing.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _carFadeAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _carFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward().then((_) => _onAnimationComplete());
  }

  void _onAnimationComplete() {
    if (!mounted) return;
    final auth = ref.read(authProvider);

    if (auth.isAdmin) {
      context.go('/dashboard');
    } else if (auth.isClient) {
      context.go('/client-portal');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background 1: Dark garage environment
          Image.asset(
            AppAssets.loaderGarageDark,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppColors.background),
          ),

          // Vignette & Dark Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(180),
                  Colors.black.withAlpha(100),
                  Colors.black.withAlpha(220),
                ],
              ),
            ),
          ),

          // Content Layer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // AutoTricks Logo
                  Center(
                    child: Image.asset(
                      AppAssets.logoOriginal,
                      height: 54,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'AutoTricks',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Car Visual with Taillight Glow
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _carFadeAnimation.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient Glow behind rear sports car
                            Container(
                              width: 260,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.red.withAlpha(
                                        (_glowAnimation.value * 255).round()),
                                    AppColors.orange.withAlpha(
                                        (_glowAnimation.value * 120).round()),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Sports car rear image
                            Image.asset(
                              AppAssets.loaderCar,
                              width: 320,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const SizedBox(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const Spacer(),

                  // Progress Bar & Percentage
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      final percent = (_progressAnimation.value * 100).round();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Getting things ready...',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 6,
                              color: AppColors.surfaceVariant,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: _progressAnimation.value.clamp(0.01, 1.0),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: AppColors.orangeGradient,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Automotive Motto Footer
                  const Text(
                    'CARS • SERVICE • PEOPLE • ALWAYS FORWARD',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
