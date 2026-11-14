import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/app_colors.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../design_lab/design_lab_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_widgets.dart';

/// Client sign-in screen.
///
/// Flow:
/// 1. User enters email + password.
/// 2. [_onLogin] validates the form and calls [AuthNotifier.login].
/// 3. On success, [AppEntry] (the parent router) detects `authState.user != null`
///    and automatically switches to home — no manual navigation needed here.
///
/// Related screens: [RegisterScreen], [ForgotPasswordScreen].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Toggles password visibility in the password field.
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the form, then delegates credentials to [authProvider].
  /// Errors are displayed via [AuthErrorMessage] from [authState.errorMessage].
  void _onLogin() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when login loading state or error message changes.
    final authState = ref.watch(authProvider);

    return AuthScreenLayout(
      formKey: _formKey,
      children: [
        const AuthHeader(
          title: 'مرحباً بعودتك',
          subtitle: 'سجّل الدخول لمتابعة رحلتك',
        ),
        AuthTextField(
          controller: _emailController,
          hint: 'البريد الإلكتروني',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              (v == null || !v.contains('@')) ? 'بريد غير صالح' : null,
        ),
        const SizedBox(height: 14),
        AuthTextField(
          controller: _passwordController,
          hint: 'كلمة المرور',
          icon: Icons.lock_outline,
          isPassword: true,
          obscure: _obscurePassword,
          onToggleVisibility: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          validator: (v) =>
              (v == null || v.length < 8) ? '8 أحرف على الأقل' : null,
        ),
        // Link to the two-step password reset flow (OTP + new password).
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            ),
            child: const Text(
              'نسيت كلمة المرور؟',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
        AuthErrorMessage(message: authState.errorMessage),
        AuthPrimaryButton(
          label: 'تسجيل الدخول',
          isLoading: authState.isLoading,
          onPressed: _onLogin,
        ),
        // Social login — disabled until OAuth providers are wired up.
        // const AuthSocialSection(),
        AuthFooterLink(
          prompt: 'ليس لديك حساب؟',
          actionLabel: 'إنشاء حساب',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
        ),
        // Debug builds only: open the Design Lab without signing in
        // (it uses sample data, so the backend doesn't need to be running).
        if (kDebugMode)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DesignLabScreen()),
            ),
            child: const Text(
              'مختبر التصميم (تجريبي)',
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
