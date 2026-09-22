import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/auth/screens/login_screen.dart';
import 'package:autotricks/features/catalogue/providers/products_provider.dart';
import 'package:autotricks/features/catalogue/screens/create_edit_product_screen.dart';
import 'package:autotricks/features/catalogue/screens/products_list_screen.dart';
import 'package:autotricks/features/clients/screens/client_detail_screen.dart';
import 'package:autotricks/features/clients/screens/client_list_screen.dart';
import 'package:autotricks/features/clients/screens/create_edit_client_screen.dart';
import 'package:autotricks/features/home/screens/admin_home_screen.dart';
import 'package:autotricks/features/quotes/screens/create_quote_screen.dart';
import 'package:autotricks/features/quotes/screens/edit_quote_revision_screen.dart';
import 'package:autotricks/features/quotes/screens/quote_change_requests_screen.dart';
import 'package:autotricks/features/quotes/screens/quote_detail_screen.dart';
import 'package:autotricks/features/quotes/screens/quote_list_screen.dart';
import 'package:autotricks/features/service_requests/screens/create_service_request_screen.dart';
import 'package:autotricks/features/service_requests/screens/service_request_detail_screen.dart';
import 'package:autotricks/features/service_requests/screens/service_requests_list_screen.dart';
import 'package:autotricks/features/vehicles/screens/create_edit_vehicle_screen.dart';
import 'package:autotricks/features/vehicles/screens/vehicle_detail_screen.dart';
import 'package:autotricks/features/vehicles/screens/vehicle_list_screen.dart';
import 'package:autotricks/features/client/screens/client_home_screen.dart';
import 'package:autotricks/features/client/screens/client_login_screen.dart';
import 'package:autotricks/features/client/screens/client_service_request_detail_screen.dart';
import 'package:autotricks/features/client/screens/client_service_requests_screen.dart';
import 'package:autotricks/features/client/screens/client_vehicle_detail_screen.dart';
import 'package:autotricks/features/client/screens/client_vehicles_screen.dart';
import 'package:autotricks/features/client/screens/client_quotes_screen.dart';
import 'package:autotricks/features/client/screens/client_quote_detail_screen.dart';
import 'package:autotricks/features/client/screens/client_request_changes_screen.dart';
import 'package:autotricks/features/client/screens/client_accept_quote_screen.dart';
import 'package:autotricks/features/client/screens/client_quote_rejected_screen.dart';
import '../helpers/mock_repositories.dart';
import '../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceWidths = [360.0, 375.0, 390.0, 430.0];
  const testClientId = '2bd5d7fb-3b55-48b1-931f-69896d3f0838'; // Rahul Kumar
  const testVehicleId = 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24'; // Honda City

  group('Responsive Layout Verification (360px, 375px, 390px, 430px)', () {
    for (final width in deviceWidths) {
      testWidgets('A01 LoginScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const LoginScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign In'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A02 AdminHomeScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const AdminHomeScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Request'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A03 ServiceRequestsListScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ServiceRequestsListScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Requests'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A04 ServiceRequestDetailScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ServiceRequestDetailScreen(requestId: 'sr-1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('#SR-2026-00021'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A05 CreateServiceRequestScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const CreateServiceRequestScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Service Request'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      // Day 5 Screens (A06–A11)
      testWidgets('A06 ClientListScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ClientListScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Clients'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A07 ClientDetailScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ClientDetailScreen(clientId: testClientId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Client Profile'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A08 CreateEditClientScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const CreateEditClientScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Client'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('A09 VehicleListScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const VehicleListScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vehicles'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A10 VehicleDetailScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const VehicleDetailScreen(vehicleId: testVehicleId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vehicle Details'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A11 CreateEditVehicleScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const CreateEditVehicleScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Register Vehicle'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('A22 ProductsListScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              productsRepositoryProvider.overrideWithValue(MockProductsRepository()),
            ],
            child: const ProductsListScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Products Catalogue'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A23 CreateEditProductScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              productsRepositoryProvider.overrideWithValue(MockProductsRepository()),
            ],
            child: const CreateEditProductScreen(productId: 'prd-1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit Product'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A12 QuoteListScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const QuoteListScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Quotations'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A13 QuoteDetailScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const QuoteDetailScreen(quotationId: 'quote-1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('QT-2026-00012'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A14 CreateQuoteScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const CreateQuoteScreen(serviceRequestId: 'sr-1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Quote'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A15 EditQuoteRevisionScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const EditQuoteRevisionScreen(
              quotationId: 'quote-1',
              revisionId: 'rev-1',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit Quote Revision'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A16 QuoteChangeRequestsScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const QuoteChangeRequestsScreen(
              quotationId: 'quote-1',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Quote Change Requests'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C01 ClientLoginScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ClientLoginScreen()),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('C02 ClientHomeScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ClientHomeScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('CURRENT SERVICE REQUEST'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C03 ClientVehiclesScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ClientVehiclesScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('My Vehicles'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C04 ClientVehicleDetailScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const ClientVehicleDetailScreen(
              vehicleId: testVehicleId,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vehicle Details'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C05 ClientServiceRequestsScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ClientServiceRequestsScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Service Requests'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C06 ClientServiceRequestDetailScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const ClientServiceRequestDetailScreen(
              requestId: 'sr-client-1',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Request Details'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C07 ClientQuotesScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ClientQuotesScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('My Quotes'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C08 ClientQuoteDetailScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const ClientQuoteDetailScreen(quotationId: 'q-client-1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('COST SUMMARY'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C09 ClientRequestChangesScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const ClientRequestChangesScreen(quotationId: 'q-client-1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Request Changes'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C10 ClientAcceptQuoteScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const ClientAcceptQuoteScreen(quotationId: 'q-client-1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Accept Quotation'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('C12 ClientQuoteRejectedScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(
            child: const ClientQuoteRejectedScreen(quotationId: 'q-client-4'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Quotation Declined'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
