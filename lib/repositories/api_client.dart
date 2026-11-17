import 'dart:math';

/// Contrato mínimo del cliente HTTP. Los repositorios dependen de esta interfaz
/// (no de `HttpService` directamente) para poder probarse con un cliente falso.
abstract class ApiClient {
  Future<Map<String, dynamic>> get(String url);

  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  });

  Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body);
}

/// Clave de idempotencia nueva: una por intento del usuario, reutilizada en los
/// reintentos automáticos de ese mismo intento.
String newIdempotencyKey() {
  final random = Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$timestamp-${random.nextInt(999999)}-${random.nextInt(999999)}';
}
