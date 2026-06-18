import '../models/risk_assessment.dart';
import 'api_client.dart';

class RiskAssessmentService {
  final _api = ApiClient.instance;

  Future<List<RiskAssessment>> activeAssessments(int residentId) async {
    final res = await _api.get(
      '/risk_assessments.php',
      query: {'resident_id': residentId},
    );
    final list = (res['assessments'] as List? ?? []);
    return list.map((e) => RiskAssessment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RiskAssessment>> assessmentHistory(int residentId, String type) async {
    final res = await _api.get(
      '/risk_assessments.php',
      query: {'resident_id': residentId, 'type': type, 'history': '1'},
    );
    final list = (res['history'] as List? ?? []);
    return list.map((e) => RiskAssessment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> create({
    required int residentId,
    required String type,
    required String riskLevel,
    int? totalScore,
    Map<String, dynamic>? detail,
    String? summary,
    String? toolVersion,
    String? reviewDue,
  }) async {
    final res = await _api.post('/risk_assessments.php', {
      'resident_id': residentId,
      'type': type,
      'risk_level': riskLevel,
      'total_score': totalScore,
      'detail': detail,
      'summary': summary,
      'tool_version': toolVersion,
      'review_due': reviewDue,
    });
    return res['id'] as int;
  }

  Future<int> reassess(int assessmentId, Map<String, dynamic> changes) async {
    final res = await _api.put('/risk_assessments.php?id=$assessmentId', changes);
    return res['id'] as int;
  }

  Future<void> delete(int assessmentId) async {
    await _api.delete('/risk_assessments.php?id=$assessmentId');
  }
}
