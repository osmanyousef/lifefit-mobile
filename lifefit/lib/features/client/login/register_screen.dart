import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/routing/app_entry.dart';
import 'widgets/auth_widgets.dart';

/// Client registration screen.
/// Data flow: form → authProvider.register → AppEntry on success.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Submits registration; navigates to [AppEntry] when user is created.
  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          role: 'client',
        );

    final state = ref.read(authProvider);
    if (mounted && state.user != null && state.errorMessage == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return AuthScreenLayout(
      formKey: _formKey,
      children: [
        const AuthHeader(
          title: 'إنشاء حساب جديد',
          subtitle: 'انضم إلى لايف فت وابدأ رحلتك اليوم',
        ),
        AuthTextField(
          controller: _nameController,
          hint: 'الاسم الكامل',
          icon: Icons.person_outline,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'الاسم مطلوب' : null,
        ),
        const SizedBox(height: 14),
        AuthTextField(
          controller: _emailController,
          hint: 'البريد الإلكتروني',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return 'البريد مطلوب';
            if (!v.contains('@')) return 'بريد غير صالح';
            return null;
          },
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
        const SizedBox(height: 14),
        AuthTextField(
          controller: _confirmController,
          hint: 'تأكيد كلمة المرور',
          icon: Icons.lock_reset,
          isPassword: true,
          obscure: _obscureConfirm,
          onToggleVisibility: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          validator: (v) =>
              (v != _passwordController.text) ? 'لا يوجد تطابق' : null,
        ),
        AuthErrorMessage(
          message: authState.errorMessage,
          padding: const EdgeInsets.only(top: 12, bottom: 12),
        ),
        AuthPrimaryButton(
          label: 'إنشاء الحساب',
          isLoading: authState.isLoading,
          onPressed: _onRegister,
        ),
       
        AuthFooterLink(
          prompt: 'لديك حساب بالفعل؟',
          actionLabel: 'سجل دخولك',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
