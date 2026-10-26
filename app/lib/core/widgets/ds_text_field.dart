import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';

/// Editorial text field — labeled, validated, themed.
/// Drop-in replacement for the legacy `LabeledTextField`.
class DsTextField extends StatelessWidget {
  const DsTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.focusNode,
    this.initialValue,
  }) : assert(
          controller == null || initialValue == null,
          'Cannot provide both controller and initialValue — choose one.',
        );

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!.toUpperCase(), style: HD.eyebrow()),
          const SizedBox(height: HD.s4),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          readOnly: readOnly,
          enabled: enabled,
          autofocus: autofocus,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          style: HD.body(color: HD.ink),
          cursorColor: HD.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: HD.body(color: HD.inkMuted),
            helperText: helper,
            helperStyle: HD.caption(),
            errorStyle: HD.caption(color: HD.negative),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 18, color: HD.inkMuted),
            suffixIcon: suffixIcon == null
                ? null
                : IconButton(
                    icon: Icon(suffixIcon, size: 18, color: HD.inkMuted),
                    onPressed: onSuffixTap,
                    splashRadius: 18,
                  ),
            counterStyle: HD.caption(),
          ),
        ),
      ],
    );
  }
}
