import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/water_animation.dart';
import 'register_car_screen.dart';
import 'wash_status_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';

/// Shell principal de la app: barra de navegación Material 3 inferior con
/// Inicio / Estado / Pagos / Ajustes. Mantiene el nombre histórico
/// [HomeScreen] porque login y registro crean instancias directas.
class HomeScreen extends StatefulWidget {
  final String userEmail;

  const HomeScreen({super.key, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HttpService _http = HttpService();
  int _tab = 0;
  String? _userId;
  bool _shellReady = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final id = await _http.getUserId();
    if (mounted) {
      setState(() {
        _userId = id;
        _shellReady = true;
      });
    }
  }

  /// En Inicio/Estado/Pagos los headers son gradientes claros → iconos
  /// blancos. En Ajustes el fondo depende del tema activo.
  SystemUiOverlayStyle get _statusBarStyle {
    if (_tab == 3) {
      return AppColors.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    }
    return SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shellReady) {
      return const Scaffold(body: LoadingState());
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _statusBarStyle,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _tab,
          children: [
            _HomeDashboard(
              userEmail: widget.userEmail,
              userId: _userId,
              onOpenStatus: () => setState(() => _tab = 1),
            ),
            _estadoPage(),
            PaymentsView(userEmail: widget.userEmail),
            const SettingsView(),
          ],
        ),
        floatingActionButton: IgnorePointer(
          ignoring: _tab != 0,
          child: AnimatedOpacity(
            opacity: _tab == 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedScale(
              scale: _tab == 0 ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: FloatingActionButton.extended(
                onPressed: () => _openRegisterCar(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Registrar lavado'),
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) {
            if (index == _tab) return;
            setState(() => _tab = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_car_wash_outlined),
              selectedIcon: Icon(Icons.local_car_wash_rounded),
              label: 'Estado',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments_rounded),
              label: 'Pagos',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoPage() {
    final id = _userId;
    if (id == null || id.isEmpty) {
      return const ErrorState(
        message: 'No se pudo identificar tu cuenta. Cierra sesión y vuelve a entrar.',
      );
    }
    return WashStatusView(userId: id);
  }

  void _openRegisterCar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterCarScreen()),
    );
  }
}

/// Página de inicio del shell: saludo, estado del lavado activo con avance
/// real y atajo para registrar el próximo lavado. Sin Drawer: la navegación
/// vive en la barra inferior.
class _HomeDashboard extends StatefulWidget {
  final String userEmail;
  final String? userId;
  final VoidCallback onOpenStatus;

  const _HomeDashboard({
    required this.userEmail,
    required this.userId,
    required this.onOpenStatus,
  });

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  final HttpService _http = HttpService();
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
    _userName = prefs.getString('userName') ?? widget.userEmail.split('@').first;
    if (mounted) setState(() {});
    await _loadVehicles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadVehicles() async {
    final id = widget.userId;
    if (id == null || id.isEmpty) return;
    try {
      final res = await _http.get(ApiConfig.getCarsStatusUrl(id));
      final list = res['data'] as List? ?? res['cars'] as List? ?? [];
      _vehicles = list.cast<Map<String, dynamic>>();
    } catch (_) {}
  }

  Map<String, dynamic>? get _activeWash {
    for (final v in _vehicles) {
      final status = (v['status'] ?? '').toString();
      if (status == 'Pendiente' || status == 'En Progreso') return v;
    }
    return null;
  }

  int get _countPending => _vehicles
      .where((v) => (v['status'] ?? '').toString() == 'Pendiente')
      .length;
  int get _countProgress => _vehicles
      .where((v) => (v['status'] ?? '').toString() == 'En Progreso')
      .length;
  int get _countDone => _vehicles
      .where((v) => (v['status'] ?? '').toString() == 'Completado')
      .length;

  /// Progreso real del flujo del negocio, derivado del estado del pedido.
  double _washProgress(String status) {
    switch (status) {
      case 'Pendiente':
        return 0.2;
      case 'En Progreso':
        return 0.6;
      case 'Completado':
        return 1.0;
      default:
        return 0.0;
    }
  }

  String _washProgressLabel(String status) => status == 'Pendiente'
      ? 'Esperando inicio del lavado (20%)'
      : 'Lavado en proceso (60%)';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadVehicles();
          if (mounted) setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loading)
                      const SkeletonCard()
                    else ...[
                      StaggeredFadeIn(index: 0, child: _buildActiveWashCard()),
                      const SizedBox(height: 12),
                      StaggeredFadeIn(index: 1, child: _buildStatsRow()),
                      const SizedBox(height: 24),
                      StaggeredFadeIn(index: 2, child: _buildRegisterCta()),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _userName ?? 'Usuario';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        22,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola, $name!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tu lavadero al día, un toque de distancia',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWashCard() {
    final active = _activeWash;

    return AppCard(
      onTap: active != null ? widget.onOpenStatus : null,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_car_wash_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text('Estado actual', style: AppTextStyles.h3),
              const Spacer(),
              Icon(
                active != null ? Icons.chevron_right : Icons.info_outline,
                size: 20,
                color: AppColors.textHint,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (active != null) ...[
            _buildActiveWashBody(active),
          ] else ...[
            Text(
              'No hay lavados activos',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando registres un lavado vas a seguir su avance acá, '
              'de la agenda a la entrega.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tocá el botón “Registrar lavado”',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveWashBody(Map<String, dynamic> active) {
    final model = active['model'] ?? '';
    final brand = active['brand'] ?? '';
    final plate = active['plate'] ?? '';
    final status = (active['status'] ?? '').toString();
    final progress = _washProgress(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$brand $model',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            StatusBadge(status: status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          plate,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _washProgressLabel(status),
                style: AppTextStyles.bodySmall,
              ),
            ),
            Text(
              'Ver detalle',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatItem(
          Icons.schedule_rounded,
          'Pendientes',
          _countPending,
          AppColors.warning,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          Icons.autorenew_rounded,
          'En progreso',
          _countProgress,
          AppColors.primary,
        ),
        const SizedBox(width: 12),
        _buildStatItem(
          Icons.check_circle_rounded,
          'Completados',
          _countDone,
          AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              count.toString(),
              style: AppTextStyles.stat.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCta() {
    return AppCard(
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterCarScreen()),
        );
      },
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Próximo lavado?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Agenda tu vehículo con un toque',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
        ],
      ),
    );
  }
}
