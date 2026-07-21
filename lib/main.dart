import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'theme/app_theme.dart';
import 'services/http_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const _inactivityTimeout = Duration(minutes: 2);

void main() {
  HttpService().onUnauthorized = () {
    _inactivityTimer?.cancel();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  };
  runApp(const MyApp());
}

Timer? _inactivityTimer;

void _resetInactivityTimer() {
  _inactivityTimer?.cancel();
  if (HttpService().isAuthenticated) {
    _inactivityTimer = Timer(_inactivityTimeout, () {
      HttpService().onUnauthorized?.call();
    });
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _resetInactivityTimer(),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Car-Wash',
          theme: AppTheme.lightTheme,
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
