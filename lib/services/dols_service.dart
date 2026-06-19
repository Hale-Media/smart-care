// ignore_for_file: use_null_aware_elements

import '../models/dols_authorisation.dart';
import 'api_client.dart';

class DoLsService {
  final _api = ApiClient.instance;

  Future<List<DoLsAuthorisation>> forResident(int residentId) async {
    final res = await _api.get('/dols.php', query: {'resident_id': residentId});
    return (res['dols'] as List? ?? [])
        .map((e) => DoLsAuthorisation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> create({
    required int residentId,
    required String status,
    bool urgent = false,
    String? reference,
    String? supervisoryBody,
    String? appliedOn,
    String? grantedOn,
    String? expiresOn,
    String? conditions,
    String? notes,
  }) async {
    final res = await _api.post('/dols.php', {
      'resident_id': residentId,
      'status': status,
      'urgent': urgent,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (supervisoryBody != null && supervisoryBody.isNotEmpty)
        'supervisory_body': supervisoryBody,
      if (appliedOn != null) 'applied_on': appliedOn,
      if (grantedOn != null) 'granted_on': grantedOn,
      if (expiresOn != null) 'expires_on': expiresOn,
      if (conditions != null && conditions.isNotEmpty) 'conditions': conditions,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res['id'] as int;
  }

  Future<void> update(int id, Map<String, dynamic> changes) async {
    await _api.put('/dols.php?id=$id', changes);
  }

  Future<void> delete(int id) async {
    await _api.delete('/dols.php?id=$id');
  }
}
