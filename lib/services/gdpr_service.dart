import 'api_client.dart';

class GdprExport {
  final DateTime? generatedAt;
  final int residentId;
  final Map<String, dynamic> data;

  GdprExport({
    required this.generatedAt,
    required this.residentId,
    required this.data,
  });

  factory GdprExport.fromJson(Map<String, dynamic> json) => GdprExport(
    generatedAt: json['generated_at'] == null
        ? null
        : DateTime.tryParse('${json['generated_at']}'),
    residentId: json['resident_id'] as int? ?? 0,
    data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
  );
}

class GdprService {
  final _api = ApiClient.instance;

  Future<GdprExport> exportResident(int residentId) async {
    final res = await _api.get('/gdpr.php', query: {'resident_id': residentId});
    return GdprExport.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Map<String, dynamic>> restrict(int residentId) =>
      _action(residentId, 'restrict');

  Future<Map<String, dynamic>> unrestrict(int residentId) =>
      _action(residentId, 'unrestrict');

  Future<Map<String, dynamic>> erase(int residentId) =>
      _action(residentId, 'erase', {'confirm': true});

  Future<Map<String, dynamic>> _action(
    int residentId,
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    final res = await _api.post(
      '/gdpr.php?resident_id=$residentId&action=$action',
      body,
    );
    return Map<String, dynamic>.from(res as Map);
  }
}
