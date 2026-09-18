import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';
import '../models/vehicle_model.dart';

abstract class ClientVehicleRepository {
  Future<List<ClientModel>> fetchClients();
  Future<List<VehicleModel>> fetchVehiclesForClient(String clientId);
}

class SupabaseClientVehicleRepository implements ClientVehicleRepository {
  final SupabaseClient _client;

  SupabaseClientVehicleRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<ClientModel>> fetchClients() async {
    try {
      final response = await _client
          .from('clients')
          .select()
          .eq('is_active', true)
          .order('full_name', ascending: true);

      return (response as List)
          .map((c) => ClientModel.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<VehicleModel>> fetchVehiclesForClient(String clientId) async {
    try {
      final response = await _client
          .from('vehicles')
          .select()
          .eq('client_id', clientId)
          .order('make', ascending: true);

      return (response as List)
          .map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
