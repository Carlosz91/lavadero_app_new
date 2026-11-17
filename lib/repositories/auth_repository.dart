import '../config/api_config.dart';
import '../services/http_service.dart' show HttpException;
import 'api_client.dart';

/// Sesión devuelta por login, registro o Google.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.refreshToken,
    required this.userId,
    this.name,
    this.role,
  });

  final String token;
  final String refreshToken;
  final String userId;
  final String? name;
  final String? role;

  factory AuthSession.fromResponse(Map<String, dynamic> data) {
    final token = data['token'] as String?;
    final userId = data['userId'] as String?;
    if (token == null || token.isEmpty || userId == null) {
      throw HttpException('No se recibió el token de sesión');
    }
    final user = data['user'] as Map<String, dynamic>?;
    return AuthSession(
      token: token,
      refreshToken: data['refreshToken'] as String? ?? '',
      userId: userId,
      name: user?['name'] as String?,
      role: user?['role'] as String?,
    );
  }
}

/// Acceso a autenticación y gestión de contraseña.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Política de contraseña (misma que valida el backend).
  static final RegExp _passwordPolicy = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
  );

  static bool isValidPassword(String password) =>
      _passwordPolicy.hasMatch(password);

  Future<AuthSession> login(String email, String password) async =>
      AuthSession.fromResponse(await _api.post(
        ApiConfig.authLoginUrl,
        {'email': email, 'password': password},
      ));

  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
  }) async =>
      AuthSession.fromResponse(await _api.post(
        ApiConfig.authRegisterUrl,
        {'email': email, 'password': password, 'name': name},
      ));

  Future<AuthSession> googleLogin(String idToken) async =>
      AuthSession.fromResponse(
          await _api.post(ApiConfig.authGoogleUrl, {'idToken': idToken}));

  Future<void> forgotPassword(String email) async {
    await _api.post(ApiConfig.authForgotPasswordUrl, {'email': email});
  }

  /// Devuelve el mensaje del servidor (o uno por defecto).
  Future<String> resetPassword(String code, String newPassword) async {
    final response = await _api.post(ApiConfig.authResetPasswordUrl,
        {'resetToken': code, 'newPassword': newPassword});
    return response['message']?.toString() ?? 'Contraseña restablecida';
  }

  Future<void> changePassword(String current, String newPassword) async {
    await _api.put(ApiConfig.authChangePasswordUrl,
        {'currentPassword': current, 'newPassword': newPassword});
  }
}
