import '../config/api_config.dart';
import 'api_client.dart';

/// Acceso a pagos y checkout de Stripe.
class PaymentRepository {
  PaymentRepository(this._api);

  final ApiClient _api;

  /// Pagos del usuario autenticado. Acepta las formas de respuesta del backend:
  /// lista directa, `{data: [...]}` o `{payments: [...]}`.
  Future<List<Map<String, dynamic>>> getPayments({String? status}) async {
    final uri = Uri.parse(ApiConfig.paymentsUrl).replace(
      queryParameters:
          (status != null && status.isNotEmpty) ? {'status': status} : null,
    );
    final data = await _api.get(uri.toString());
    return parseList(data);
  }

  /// ¿Tiene el usuario algún pago pendiente?
  Future<bool> hasPending() async =>
      (await getPayments(status: 'Pendiente')).isNotEmpty;

  /// Crea la sesión de checkout y devuelve la URL de Stripe. El monto NUNCA
  /// viaja desde el cliente: el backend usa el pago guardado.
  Future<String?> startStripeCheckout(
    String paymentId, {
    required String idempotencyKey,
  }) async {
    final response = await _api.post(
      ApiConfig.stripeCheckoutUrl,
      {'paymentId': paymentId},
      idempotencyKey: idempotencyKey,
    );
    return response['url'] as String?;
  }

  static List<Map<String, dynamic>> parseList(dynamic data) {
    dynamic source = data;
    if (data is Map) source = data['data'] ?? data['payments'];
    if (source is! List) return [];
    return source.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
