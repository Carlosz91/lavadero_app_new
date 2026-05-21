import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl =
      "http://10.0.2.2:5000/api/auth/login"; // Reemplaza con tu URL real

  // Método genérico para realizar solicitudes POST
  Future<Map<String, dynamic>> _postRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'error': 'Error ${response.statusCode}: ${response.reasonPhrase}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {'error': 'Error de conexión: $e', 'details': e.toString()};
    }
  }

  // Método para login
  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _postRequest('/auth/login', {
      'email': email,
      'password': password,
    });
  }
}
