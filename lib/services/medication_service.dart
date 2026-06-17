import '../models/due_medication.dart';
import '../models/medication.dart';
import 'api_client.dart';

class MedicationService {
  final _api = ApiClient.instance;

  Future<List<Medication>> forResident(int residentId) async {
    final res = await _api.get('/medications/list.php',
        query: {'resident_id': residentId});
    final items = (res['medications'] as List? ?? []);
    return items.map((e) => Medication.fromJson(e)).toList();
  }

  Future<List<DueMedication>> dueMedications({
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _api.get('/medications/mar_due.php', query: {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    });
    return (res['slots'] as List? ?? [])
        .map((e) => DueMedication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Medication> create(Medication m) async {
    final res = await _api.post('/medications/create.php', m.toJson());
    return Medication.fromJson(res['medication']);
  }

  Future<void> update(Medication m) =>
      _api.post('/medications/update.php', m.toJson());

  Future<MarEntry> administer(MarEntry e) async {
    final res = await _api.post('/medications/administer.php', e.toJson());
    return MarEntry.fromJson(res['entry']);
  }

  Future<List<MarEntry>> marHistory({
    required int residentId,
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _api.get('/medications/mar_history.php', query: {
      'resident_id': residentId.toString(),
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    });
    final items = (res['entries'] as List? ?? []);
    return items.map((e) => MarEntry.fromJson(e)).toList();
  }
}
