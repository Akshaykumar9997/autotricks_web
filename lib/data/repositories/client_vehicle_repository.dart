import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';
import '../models/service_request_model.dart';
import '../models/vehicle_model.dart';

abstract class ClientVehicleRepository {
  // Clients
  Future<List<ClientModel>> fetchClients({
    bool? activeOnly,
    String? searchQuery,
  });

  Future<ClientModel> getClientById(String id);

  Future<ClientModel> createClient({
    required String fullName,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? notes,
    bool isActive = true,
  });

  Future<ClientModel> updateClient({
    required String id,
    required String fullName,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? notes,
    required bool isActive,
  });

  // Vehicles
  Future<List<VehicleModel>> fetchVehicles({
    String? searchQuery,
    String? makeFilter,
  });

  Future<List<VehicleModel>> fetchVehiclesForClient(String clientId);

  Future<VehicleModel> getVehicleById(String id);

  Future<VehicleModel> createVehicle({
    required String clientId,
    required String make,
    required String model,
    int? manufacturingYear,
    required String chassisNumber,
    required String registrationNumber,
  });

  Future<VehicleModel> updateVehicle({
    required String id,
    required String make,
    required String model,
    int? manufacturingYear,
    required String chassisNumber,
    required String registrationNumber,
  });

  // Related Service Requests (A07 & A10) via public.admin_service_requests
  Future<List<ServiceRequestModel>> fetchServiceRequestsForClient(String clientId);
  Future<List<ServiceRequestModel>> fetchServiceRequestsForVehicle(String vehicleId);
}

class SupabaseClientVehicleRepository implements ClientVehicleRepository {
  final SupabaseClient _client;

  SupabaseClientVehicleRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<ClientModel>> fetchClients({
    bool? activeOnly,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('admin_clients').select('*');
      if (activeOnly != null) {
        query = query.eq('is_active', activeOnly);
      }

      final clientRows = await query.order('full_name', ascending: true);

      // Fetch vehicles to provide summary counts and model names on client cards
      final vehicleRows = await _client
          .from('vehicles')
          .select('id, client_id, make, model, manufacturing_year, registration_number');

      final vehiclesMap = <String, List<VehicleModel>>{};
      for (final v in (vehicleRows as List)) {
        final vm = VehicleModel.fromJson(v as Map<String, dynamic>);
        vehiclesMap.putIfAbsent(vm.clientId, () => []).add(vm);
      }

      final list = (clientRows as List).map((c) {
        final map = c as Map<String, dynamic>;
        final clientId = map['id'] as String;
        final clientVehicles = vehiclesMap[clientId] ?? [];
        return ClientModel.fromJson(map).copyWith(vehicles: clientVehicles);
      }).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        return list.where((c) {
          final name = c.fullName.toLowerCase();
          final phone = c.phone.toLowerCase();
          final email = c.email?.toLowerCase() ?? '';
          return name.contains(q) || phone.contains(q) || email.contains(q);
        }).toList();
      }

      return list;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ClientModel> getClientById(String id) async {
    try {
      final data = await _client
          .from('admin_clients')
          .select('*')
          .eq('id', id)
          .single();

      final vehicles = await fetchVehiclesForClient(id);
      return ClientModel.fromJson(data).copyWith(vehicles: vehicles);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ClientModel> createClient({
    required String fullName,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? notes,
    bool isActive = true,
  }) async {
    try {
      final insertData = {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
        'address': (address != null && address.trim().isNotEmpty) ? address.trim() : null,
        'city': (city != null && city.trim().isNotEmpty) ? city.trim() : null,
        'state': (state != null && state.trim().isNotEmpty) ? state.trim() : null,
        'pincode': (pincode != null && pincode.trim().isNotEmpty) ? pincode.trim() : null,
        'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
        'is_active': isActive,
      };

      final response = await _client
          .from('clients')
          .insert(insertData)
          .select('id')
          .single();

      final newId = response['id'] as String;

      if (notes != null && notes.trim().isNotEmpty) {
        try {
          await _client.rpc('admin_set_client_notes', params: {
            'p_client_id': newId,
            'p_notes': notes.trim(),
          });
        } catch (_) {}
      }

      return await getClientById(newId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ClientModel> updateClient({
    required String id,
    required String fullName,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? notes,
    required bool isActive,
  }) async {
    try {
      final updateData = {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
        'address': (address != null && address.trim().isNotEmpty) ? address.trim() : null,
        'city': (city != null && city.trim().isNotEmpty) ? city.trim() : null,
        'state': (state != null && state.trim().isNotEmpty) ? state.trim() : null,
        'pincode': (pincode != null && pincode.trim().isNotEmpty) ? pincode.trim() : null,
        'is_active': isActive,
      };

      await _client.from('clients').update(updateData).eq('id', id);

      await _client.rpc('admin_set_client_notes', params: {
        'p_client_id': id,
        'p_notes': notes?.trim() ?? '',
      });

      return await getClientById(id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<VehicleModel>> fetchVehicles({
    String? searchQuery,
    String? makeFilter,
  }) async {
    try {
      final vehicleRows = await _client
          .from('vehicles')
          .select('*')
          .order('created_at', ascending: false);

      final clientRows = await _client
          .from('admin_clients')
          .select('id, full_name, phone, email');

      final clientMap = {
        for (final c in (clientRows as List))
          c['id'] as String: ClientModel.fromJson(c as Map<String, dynamic>)
      };

      final list = (vehicleRows as List).map((v) {
        final map = v as Map<String, dynamic>;
        final clientId = map['client_id'] as String;
        final client = clientMap[clientId];
        return VehicleModel.fromJson(map).copyWith(client: client);
      }).toList();

      var filtered = list;
      if (makeFilter != null &&
          makeFilter.isNotEmpty &&
          makeFilter.toLowerCase() != 'all') {
        filtered = filtered
            .where((v) => v.make.toLowerCase() == makeFilter.toLowerCase())
            .toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        filtered = filtered.where((v) {
          final make = v.make.toLowerCase();
          final model = v.model.toLowerCase();
          final plate = v.registrationNumber?.toLowerCase() ?? '';
          final vin = v.chassisNumber?.toLowerCase() ?? '';
          final owner = v.client?.fullName.toLowerCase() ?? '';
          return make.contains(q) ||
              model.contains(q) ||
              plate.contains(q) ||
              vin.contains(q) ||
              owner.contains(q);
        }).toList();
      }

      return filtered;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<VehicleModel>> fetchVehiclesForClient(String clientId) async {
    try {
      final response = await _client
          .from('vehicles')
          .select('*')
          .eq('client_id', clientId)
          .order('make', ascending: true);

      return (response as List)
          .map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<VehicleModel> getVehicleById(String id) async {
    try {
      final data = await _client
          .from('vehicles')
          .select('*')
          .eq('id', id)
          .single();

      final clientId = data['client_id'] as String;
      final clientData = await _client
          .from('admin_clients')
          .select('*')
          .eq('id', clientId)
          .single();

      return VehicleModel.fromJson(data).copyWith(
        client: ClientModel.fromJson(clientData),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<VehicleModel> createVehicle({
    required String clientId,
    required String make,
    required String model,
    int? manufacturingYear,
    required String chassisNumber,
    required String registrationNumber,
  }) async {
    try {
      final insertData = {
        'client_id': clientId,
        'make': make.trim(),
        'model': model.trim(),
        'manufacturing_year': manufacturingYear,
        'chassis_number': chassisNumber.trim().toUpperCase(),
        'registration_number': registrationNumber.trim().toUpperCase(),
      };

      final response = await _client
          .from('vehicles')
          .insert(insertData)
          .select('id')
          .single();

      final newId = response['id'] as String;
      return await getVehicleById(newId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<VehicleModel> updateVehicle({
    required String id,
    required String make,
    required String model,
    int? manufacturingYear,
    required String chassisNumber,
    required String registrationNumber,
  }) async {
    try {
      // Note: client_id is strictly omitted per vehicles_guard trigger
      final updateData = {
        'make': make.trim(),
        'model': model.trim(),
        'manufacturing_year': manufacturingYear,
        'chassis_number': chassisNumber.trim().toUpperCase(),
        'registration_number': registrationNumber.trim().toUpperCase(),
      };

      await _client.from('vehicles').update(updateData).eq('id', id);
      return await getVehicleById(id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceRequestModel>> fetchServiceRequestsForClient(String clientId) async {
    try {
      final response = await _client
          .from('admin_service_requests')
          .select('*, vehicles(*), clients(id, full_name, phone, email, address, city, state, pincode, is_active)')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((r) => ServiceRequestModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceRequestModel>> fetchServiceRequestsForVehicle(String vehicleId) async {
    try {
      final response = await _client
          .from('admin_service_requests')
          .select('*, vehicles(*), clients(id, full_name, phone, email, address, city, state, pincode, is_active)')
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((r) => ServiceRequestModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
