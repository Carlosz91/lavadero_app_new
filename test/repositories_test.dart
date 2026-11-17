import 'package:flutter_test/flutter_test.dart';
import 'package:lavadero_app/config/api_config.dart';
import 'package:lavadero_app/repositories/api_client.dart';
import 'package:lavadero_app/repositories/auth_repository.dart';
import 'package:lavadero_app/repositories/car_repository.dart';
import 'package:lavadero_app/repositories/payment_repository.dart';
import 'package:lavadero_app/services/http_service.dart' show HttpException;

import 'helpers/fake_api.dart';

void main() {
  group('CarRepository', () {
    late FakeApi api;
    late CarRepository repo;
    setUp(() {
      api = FakeApi();
      repo = CarRepository(api);
    });

    test('dateKey/timeKey rellenan con ceros', () {
      expect(CarRepository.dateKey(DateTime(2030, 3, 5)), '2030-03-05');
      expect(CarRepository.timeKey(9, 5), '09:05');
    });

    test('fetchPrices ignora valores que no son numéricos', () async {
      api.responses[ApiConfig.carsPricesUrl] = {
        'prices': {'Básico': 50000, 'Premium': 80000.5, 'Raro': 'x'},
      };
      expect(await repo.fetchPrices(), {'Básico': 50000.0, 'Premium': 80000.5});
    });

    test('availableSlots consulta la fecha y usa el valor del servidor', () async {
      api.responses[ApiConfig.carsAvailabilityUrl] = {'available': 2};
      expect(await repo.availableSlots(DateTime(2030, 6, 15)), 2);
      expect(api.gets.single, endsWith('?date=2030-06-15'));
    });

    test('availableSlots sin dato usa el valor por defecto', () async {
      expect(await repo.availableSlots(DateTime(2030, 6, 15)),
          CarRepository.defaultSlots);
    });

    Future<void> register() => repo.registerCar(
          plate: ' abc-123 ',
          model: ' Civic ',
          brand: 'Honda ',
          color: 'Rojo',
          washType: 'Básico',
          scheduledDate: DateTime(2030, 6, 5),
          scheduledHour: 9,
          scheduledMinute: 5,
          userId: 'u1',
          idempotencyKey: 'key-1',
        );

    test('registerCar normaliza datos y reenvía la idempotency key', () async {
      api.responses[ApiConfig.paymentsUrl] = {'data': []};
      await register();

      final post = api.posts.single;
      expect(post['url'], ApiConfig.carsRegisterUrl);
      expect(post['key'], 'key-1');
      expect(post['body'], {
        'plate': 'ABC-123',
        'model': 'Civic',
        'brand': 'Honda',
        'color': 'Rojo',
        'washType': 'Básico',
        'scheduledDate': '2030-06-05',
        'scheduledTime': '09:05',
        'userId': 'u1',
      });
    });

    test('registerCar se bloquea con un pago pendiente y no envía nada', () async {
      api.responses[ApiConfig.paymentsUrl] = {
        'data': [
          {'id': 'p1'}
        ],
      };
      await expectLater(register(), throwsA(isA<HttpException>()));
      expect(api.posts, isEmpty);
    });

    test('userCars acepta las claves data y cars', () async {
      api.responses[ApiConfig.getCarsStatusUrl('u1')] = {
        'cars': [
          {'plate': 'A'}
        ],
      };
      expect(await repo.userCars('u1'), [
        {'plate': 'A'}
      ]);
    });
  });

  group('PaymentRepository', () {
    late FakeApi api;
    late PaymentRepository repo;
    setUp(() {
      api = FakeApi();
      repo = PaymentRepository(api);
    });

    test('parseList entiende lista directa, data y payments', () {
      final item = {'id': '1'};
      expect(PaymentRepository.parseList([item]), [item]);
      expect(PaymentRepository.parseList({'data': [item]}), [item]);
      expect(PaymentRepository.parseList({'payments': [item]}), [item]);
      expect(PaymentRepository.parseList({'otro': 1}), isEmpty);
    });

    test('getPayments agrega el filtro de estado a la URL', () async {
      api.responses[ApiConfig.paymentsUrl] = {'data': []};
      await repo.getPayments(status: 'Pendiente');
      await repo.getPayments();
      expect(api.gets[0], contains('status=Pendiente'));
      expect(api.gets[1], isNot(contains('status=')));
    });

    test('hasPending refleja si hay pagos pendientes', () async {
      api.responses[ApiConfig.paymentsUrl] = {'data': []};
      expect(await repo.hasPending(), isFalse);
      api.responses[ApiConfig.paymentsUrl] = {
        'data': [
          {'id': 'p'}
        ]
      };
      expect(await repo.hasPending(), isTrue);
    });

    test('startStripeCheckout envía solo el paymentId (nunca el monto)', () async {
      api.responses[ApiConfig.stripeCheckoutUrl] = {'url': 'https://stripe/x'};
      final url = await repo.startStripeCheckout('p1', idempotencyKey: 'k');

      expect(url, 'https://stripe/x');
      final post = api.posts.single;
      expect(post['body'], {'paymentId': 'p1'});
      expect(post['key'], 'k');
    });

    test('los errores del cliente se propagan', () async {
      api.error = HttpException('boom');
      await expectLater(repo.getPayments(), throwsA(isA<HttpException>()));
    });
  });

  group('AuthRepository', () {
    late FakeApi api;
    late AuthRepository repo;
    setUp(() {
      api = FakeApi();
      repo = AuthRepository(api);
    });

    final okResponse = {
      'token': 't',
      'refreshToken': 'r',
      'userId': 'u1',
      'user': {'name': 'Ana', 'role': 'admin'},
    };

    test('login devuelve la sesión completa', () async {
      api.responses[ApiConfig.authLoginUrl] = okResponse;
      final s = await repo.login('a@b.com', 'Pass1!aa');
      expect([s.token, s.refreshToken, s.userId, s.name, s.role],
          ['t', 'r', 'u1', 'Ana', 'admin']);
      expect(api.posts.single['body'], {'email': 'a@b.com', 'password': 'Pass1!aa'});
    });

    test('una respuesta sin token falla con mensaje claro', () async {
      api.responses[ApiConfig.authLoginUrl] = {'userId': 'u1'};
      await expectLater(repo.login('a@b.com', 'x'), throwsA(isA<HttpException>()));
    });

    test('register y googleLogin usan sus endpoints', () async {
      api.responses[ApiConfig.authRegisterUrl] = okResponse;
      api.responses[ApiConfig.authGoogleUrl] = okResponse;
      await repo.register(email: 'a@b.com', password: 'p', name: 'Ana');
      await repo.googleLogin('id-token');
      expect(api.posts[0]['url'], ApiConfig.authRegisterUrl);
      expect(api.posts[1]['body'], {'idToken': 'id-token'});
    });

    test('resetPassword devuelve el mensaje del servidor o uno por defecto', () async {
      api.responses[ApiConfig.authResetPasswordUrl] = {'message': 'Listo'};
      expect(await repo.resetPassword('123', 'Pass1!aa'), 'Listo');
      api.responses[ApiConfig.authResetPasswordUrl] = {};
      expect(await repo.resetPassword('123', 'Pass1!aa'), 'Contraseña restablecida');
    });

    test('forgotPassword envía solo el email', () async {
      await repo.forgotPassword('a@b.com');
      expect(api.posts.single['body'], {'email': 'a@b.com'});
    });

    test('política de contraseña: mayúscula, minúscula, número, símbolo y 8+', () {
      expect(AuthRepository.isValidPassword('Abcdef1!'), isTrue);
      for (final bad in ['abcdef1!', 'ABCDEF1!', 'Abcdefg!', 'Abcdefg1', 'Ab1!']) {
        expect(AuthRepository.isValidPassword(bad), isFalse, reason: bad);
      }
    });
  });

  test('newIdempotencyKey genera claves distintas', () {
    expect(newIdempotencyKey(), isNot(newIdempotencyKey()));
  });
}
