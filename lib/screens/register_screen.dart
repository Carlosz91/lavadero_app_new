import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/water_animation.dart';
import 'login_screen.dart';
import 'homescreen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final httpService = HttpService();
      final response = await httpService.post(
        ApiConfig.authRegisterUrl,
        {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'name': _nameController.text.trim(),
        },
      );

      final token = response['token'] as String?;
      final refreshToken = response['refreshToken'] as String? ?? '';
      final email = _emailController.text.trim();

      if (token == null) {
        _setError('No se recibió el token de sesión');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = response['userId'] as String?;
      await httpService.saveAuthData(token, refreshToken);
      if (userId != null) await httpService.saveUserId(userId);
      await prefs.setString('userEmail', email);
      await prefs.setString('userName', _nameController.text.trim());
      final role = response['user']?['role'] as String?;
      await prefs.setString('role', role ?? 'user');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro exitoso'),
            backgroundColor: AppColors.success,
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(userEmail: _emailController.text.trim()),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      _setError(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaterBackground(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    StaggeredFadeIn(index: 0, child: _buildHeader()),
                    const SizedBox(height: 32),
                    StaggeredFadeIn(index: 1, child: _buildNameField()),
                    const SizedBox(height: 16),
                    StaggeredFadeIn(index: 2, child: _buildEmailField()),
                    const SizedBox(height: 16),
                    StaggeredFadeIn(index: 3, child: _buildPasswordField()),
                    const SizedBox(height: 16),
                    StaggeredFadeIn(index: 4, child: _buildConfirmPasswordField()),
                    if (_hasError) ...[
                      const SizedBox(height: 16),
                      StaggeredFadeIn(index: 5, child: ErrorBox(message: _errorMessage)),
                    ],
                    const SizedBox(height: 28),
                    StaggeredFadeIn(index: 6, child: _buildRegisterButton()),
                    const SizedBox(height: 20),
                    StaggeredFadeIn(index: 7, child: _buildLoginLink()),
                    const SizedBox(height: 24),
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
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.person_add_rounded, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'Crear Cuenta',
          style: AppTextStyles.h1.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Completa tus datos para registrarte',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Nombre completo',
        prefixIcon: Icon(Icons.person_rounded),
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor ingresa tu nombre';
        }
        if (value.trim().length < 2) {
          return 'Debe tener al menos 2 caracteres';
        }
        if (value.trim().length > 50) {
          return 'Máximo 50 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Correo electr\u00f3nico',
        prefixIcon: Icon(Icons.email_rounded),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor ingresa tu email';
        }
        if (!isValidEmail(value)) {
          return 'Ingresa un email v\u00e1lido';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        helperText:
            'Mínimo 8 caracteres, con mayúscula, minúscula, número y símbolo',
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textHint,
          ),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
      validator: _validateStrongPassword,
    );
  }

  static String? _validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa una contraseña';
    }
    final passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );
    if (!passwordRegex.hasMatch(value)) {
      return 'Mínimo 8 caracteres, mayúscula, minúscula, número y símbolo (@\$!%*?&)';
    }
    return null;
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: !_isConfirmPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Confirmar contrase\u00f1a',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(
            _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textHint,
          ),
          onPressed: () =>
              setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Confirma tu contrase\u00f1a';
        }
        if (value != _passwordController.text) {
          return 'Las contrase\u00f1as no coinciden';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton() {
    return GradientButton(
      label: _isLoading ? 'Registrando...' : 'Crear Cuenta',
      icon: Icons.check,
      isLoading: _isLoading,
      onPressed: _isLoading ? null : _register,
    );
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: _isLoading
          ? null
          : () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
      child: RichText(
        text: TextSpan(
          text: '\u00bfYa tienes cuenta? ',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          children: const [
            TextSpan(
              text: 'Inicia sesi\u00f3n',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
