import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/quotation_model.dart';

void main() {
  group('Quotation Models Test', () {
    test('QuotationModel.fromJson parses nested structure correctly', () {
      final json = {
        'id': 'quote-101',
        'quotation_number': 'QT-2026-00099',
        'service_request_id': 'sr-101',
        'created_by': 'usr-admin-1',
        'created_at': '2026-09-21T10:00:00Z',
        'updated_at': '2026-09-21T10:30:00Z',
        'service_requests': {
          'id': 'sr-101',
          'request_number': 'SR-2026-00099',
          'source': 'PHONE',
          'status': 'QUOTATION_CREATED',
          'clients': {
            'id': 'c-1',
            'full_name': 'Aarav Sharma',
            'phone': '+91 99887 76655',
            'email': 'aarav@example.com',
          },
          'vehicles': {
            'id': 'v-1',
            'client_id': 'c-1',
            'make': 'Maruti Suzuki',
            'model': 'Baleno',
            'manufacturing_year': 2023,
            'registration_number': 'KA 05 MN 1234',
          },
        },
        'quotation_revisions': [
          {
            'id': 'rev-101',
            'quotation_id': 'quote-101',
            'revision_number': 1,
            'status': 'DRAFT',
            'subtotal': 5000.0,
            'discount': 500.0,
            'tax': 810.0,
            'total': 5310.0,
            'notes': 'Periodic maintenance inspection.',
            'terms': 'Valid for 15 days.',
            'created_at': '2026-09-21T10:00:00Z',
            'quotation_items': [
              {
                'id': 'item-1',
                'quotation_revision_id': 'rev-101',
                'catalogue_product_id': 'prd-1',
                'name': 'Engine Oil 5W-40',
                'description': 'Full synthetic',
                'quantity': 3.5,
                'approximate_value': null,
                'final_value': 800.0,
                'line_total': 2800.0,
                'created_at': '2026-09-21T10:00:00Z',
                'updated_at': '2026-09-21T10:00:00Z',
              },
              {
                'id': 'item-2',
                'quotation_revision_id': 'rev-101',
                'catalogue_product_id': null,
                'name': 'Labour - Oil & Filter Replacement',
                'description': 'Labour charges',
                'quantity': 1.0,
                'approximate_value': null,
                'final_value': 2200.0,
                'line_total': 2200.0,
                'created_at': '2026-09-21T10:00:00Z',
                'updated_at': '2026-09-21T10:00:00Z',
              },
            ],
          },
        ],
      };

      final quote = QuotationModel.fromJson(json);

      expect(quote.id, 'quote-101');
      expect(quote.quotationNumber, 'QT-2026-00099');
      expect(quote.customerName, 'Aarav Sharma');
      expect(quote.customerPhone, '+91 99887 76655');
      expect(quote.vehiclePlate, 'KA 05 MN 1234');
      expect(quote.vehicleTitle, contains('Baleno'));
      expect(quote.requestNumber, 'SR-2026-00099');
      expect(quote.revisions.length, 1);

      final rev = quote.latestRevision;
      expect(rev, isNotNull);
      expect(rev!.revisionNumber, 1);
      expect(rev.status, 'DRAFT');
      expect(rev.subtotal, 5000.0);
      expect(rev.discount, 500.0);
      expect(rev.tax, 810.0);
      expect(rev.total, 5310.0);
      expect(rev.items.length, 2);

      expect(rev.items[0].name, 'Engine Oil 5W-40');
      expect(rev.items[0].quantity, 3.5);
      expect(rev.items[0].finalValue, 800.0);
      expect(rev.items[0].lineTotal, 2800.0);

      expect(rev.items[1].name, 'Labour - Oil & Filter Replacement');
      expect(rev.items[1].catalogueProductId, isNull);
    });

    test('DraftQuotationItemInput computes lineTotal accurately', () {
      const item = DraftQuotationItemInput(
        name: 'Brake Rotor Resurfacing',
        quantity: 2.0,
        finalValue: 1250.50,
      );

      expect(item.lineTotal, 2501.0);
      final json = item.toJson();
      expect(json['name'], 'Brake Rotor Resurfacing');
      expect(json['quantity'], 2.0);
      expect(json['final_value'], 1250.50);
      expect(json['line_total'], 2501.0);
    });

    test('QuotationRevisionModel computes item count and fallback status', () {
      final rev = QuotationRevisionModel(
        id: 'rev-x',
        quotationId: 'q-x',
        revisionNumber: 2,
        status: 'SENT',
        subtotal: 1000,
        total: 1180,
        createdAt: DateTime.now(),
        items: const [],
      );

      expect(rev.status, 'SENT');
      expect(rev.items.isEmpty, isTrue);
    });
  });
}
