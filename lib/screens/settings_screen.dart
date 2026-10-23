import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../services/theme_service.dart';
import '../services/app_lock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import 'login_screen.dart';
import 'about_screen.dart';

/// Página embebible de ajustes. Sin Scaffold ni AppBar: vive en la barra
/// inferior del shell; su contenido es una card de usuario + secciones.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isLoading = false;
  String _userEmail = '';
  String _userName = '';

  final HttpService _httpService = HttpService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userEmail = prefs.getString('userEmail') ?? '';
      _userName = prefs.getString('userName') ?? '';
    });
  }

  // ── Bloqueo biométrico ──

  Future<void> _toggleAppLock(bool enable) async {
    if (enable) {
      if (!AppLockController.available()) {
        AppSnackBar.error(
          context,
          'Tu dispositivo no soporta huella, rostro o credenciales de pantalla de bloqueo',
        );
        return;
      }
      // Medir por primera vez: la biometría de confirmación es real.
      final ok = await AppLockController.enable();
      if (!ok) {
        if (!mounted) return;
        AppSnackBar.error(context, 'Verificación cancelada. Se mantiene desactivado');
      }
    } else {
      await AppLockController.disable();
    }
  }

  // ── Cambio de contraseña ──

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cambiar contraseña', style: AppTextStyles.h3),
              const SizedBox(height: 6),
              Text(
                'Mínimo 8 caracteres, con mayúscula, minúscula, número y símbolo (@\$!%*?&).',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar'),
                  onPressed: () async {
                    final current = currentController.text;
                    final newPassword = newController.text;
                    final confirm = confirmController.text;

                    final navigator = Navigator.of(sheetContext);
                    final messenger = ScaffoldMessenger.of(context);
                    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Completa los tres campos'),
                        backgroundColor: AppColors.error,
                      ));
                      return;
                    }
                    if (newPassword != confirm) {
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Las contraseñas no coinciden'),
                        backgroundColor: AppColors.error,
                      ));
                      return;
                    }
                    final passwordRegex = RegExp(
                      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
                    );
                    if (!passwordRegex.hasMatch(newPassword)) {
                      messenger.showSnackBar(const SnackBar(
                        content: Text('La contraseña no cumple la política requerida'),
                        backgroundColor: AppColors.error,
                      ));
                      return;
                    }

                    try {
                      await _httpService.loadToken();
                      await _httpService.put(
                        ApiConfig.authChangePasswordUrl,
                        {
                          'currentPassword': current,
                          'newPassword': newPassword,
                        },
                      );
                      navigator.pop();
                      messenger.showSnackBar(const SnackBar(
                        content: Text('Contraseña actualizada exitosamente'),
                        backgroundColor: AppColors.success,
                      ));
                    } catch (e) {
                      navigator.pop();
                      messenger.showSnackBar(SnackBar(
                        content: Text('Error: $e'.replaceFirst('Exception: ', '')),
                        backgroundColor: AppColors.error,
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Logout ──

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cerrar sesión',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
          ),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _logout();
              },
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Logout completo: memoria + secure storage + preferencias locales.
  Future<void> _logout() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _httpService.clearAuth();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );

    if (!mounted) return;
    AppSnackBar.success(context, 'Sesión cerrada correctamente');
  }

  @override
  Widget build(BuildContext context) {
    const initial = '1.0.0';

    return _isLoading
        ? const LoadingState()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SectionHeader('APARIENCIA'),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.mode,
                  builder: (context, mode, child) {
                    final isDark = mode == ThemeMode.dark;
                    return _buildSettingTile(
                      icon: isDark ? Icons.nightlight_round : Icons.wb_sunny,
                      title: 'Modo oscuro',
                      subtitle: _modeDescription(mode),
                      trailing: Switch(
                        value: isDark,
                        onChanged: (value) => ThemeController.setDark(value),
                      ),
                    );
                  },
                ),
                const SectionHeader('SEGURIDAD'),
                ValueListenableBuilder<bool>(
                  valueListenable: AppLockController.enabledNotifier,
                  builder: (context, enabled, child) => _buildSettingTile(
                    icon: Icons.fingerprint,
                    title: 'Bloqueo con biometría',
                    subtitle: AppLockController.available()
                        ? 'Pedir huella, rostro o PIN al abrir la app'
                        : 'No disponible en este dispositivo',
                    trailing: Switch(
                      value: enabled,
                      onChanged: (value) async => _toggleAppLock(value),
                    ),
                  ),
                ),
                if (AppLockController.available()) ...[
                  _buildSettingTile(
                    icon: Icons.password,
                    title: 'Cambiar contraseña',
                    subtitle: 'Actualiza tu contraseña de acceso',
                    trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
                    onTap: _showChangePasswordDialog,
                  ),
                ],
                const SectionHeader('INFORMACIÓN'),
                _buildSettingTile(
                  icon: Icons.info,
                  title: 'Versión de la aplicación',
                  subtitle: initial,
                ),
                _buildSettingTile(
                  icon: Icons.help,
                  title: 'Ayuda y soporte',
                  subtitle: 'Centro de ayuda y preguntas frecuentes',
                  trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {
                    AppSnackBar.info(context, 'Centro de ayuda no disponible aún');
                  },
                ),
                _buildSettingTile(
                  icon: Icons.info_outline,
                  title: 'Acerca de',
                  subtitle: 'Información de la aplicación',
                  trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
                _buildSettingTile(
                  icon: Icons.security,
                  title: 'Política de privacidad',
                  subtitle: 'Términos y condiciones de uso',
                  trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {
                    AppSnackBar.info(context, 'Política de privacidad no disponible aún');
                  },
                ),
                const SizedBox(height: 32),
                Pressable(
                  onTap: _showLogoutDialog,
                  borderRadius: 14,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout, size: 22),
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Lavadero App v1.0.0\n© 2026 Todos los derechos reservados',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ),
              ],
            ),
          );
  }

  String _modeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Tema oscuro activo';
      default:
        return 'Tema claro activo';
    }
  }

  Widget _buildHeader() {
    return AppCard(
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName.isEmpty ? 'Preferencias' : 'Hola, $_userName',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail.isEmpty ? 'Personaliza tu experiencia en la app' : _userEmail,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          title: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
          trailing: trailing,
          // El gesto lo maneja el AppCard (Pressable) que envuelve la tile.
          onTap: null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      ),
    );
  }
}

/// Wrapper standalone por compatibilidad: Scaffold + AppBar con gradiente
/// alrededor de la misma página embebible.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Configuración'),
      body: const SettingsView(),
    );
  }
}
