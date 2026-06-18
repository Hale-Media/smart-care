import '../models/care_intervention.dart';
import 'api_client.dart';

class CareInterventionService {
  final _api = ApiClient.instance;

  Future<List<CareIntervention>> forResident(int residentId) async {
    final res = await _api.get(
      '/care_interventions.php',
      query: {'resident_id': residentId},
    );
    return (res['interventions'] as List? ?? [])
        .map((e) => CareIntervention.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> create({
    required int residentId,
    required int sectionId,
    required String description,
    String? frequency,
  }) async {
    final res = await _api.post('/care_interventions.php', {
      'resident_id': residentId,
      'section_id': sectionId,
      'description': description,
      if (frequency != null && frequency.isNotEmpty) 'frequency': frequency,
    });
    return res['id'] as int;
  }

  Future<void> stop(int id) async {
    await _api.put('/care_interventions.php?id=$id', {'status': 'stopped'});
  }

  Future<void> delete(int id) async {
    await _api.delete('/care_interventions.php?id=$id');
  }
}
