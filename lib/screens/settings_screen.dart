import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import 'login_screen.dart';
import 'about_screen.dart';

const kNotificationsKey = 'notifications';
const kDarkModeKey = 'darkMode';
const kBiometricAuthKey = 'biometricAuth';
const kAutoSyncKey = 'autoSync';
const kLanguageKey = 'language';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _biometricAuth = false;
  bool _autoSync = true;
  String _selectedLanguage = 'Espa\u00f1ol';

  final List<String> _languages = ['Espa\u00f1ol', 'English', 'Portugu\u00eas'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool(kNotificationsKey) ?? true;
        _darkMode = prefs.getBool(kDarkModeKey) ?? false;
        _biometricAuth = prefs.getBool(kBiometricAuthKey) ?? false;
        _autoSync = prefs.getBool(kAutoSyncKey) ?? true;
        _selectedLanguage = prefs.getString(kLanguageKey) ?? 'Espa\u00f1ol';
      });
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Seleccionar idioma',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            child: RadioGroup<String>(
              groupValue: _selectedLanguage,
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  _selectedLanguage = value;
                  _saveSetting(kLanguageKey, value);
                });
                Navigator.pop(context);
              },
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final language = _languages[index];
                  return RadioListTile<String>(
                    title: Text(language),
                    value: language,
                    toggleable: false,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Cerrar sesi\u00f3n',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
          ),
          content: const Text('\u00bfEst\u00e1s seguro de que quieres cerrar sesi\u00f3n?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _logout();
              },
              child: const Text(
                'Cerrar sesi\u00f3n',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesi\u00f3n cerrada correctamente'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Configuraci\u00f3n'),
      body: _isLoading
          ? const LoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SectionHeader('PREFERENCIAS DE LA APP'),
                  _buildSettingTile(
                    icon: Icons.notifications,
                    title: 'Notificaciones',
                    subtitle: 'Activar o desactivar notificaciones push',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveSetting(kNotificationsKey, value);
                      },
                                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  _buildSettingTile(
                    icon: Icons.dark_mode,
                    title: 'Modo oscuro',
                    subtitle: 'Activar el tema oscuro de la aplicaci\u00f3n',
                    trailing: Switch(
                      value: _darkMode,
                      onChanged: (value) {
                        setState(() => _darkMode = value);
                        _saveSetting(kDarkModeKey, value);
                      },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  _buildSettingTile(
                    icon: Icons.sync,
                    title: 'Sincronizaci\u00f3n autom\u00e1tica',
                    subtitle: 'Sincronizar datos autom\u00e1ticamente',
                    trailing: Switch(
                      value: _autoSync,
                      onChanged: (value) {
                        setState(() => _autoSync = value);
                        _saveSetting(kAutoSyncKey, value);
                      },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  const SectionHeader('SEGURIDAD'),
                  _buildSettingTile(
                    icon: Icons.fingerprint,
                    title: 'Autenticaci\u00f3n biom\u00e9trica',
                    subtitle: 'Usar huella digital o reconocimiento facial',
                    trailing: Switch(
                      value: _biometricAuth,
                      onChanged: (value) {
                        setState(() => _biometricAuth = value);
                        _saveSetting(kBiometricAuthKey, value);
                      },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  const SectionHeader('IDIOMA'),
                  _buildSettingTile(
                    icon: Icons.language,
                    title: 'Idioma de la aplicaci\u00f3n',
                    subtitle: _selectedLanguage,
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                    onTap: _showLanguageDialog,
                  ),
                  const SectionHeader('INFORMACI\u00d3N'),
                  _buildSettingTile(
                    icon: Icons.info,
                    title: 'Versi\u00f3n de la aplicaci\u00f3n',
                    subtitle: '1.0.0 (Build 123)',
                  ),
                  _buildSettingTile(
                    icon: Icons.help,
                    title: 'Ayuda y soporte',
                    subtitle: 'Centro de ayuda y preguntas frecuentes',
                    trailing:
                        const Icon(Icons.chevron_right, color: AppColors.textHint),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Centro de ayuda no disponible a\u00fan'),
                        ),
                      );
                    },
                  ),
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: 'Acerca de',
                    subtitle: 'Informaci\u00f3n de la aplicaci\u00f3n',
                    trailing:
                        const Icon(Icons.chevron_right, color: AppColors.textHint),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                  _buildSettingTile(
                    icon: Icons.security,
                    title: 'Pol\u00edtica de privacidad',
                    subtitle: 'T\u00e9rminos y condiciones de uso',
                    trailing:
                        const Icon(Icons.chevron_right, color: AppColors.textHint),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pol\u00edtica de privacidad no disponible a\u00fan'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout, size: 22),
                      label: const Text(
                        'Cerrar sesi\u00f3n',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Lavadero App v1.0.0\n\u00a9 2024 Todos los derechos reservados',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
            child: const Icon(Icons.settings, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preferencias',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Personaliza tu experiencia en la app',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
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
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
