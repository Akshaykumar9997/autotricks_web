import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/design_system/theme/app_theme.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/home/providers/home_provider.dart';
import 'package:autotricks/features/service_requests/providers/service_requests_provider.dart';
import 'mock_repositories.dart';

Widget createTestWidget({
  required Widget child,
  List? overrides,
  MockAuthRepository? authRepo,
  MockHomeRepository? homeRepo,
  MockServiceRequestsRepository? serviceRequestsRepo,
  MockClientVehicleRepository? clientVehicleRepo,
}) {
  final effectiveOverrides = [
    authRepositoryProvider.overrideWithValue(authRepo ?? MockAuthRepository()),
    homeRepositoryProvider.overrideWithValue(homeRepo ?? MockHomeRepository()),
    serviceRequestsRepositoryProvider.overrideWithValue(serviceRequestsRepo ?? MockServiceRequestsRepository()),
    clientVehicleRepositoryProvider.overrideWithValue(clientVehicleRepo ?? MockClientVehicleRepository()),
    ...?overrides,
  ];

  return ProviderScope(
    overrides: effectiveOverrides.cast(),
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: child,
    ),
  );
}
