import '../models/incident.dart';
import 'api_client.dart';

class IncidentService {
  final _api = ApiClient.instance;

  Future<List<Incident>> list({String? status, int? residentId}) async {
    final res = await _api.get(
      '/incidents/list.php',
      query: {
        'status': ?status,
        if (residentId != null) 'resident_id': residentId.toString(),
      },
    );
    final items = (res['incidents'] as List? ?? []);
    return items.map((e) => Incident.fromJson(e)).toList();
  }

  Future<Incident> create(Incident i) async {
    final res = await _api.post('/incidents/create.php', i.toJson());
    return Incident.fromJson(res['incident']);
  }

  Future<Incident> update(Incident i) async {
    final res = await _api.post('/incidents/update.php', i.toJson());
    return Incident.fromJson(res['incident']);
  }
}
