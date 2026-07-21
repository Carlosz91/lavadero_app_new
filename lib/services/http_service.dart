import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// ✅ Servicio centralizado para requests HTTP
class HttpService {
  static final HttpService _instance = HttpService._internal();

  factory HttpService() {
    return _instance;
  }

  HttpService._internal();

  String? _authToken;

  Function()? onUnauthorized;

  Future<void> _clearAuth() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'token');
    await storage.delete(key: 'refreshToken');
  }

  /// ✅ Setter para guardar token JWT
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// ✅ Getter para verificar autenticación
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

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

  /// ✅ GET request con manejo de errores mejorado
  Future<Map<String, dynamic>> get(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: _getHeaders(),
          )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } on http.ClientException {
      throw HttpException('Error de conexión. Verifica tu internet');
    } catch (e) {
      throw HttpException('Error inesperado: $e');
    }
  }

  /// ✅ POST request
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _getHeaders(),
            body: json.encode(body),
          )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } on HttpException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw HttpException('$e');
    }
  }

  /// ✅ PUT request
  Future<Map<String, dynamic>> put(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: _getHeaders(),
            body: json.encode(body),
          )
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } on HttpException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw HttpException('$e');
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
          await _clearAuth();
          onUnauthorized?.call();
          throw UnauthorizedException(
            decoded['error'] ?? 'Sesión expirada',
          );

        case 403:
          throw HttpException('No tienes permisos para esta acción');

        case 404:
          throw HttpException(
            decoded['error'] ?? 'Recurso no encontrado',
          );

        case 500:
          throw HttpException('Error del servidor');

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

  /// ✅ Cargar token desde SharedPreferences
  Future<void> loadToken() async {
    if (_authToken != null) return;
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('token');
  }

  /// ✅ Limpiar token (logout)
  void clearAuth() {
    _authToken = null;
  }
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
