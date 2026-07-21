/// Configuración centralizada para la API
class ApiConfig {
  // ✅ Base URL configurable por ambiente
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000', // Emulador Android
  );

  // ✅ Timeouts
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // ✅ Endpoints
  static const String carsStatus = '/api/cars/status';
  static const String carsRegister = '/api/cars/registercar';
  static const String carsAvailability = '/api/cars/availability';
  static const String authLogin = '/api/auth/login';
  static const String authRegister = '/api/auth/register';
  static const String authRefresh = '/api/auth/refresh';

  // ✅ Refresh interval
  static const Duration refreshInterval = Duration(seconds: 20);

  // ✅ Métodos helper
  static String getCarsStatusUrl(String userId) {
    if (userId.isEmpty) throw ArgumentError('userId no puede estar vacío');
    return '$baseUrl$carsStatus/$userId';
  }
}
