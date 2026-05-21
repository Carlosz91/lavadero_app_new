import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final storage = const FlutterSecureStorage(); // Token seguro
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
      _showError('Error al cerrar sesión');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
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
      appBar: AppBar(
        title: const Text("🚗 Car-Wash"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getUserId,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _buildBody(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text(
              "Bienvenido",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              widget.userEmail,
              style: const TextStyle(fontSize: 12),
            ),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.shade700,
                    Colors.blueAccent.shade400,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blueAccent.shade700,
                  Colors.blueAccent.shade400,
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.blueAccent),
            title: const Text('Inicio'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.directions_car, color: Colors.blue),
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
            leading: const Icon(Icons.local_car_wash, color: Colors.cyan),
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
            leading: const Icon(Icons.payment, color: Colors.green),
            title: const Text('Pagos'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.orange),
            title: const Text('Configuración'),
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
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header con saludo
            _buildHeader(),
            const SizedBox(height: 30),

            // ✅ Tarjeta de información del usuario
            InfoCard(
              icon: Icons.person,
              title: 'Usuario',
              subtitle: widget.userEmail,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 24),

            // ✅ Sección de acciones principales
            const Text(
              'Acciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Grid de acciones con ActionCard
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
                  backgroundColor: Colors.blueAccent,
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
                  backgroundColor: Colors.cyan,
                  onPressed: () {
                    if (_userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WashStatusScreen(userId: _userId!),
                        ),
                      );
                    } else {
                      _showError('No se encontró el ID de usuario');
                      _getUserId();
                    }
                  },
                ),
                ActionCard(
                  label: 'Ver\nPagos',
                  icon: Icons.payment,
                  backgroundColor: Colors.green,
                  onPressed: () async {
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
                  label: 'Configuración',
                  icon: Icons.settings,
                  backgroundColor: Colors.orange,
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
          ],
        ),
      ),
    );
  }

  /// ✅ Widget para header personalizado
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 50,
              width: 50,
              errorBuilder: (_, __, ___) => Icon(
                Icons.local_car_wash,
                size: 50,
                color: Colors.blueAccent.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¡Bienvenido!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Gestiona tus autos y lavados',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
