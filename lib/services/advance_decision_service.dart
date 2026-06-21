// ignore_for_file: use_null_aware_elements

import '../models/advance_decision.dart';
import 'api_client.dart';

class AdvanceDecisionService {
  final _api = ApiClient.instance;

  Future<List<AdvanceDecision>> forResident(int residentId) async {
    final res = await _api.get(
      '/advance_decisions.php',
      query: {'resident_id': residentId},
    );
    return (res['advance_decisions'] as List? ?? [])
        .map((e) => AdvanceDecision.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> create({
    required int residentId,
    required String type,
    bool inPlace = true,
    String? formReference,
    String? completedBy,
    String? dateCompleted,
    String? reviewDate,
    String? location,
    String? notes,
  }) async {
    final res = await _api.post('/advance_decisions.php', {
      'resident_id': residentId,
      'type': type,
      'in_place': inPlace,
      if (formReference != null && formReference.isNotEmpty)
        'form_reference': formReference,
      if (completedBy != null && completedBy.isNotEmpty)
        'completed_by': completedBy,
      if (dateCompleted != null) 'date_completed': dateCompleted,
      if (reviewDate != null) 'review_date': reviewDate,
      if (location != null && location.isNotEmpty) 'location': location,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res['id'] as int;
  }

  Future<void> update(int id, Map<String, dynamic> changes) async {
    await _api.put('/advance_decisions.php?id=$id', changes);
  }

  Future<void> delete(int id) async {
    await _api.delete('/advance_decisions.php?id=$id');
  }
}
