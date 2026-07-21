import '../config/api_config.dart';
import '../services/http_service.dart';

/// ✅ PaymentService refactorizado con HttpService centralizado
class PaymentService {
  static final HttpService _httpService = HttpService();

  // ✅ URLs centralizadas en ApiConfig
  static String get _paymentsEndpoint => '${ApiConfig.baseUrl}/api/payments';
  static String get _washStatusEndpoint =>
      '${ApiConfig.baseUrl}/api/cars/status';

  /// ✅ Obtiene la lista de pagos del usuario autenticado
  static Future<List<Map<String, dynamic>>> getPayments({
    String? carid,
    String? plate,
    String? status,
  }) async {
    try {
      await _httpService.loadToken();
      final queryParams = <String, String>{};
      if (carid != null && carid.isNotEmpty) queryParams['carid'] = carid;
      if (plate != null && plate.isNotEmpty) queryParams['plate'] = plate;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      // ✅ Construir URL con parámetros
      final uri = Uri.parse(_paymentsEndpoint).replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);

      // ✅ Usar HttpService en lugar de http directo
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
    } on HttpException catch (e) {
      throw Exception("Error al cargar pagos: ${e.message}");
    } catch (e) {
      throw Exception("Error inesperado al cargar pagos: $e");
    }
  }

  /// ✅ Crea un nuevo pago
  static Future<Map<String, dynamic>> createPayment({
    required String plate,
    required String method,
    required double amount,
    String status = "Pendiente",
    String? carid,
  }) async {
    try {
      await _httpService.loadToken();
      final body = {
        "plate": plate,
        "method": method,
        "amount": amount,
        "status": status,
        if (carid != null && carid.isNotEmpty) "carid": carid,
      };

      // ✅ Usar HttpService en lugar de http directo
      final data = await _httpService.post(_paymentsEndpoint, body);

      return Map<String, dynamic>.from(data);
    } on HttpException catch (e) {
      throw Exception("Error al registrar pago: ${e.message}");
    } catch (e) {
      throw Exception("Error inesperado al registrar pago: $e");
    }
  }

  /// ✅ Actualiza el estado (y opcionalmente el método) de un pago
  static Future<Map<String, dynamic>> updatePaymentStatus(
    String id,
    String status, {
    String? method,
  }) async {
    try {
      await _httpService.loadToken();
      final body = {"status": status};
      if (method != null) body["method"] = method;

      final data = await _httpService.put(
        '$_paymentsEndpoint/$id',
        body,
      );

      return Map<String, dynamic>.from(data);
    } on HttpException catch (e) {
      throw Exception("Error al actualizar pago: ${e.message}");
    } catch (e) {
      throw Exception("Error inesperado al actualizar pago: $e");
    }
  }

  /// ✅ Obtiene lavados de un usuario filtrados por estado
  static Future<List<Map<String, dynamic>>> getWashesByStatus({
    required String userId,
    String status = "Completado",
  }) async {
    try {
      await _httpService.loadToken();
      final uri = Uri.parse('$_washStatusEndpoint/$userId')
          .replace(queryParameters: {"status": status});

      // ✅ Usar HttpService en lugar de http directo
      final data = await _httpService.get(uri.toString());

      if (data is List) {
        return (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      final dataMap = data as Map<String, dynamic>?;
      if (dataMap?.containsKey('data') ?? false) {
        final carsList = dataMap!['data'];
        if (carsList is List) {
          return carsList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      if (dataMap?.containsKey('cars') ?? false) {
        final carsList = dataMap!['cars'];
        if (carsList is List) {
          return carsList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      return [];
    } on HttpException catch (e) {
      throw Exception(
          "Error al cargar lavados con estado $status: ${e.message}");
    } catch (e) {
      throw Exception("Error inesperado al cargar lavados: $e");
    }
  }
}
