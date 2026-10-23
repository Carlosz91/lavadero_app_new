import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/lock_screen.dart';
import 'theme/app_theme.dart';
import 'services/http_service.dart';
import 'services/theme_service.dart';
import 'services/app_lock_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const _inactivityTimeout = Duration(minutes: 2);

Timer? _inactivityTimer;

void _resetInactivityTimer() {
  _inactivityTimer?.cancel();
  if (HttpService().isAuthenticated) {
    _inactivityTimer = Timer(_inactivityTimeout, () {
      HttpService().onUnauthorized?.call();
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ Sincroniza la paleta antes del primer frame para modo oscuro.
  await ThemeController.load();
  await AppLockController.load();
  AppLockLifecycle.instance.attach();

  HttpService().onUnauthorized = () {
    _inactivityTimer?.cancel();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppLockController.locked,
          builder: (context, locked, innerChild) {
            return Listener(
              // Reinicia el timer de inactividad con cualquier interacción.
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _resetInactivityTimer(),
              child: MaterialApp(
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                title: 'Car-Wash',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                builder: (context, nav) =>
                    locked ? const LockScreen() : nav ?? const SizedBox.shrink(),
                initialRoute: '/login',
                routes: {
                  '/login': (context) => const LoginScreen(),
                  '/register': (context) => const RegisterScreen(),
                },
              ),
            );
          },
        );
      },
    );
  }
}
