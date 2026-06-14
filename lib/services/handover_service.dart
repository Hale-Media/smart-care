import '../models/handover_note.dart';
import 'api_client.dart';

class HandoverService {
  final _api = ApiClient.instance;

  Future<List<HandoverNote>> list({int limit = 20}) async {
    final res = await _api
        .get('/handover/list.php', query: {'limit': limit});
    final items = (res['notes'] as List? ?? []);
    return items.map((e) => HandoverNote.fromJson(e)).toList();
  }

  Future<HandoverNote> create(HandoverNote note) async {
    final res = await _api.post('/handover/create.php', note.toJson());
    return HandoverNote.fromJson(res['note']);
  }
}
