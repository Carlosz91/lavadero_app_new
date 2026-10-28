import 'package:flutter/foundation.dart';

/// Configuración centralizada para la API
class ApiConfig {
  /// URL forzada por `--dart-define=API_BASE_URL=...`. Si está vacía se usa
  /// el default según el modo de compilación.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// ✅ Base URL del backend.
  ///
  /// - Release/Profile: producción en Railway.
  /// - Debug en Android: `10.0.2.2` (alias del host en el emulador).
  /// - Debug en el resto (Windows, web, iOS sim): `localhost`.
  ///
  /// Para apuntar a otro entorno usar:
  /// `flutter run --dart-define=API_BASE_URL=https://mi-servidor`
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (!kDebugMode) return 'https://lavaderoappnew-production.up.railway.app';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  // ✅ Timeouts
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // ✅ Auth
  static const String authLogin = '/api/auth/login';
  static const String authRegister = '/api/auth/register';
  static const String authGoogle = '/api/auth/google';
  static const String authRefresh = '/api/auth/refresh';
  static const String authForgotPassword = '/api/auth/forgot-password';
  static const String authResetPassword = '/api/auth/reset-password';
  static const String authChangePassword = '/api/auth/change-password';

  // ✅ Google Sign-In: serverClientId configurable por --dart-define
  // ⚠️ Debe ser el client de tipo **Web** (no el Android, que solo existe para
  // emparejar package + SHA-1 en la consola de Google Cloud).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '768691636599-hfor0s68b39vot0epefpnaio8dplv51u.apps.googleusercontent.com',
  );

  // ✅ Cars
  static const String carsStatus = '/api/cars/status';
  static const String carsRegister = '/api/cars/registercar';
  static const String carsAvailability = '/api/cars/availability';
  static const String carsPrices = '/api/cars/prices';

  // ✅ Payments y Stripe
  static const String payments = '/api/payments';
  static const String stripeCheckoutSession = '/api/stripe/create-checkout-session';

  // ✅ Refresh interval
  static const Duration refreshInterval = Duration(seconds: 20);

  // ✅ Métodos helper
  static String getCarsStatusUrl(String userId) {
    if (userId.isEmpty) throw ArgumentError('userId no puede estar vacío');
    return '$baseUrl$carsStatus/$userId';
  }

  static String get authLoginUrl => '$baseUrl$authLogin';
  static String get authRegisterUrl => '$baseUrl$authRegister';
  static String get authGoogleUrl => '$baseUrl$authGoogle';
  static String get authRefreshUrl => '$baseUrl$authRefresh';
  static String get authForgotPasswordUrl => '$baseUrl$authForgotPassword';
  static String get authResetPasswordUrl => '$baseUrl$authResetPassword';
  static String get authChangePasswordUrl => '$baseUrl$authChangePassword';
  static String get paymentsUrl => '$baseUrl$payments';
  static String get stripeCheckoutUrl => '$baseUrl$stripeCheckoutSession';
  static String get carsPricesUrl => '$baseUrl$carsPrices';
  static String get carsRegisterUrl => '$baseUrl$carsRegister';
  static String get carsAvailabilityUrl => '$baseUrl$carsAvailability';
}
