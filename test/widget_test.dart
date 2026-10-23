import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lavadero_app/main.dart';
import 'package:lavadero_app/services/theme_service.dart';
import 'package:lavadero_app/theme/app_theme.dart';

void main() {
  setUp(() {
    // Sincroniza la paleta con el brillo del tema (lo hace main() en producción).
    AppColors.apply(Brightness.light);
    ThemeController.mode.value = ThemeMode.light;
    // Mock de preferencias para cualquier pantalla que consulte prefs.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Login muestra validaciones básicas', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MyApp());

    // Nota: no usamos pumpAndSettle porque WaterBackground/AnimatedLogo
    // tienen animaciones infinitas y nunca terminan de 'settle'.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // Login usa un delay escalonado (StaggeredFadeIn): avanzamos su animación.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Bienvenido'), findsOneWidget);

    // Intentar enviar vacío -> aparecen validaciones del Form.
    final loginButton = find.byType(ElevatedButton);
    expect(loginButton, findsOneWidget);

    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.text('Por favor ingresa tu email'), findsOneWidget);
    expect(find.textContaining('Por favor ingresa tu contrase'), findsOneWidget);

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
