import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/client_model.dart';
import 'package:autotricks/data/models/quotation_model.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/data/models/vehicle_model.dart';
import 'package:autotricks/design_system/components/auto_signature_canvas.dart';
import 'package:autotricks/features/client/screens/client_accept_quote_screen.dart';
import 'package:autotricks/features/client/screens/client_quote_detail_screen.dart';
import 'package:autotricks/features/quotes/screens/quote_detail_screen.dart';
import 'package:autotricks/core/utils/pdf_launcher_helper.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('AutoSignatureCanvas Component Tests', () {
    test('Initial state is empty and exports null', () async {
      final controller = AutoSignatureController();
      expect(controller.isEmpty, isTrue);
      expect(controller.isNotEmpty, isFalse);
      expect(controller.strokeCount, 0);

      final bytes = await controller.toPngBytes();
      expect(bytes, isNull);
      controller.dispose();
    });

    test('Adding points updates state and clears cleanly', () async {
      final controller = AutoSignatureController();
      controller.startStroke(const Offset(10, 10));
      controller.addPoint(const Offset(20, 20));
      controller.addPoint(const Offset(30, 30));
      controller.endStroke();

      expect(controller.isEmpty, isFalse);
      expect(controller.isNotEmpty, isTrue);
      expect(controller.strokeCount, 1);

      controller.clear();
      expect(controller.isEmpty, isTrue);
      expect(controller.strokeCount, 0);
      controller.dispose();
    });

    test('toPngBytes exports valid PNG magic bytes', () async {
      final controller = AutoSignatureController();
      controller.startStroke(const Offset(15, 20));
      controller.addPoint(const Offset(50, 60));
      controller.addPoint(const Offset(100, 40));
      controller.endStroke();

      final bytes = await controller.toPngBytes(width: 200, height: 100);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(16));

      // PNG magic number: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      const pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      expect(bytes.sublist(0, 8), equals(pngMagic));
      controller.dispose();
    });

    testWidgets('Interactive drawing and Clear button on AutoSignatureCanvas',
        (tester) async {
      final controller = AutoSignatureController();
      bool signedCallbackCalled = false;
      bool clearedCallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: AutoSignatureCanvas(
                controller: controller,
                height: 200,
                onSigned: () => signedCallbackCalled = true,
                onCleared: () => clearedCallbackCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AutoSignatureCanvas), findsOneWidget);
      expect(find.text('Sign above with finger or stylus'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);

      // Perform a drag stroke
      final canvasFinder = find.byType(AutoSignatureCanvas);
      await tester.drag(canvasFinder, const Offset(60, 40));
      await tester.pumpAndSettle();

      expect(controller.isNotEmpty, isTrue);
      expect(signedCallbackCalled, isTrue);
      expect(find.text('Clear'), findsOneWidget);

      // Tap Clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(controller.isEmpty, isTrue);
      expect(clearedCallbackCalled, isTrue);
      expect(find.text('Clear'), findsNothing);

      controller.dispose();
    });

    testWidgets(
        'AutoSignatureCanvas exclusively captures drag gestures and prevents parent scrolling',
        (tester) async {
      final controller = AutoSignatureController();
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    Container(height: 100, color: Colors.blue, key: const Key('header-box')),
                    AutoSignatureCanvas(
                      controller: controller,
                      height: 200,
                    ),
                    Container(height: 600, color: Colors.amber, key: const Key('footer-box')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(scrollController.offset, 0.0);
      expect(controller.isEmpty, isTrue);

      // 1. Drag vertically on the AutoSignatureCanvas
      final canvasFinder = find.byType(AutoSignatureCanvas);
      await tester.drag(canvasFinder, const Offset(0, -60));
      await tester.pumpAndSettle();

      // Parent scroll offset MUST remain 0.0, and strokes MUST register
      expect(scrollController.offset, 0.0);
      expect(controller.isNotEmpty, isTrue);

      // 2. Drag vertically on the header box outside the signature canvas
      final headerFinder = find.byKey(const Key('header-box'));
      await tester.drag(headerFinder, const Offset(0, -50));
      await tester.pumpAndSettle();

      // Outside gesture scrolls the parent normally!
      expect(scrollController.offset, greaterThan(0.0));

      controller.dispose();
      scrollController.dispose();
    });
  });

  group('Day 11 — Client Digital Signature Flow Tests', () {
    testWidgets(
        'Step 1 -> Step 2 -> Step 3: Full drawing, confirmation, and acceptance flow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientAcceptQuoteScreen(quotationId: 'q-client-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Initial screen inspection
      expect(find.text('Accept Quotation'), findsWidgets);
      expect(find.text('CLIENT ACCEPTANCE & CONSENT'), findsOneWidget);
      expect(find.text('DIGITAL SIGNATURE'), findsOneWidget);
      expect(find.text('Total Agreed Value'), findsOneWidget);
      expect(find.text('₹21000'), findsOneWidget);

      // Verify button is disabled before consent and before signature
      final reviewButtonInitial = find.widgetWithText(ElevatedButton, 'Review & Confirm');
      expect(tester.widget<ElevatedButton>(reviewButtonInitial).enabled, isFalse);

      // REGRESSION TEST BUG 2: Toggle consent checkbox alone (leave signature empty)
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Crucial check: Button MUST STILL be disabled because signature is empty!
      expect(tester.widget<ElevatedButton>(reviewButtonInitial).enabled, isFalse);

      // Draw a signature on the canvas
      final canvas = find.byType(AutoSignatureCanvas);
      await tester.drag(canvas, const Offset(80, 50));
      await tester.pumpAndSettle();

      // Button updates to 'Review & Confirm'
      final reviewButton = find.widgetWithText(ElevatedButton, 'Review & Confirm');
      expect(tester.widget<ElevatedButton>(reviewButton).enabled, isTrue);

      // Tap 'Review & Confirm' to move to Step 2: Deliberate Confirmation
      await tester.tap(reviewButton);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text('Confirm Signature'), findsWidgets);
      expect(find.text('Deliberate Confirmation'), findsOneWidget);
      expect(find.text('CONFIRMED CONSENT STATEMENT'), findsOneWidget);
      expect(find.text('AUTHORIZED SIGNATURE'), findsOneWidget);
      expect(find.text('Edit Signature'), findsOneWidget);
      expect(find.text('Confirm & Sign'), findsOneWidget);

      // Test "Edit Signature" returns to Step 1
      await tester.tap(find.text('Edit Signature'));
      await tester.pumpAndSettle();
      expect(find.text('Review & Confirm'), findsOneWidget);

      // Return to confirmation step
      await tester.tap(find.text('Review & Confirm'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Tap 'Confirm & Sign' to finalize signing
      final confirmAndSignButton =
          find.widgetWithText(ElevatedButton, 'Confirm & Sign');
      await tester.tap(confirmAndSignButton);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Step 3: Success Screen
      expect(find.text('Quotation Accepted & Signed!'), findsOneWidget);
      expect(find.text('ACCEPTED'), findsOneWidget);
      expect(find.text('View Signed Quotation (PDF)'), findsOneWidget);
      expect(find.text('Back to My Quotes'), findsOneWidget);

      // Verify DB / Repository State Invariants
      final quote = await clientRepo.getQuotationById('q-client-1');
      expect(quote.currentStatus, 'ACCEPTED');
      expect(quote.latestRevision!.isSigned, isTrue);
      expect(quote.latestRevision!.signature, isNotNull);
      expect(quote.latestRevision!.signature!.signatureMethod, 'DRAWN');
      expect(quote.latestRevision!.signedDocument, isNotNull);
      expect(quote.latestRevision!.signedDocument!.documentType,
          'SIGNED_QUOTATION_PDF');

      // Verify Service Request updated to APPROVED
      final sr = await clientRepo.getServiceRequestById('sr-client-quote-ready');
      expect(sr.status, 'APPROVED');

      // CRITICAL INVARIANT: Signing quotation MUST NOT create a Service Job
      expect(sr.jobId, isNull);
      expect(sr.jobNumber, isNull);
    });
  });

  group('Day 11 — Quotation Detail Screens with Signed State', () {
    testWidgets('ClientQuoteDetailScreen displays signed badge and PDF action',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      // Sign the quotation revision first
      final fakeBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      ]);
      await clientRepo.signQuotationRevision(
        revisionId: 'rev-client-1',
        consentText: 'Agreed to terms',
        signatureBytes: fakeBytes,
      );

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuoteDetailScreen(quotationId: 'q-client-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quotation Signed & Accepted'), findsWidgets);
      expect(find.text('DIGITAL SIGNATURE & ACCEPTANCE'), findsOneWidget);
      expect(find.text('AUTHORIZED'), findsOneWidget);
      expect(find.text('DRAWN'), findsOneWidget);
      expect(find.text('View Signed Quotation (PDF)'), findsOneWidget);
      expect(find.text('View PDF'), findsOneWidget);
    });

    testWidgets(
        'Admin QuoteDetailScreen displays Customer Signature & Acceptance card with signed PDF action',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final signedRev = QuotationRevisionModel(
        id: 'rev-signed-1',
        quotationId: 'q-signed-1',
        revisionNumber: 1,
        status: 'ACCEPTED',
        subtotal: 10000,
        discount: 0,
        tax: 1000,
        total: 11000,
        createdAt: now.subtract(const Duration(days: 1)),
        acceptedAt: now,
        acceptedByProfileId: 'prof-client-1',
        acceptanceConsentText: 'Agreed to scope and terms',
        signature: QuotationSignatureModel(
          id: 'sig-1',
          quotationRevisionId: 'rev-signed-1',
          clientId: 'c-1',
          profileId: 'prof-client-1',
          signatureFile: 'signatures/c-1/rev-signed-1/signature.png',
          signatureMethod: 'DRAWN',
          consentText: 'Agreed to scope and terms',
          acceptedAt: now,
          signedAt: now,
          createdAt: now,
        ),
        documents: [
          DocumentModel(
            id: 'doc-1',
            clientId: 'c-1',
            quotationRevisionId: 'rev-signed-1',
            documentType: 'SIGNED_QUOTATION_PDF',
            storagePath: 'signed-quotation-pdfs/c-1/q-signed-1/revision-1-signed.pdf',
            createdAt: now,
          ),
        ],
        items: [
          QuotationItemModel(
            id: 'item-1',
            quotationRevisionId: 'rev-signed-1',
            name: 'Full Brake Service',
            quantity: 1,
            finalValue: 10000,
            lineTotal: 10000,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final signedQuote = QuotationModel(
        id: 'q-signed-1',
        quotationNumber: 'QT-2026-00099',
        serviceRequestId: 'sr-1',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
        serviceRequest: ServiceRequestModel(
          id: 'sr-1',
          requestNumber: 'SR-2026-00099',
          source: 'PORTAL',
          status: 'APPROVED',
          createdAt: now,
          updatedAt: now,
          client: const ClientModel(
            id: 'c-1',
            fullName: 'Rahul Kumar',
            phone: '+91 98450 12890',
            email: 'rahul.kumar@gmail.com',
          ),
          vehicle: const VehicleModel(
            id: 'v-1',
            clientId: 'c-1',
            make: 'Honda',
            model: 'City',
            manufacturingYear: 2022,
            registrationNumber: 'KA-01-MJ-4412',
          ),
        ),
        revisions: [signedRev],
      );

      final quotesRepo = MockQuotationsRepository(initialQuotes: [signedQuote]);

      await tester.pumpWidget(
        createTestWidget(
          quotationsRepo: quotesRepo,
          child: const QuoteDetailScreen(quotationId: 'q-signed-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Customer Signature & Acceptance'), findsOneWidget);
      expect(find.text('ACCEPTED · SIGNED'), findsOneWidget);
      expect(find.text('DRAWN'), findsOneWidget);
      expect(find.text('“Agreed to scope and terms”'), findsOneWidget);
      expect(find.text('View Signed Quotation (PDF)'), findsOneWidget);
    });
  });

  group('Day 11 — Bug 2 & Bug 1 Regression Unit Tests', () {
    test('Direct acceptQuotationRevision is explicitly forbidden and throws UnsupportedError', () async {
      final repo = MockClientPortalRepository();
      expect(
        () => repo.acceptQuotationRevision(
          revisionId: 'rev-client-1',
          consentText: 'Test consent',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    testWidgets('PdfLauncherHelper handles empty URL gracefully with snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PdfLauncherHelper.openPdf(context, pdfUrl: ''),
                child: const Text('Launch Empty'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Launch Empty'));
      await tester.pumpAndSettle();

      expect(find.text('Document URL is not available.'), findsOneWidget);
    });
  });
}
