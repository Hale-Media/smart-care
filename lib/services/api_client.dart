import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin HTTP client wrapping the PHP/MySQL backend.
/// Attaches the JWT bearer token to every request and centralises error
/// handling and JSON decoding.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final _storage = const FlutterSecureStorage();
  String? _cachedToken;

  Future<String?> _token() async {
    _cachedToken ??= await _storage.read(key: AppConfig.kAuthToken);
    return _cachedToken;
  }

  Future<void> setToken(String? token) async {
    _cachedToken = token;
    if (token == null) {
      await _storage.delete(key: AppConfig.kAuthToken);
    } else {
      await _storage.write(key: AppConfig.kAuthToken, value: token);
    }
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final t = await _token();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = '${AppConfig.apiBaseUrl}$path';
    if (query == null || query.isEmpty) return Uri.parse(base);
    final qp = query.map((k, v) => MapEntry(k, '$v'));
    return Uri.parse(base).replace(queryParameters: qp);
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? query, bool auth = true}) async {
    final res = await http
        .get(_uri(path, query), headers: await _headers(auth: auth))
        .timeout(AppConfig.httpTimeout);
    return _decode(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final res = await http
        .post(_uri(path),
            headers: await _headers(auth: auth), body: jsonEncode(body))
        .timeout(AppConfig.httpTimeout);
    return _decode(res);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http
        .put(_uri(path), headers: await _headers(), body: jsonEncode(body))
        .timeout(AppConfig.httpTimeout);
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http
        .delete(_uri(path), headers: await _headers())
        .timeout(AppConfig.httpTimeout);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = res.body;
      }
    }
    if (ok) return data;

    String msg = 'Request failed';
    if (data is Map) {
      if (data['message'] != null) {
        msg = data['message'].toString();
      } else if (data['error'] != null) {
        msg = data['error'].toString();
      } else if (data['errors'] is List) {
        msg = (data['errors'] as List).join(', ');
      }
      if (data['detail'] != null) {
        msg = '$msg — ${data['detail']}';
      }
    }
    throw ApiException(res.statusCode, msg);
  }
}
