import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/app/router.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/app/theme/app_theme.dart';

/// Root application widget for AutoTricks.
class AutoTricksApp extends ConsumerWidget {
  const AutoTricksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AutoTricks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(context),
      routerConfig: router,
      builder: (context, child) {
        // Mobile-first responsive wrapper:
        // Centers UI within a clean phone/tablet max width on large displays,
        // without stretching or breaking the automotive atmospheric layout.
        return Container(
          color: Colors.black,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        );
      },
    );
  }
}
