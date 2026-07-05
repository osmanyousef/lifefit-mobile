import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/routing/app_entry.dart';
import '../../../core/ui/app_colors.dart';
import 'widgets/auth_widgets.dart';
import 'widgets/otp_input_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RegisterScreen — two-step client registration with email OTP verification.
// ─────────────────────────────────────────────────────────────────────────────

/// Client registration screen.
///
/// Flow:
/// 1. User fills the account form → [AuthNotifier.register] creates the account.
///    The backend sends a 6-digit OTP to the email and returns a Bearer token.
/// 2. User enters the OTP → [AuthNotifier.verifyEmail] calls POST /api/email/verify.
/// 3. On success, navigates to [AppEntry] (home / onboarding).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step 1 form controllers.
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  /// Key to control [OtpInputWidget] (focus, clear) from the parent.
  final _otpKey = GlobalKey<OtpInputWidgetState>();

  /// 1 = account form, 2 = OTP verification step.
  int _step = 1;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  /// Shown after a successful resend (backend success message).
  String? _successMessage;

  /// Current OTP value synced from [OtpInputWidget.onChanged].
  String _otp = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Clears local success text and any auth error from the previous attempt.
  void _clearMessages() {
    setState(() => _successMessage = null);
    ref.read(authProvider.notifier).clearErrorMessage();
  }

  /// Step 1: creates the account; backend sends OTP to email.
  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    _clearMessages();

    await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          role: 'client',
        );

    final state = ref.read(authProvider);
    if (mounted && state.user != null && state.errorMessage == null) {
      // Token is already saved by AuthService.register — advance to OTP step.
      setState(() => _step = 2);
      // Auto-focus the OTP field once the step-2 UI is built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpKey.currentState?.requestFocus();
      });
    }
  }

  /// Step 2: verifies the 6-digit OTP via POST /api/email/verify.
  Future<void> _onVerifyOtp() async {
    if (_otp.length != 6) {
      ref.read(authProvider.notifier).setErrorMessage(
            'يرجى إدخال رمز التحقق المكوّن من 6 أرقام',
          );
      return;
    }
    _clearMessages();

    final verified = await ref.read(authProvider.notifier).verifyEmail(otp: _otp);
    if (mounted && verified) {
      // Replace the entire auth stack — user is fully verified at this point.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    }
  }

  /// Resends OTP via POST /api/email/resend.
  Future<void> _onResendOtp() async {
    _clearMessages();
    _otpKey.currentState?.clear();
    setState(() => _otp = '');

    final message = await ref.read(authProvider.notifier).resendVerificationEmail();
    if (mounted && message != null) {
      setState(() => _successMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return AuthScreenLayout(
      formKey: _formKey,
      children: [
        // Switch between account form (step 1) and OTP verification (step 2).
        if (_step == 1) ..._buildRegistrationStep(authState) else ..._buildOtpStep(authState),
        AuthFooterLink(
          prompt: _step == 1 ? 'لديك حساب بالفعل؟' : 'خطأ في البريد؟',
          actionLabel: _step == 1 ? 'سجل دخولك' : 'تعديل البيانات',
          onPressed: () {
            if (_step == 1) {
              Navigator.pop(context);
            } else {
              // Go back to step 1 so the user can fix their email if needed.
              setState(() {
                _step = 1;
                _otp = '';
                _successMessage = null;
              });
              _otpKey.currentState?.clear();
              _clearMessages();
            }
          },
        ),
      ],
    );
  }

  /// Step 1 UI: name, email, password, and confirm password fields.
  List<Widget> _buildRegistrationStep(AuthState authState) {
    return [
      const AuthHeader(
        title: 'إنشاء حساب جديد',
        subtitle: 'انضم إلى لايف فت وابدأ رحلتك اليوم',
      ),
      AuthTextField(
        controller: _nameController,
        hint: 'الاسم الكامل',
        icon: Icons.person_outline,
        validator: (v) => (v == null || v.isEmpty) ? 'الاسم مطلوب' : null,
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
        onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
        validator: (v) => (v == null || v.length < 8) ? '8 أحرف على الأقل' : null,
      ),
      const SizedBox(height: 14),
      AuthTextField(
        controller: _confirmController,
        hint: 'تأكيد كلمة المرور',
        icon: Icons.lock_reset,
        isPassword: true,
        obscure: _obscureConfirm,
        onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
        validator: (v) => (v != _passwordController.text) ? 'لا يوجد تطابق' : null,
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
    ];
  }

  /// Step 2 UI: OTP input, verify button, and resend link.
  List<Widget> _buildOtpStep(AuthState authState) {
    final email = _emailController.text.trim();

    return [
      AuthHeader(
        title: 'تحقق من بريدك الإلكتروني',
        subtitle: 'أرسلنا رمز تحقق مكوّناً من 6 أرقام إلى $email',
      ),
      OtpInputWidget(
        key: _otpKey,
        enabled: !authState.isLoading,
        onChanged: (value) => setState(() => _otp = value),
        // Auto-submit when all 6 digits are entered.
        onCompleted: (_) => _onVerifyOtp(),
      ),
      const SizedBox(height: 8),
      AuthErrorMessage(message: authState.errorMessage),
      if (_successMessage != null)
        // Green feedback shown after a successful OTP resend.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _successMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      AuthPrimaryButton(
        label: 'تأكيد الرمز',
        isLoading: authState.isLoading,
        onPressed: _onVerifyOtp,
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.center,
        child: TextButton(
          onPressed: authState.isLoading ? null : _onResendOtp,
          child: const Text(
            'لم يصلك الرمز؟ أعد الإرسال',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    ];
  }
}
