// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';
import 'package:autotricks/data/repositories/client_portal_repository.dart';

void main() {
  test('Live Supabase client flow test', () async {
    const url = 'https://extsmeyxnzhhvcmwyvbi.supabase.co';
    const anonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4dHNtZXl4bnpoaHZjbXd5dmJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMTc5MDcsImV4cCI6MjEwNDU5MzkwN30.mZ7b02kRLI-UN1v5u0FZfllAji79ZYJn_0CkVuZagPg';

    print('--- Step 1: Initializing Supabase ---');
    final client = SupabaseClient(url, anonKey);

    print('--- Step 2: Signing in as rahul.kumar@gmail.com ---');
    final authRepo = SupabaseAuthRepository(client);
    final userProfile = await authRepo.signIn(
      email: 'rahul.kumar@gmail.com',
      password: 'Client@12345',
    );
    print('Signed in! userProfile: id=${userProfile.id}, role=${userProfile.role}, clientId=${userProfile.clientId}, fullName=${userProfile.fullName}');

    print('--- Step 3: Fetching Client Profile ---');
    final clientRepo = SupabaseClientPortalRepository(client);
    final profile = await clientRepo.fetchClientProfile();
    print('Fetched profile: id=${profile?.id}, fullName=${profile?.fullName}, email=${profile?.email}');

    print('--- Step 4: Fetching Client Service Requests ---');
    final requests = await clientRepo.fetchClientServiceRequests();
    print('Fetched ${requests.length} service requests:');
    for (final sr in requests) {
      print('  SR: id=${sr.id}, reqNum=${sr.requestNumber}, status=${sr.status}, jobStatus=${sr.jobStatus}');
    }

    print('--- Step 5: Direct raw query for quotations ---');
    try {
      final rawQuotations = await client
          .from('quotations')
          .select('''
            id,
            quotation_number,
            service_request_id,
            created_by,
            created_at,
            updated_at,
            service_requests (
              id,
              request_number,
              client_id,
              vehicle_id,
              source,
              status,
              created_by,
              created_at,
              updated_at,
              original_submission,
              clients (
                id,
                full_name,
                phone,
                email,
                address,
                city,
                state,
                pincode,
                is_active
              ),
              vehicles (
                id,
                client_id,
                make,
                model,
                manufacturing_year,
                chassis_number,
                registration_number
              )
            ),
            quotation_revisions (
              id,
              quotation_id,
              revision_number,
              status,
              subtotal,
              discount,
              tax,
              total,
              notes,
              terms,
              created_by,
              created_at,
              updated_at,
              sent_at,
              accepted_at,
              accepted_by_profile_id,
              acceptance_consent_text,
              rejected_at,
              rejection_reason,
              quotation_items (
                id,
                quotation_revision_id,
                catalogue_product_id,
                name,
                description,
                quantity,
                approximate_value,
                final_value,
                line_total,
                created_at,
                updated_at
              ),
              quotation_change_requests (
                id,
                quotation_revision_id,
                client_id,
                profile_id,
                message,
                status,
                admin_response,
                created_at,
                responded_at
              )
            )
          ''')
          .order('created_at', ascending: false);
      print('Raw quotations query returned: $rawQuotations');
    } catch (e, st) {
      print('RAW QUOTATIONS QUERY FAILED: $e');
      print(st);
    }

    print('--- Step 6: Testing clientRepo.fetchClientQuotations() ---');
    late String testQuoteId;
    late String testRevId;
    try {
      final quotes = await clientRepo.fetchClientQuotations();
      print('fetchClientQuotations returned ${quotes.length} quotes:');
      expect(quotes.isNotEmpty, isTrue);
      final q = quotes.first;
      testQuoteId = q.id;
      testRevId = q.currentRevision!.id;
      print('  Quote: id=${q.id}, num=${q.quotationNumber}, revs=${q.revisions.length}, currentRev=${q.currentRevision?.revisionNumber}, status=${q.currentStatus}, total=${q.totalAmount}');
      for (final r in q.revisions) {
        print('    Revision ${r.revisionNumber}: id=${r.id}, status=${r.status}, total=${r.total}, items=${r.items.length}');
        for (final item in r.items) {
          print('      Item: ${item.name}, qty=${item.quantity}, lineTotal=${item.lineTotal}');
        }
      }
      expect(q.currentRevisionNumber, equals(2));
      expect(q.totalAmount, equals(11000.0));
    } catch (e, st) {
      print('fetchClientQuotations FAILED: $e');
      print(st);
      rethrow;
    }

    print('--- Step 7: Testing clientRepo.getQuotationById() ---');
    try {
      final quote = await clientRepo.getQuotationById(testQuoteId);
      print('getQuotationById returned: id=${quote.id}, num=${quote.quotationNumber}, currentRev=${quote.currentRevisionNumber}, total=${quote.totalAmount}');
      expect(quote.currentRevisionNumber, equals(2));
      expect(quote.totalAmount, equals(11000.0));
      expect(quote.revisions.length, equals(2));
    } catch (e, st) {
      print('getQuotationById FAILED: $e');
      print(st);
      rethrow;
    }

    print('--- Step 8: Testing clientRepo.getQuotationByServiceRequestId() ---');
    try {
      final quote = await clientRepo.getQuotationByServiceRequestId('6b0b363a-cad3-4713-8d88-4e88e80e0754');
      print('getQuotationByServiceRequestId returned: id=${quote?.id}, num=${quote?.quotationNumber}, currentRev=${quote?.currentRevisionNumber}');
      expect(quote, isNotNull);
      expect(quote!.currentRevisionNumber, equals(2));
    } catch (e, st) {
      print('getQuotationByServiceRequestId FAILED: $e');
      print(st);
      rethrow;
    }

    print('--- Step 8b: Testing clientRepo.markQuotationViewed() ---');
    try {
      await clientRepo.markQuotationViewed(testRevId);
      print('markQuotationViewed succeeded!');
      final quoteAfterView = await clientRepo.getQuotationById(testQuoteId);
      print('After mark viewed: status=${quoteAfterView.currentStatus}');
    } catch (e, st) {
      print('markQuotationViewed FAILED: $e');
      print(st);
      rethrow;
    }

    print('--- Step 9: Testing Client Isolation with arun.prakash@gmail.com ---');
    final client2 = SupabaseClient(url, anonKey);
    final authRepo2 = SupabaseAuthRepository(client2);
    final arunProfile = await authRepo2.signIn(
      email: 'arun.prakash@gmail.com',
      password: 'Client@12345',
    );
    print('Signed in as Arun: id=${arunProfile.id}, clientId=${arunProfile.clientId}');
    final clientRepo2 = SupabaseClientPortalRepository(client2);
    final arunQuotes = await clientRepo2.fetchClientQuotations();
    print('Arun quotes count: ${arunQuotes.length}');
    expect(arunQuotes.any((q) => q.id == testQuoteId), isFalse, reason: 'Arun should NOT see Rahul\'s quotation!');

    try {
      await clientRepo2.getQuotationById(testQuoteId);
      fail('Arun should not be able to get Rahul\'s quotation by ID');
    } catch (e) {
      print('Arun direct fetch correctly rejected by RLS: $e');
    }
  });
}
