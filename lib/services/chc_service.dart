import '../models/chc_checklist.dart';
import 'api_client.dart';

class ChcService {
  final _api = ApiClient.instance;

  Future<List<ChcChecklist>> list(int residentId) async {
    final res = await _api.get('/chc.php', query: {'resident_id': residentId});
    return (res['checklists'] as List? ?? [])
        .map((e) => ChcChecklist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChcChecklist> getOne(int id) async {
    final res = await _api.get('/chc.php', query: {'id': id});
    return ChcChecklist.fromJson(res['checklist'] as Map<String, dynamic>);
  }

  Future<int> create({
    required int residentId,
    required Map<String, ChcDomain> domains,
    String? rationale,
    bool personInvolved = false,
    String? representativeName,
    bool representativeInvolved = false,
  }) async {
    final body = <String, dynamic>{
      'resident_id': residentId,
      'domains': domains.map((k, v) => MapEntry(k, v.toJson())),
      'person_involved': personInvolved,
      'representative_involved': representativeInvolved,
    };
    if (rationale != null && rationale.isNotEmpty) body['rationale'] = rationale;
    if (representativeName != null && representativeName.isNotEmpty) {
      body['representative_name'] = representativeName;
    }
    final res = await _api.post('/chc.php', body);
    return res['id'] as int;
  }

  Future<void> update(
    int id, {
    Map<String, ChcDomain>? domains,
    String? rationale,
    bool? personInvolved,
    String? representativeName,
    bool? representativeInvolved,
  }) async {
    final body = <String, dynamic>{};
    if (domains != null) body['domains'] = domains.map((k, v) => MapEntry(k, v.toJson()));
    if (rationale != null) body['rationale'] = rationale;
    if (personInvolved != null) body['person_involved'] = personInvolved;
    if (representativeName != null) body['representative_name'] = representativeName;
    if (representativeInvolved != null) body['representative_involved'] = representativeInvolved;
    await _api.put('/chc.php?id=$id', body);
  }

  Future<void> complete(
    int id, {
    String? assessorName,
    String? assessorRole,
    String? assessorOrg,
  }) async {
    final body = <String, dynamic>{};
    if (assessorName != null) body['assessor_name'] = assessorName;
    if (assessorRole != null) body['assessor_role'] = assessorRole;
    if (assessorOrg != null) body['assessor_org'] = assessorOrg;
    await _api.put('/chc.php?id=$id&action=complete', body);
  }

  Future<void> delete(int id) async {
    await _api.delete('/chc.php?id=$id');
  }

  Future<String> printHtml(int id) async {
    final res = await _api.get('/chc_print.php', query: {'id': id});
    return res as String;
  }
}
