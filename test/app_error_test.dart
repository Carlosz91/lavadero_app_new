import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:lavadero_app/services/http_service.dart';
import 'package:lavadero_app/utils/app_error.dart';

void main() {
  group('AppErrorMessages.forNetworkDetail', () {
    test('red inalcanzable se traduce a mensaje de conexión', () {
      expect(
        AppErrorMessages.forNetworkDetail(
          'SocketException: Network is unreachable '
          '(OS Error: Network is unreachable, errno = 1001)',
        ),
        AppErrorMessages.noConnection,
      );
    });

    test('DNS no resuelto se traduce a servidor no encontrado', () {
      expect(
        AppErrorMessages.forNetworkDetail('Failed host lookup: ejemplo.com'),
        AppErrorMessages.hostNotFound,
      );
    });

    test('timeout se traduce a mensaje de demora', () {
      expect(
        AppErrorMessages.forNetworkDetail('Connection timed out'),
        AppErrorMessages.timeout,
      );
    });

    test('conexión rechazada se traduce a mensaje de conexión', () {
      expect(
        AppErrorMessages.forNetworkDetail('Connection refused'),
        AppErrorMessages.noConnection,
      );
    });

    test('handshake/certificado se traduce a servidor no disponible', () {
      expect(
        AppErrorMessages.forNetworkDetail('Handshake error in client'),
        AppErrorMessages.serverUnavailable,
      );
    });
  });

  group('AppErrorMessages.looksLikeNetworkError', () {
    test('detecta excepciones de red', () {
      expect(
        AppErrorMessages.looksLikeNetworkError(
          'ClientException with SocketException: Network is unreachable',
        ),
        isTrue,
      );
      expect(
        AppErrorMessages.looksLikeNetworkError('XMLHttpRequest error.'),
        isTrue,
      );
    });

    test('no confunde errores funcionales del backend', () {
      expect(
        AppErrorMessages.looksLikeNetworkError('El correo ya está registrado'),
        isFalse,
      );
      expect(
        AppErrorMessages.looksLikeNetworkError('Contraseña incorrecta'),
        isFalse,
      );
    });
  });

  group('AppErrorMessages.serverMessage', () {
    test('muestra todos los detalles de validación del backend', () {
      final body = {
        'error': 'Validación fallida',
        'details': [
          {'message': 'Email inválido'},
          {'message': 'Contraseña mínimo 8 caracteres'},
        ],
      };

      expect(
        AppErrorMessages.serverMessage(body),
        'Email inválido\nContraseña mínimo 8 caracteres',
      );
    });

    test('usa el campo error cuando no hay detalles', () {
      expect(
        AppErrorMessages.serverMessage({'error': 'El correo ya está registrado'}),
        'El correo ya está registrado',
      );
    });

    test('devuelve null si no hay mensaje útil', () {
      expect(AppErrorMessages.serverMessage({}), isNull);
      expect(AppErrorMessages.serverMessage({'error': '   '}), isNull);
    });
  });

  group('friendlyErrorMessage', () {
    test('respeta el mensaje funcional de HttpException', () {
      expect(
        friendlyErrorMessage(HttpException('El correo ya está registrado')),
        'El correo ya está registrado',
      );
    });

    test('traduce ClientException sin filtrar detalles técnicos', () {
      final message = friendlyErrorMessage(
        http.ClientException(
          'SocketException: Network is unreachable (OS Error: errno = 1001)',
        ),
      );

      expect(message, AppErrorMessages.noConnection);
      expect(message.contains('SocketException'), isFalse);
      expect(message.contains('errno'), isFalse);
    });

    test('un error desconocido no expone su detalle', () {
      final message = friendlyErrorMessage(StateError('internal detail'));

      expect(message, AppErrorMessages.unexpected);
      expect(message.contains('internal detail'), isFalse);
    });
  });
}
