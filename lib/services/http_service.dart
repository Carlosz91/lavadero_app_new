import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// ✅ Servicio centralizado para requests HTTP.
///
/// - Token y refreshToken viven en FlutterSecureStorage (fuente de verdad)
///   y se mantienen en memoria para construir los headers.
/// - Ante un 401 se intenta renovar la sesión una sola vez con el refresh
///   token; si falla, se limpian credenciales y se navega al login.
class HttpService {
  static final HttpService _instance = HttpService._internal();

  factory HttpService() {
    return _instance;
  }

  HttpService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _authToken;
  String? _refreshToken;
  bool _wasAuthenticated = false;

  /// Evita bucles de renovación y saltos de login simultáneos.
  Future<bool>? _refreshInFlight;

  Function()? onUnauthorized;

  /// ✅ Guarda el par de tokens (login, register, Google).
  Future<void> saveAuthData(String token, String refreshToken) async {
    _authToken = token;
    _refreshToken = refreshToken;
    _wasAuthenticated = true;
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'refreshToken', value: refreshToken);
    await _migrateTokenFromPrefs();
  }

  /// El token en SharedPreferences es legacy: al cargarlo se migra a secure
  /// storage y se elimina del almacenamiento plano.
  Future<void> _migrateTokenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('token') != null) {
      await prefs.remove('token');
      await prefs.remove('refreshToken');
    }
  }

  /// ✅ Headers base con autenticación
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  /// ✅ GET request
  Future<Map<String, dynamic>> get(String url) async {
    return _request((headers) => http
        .get(Uri.parse(url), headers: headers)
        .timeout(ApiConfig.receiveTimeout));
  }

  /// ✅ POST request con soporte de idempotencia
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    return _request((headers) {
      final merged = Map<String, String>.of(headers);
      if (idempotencyKey != null) merged['Idempotency-Key'] = idempotencyKey;
      return http
          .post(Uri.parse(url), headers: merged, body: json.encode(body))
          .timeout(ApiConfig.receiveTimeout);
    });
  }

  /// ✅ PUT request
  Future<Map<String, dynamic>> put(
    String url,
    Map<String, dynamic> body,
  ) async {
    return _request((headers) => http
        .put(Uri.parse(url), headers: headers, body: json.encode(body))
        .timeout(ApiConfig.receiveTimeout));
  }

  /// Pipeline común: envía la petición, renueva token si expiró (una vez) y
  /// delega el mapping de respuesta.
  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    // Carga diferida: recupera el token si la app arrancó en caliente.
    if (_authToken == null && !_wasAuthenticated) {
      await loadToken();
    }

    try {
      var response = await send(_getHeaders());

      if (response.statusCode == 401) {
        final refreshed = await tryRefreshToken();
        if (refreshed) {
          response = await send(_getHeaders());
        }
      }

      return _handleResponse(response);
    } on HttpException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } on TimeoutException {
      throw HttpException('Tiempo de espera agotado. Verifica tu conexión');
    } catch (e) {
      throw HttpException('Error inesperado: $e');
    }
  }

  /// ✅ Intenta renovar la sesión con el refresh token.
  ///
  /// Devuelve true si la sesión fue renovada. Si no hay refresh token o la
  /// renovación falla, limpia las credenciales y dispara el logout global.
  Future<bool> tryRefreshToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final task = _doRefresh();
    _refreshInFlight = task;
    try {
      return await task;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _doRefresh() async {
    final refreshToken = _refreshToken ?? await _storage.read(key: 'refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) {
      await _handleSessionExpired();
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.authRefreshUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'refreshToken': refreshToken}),
          )
          .timeout(ApiConfig.receiveTimeout);

      if (response.statusCode != 200) {
        await _handleSessionExpired();
        return false;
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final newToken = decoded['token'] as String?;
      final newRefresh = decoded['refreshToken'] as String?;
      if (newToken == null || newToken.isEmpty) {
        await _handleSessionExpired();
        return false;
      }

      _refreshToken = newRefresh;
      _authToken = newToken;
      await _storage.write(key: 'token', value: newToken);
      if (newRefresh != null) {
        await _storage.write(key: 'refreshToken', value: newRefresh);
      }
      return true;
    } catch (_) {
      // Red fallida al renovar: no cerramos sesión de golpe si había una
      // sesión previa válida; la próxima petición lo volverá a intentar.
      return false;
    }
  }

  Future<void> _handleSessionExpired() async {
    await clearAuth();
    if (_wasAuthenticated) {
      _wasAuthenticated = false;
      onUnauthorized?.call();
    }
  }

  /// ✅ Manejo centralizado de respuestas
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    try {
      final decoded = json.decode(response.body) as Map<String, dynamic>;

      switch (response.statusCode) {
        case 200:
        case 201:
          return decoded;

        case 400:
          throw HttpException(
            decoded['error'] ?? 'Solicitud inválida',
          );

        case 401:
          await _handleSessionExpired();
          throw UnauthorizedException(
            decoded['error'] ?? 'Sesión expirada',
          );

        case 403:
          throw HttpException(
            decoded['error'] ?? 'No tienes permisos para esta acción',
          );

        case 404:
          throw HttpException(
            decoded['error'] ?? 'Recurso no encontrado',
          );

        case 500:
          throw HttpException(decoded['error'] ?? 'Error del servidor');

        default:
          throw HttpException(
            'Error ${response.statusCode}: ${decoded['error'] ?? 'Desconocido'}',
          );
      }
    } catch (e) {
      if (e is HttpException || e is UnauthorizedException) {
        rethrow;
      }
      throw HttpException('Error al procesar respuesta: $e');
    }
  }

  /// ✅ Carga el token desde secure storage (migra desde prefs si hace falta).
  Future<void> loadToken() async {
    if (_authToken != null) return;
    _authToken = await _storage.read(key: 'token');
    _refreshToken = await _storage.read(key: 'refreshToken');
    if (_authToken != null && _authToken!.isNotEmpty) {
      _wasAuthenticated = true;
      await _migrateTokenFromPrefs();
    }
  }

  /// ✅ Guardar userId en almacenamiento seguro
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: 'userId', value: userId);
  }

  /// ✅ Leer userId desde almacenamiento seguro (con fallback a prefs)
  Future<String?> getUserId() async {
    String? userId = await _storage.read(key: 'userId');
    if (userId == null || userId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('userId');
      if (userId != null) {
        await _storage.write(key: 'userId', value: userId);
      }
    }
    return userId;
  }

  /// ✅ Limpiar credenciales (logout + manejo de 401 definitivo)
  Future<void> clearAuth() async {
    _authToken = null;
    _refreshToken = null;
    _wasAuthenticated = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('role');
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'refreshToken');
  }

  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;
}

/// ✅ Excepciones personalizadas
class HttpException implements Exception {
  final String message;
  HttpException(this.message);

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => message;
}
