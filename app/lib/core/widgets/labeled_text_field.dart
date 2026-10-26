import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// A reusable labeled text input field, HD-toned.
///
/// Renders a label above the text field with consistent styling.
/// Newer code should prefer `DsTextField`. Kept for backward compat with
/// legacy onboarding screens.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.isRequired = false,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.suffixIcon,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool isRequired;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final Widget? suffixIcon;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label.toUpperCase(),
            style: HD.eyebrow(color: HD.inkSoft),
            children: isRequired
                ? [
                    TextSpan(text: ' *', style: HD.eyebrow(color: HD.accent)),
                  ]
                : const [],
          ),
        ),
        const SizedBox(height: HD.s8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          onChanged: onChanged,
          style: HD.body(size: 15, color: HD.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: HD.body(size: 14, color: HD.inkMuted),
            filled: true,
            fillColor: enabled ? HD.paperRaised : HD.paperSunken,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: HD.s16,
              vertical: HD.s12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r8),
              borderSide: const BorderSide(color: HD.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r8),
              borderSide: const BorderSide(color: HD.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r8),
              borderSide: const BorderSide(color: HD.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r8),
              borderSide: const BorderSide(color: HD.negative),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r8),
              borderSide: const BorderSide(color: HD.negative, width: 1.5),
            ),
            errorStyle: HD.caption(color: HD.negative),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }
}
