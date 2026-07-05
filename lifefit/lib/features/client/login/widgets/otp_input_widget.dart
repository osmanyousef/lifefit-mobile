import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/app_colors.dart';
import 'auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OtpInputWidget — reusable 6-digit OTP input for email verification.
// ─────────────────────────────────────────────────────────────────────────────

/// Six-digit OTP input used for email verification after registration.
///
/// Architecture: a single invisible [TextField] captures keyboard input
/// (paste, autofill, backspace) while [_OtpBox] widgets render the visual
/// digit boxes on top. This gives a polished UI without managing 6 separate
/// focus nodes.
class OtpInputWidget extends StatefulWidget {
  /// Called on every digit change with the current partial or full code.
  final ValueChanged<String>? onChanged;

  /// Called once when all 6 digits have been entered.
  final ValueChanged<String>? onCompleted;

  /// When false, input and tap-to-focus are disabled (e.g. while loading).
  final bool enabled;

  const OtpInputWidget({
    super.key,
    this.onChanged,
    this.onCompleted,
    this.enabled = true,
  });

  @override
  State<OtpInputWidget> createState() => OtpInputWidgetState();
}

class OtpInputWidgetState extends State<OtpInputWidget> {
  static const _length = 6;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// Current OTP string (0–6 digits).
  String get value => _controller.text;

  /// Resets the input — used before resending a new code.
  void clear() {
    _controller.clear();
    setState(() {});
  }

  /// Opens the keyboard — call after navigating to the OTP step.
  void requestFocus() => _focusNode.requestFocus();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Strips non-digits, caps at 6 chars, then notifies parent callbacks.
  void _onChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > _length ? digits.substring(0, _length) : digits;

    if (trimmed != _controller.text) {
      _controller.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }

    setState(() {});
    widget.onChanged?.call(trimmed);

    if (trimmed.length == _length) {
      widget.onCompleted?.call(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    // OTP is always LTR regardless of app locale (digits read left-to-right).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Visual layer: 6 styled boxes showing each digit.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_length, (index) {
                final char = index < _controller.text.length
                    ? _controller.text[index]
                    : '';
                // Highlight the box that will receive the next digit.
                final isFocused =
                    widget.enabled && _focusNode.hasFocus && index == _controller.text.length;

                return _OtpBox(
                  digit: char,
                  isFocused: isFocused,
                  enabled: widget.enabled,
                );
              }),
            ),
            // Input layer: invisible TextField handles keyboard & paste.
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 56,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_length),
                  ],
                  onChanged: _onChanged,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single digit box in the OTP row.
class _OtpBox extends StatelessWidget {
  final String digit;
  final bool isFocused;
  final bool enabled;

  const _OtpBox({
    required this.digit,
    required this.isFocused,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused
              ? AppColors.primary
              : digit.isNotEmpty
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AuthColors.border,
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        digit,
        style: const TextStyle(
          color: AuthColors.navy,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
