import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../utils/app_error.dart';

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
      throw NetworkException(AppErrorMessages.timeout);
    } on http.ClientException catch (error) {
      debugPrint('HttpService: fallo de red: $error');
      throw NetworkException(AppErrorMessages.forNetworkDetail(error.message));
    } catch (error) {
      debugPrint('HttpService: error inesperado: $error');
      final raw = error.toString();
      if (AppErrorMessages.looksLikeNetworkError(raw)) {
        throw NetworkException(AppErrorMessages.forNetworkDetail(raw));
      }
      throw HttpException(AppErrorMessages.unexpected);
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

  /// ✅ Manejo centralizado de respuestas.
  ///
  /// Los mensajes del backend se muestran solo en errores 4xx (son mensajes
  /// funcionales). Para 5xx se usa un texto genérico para no exponer detalles
  /// internos del servidor.
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final status = response.statusCode;
    final decoded = _decodeBody(response.body);
    final serverMessage = AppErrorMessages.serverMessage(decoded);

    if (status >= 200 && status < 300) {
      return decoded;
    }

    switch (status) {
      case 400:
        throw HttpException(
          serverMessage ?? 'Revisa los datos ingresados e inténtalo de nuevo.',
        );

      case 401:
        await _handleSessionExpired();
        throw UnauthorizedException(
          serverMessage ?? 'Tu sesión expiró. Inicia sesión de nuevo.',
        );

      case 403:
        throw HttpException(
          serverMessage ?? 'No tienes permisos para realizar esta acción.',
        );

      case 404:
        throw HttpException(serverMessage ?? 'No encontramos lo que buscabas.');

      case 409:
        throw HttpException(
          serverMessage ??
              'La operación no se pudo completar. Inténtalo de nuevo.',
        );

      case 429:
        throw HttpException(serverMessage ?? AppErrorMessages.tooManyRequests);

      default:
        if (status >= 500) {
          throw HttpException(AppErrorMessages.serverUnavailable);
        }
        throw HttpException(serverMessage ?? AppErrorMessages.unexpected);
    }
  }

  /// Intenta decodificar el cuerpo como JSON. Si viene vacío, es HTML o texto
  /// plano (por ejemplo un 502 del proxy), devuelve un mapa vacío.
  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return const {};

    try {
      final decoded = json.decode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
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

/// Fallo de conectividad (sin red, DNS, timeout, servidor caído).
/// Permite a las pantallas distinguirlo de un error funcional del backend.
class NetworkException extends HttpException {
  NetworkException(super.message);
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => message;
}

/// Traduce cualquier error a un mensaje apto para el usuario final.
///
/// Úsalo en los `catch` genéricos de las pantallas para no filtrar nunca
/// excepciones técnicas al cliente.
String friendlyErrorMessage(Object error) {
  if (error is HttpException) return error.message;
  if (error is UnauthorizedException) return error.message;
  if (error is TimeoutException) return AppErrorMessages.timeout;
  if (error is http.ClientException) {
    return AppErrorMessages.forNetworkDetail(error.message);
  }

  final raw = error.toString();
  if (AppErrorMessages.looksLikeNetworkError(raw)) {
    return AppErrorMessages.forNetworkDetail(raw);
  }
  return AppErrorMessages.unexpected;
}
