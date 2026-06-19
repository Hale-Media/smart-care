import '../models/lasting_power.dart';
import 'api_client.dart';

class LastingPowerService {
  final _api = ApiClient.instance;

  Future<List<LastingPower>> forResident(int residentId) async {
    final res = await _api.get(
      '/lasting_powers.php',
      query: {'resident_id': residentId},
    );
    return (res['lasting_powers'] as List? ?? [])
        .map((e) => LastingPower.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> create({
    required int residentId,
    required String type,
    required String attorneyName,
    bool registered = false,
    String? attorneyContact,
    String? reference,
    String? notes,
  }) async {
    final res = await _api.post('/lasting_powers.php', {
      'resident_id': residentId,
      'type': type,
      'attorney_name': attorneyName,
      'registered': registered,
      if (attorneyContact != null && attorneyContact.isNotEmpty)
        'attorney_contact': attorneyContact,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res['id'] as int;
  }

  Future<void> update(int id, Map<String, dynamic> changes) async {
    await _api.put('/lasting_powers.php?id=$id', changes);
  }

  Future<void> delete(int id) async {
    await _api.delete('/lasting_powers.php?id=$id');
  }
}
