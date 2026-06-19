// ignore_for_file: use_null_aware_elements

import '../models/capacity_assessment.dart';
import 'api_client.dart';

class CapacityAssessmentService {
  final _api = ApiClient.instance;

  Future<List<CapacityAssessment>> activeAssessments(int residentId) async {
    final res = await _api.get(
      '/capacity_assessments.php',
      query: {'resident_id': residentId},
    );
    return (res['assessments'] as List? ?? [])
        .map((e) => CapacityAssessment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CapacityAssessment>> history(
    int residentId,
    String decision,
  ) async {
    final res = await _api.get(
      '/capacity_assessments.php',
      query: {'resident_id': residentId, 'decision': decision, 'history': 1},
    );
    return (res['history'] as List? ?? [])
        .map((e) => CapacityAssessment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> create({
    required int residentId,
    required String decision,
    required bool hasCapacity,
    String? assessmentSummary,
    String? bestInterests,
    String? reviewDue,
  }) async {
    final res = await _api.post('/capacity_assessments.php', {
      'resident_id': residentId,
      'decision': decision,
      'has_capacity': hasCapacity,
      if (assessmentSummary != null && assessmentSummary.isNotEmpty)
        'assessment_summary': assessmentSummary,
      if (bestInterests != null && bestInterests.isNotEmpty)
        'best_interests': bestInterests,
      if (reviewDue != null) 'review_due': reviewDue,
    });
    return res['id'] as int;
  }

  Future<int> reassess(
    int id, {
    required bool hasCapacity,
    String? assessmentSummary,
    String? bestInterests,
    String? reviewDue,
  }) async {
    final res = await _api.put('/capacity_assessments.php?id=$id', {
      'has_capacity': hasCapacity,
      if (assessmentSummary != null) 'assessment_summary': assessmentSummary,
      if (bestInterests != null) 'best_interests': bestInterests,
      if (reviewDue != null) 'review_due': reviewDue,
    });
    return res['id'] as int;
  }

  Future<void> delete(int id) async {
    await _api.delete('/capacity_assessments.php?id=$id');
  }
}
