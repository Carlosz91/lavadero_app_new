import 'package:flutter/material.dart';
import 'dart:async';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/water_animation.dart';
import 'login_screen.dart';

/// Pantalla para restablecer la contraseña con el código recibido por email.
class ResetPasswordScreen extends StatefulWidget {
  final String? initialCode;

  const ResetPasswordScreen({super.key, this.initialCode});

  @override
  ResetPasswordScreenState createState() => ResetPasswordScreenState();
}

class ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final HttpService _httpService = HttpService();

  bool _isLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _success = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeController.text = widget.initialCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _httpService.post(
        ApiConfig.authResetPasswordUrl,
        {
          'resetToken': _codeController.text.trim(),
          'newPassword': _passwordController.text,
        },
      );

      if (!mounted) return;
      setState(() {
        _success = true;
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'Contraseña restablecida'),
          backgroundColor: AppColors.success,
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on HttpException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Restablecer Contraseña'),
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
            child: _success ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt, size: 72, color: AppColors.success),
          ),
          const SizedBox(height: 24),
          Text('¡Contraseña actualizada!', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Ahora puedes iniciar sesión con tu nueva contraseña',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredFadeIn(index: 0, child: _buildHeader()),
            const SizedBox(height: 32),
            StaggeredFadeIn(index: 1, child: _buildCodeField()),
            const SizedBox(height: 16),
            StaggeredFadeIn(index: 2, child: _buildPasswordField()),
            const SizedBox(height: 16),
            StaggeredFadeIn(index: 3, child: _buildConfirmField()),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              StaggeredFadeIn(index: 4, child: ErrorBox(message: _errorMessage!)),
            ],
            const SizedBox(height: 28),
            StaggeredFadeIn(index: 5, child: _buildSubmitButton()),
            const SizedBox(height: 24),
          ],
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
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.lock_reset, size: 72, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        Text('Ingresa tu código', style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
        const SizedBox(height: 12),
        Text(
          'Abre el correo que te enviamos y copia el código de restablecimiento. '
          'Pega el código aquí junto con tu nueva contraseña.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildCodeField() {
    return TextFormField(
      controller: _codeController,
      decoration: const InputDecoration(
        labelText: 'Código de restablecimiento',
        hintText: 'Ej: 8f1a2b3c4d5e...',
        prefixIcon: Icon(Icons.vpn_key),
      ),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Ingresa el código del correo' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: 'Nueva contraseña',
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textHint,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        )
      ),
      validator: (value) => _validateStrongPassword(value, null),
    );
  }

  Widget _buildConfirmField() {
    return TextFormField(
      controller: _confirmController,
      obscureText: _obscureConfirm,
      decoration: InputDecoration(
        labelText: 'Confirmar contraseña',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirm ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textHint,
          ),
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ),
      validator: (value) => _validateStrongPassword(value, _passwordController.text),
    );
  }

  static String? _validateStrongPassword(String? value, String? other) {
    if (value == null || value.isEmpty) return 'Ingresa la contraseña';
    final passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );
    if (!passwordRegex.hasMatch(value)) {
      return 'Mínimo 8 caracteres, mayúscula, minúscula, número y símbolo (@\$!%*?&)';
    }
    if (other != null && value != other) return 'Las contraseñas no coinciden';
    return null;
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Text('Restablecer contraseña'),
      ),
    );
  }
}
