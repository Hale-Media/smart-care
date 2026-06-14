import '../models/home.dart';
import 'api_client.dart';

class HomeService {
  final _api = ApiClient.instance;

  Future<List<Home>> list() async {
    final res = await _api.get('/homes/list.php');
    final items = res['homes'] as List? ?? [];
    return items.map((e) => Home.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Home> create(String name, {String? address}) async {
    final body = <String, dynamic>{'name': name};
    if (address != null && address.isNotEmpty) body['address'] = address;
    final res = await _api.post('/homes/create.php', body);
    return Home.fromJson(res['home'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) =>
      _api.post('/homes/delete.php', {'id': id});
}
