import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_lock_service.dart';
import '../services/theme_service.dart';

/// Pantalla de bloqueo biométrico. Se muestra como overlay cuando
/// AppLockController.locked es true (arranque con sesión o regreso desde
/// segundo plano). No admite navegación atrás: se sale autenticando.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _busy = false;
  String _error = '';

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final ok = await AppLockController.authenticateToUnlock();
      if (mounted && !ok) {
        setState(() => _error = 'No se pudo verificar. Intenta de nuevo');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ThemeController.isDark.value
                  ? [const Color(0xFF0B1421), const Color(0xFF15283C)]
                  : [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'App bloqueada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Verifica tu identidad con huella facial o PIN para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                    ),
                  ),
                _busy
                    ? const Column(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Verificando...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      )
                    : FilledButton.icon(
                        onPressed: _unlock,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Desbloquear'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
