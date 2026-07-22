import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import 'register_car_screen.dart';
import 'wash_status_screen.dart';
import 'login_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userEmail;

  const HomeScreen({super.key, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HttpService _http = HttpService();
  String? _userId;
  String? _userName;
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _userName = prefs.getString('userName') ?? widget.userEmail.split('@').first;
    if (_userId != null) await _loadVehicles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadVehicles() async {
    try {
      final res = await _http.get(ApiConfig.getCarsStatusUrl(_userId!));
      final list = res['data'] as List? ?? res['cars'] as List? ?? [];
      _vehicles = list.cast<Map<String, dynamic>>();
    } catch (_) {}
  }

  Map<String, dynamic>? get _activeWash {
    try {
      return _vehicles.cast<Map<String, dynamic>?>().firstWhere(
        (v) => v?['status'] == 'Pendiente' || v?['status'] == 'En Progreso',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingState());
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _initData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildProfileCard(),
                      const SizedBox(height: 16),
                      _buildWashStatusCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Acciones'),
                      const SizedBox(height: 12),
                      _buildActionsGrid(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text('Bienvenido', style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(widget.userEmail, style: const TextStyle(fontSize: 12)),
            currentAccountPicture: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: AppColors.primary),
            title: const Text('Inicio'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.payment, color: AppColors.success),
            title: const Text('Pagos'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentsScreen(userEmail: widget.userEmail))); },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.warning),
            title: const Text('Configuración'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            onTap: _confirmLogout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u00a1Hola, $_userName!',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tus lavados al instante',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = _userName ?? 'Usuario';
    final initial = name.substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.userEmail,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Editar',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWashStatusCard() {
    final active = _activeWash;
    final model = active?['model'] ?? '';
    final brand = active?['brand'] ?? '';
    final plate = active?['plate'] ?? '';
    final status = active?['status'] ?? '';
    final isInProgress = status == 'En Progreso';
    final isPending = status == 'Pendiente';
    final progress = isInProgress ? 0.65 : isPending ? 0.25 : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_car_wash, color: Color(0xFF14B8A6), size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Estado Actual',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (active != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$brand $model',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(isInProgress ? 0xFF2563EB : 0xFFF59E0B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(isInProgress ? 0xFF2563EB : 0xFFF59E0B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            plate,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPending ? 'Esperando inicio del lavado' : 'Lavado en proceso',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'No hay lavados activos',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTextStyles.h3);
  }

  Widget _buildActionsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _PrototypeButton(
              label: 'Registrar Auto',
              icon: Icons.directions_car_rounded,
              color: AppColors.primary,
              textColor: Colors.white,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterCarScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(child: _PrototypeButton(
              label: 'Estado de Lavado',
              icon: Icons.local_car_wash,
              color: Colors.white,
              textColor: AppColors.textPrimary,
              borderColor: AppColors.border,
              iconBg: const Color(0xFF14B8A6),
              onTap: () {
                if (_userId != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => WashStatusScreen(userId: _userId!)));
                }
              },
            )),
          ],
        ),
        const SizedBox(height: 12),
        _WideCtaButton(
          label: 'Solicitar Nuevo Lavado',
          icon: Icons.add_rounded,
          color: const Color(0xFF14B8A6),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterCarScreen())),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _PrototypeButton(
              label: 'Ver Pagos',
              icon: Icons.credit_card_rounded,
              color: Colors.white,
              textColor: AppColors.textPrimary,
              borderColor: AppColors.border,
              iconBg: AppColors.success,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentsScreen(userEmail: widget.userEmail))),
            )),
            const SizedBox(width: 12),
            Expanded(child: _PrototypeButton(
              label: 'Configuración',
              icon: Icons.settings_rounded,
              color: Colors.white,
              textColor: AppColors.textPrimary,
              borderColor: AppColors.border,
              iconBg: AppColors.warning,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            )),
          ],
        ),
      ],
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => CustomDialog(
        title: 'Cerrar sesión',
        message: '¿Estás seguro de que quieres cerrar sesión?',
        confirmText: 'Sí, cerrar',
        cancelText: 'Cancelar',
        isWarning: true,
        onConfirm: () { Navigator.pop(context); _logout(); },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }
}

class _PrototypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final Color? iconBg;
  final VoidCallback onTap;

  const _PrototypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    this.borderColor,
    this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
          boxShadow: color == Colors.white
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg?.withValues(alpha: 0.12) ?? Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconBg ?? Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _WideCtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _WideCtaButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
