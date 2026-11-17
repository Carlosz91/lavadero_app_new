import '../config/api_config.dart';
import '../services/http_service.dart' show HttpException;
import 'api_client.dart';
import 'payment_repository.dart';

/// Acceso a vehículos, precios y cupos.
class CarRepository {
  CarRepository(this._api) : _payments = PaymentRepository(_api);

  final ApiClient _api;
  final PaymentRepository _payments;

  /// Cupos por defecto cuando el servidor no responde.
  static const int defaultSlots = 5;

  /// 'YYYY-MM-DD' sin depender de la zona horaria del dispositivo.
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String timeKey(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Catálogo oficial de precios (nombre -> precio).
  Future<Map<String, double>> fetchPrices() async {
    final data = await _api.get(ApiConfig.carsPricesUrl);
    final raw = (data['prices'] as Map<String, dynamic>?) ?? {};
    return {
      for (final e in raw.entries)
        if (e.value is num) e.key: (e.value as num).toDouble(),
    };
  }

  /// Cupos libres para un día.
  Future<int> availableSlots(DateTime date) async {
    final data = await _api
        .get('${ApiConfig.carsAvailabilityUrl}?date=${dateKey(date)}');
    return data['available'] as int? ?? defaultSlots;
  }

  /// Registra un vehículo. Bloquea si el usuario tiene un pago pendiente
  /// (la regla también la aplica el backend; acá se avisa antes de enviar).
  Future<void> registerCar({
    required String plate,
    required String model,
    required String brand,
    required String? color,
    required String washType,
    required DateTime scheduledDate,
    required int scheduledHour,
    required int scheduledMinute,
    required String userId,
    required String idempotencyKey,
  }) async {
    if (await _payments.hasPending()) {
      throw HttpException(
          'Tenés un pago pendiente. Pagalo antes de registrar otro vehículo.');
    }
    await _api.post(
      ApiConfig.carsRegisterUrl,
      {
        'plate': plate.trim().toUpperCase(),
        'model': model.trim(),
        'brand': brand.trim(),
        'color': color,
        'washType': washType,
        'scheduledDate': dateKey(scheduledDate),
        'scheduledTime': timeKey(scheduledHour, scheduledMinute),
        'userId': userId,
      },
      idempotencyKey: idempotencyKey,
    );
  }

  /// Vehículos del usuario (el backend responde `data` o `cars`).
  Future<List<Map<String, dynamic>>> userCars(String userId) async {
    final data = await _api.get(ApiConfig.getCarsStatusUrl(userId));
    return List<Map<String, dynamic>>.from(data['data'] ?? data['cars'] ?? []);
  }
}
