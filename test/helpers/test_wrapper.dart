import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/design_system/theme/app_theme.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/client/providers/client_portal_provider.dart';
import 'package:autotricks/features/home/providers/home_provider.dart';
import 'package:autotricks/features/quotes/providers/quotes_provider.dart';
import 'package:autotricks/features/service_jobs/providers/service_jobs_provider.dart';
import 'package:autotricks/features/service_requests/providers/service_requests_provider.dart';
import 'package:autotricks/data/repositories/notifications_repository.dart';
import 'package:autotricks/data/repositories/device_tokens_repository.dart';
import 'mock_repositories.dart';

Widget createTestWidget({
  required Widget child,
  List? overrides,
  MockAuthRepository? authRepo,
  MockHomeRepository? homeRepo,
  MockServiceRequestsRepository? serviceRequestsRepo,
  MockClientVehicleRepository? clientVehicleRepo,
  MockQuotationsRepository? quotationsRepo,
  MockClientPortalRepository? clientPortalRepo,
  MockServiceJobsRepository? serviceJobsRepo,
  MockNotificationsRepository? notificationsRepo,
  MockDeviceTokensRepository? deviceTokensRepo,
}) {
  final effectiveOverrides = [
    authRepositoryProvider.overrideWithValue(authRepo ?? MockAuthRepository()),
    homeRepositoryProvider.overrideWithValue(homeRepo ?? MockHomeRepository()),
    serviceRequestsRepositoryProvider.overrideWithValue(serviceRequestsRepo ?? MockServiceRequestsRepository()),
    clientVehicleRepositoryProvider.overrideWithValue(clientVehicleRepo ?? MockClientVehicleRepository()),
    quotationsRepositoryProvider.overrideWithValue(quotationsRepo ?? MockQuotationsRepository()),
    clientPortalRepositoryProvider.overrideWithValue(clientPortalRepo ?? MockClientPortalRepository()),
    serviceJobsRepositoryProvider.overrideWithValue(serviceJobsRepo ?? MockServiceJobsRepository()),
    notificationsRepositoryProvider.overrideWithValue(notificationsRepo ?? MockNotificationsRepository()),
    deviceTokensRepositoryProvider.overrideWithValue(deviceTokensRepo ?? MockDeviceTokensRepository()),
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
