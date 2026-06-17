import '../models/staff_competency_record.dart';
import '../models/staff_competency_summary.dart';
import 'api_client.dart';

class StaffCompetencyService {
  final _api = ApiClient.instance;

  Future<List<StaffCompetencyRecord>> list(int staffId) async {
    final res = await _api.get(
      '/staff/competency/list.php',
      query: {'staff_id': staffId},
    );
    return (res['records'] as List? ?? [])
        .map((e) => StaffCompetencyRecord.fromJson(e))
        .toList();
  }

  Future<StaffCompetencyRecord> create(StaffCompetencyRecord record) async {
    final res = await _api.post(
      '/staff/competency/create.php',
      record.toJson(),
    );
    return StaffCompetencyRecord.fromJson(res['record']);
  }

  Future<void> delete(int id) async {
    await _api.post('/staff/competency/delete.php', {'id': id});
  }

  Future<List<StaffCompetencySummary>> overviewAll() async {
    final res = await _api.get('/staff/competency/summary.php');
    return (res['staff'] as List? ?? [])
        .map((e) => StaffCompetencySummary.fromJson(e))
        .toList();
  }
}
