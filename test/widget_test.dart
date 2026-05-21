import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lavadero_app/main.dart';

void main() {
  testWidgets('Login muestra validaciones básicas',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Bienvenido'), findsOneWidget);

    // Intentar enviar vacío -> aparecen validaciones del Form.
    final loginButton = find.byType(ElevatedButton);
    expect(loginButton, findsOneWidget);

    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('Por favor ingresa tu email'), findsOneWidget);
    expect(
      find.textContaining('Por favor ingresa tu contrase'),
      findsOneWidget,
    );

    // Email inválido + password corta -> validaciones específicas.
    final emailField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    await tester.enterText(emailField, 'invalido');
    await tester.enterText(passwordField, '123');

    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.textContaining('Ingresa un email'), findsOneWidget);
    expect(find.textContaining('al menos 6'), findsOneWidget);
  });
}
