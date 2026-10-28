import '../config/api_config.dart';
import '../services/http_service.dart';

/// ✅ Servicio de pagos. Actualiza la lista del usuario autenticado.
class PaymentService {
  static final HttpService _httpService = HttpService();

  /// ✅ Obtiene la lista de pagos del usuario autenticado (paginated del backend)
  static Future<List<Map<String, dynamic>>> getPayments({
    String? status,
  }) async {
    try {
      await _httpService.loadToken();
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final uri = Uri.parse(ApiConfig.paymentsUrl).replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final data = await _httpService.get(uri.toString());

      if (data is List) {
        return (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      final dataMap = data as Map<String, dynamic>?;
      if (dataMap != null) {
        final source = dataMap['data'] ?? dataMap['payments'];
        if (source is List) {
          return source
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      return [];
    } catch (e) {
      throw HttpException(friendlyErrorMessage(e));
    }
  }
}
