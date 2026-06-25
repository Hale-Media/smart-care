import '../models/chc_checklist.dart';
import '../models/chc_summary.dart';
import 'api_client.dart';

class ChcService {
  final _api = ApiClient.instance;

  Future<ChcSummary> summary() async {
    final res = await _api.get('/chc.php');
    return ChcSummary.fromJson(res);
  }

  Future<List<ChcChecklist>> forResident(int residentId) async {
    final res = await _api.get('/chc.php', query: {'resident_id': residentId});
    return (res['checklists'] as List? ?? [])
        .map((e) => ChcChecklist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChcChecklist> getOne(int id) async {
    final res = await _api.get('/chc.php', query: {'id': id});
    return ChcChecklist.fromJson(res['checklist'] as Map<String, dynamic>);
  }

  Future<void> create({
    required int residentId,
    required Map<String, Map<String, String?>> domains,
    String? rationale,
    bool personInvolved = false,
    String? representativeName,
    bool representativeInvolved = false,
  }) =>
      _api.post('/chc.php', {
        'resident_id': residentId,
        'domains': domains,
        if (rationale != null && rationale.isNotEmpty) 'rationale': rationale,
        'person_involved': personInvolved,
        if (representativeName != null && representativeName.isNotEmpty)
          'representative_name': representativeName,
        'representative_involved': representativeInvolved,
      });

  Future<void> update(
    int id, {
    required Map<String, Map<String, String?>> domains,
    String? rationale,
    bool personInvolved = false,
    String? representativeName,
    bool representativeInvolved = false,
  }) =>
      _api.put('/chc.php?id=$id', {
        'domains': domains,
        if (rationale != null && rationale.isNotEmpty) 'rationale': rationale,
        'person_involved': personInvolved,
        if (representativeName != null && representativeName.isNotEmpty)
          'representative_name': representativeName,
        'representative_involved': representativeInvolved,
      });

  Future<void> complete(
    int id, {
    required String assessorName,
    String? assessorRole,
    String? assessorOrg,
  }) =>
      _api.put('/chc.php?id=$id&action=complete', {
        'assessor_name': assessorName,
        if (assessorRole != null && assessorRole.isNotEmpty)
          'assessor_role': assessorRole,
        if (assessorOrg != null && assessorOrg.isNotEmpty)
          'assessor_org': assessorOrg,
      });

  Future<void> delete(int id) => _api.delete('/chc.php?id=$id');
}
