import 'package:lavadero_app/repositories/api_client.dart';

/// Cliente falso: registra las llamadas y responde con datos preparados.
class FakeApi implements ApiClient {
  final List<String> gets = [];
  final List<Map<String, dynamic>> posts = [];
  final Map<String, Map<String, dynamic>> responses = {};
  Object? error;

  Map<String, dynamic> _reply(String url) {
    if (error != null) throw error!;
    for (final entry in responses.entries) {
      if (url.startsWith(entry.key)) return entry.value;
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> get(String url) async {
    gets.add(url);
    return _reply(url);
  }

  @override
  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    posts.add({'url': url, 'body': body, 'key': idempotencyKey});
    return _reply(url);
  }

  @override
  Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body) async =>
      _reply(url);
}
