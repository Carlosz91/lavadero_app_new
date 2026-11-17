import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/api_config.dart';
import '../l10n/app_localizations.dart';
import '../repositories/auth_repository.dart';
import '../services/http_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/water_animation.dart';
import 'homescreen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final HttpService _httpService = HttpService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Guarda la sesión local: tokens en secure storage vía HttpService y
  /// datos no sensibles (email/rol/nombre) en prefs.
  Future<void> _persistSession(
    String email, {
    required String token,
    required String refreshToken,
    required String userId,
    String? name,
    String? role,
  }) async {
    await _httpService.saveAuthData(token, refreshToken);
    await _httpService.saveUserId(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userEmail', email);
    if (name != null && name.isNotEmpty) await prefs.setString('userName', name);
    await prefs.setString('role', role ?? 'user');
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final String email = _emailController.text.trim();
      final String password = _passwordController.text;

      try {
        final session = await AuthRepository(_httpService).login(email, password);
        await _persistSession(
          email,
          token: session.token,
          refreshToken: session.refreshToken,
          userId: session.userId,
          name: session.name,
          role: session.role,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userEmail: email),
          ),
        );
      } on HttpException catch (e) {
        if (!mounted) return;
        setState(() { _errorMessage = e.message; });
      } on UnauthorizedException catch (e) {
        if (!mounted) return;
        setState(() { _errorMessage = e.message; });
      } catch (e) {
        if (!mounted) return;
        setState(() { _errorMessage = friendlyErrorMessage(e); });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _googleLogin() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: ApiConfig.googleServerClientId,
      );
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) return;

      final GoogleSignInAuthentication auth = await account.authentication;
      if (auth.idToken == null) {
        if (!mounted) return;
        setState(() => _errorMessage = AppLocalizations.of(context).googleTokenError);
        return;
      }

      setState(() { _isLoading = true; _errorMessage = null; });

      final session = await AuthRepository(_httpService).googleLogin(auth.idToken!);
      await _persistSession(
        account.email,
        token: session.token,
        refreshToken: session.refreshToken,
        userId: session.userId,
        name: session.name,
        role: session.role,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(userEmail: account.email),
        ),
      );
    } on HttpException catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.message; });
    } on UnauthorizedException catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.message; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = friendlyErrorMessage(e); });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaterBackground(
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    StaggeredFadeIn(index: 0, child: _buildLogo()),
                    const SizedBox(height: 28),
                    StaggeredFadeIn(index: 1, child: _buildHeader()),
                    const SizedBox(height: 40),
                    StaggeredFadeIn(index: 2, child: _buildEmailField()),
                    const SizedBox(height: 16),
                    StaggeredFadeIn(index: 3, child: _buildPasswordField()),
                    const SizedBox(height: 8),
                    StaggeredFadeIn(index: 4, child: _buildForgotPasswordButton()),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      StaggeredFadeIn(index: 5, child: ErrorBox(message: _errorMessage!)),
                      const SizedBox(height: 16),
                    ],
                    StaggeredFadeIn(index: 6, child: _buildLoginButton()),
                    const SizedBox(height: 24),
                    StaggeredFadeIn(index: 7, child: _buildDivider()),
                    const SizedBox(height: 16),
                    StaggeredFadeIn(index: 8, child: _buildGoogleButton()),
                    const SizedBox(height: 24),
                    StaggeredFadeIn(index: 9, child: _buildRegisterLink()),
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

  Widget _buildLogo() {
    return const AnimatedLogo();
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.loginWelcome,
          style: AppTextStyles.h1.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.loginSubtitle,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: l10n.emailLabel,
        hintText: l10n.emailHint,
        prefixIcon: const Icon(Icons.email_rounded),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) return l10n.emailRequired;
        if (!isValidEmail(value)) return l10n.emailInvalid;
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: l10n.passwordLabel,
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textHint,
          ),
          tooltip: _obscurePassword ? l10n.showPassword : l10n.hidePassword,
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return l10n.passwordRequired;
        if (value.length < 6) return l10n.passwordTooShort;
        return null;
      },
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(visualDensity: VisualDensity.standard, minimumSize: const Size(48, 48)),
        onPressed: _navigateToForgotPassword,
        child: Text(
          AppLocalizations.of(context).forgotPassword,
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(AppLocalizations.of(context).signIn),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(AppLocalizations.of(context).orSeparator, style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _googleLogin,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/google_logo.svg',
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context).continueWithGoogle,
              style: AppTextStyles.body.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    final l10n = AppLocalizations.of(context);
    return TextButton(
      style: TextButton.styleFrom(visualDensity: VisualDensity.standard, minimumSize: const Size(48, 48)),
      onPressed: _navigateToRegister,
      child: RichText(
        text: TextSpan(
          text: l10n.noAccount,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          children: [
            TextSpan(
              text: l10n.registerNow,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
