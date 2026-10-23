import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http_service.dart';

/// Bloqueo de app con biometría/PIN del dispositivo.
///
/// - Cuando está activado, la app se bloquea al iniciarse **con sesión
///   iniciada** y al volver del segundo plano.
/// - Si el dispositivo no soporta biometría (o no hay credencial enrolada),
///   el bloqueo se desactiva solo y se notifica.
class AppLockController {
  static const String _enabledKey = 'biometricAuth';

  static final ValueNotifier<bool> locked = ValueNotifier(false);
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier(false);
  static bool _enabled = false;
  static bool _canUse = false;

  static final LocalAuthentication _auth = LocalAuthentication();

  static bool get isEnabled => enabledNotifier.value;

  static void _setEnabled(bool value) {
    _enabled = value;
    enabledNotifier.value = value;
  }
  static bool get canUseBiometrics => _canUse;

  /// Evalúa soporte del dispositivo y carga la preferencia.
  static Future<void> load() async {
    _enabled = (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      _canUse = supported && canCheck;
    } catch (_) {
      _canUse = false;
    }
    if (_enabled && !_canUse) {
      // El dispositivo ya no puede: desactiva el bloqueo para no encerrarse.
      await Future.wait([
        SharedPreferences.getInstance().then((p) => p.setBool(_enabledKey, false)),
      ]);
      _setEnabled(false);
    }
    if (_enabled) {
      // Bloquea solo si hay una sesión previa (no tiene sentido en el login).
      final userId = await HttpService().getUserId();
      if (userId != null && userId.isNotEmpty) {
        locked.value = true;
      }
    }
  }

  /// Activa el bloqueo pidiendo una verificación vía biometría/PIN.
  /// Devuelve true si quedó activado.
  static Future<bool> enable() async {
    if (!_canUse) return false;
    final ok = await _authenticate(
      'Activa el bloqueo con huella o PIN para proteger tu sesión',
    );
    if (!ok) return false;
    _setEnabled(true);
    locked.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    return true;
  }

  static Future<void> disable() async {
    _setEnabled(false);
    locked.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  /// Soporte real del dispositivo para biometría/PIN.
  static bool available() => _canUse;

  /// Bloquea la app (al iniciarse con sesión o al pasar a segundo plano).
  static void lock() {
    if (_enabled && HttpService().isAuthenticated) {
      locked.value = true;
    }
  }

  /// Pide biometría/PIN y desbloquea si sale bien.
  static Future<bool> authenticateToUnlock() async {
    if (!_enabled) {
      locked.value = false;
      return true;
    }
    final ok = await _authenticate('Desbloquea Lavadero App');
    if (ok) {
      locked.value = false;
    }
    return ok;
  }

  static Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // admite PIN/patrón del sistema como fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Extensión de ciclo de vida para bloquear al perder primer plano.
class AppLockLifecycle with WidgetsBindingObserver {
  static final AppLockLifecycle instance = AppLockLifecycle._();
  AppLockLifecycle._();

  Timer? _pauseDebounce;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Cancela el bloqueo si regresa enseguida (cambio de app rápido).
        _pauseDebounce?.cancel();
        _pauseDebounce = Timer(const Duration(seconds: 2), () {
          AppLockController.lock();
        });
        break;
      case AppLifecycleState.resumed:
        _pauseDebounce?.cancel();
        break;
    }
  }
}
