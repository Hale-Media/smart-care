import '../models/safeguarding_concern.dart';
import 'api_client.dart';

class SafeguardingService {
  final _api = ApiClient.instance;

  Future<List<SafeguardingConcern>> forResident(int residentId) async {
    final res = await _api.get(
      '/safeguarding.php',
      query: {'resident_id': residentId},
    );
    return (res['concerns'] as List? ?? [])
        .map((e) => SafeguardingConcern.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> create({
    required String category,
    required String description,
    required int residentId,
  }) async {
    final res = await _api.post('/safeguarding.php', {
      'category': category,
      'description': description,
      'resident_id': residentId,
    });
    return res['id'] as int;
  }

  Future<void> action(
      int id, String action, Map<String, dynamic> data) async {
    await _api.put('/safeguarding.php?id=$id&action=$action', data);
  }

  Future<void> delete(int id) async {
    await _api.delete('/safeguarding.php?id=$id');
  }
}
