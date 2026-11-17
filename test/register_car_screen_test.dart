import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lavadero_app/config/api_config.dart';
import 'package:lavadero_app/screens/register_car_screen.dart';
import 'package:lavadero_app/services/theme_service.dart';
import 'package:lavadero_app/theme/app_theme.dart';

import 'helpers/fake_api.dart';

Future<FakeApi> pumpScreen(WidgetTester tester, {int slots = 3}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final api = FakeApi()
    ..responses[ApiConfig.carsPricesUrl] = {
      'prices': {'Básico': 55000, 'Premium': 90000},
    }
    ..responses[ApiConfig.carsAvailabilityUrl] = {'available': slots};

  await tester.pumpWidget(MaterialApp(home: RegisterCarScreen(api: api)));
  // Las pantallas tienen animaciones infinitas: nada de pumpAndSettle.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
  return api;
}

void main() {
  setUp(() {
    AppColors.apply(Brightness.light);
    ThemeController.mode.value = ThemeMode.light;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('consulta precios y cupos al abrir y muestra los cupos del servidor',
      (tester) async {
    final api = await pumpScreen(tester, slots: 3);

    expect(api.gets.any((u) => u.startsWith(ApiConfig.carsPricesUrl)), isTrue);
    expect(
      api.gets.any((u) => u.startsWith(ApiConfig.carsAvailabilityUrl) && u.contains('?date=')),
      isTrue,
    );
    // Los cupos se muestran en el paso de agenda; el estado ya los tiene cargados.
    expect(find.text('Siguiente'), findsOneWidget);
  });

  testWidgets('sin datos, "Siguiente" muestra las tres validaciones', (tester) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.text('Siguiente'));
    await tester.tap(find.text('Siguiente'));
    await tester.pump();

    expect(find.text('Ingrese la placa'), findsOneWidget);
    expect(find.text('Ingrese el modelo'), findsOneWidget);
    expect(find.text('Ingrese la marca'), findsOneWidget);
  });

  testWidgets('con los datos completos avanza de paso', (tester) async {
    await pumpScreen(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ABC 123');
    await tester.enterText(fields.at(1), 'Corolla');
    await tester.enterText(fields.at(2), 'Toyota');

    await tester.ensureVisible(find.text('Siguiente'));
    await tester.tap(find.text('Siguiente'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Ingrese la placa'), findsNothing);
    // El paso 0 (campos de texto) ya no se muestra.
    expect(find.byType(TextFormField), findsNothing);
  });

  group('accesibilidad', () {
    testWidgets('los controles tienen tamaño de toque mínimo y etiqueta', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
