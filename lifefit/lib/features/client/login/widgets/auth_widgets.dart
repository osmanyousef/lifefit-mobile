import 'package:flutter/material.dart';
import '../../../../core/ui/app_colors.dart';
import '../../../../core/ui/widgets/fitlife_logo.dart';
import '../../../../core/ui/widgets/fitlife_wave_background.dart';

/// Shared UI building blocks for all auth screens in this module.
///
/// Used by: [LoginScreen], [RegisterScreen], [ForgotPasswordScreen].
/// Keeps layout, colors, and form styling consistent across login flows.

/// Local color tokens for auth screens (separate from global [AppColors]).
abstract final class AuthColors {
  static const navy = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
}

/// Full-screen scaffold wrapper shared by every auth screen.
///
/// Provides:
/// - Wave background ([FitLifeAuthBackground])
/// - Scrollable, centered form (max width 400)
/// - Tap-outside to dismiss keyboard
/// - [Form] with the given [formKey] for validation
class AuthScreenLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  const AuthScreenLayout({
    super.key,
    required this.formKey,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        // Dismiss keyboard when tapping outside input fields.
        onTap: () => FocusScope.of(context).unfocus(),
        child: FitLifeAuthBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top section of every auth screen: logo + RTL title and subtitle.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Center(
          child: FitLifeLogo(
            height: 170,
            clipToMark: true,
            showWordmark: true,
          ),
        ),
        const SizedBox(height: 24),
        // Force RTL for Arabic title/subtitle regardless of system locale.
        Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AuthColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AuthColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Styled [TextFormField] used across all auth forms.
///
/// Supports optional password mode with a visibility toggle icon.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscure;
  final VoidCallback? onToggleVisibility;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscure = false,
    this.onToggleVisibility,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AuthColors.navy, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AuthColors.muted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AuthColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

/// Primary call-to-action button with gradient background.
///
/// Shows a loading spinner and disables tap while [isLoading] is true.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}

/// Displays a centered red error message below the form fields.
///
/// Returns [SizedBox.shrink] when [message] is null — safe to always include.
/// Used with [authProvider] errors on login/register, or local errors on
/// [ForgotPasswordScreen].
class AuthErrorMessage extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry padding;

  const AuthErrorMessage({
    super.key,
    required this.message,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Text(
        message!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Optional social-login section (Google / Apple).
///
/// Currently unused — kept for future OAuth integration.
class AuthSocialSection extends StatelessWidget {
  const AuthSocialSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'أو تابع عبر',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AuthSocialButton(icon: Icons.g_mobiledata_rounded),
            const SizedBox(width: 16),
            AuthSocialButton(icon: Icons.apple_rounded),
          ],
        ),
      ],
    );
  }
}

/// Outlined icon button for a third-party sign-in provider.
class AuthSocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const AuthSocialButton({
    super.key,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuthColors.border),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 30, color: AuthColors.navy),
      ),
    );
  }
}

/// Bottom footer with a prompt text and a tappable action link.
///
/// Examples: "Already have an account? Sign in" / "No account? Register".
class AuthFooterLink extends StatelessWidget {
  final String prompt;
  final String actionLabel;
  final VoidCallback onPressed;

  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              prompt,
              style: const TextStyle(color: AuthColors.muted),
            ),
            TextButton(
              onPressed: onPressed,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
