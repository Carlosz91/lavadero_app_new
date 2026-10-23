import 'package:flutter/material.dart';
import 'dart:async';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/water_animation.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  final HttpService _httpService = HttpService();

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _httpService.post(
          ApiConfig.authForgotPasswordUrl,
          {'email': _emailController.text.trim()},
        );

        if (!mounted) return;

        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      } on HttpException catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error inesperado. Intenta nuevamente.';
          _isLoading = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _emailSent = false;
      _emailController.clear();
      _errorMessage = null;
    });
    _formKey.currentState?.reset();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Recuperar Contraseña'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: WaterBackground(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaggeredFadeIn(index: 0, child: _buildHeader()),
                    const SizedBox(height: 32),
                    if (!_emailSent) StaggeredFadeIn(index: 1, child: _buildEmailField()),
                    if (!_emailSent) const SizedBox(height: 20),
                    if (_errorMessage != null) ...[
                      StaggeredFadeIn(index: 2, child: ErrorBox(message: _errorMessage!)),
                      const SizedBox(height: 20),
                    ],
                    StaggeredFadeIn(index: 3, child: _buildActionButtons()),
                    const SizedBox(height: 24),
                    if (!_emailSent) StaggeredFadeIn(index: 4, child: _buildHintText()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _emailSent
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _emailSent ? Icons.mark_email_read_rounded : Icons.lock_reset,
            size: 72,
            color: _emailSent ? AppColors.success : AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _emailSent ? '\u00a1Revisa tu correo!' : 'Recupera tu contrase\u00f1a',
          style: AppTextStyles.h1.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(
          _emailSent
              ? 'Hemos enviado un enlace de recuperaci\u00f3n a:\n${_emailController.text}'
              : 'Ingresa tu correo electr\u00f3nico para recibir un enlace de recuperaci\u00f3n.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Correo electr\u00f3nico',
        hintText: 'ejemplo@correo.com',
        prefixIcon: Icon(Icons.email_rounded),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor, ingresa tu correo electr\u00f3nico';
        }
        if (!isValidEmail(value)) {
          return 'Ingresa un correo v\u00e1lido';
        }
        return null;
      },
    );
  }

  Widget _buildActionButtons() {
    if (_emailSent) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                );
              },
              icon: const Icon(Icons.lock_reset),
              label: const Text('Ingresar c\u00f3digo y cambiar contrase\u00f1a'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _resetForm,
              icon: const Icon(Icons.mail_outline),
              label: const Text('Enviar a otro correo'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver al login'),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text('Enviar enlace de recuperaci\u00f3n'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al login'),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildHintText() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '\u00bfNo recibiste el correo? Revisa tu carpeta de spam o solicita otro enlace.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
