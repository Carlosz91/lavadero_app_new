/// Mensajes de error orientados al usuario final.
///
/// La app nunca debe mostrar detalles técnicos (SocketException,
/// ClientException, stack traces, códigos de error). Este catálogo centraliza
/// el texto que ve el cliente y la clasificación de los fallos de red.
class AppErrorMessages {
  AppErrorMessages._();

  static const String noConnection =
      'No pudimos conectar con el servidor. Revisa tu conexión a internet e inténtalo de nuevo.';

  static const String timeout =
      'La conexión está tardando demasiado. Revisa tu internet e inténtalo otra vez.';

  static const String hostNotFound =
      'No pudimos encontrar el servidor. Verifica tu conexión e inténtalo de nuevo.';

  static const String serverUnavailable =
      'El servidor no está disponible en este momento. Inténtalo en unos minutos.';

  static const String tooManyRequests =
      'Demasiados intentos. Espera unos segundos e inténtalo de nuevo.';

  static const String unexpected =
      'Ocurrió un problema inesperado. Inténtalo de nuevo.';

  /// Convierte el detalle técnico de un fallo de red en un mensaje entendible.
  static String forNetworkDetail(String detail) {
    final d = detail.toLowerCase();

    if (d.contains('timed out') || d.contains('timeout')) {
      return timeout;
    }

    if (d.contains('failed host lookup') ||
        d.contains('host lookup') ||
        d.contains('name or service not known') ||
        d.contains('nodename nor servname')) {
      return hostNotFound;
    }

    if (d.contains('certificate') || d.contains('handshake')) {
      return serverUnavailable;
    }

    return noConnection;
  }

  /// Extrae el mensaje funcional de una respuesta de error del backend.
  ///
  /// Si viene `details` (errores de validación campo por campo), se muestran
  /// todos para que el usuario sepa exactamente qué corregir. Ejemplo:
  /// `{"error":"Validación fallida","details":[{"message":"Email inválido"}]}`
  static String? serverMessage(Map<String, dynamic> body) {
    final details = body['details'];
    if (details is List && details.isNotEmpty) {
      final messages = details
          .whereType<Map>()
          .map((detail) => detail['message']?.toString().trim())
          .whereType<String>()
          .where((message) => message.isNotEmpty)
          .toList();

      if (messages.length == 1) return messages.first;
      if (messages.isNotEmpty) return messages.join('\n');
    }

    final error = body['error']?.toString().trim();
    return (error == null || error.isEmpty) ? null : error;
  }

  /// Detecta si un error desconocido es en realidad un fallo de red, para no
  /// mostrar el detalle técnico cuando la excepción no viene tipada.
  static bool looksLikeNetworkError(String raw) {
    final d = raw.toLowerCase();

    return d.contains('socketexception') ||
        d.contains('clientexception') ||
        d.contains('network is unreachable') ||
        d.contains('network unreachable') ||
        d.contains('no route to host') ||
        d.contains('connection refused') ||
        d.contains('connection reset') ||
        d.contains('connection closed') ||
        d.contains('failed host lookup') ||
        d.contains('host lookup') ||
        d.contains('xmlhttprequest error') ||
        d.contains('failed to fetch') ||
        d.contains('handshake') ||
        d.contains('timed out');
  }
}
