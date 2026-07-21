import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Acerca de'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Column(
                children: [
                  Icon(Icons.local_car_wash, size: 64, color: AppColors.primary),
                  SizedBox(height: 12),
                  Text(
                    'Lavadero App',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Versi\u00f3n 1.0.0',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Descripci\u00f3n',
              'Aplicaci\u00f3n para la gesti\u00f3n de lavaderos de veh\u00edculos. '
              'Permite registrar autos para lavado, consultar el estado del '
              'proceso en tiempo real, gestionar pagos y administrar el '
              'flujo de trabajo del lavadero.',
            ),
            _buildSection(
              'Funcionalidades',
              '\u2022 Registro de veh\u00edculos para lavado\n'
              '\u2022 Seguimiento del estado del lavado\n'
              '\u2022 Gesti\u00f3n de pagos\n'
              '\u2022 Panel de administraci\u00f3n web\n'
              '\u2022 Notificaciones push\n'
              '\u2022 Autenticaci\u00f3n biom\u00e9trica\n'
              '\u2022 Roles de usuario (admin/staff/cliente)',
            ),
            _buildSection(
              'Tecnolog\u00edas',
              '\u2022 Frontend: Flutter 3.35.2 / Dart 3.9.0\n'
              '\u2022 Backend: Node.js / Express\n'
              '\u2022 Base de datos: MongoDB\n'
              '\u2022 Autenticaci\u00f3n: JWT',
            ),
            _buildSection(
              'Desarrollador',
              'Carlos Z.\n'
              '\u00a9 2024 Todos los derechos reservados.',
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'Hecho con Flutter \u2764\ufe0f',
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h3.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTextStyles.body.copyWith(height: 1.6, color: AppColors.textSecondary),
          ),
          const Divider(height: 32, color: AppColors.border),
        ],
      ),
    );
  }
}
