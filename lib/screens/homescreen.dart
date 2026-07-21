import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import 'register_car_screen.dart';
import 'wash_status_screen.dart';
import 'payments_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userEmail;

  const HomeScreen({super.key, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = const FlutterSecureStorage();
  String? _userId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
    } catch (_) {
      _showError('Error al cargar datos del usuario');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await storage.deleteAll();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      _showError('Error al cerrar sesi\u00f3n');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => CustomDialog(
        title: 'Cerrar sesi\u00f3n',
        message: '\u00bfEst\u00e1s seguro de que quieres cerrar sesi\u00f3n?',
        confirmText: 'S\u00ed, cerrar',
        cancelText: 'Cancelar',
        isWarning: true,
        onConfirm: () {
          Navigator.pop(context);
          _logout();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: _isLoading
          ? const LoadingState(message: 'Cargando datos...')
          : _buildBody(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text(
              'Bienvenido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              widget.userEmail,
              style: const TextStyle(fontSize: 12),
            ),
            currentAccountPicture: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
            leading: const Icon(Icons.directions_car, color: AppColors.primary),
            title: const Text('Registrar Auto'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterCarScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_car_wash, color: AppColors.primary),
            title: const Text('Estado de Lavado'),
            onTap: () {
              Navigator.pop(context);
              if (_userId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WashStatusScreen(userId: _userId!),
                  ),
                );
              } else {
                _showError('ID de usuario no encontrado');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.payment, color: AppColors.success),
            title: const Text('Pagos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentsScreen(userEmail: widget.userEmail),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.warning),
            title: const Text('Configuraci\u00f3n'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              'Cerrar sesi\u00f3n',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            onTap: _confirmLogout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoCard(
                  icon: Icons.person,
                  title: 'Usuario',
                  subtitle: widget.userEmail,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Acciones',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    ActionCard(
                      label: 'Registrar\nAuto',
                      icon: Icons.directions_car,
                      backgroundColor: AppColors.primary,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterCarScreen(),
                          ),
                        );
                      },
                    ),
                    ActionCard(
                      label: 'Estado de\nLavado',
                      icon: Icons.local_car_wash,
                      backgroundColor: const Color(0xFF00ACC1),
                      onPressed: () {
                        if (_userId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WashStatusScreen(userId: _userId!),
                            ),
                          );
                        } else {
                          _showError('No se encontr\u00f3 el ID de usuario');
                          _getUserId();
                        }
                      },
                    ),
                    ActionCard(
                      label: 'Ver\nPagos',
                      icon: Icons.payment,
                      backgroundColor: AppColors.success,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentsScreen(
                              userEmail: widget.userEmail,
                            ),
                          ),
                        );
                      },
                    ),
                    ActionCard(
                      label: 'Configuraci\u00f3n',
                      icon: Icons.settings,
                      backgroundColor: AppColors.warning,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu, color: Colors.white, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u00a1Bienvenido!',
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                    Text(
                      'Gestiona tus autos y lavados',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_car_wash,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
