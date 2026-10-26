/// JP postal code input field with auto-lookup.
///
/// Formats input as `###-####` (7-digit Japan postal code).
/// On 7-digit completion: debounces 300 ms, then calls
/// `GET /api/jp/address/lookup?postal_code=<7digits>` via [ApiClient].
/// Invokes [onAddressResolved] with the parsed [JpAddress] on success.
///
/// Route: n/a (embedded widget).
/// API: GET /api/jp/address/lookup
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:house_booking/core/widgets/ds_text_field.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Address result returned by the JP postal lookup endpoint.
class JpAddress {
  const JpAddress({
    required this.postalCode,
    required this.prefecture,
    required this.city,
    required this.town,
    this.street,
  });

  final String postalCode;

  /// Prefecture name in Japanese, e.g. `東京都`.
  final String prefecture;

  /// City/ward/gun, e.g. `渋谷区`.
  final String city;

  /// Town/cho, e.g. `道玄坂`.
  final String town;

  /// Optional street / block number, may be null.
  final String? street;

  factory JpAddress.fromJson(Map<String, dynamic> json) {
    return JpAddress(
      postalCode: json['postal_code'] as String? ?? '',
      prefecture: json['prefecture'] as String? ?? '',
      city: json['city'] as String? ?? '',
      town: json['town'] as String? ?? '',
      street: json['street'] as String?,
    );
  }
}

/// Formatter that enforces `###-####` mask for JP postal codes.
///
/// Accepts only digits; inserts hyphen automatically at position 3.
class _PostalCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip all non-digits.
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Cap at 7 digits.
    final capped = digits.length > 7 ? digits.substring(0, 7) : digits;

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 3) buffer.write('-');
      buffer.write(capped[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// JP postal code input field with debounced address auto-lookup.
///
/// [onAddressResolved] is called when a valid address is returned from the BE.
/// [onError] is called when the lookup fails (network error, 404, etc.) — parent
/// can show a snackbar or inline error.
class JpPostalCodeField extends StatefulWidget {
  const JpPostalCodeField({
    super.key,
    required this.onAddressResolved,
    this.onError,
    this.label,
    this.controller,
    this.apiClient,
  });

  /// Called with the resolved address when lookup succeeds.
  final void Function(JpAddress address) onAddressResolved;

  /// Called with a user-facing error message when lookup fails. Optional.
  final void Function(String message)? onError;

  /// Optional field label; defaults to '郵便番号'.
  final String? label;

  /// Optional external [TextEditingController] for integration with Form.
  final TextEditingController? controller;

  /// Override for testing — injects a mock [ApiClient].
  final ApiClient? apiClient;

  @override
  State<JpPostalCodeField> createState() => _JpPostalCodeFieldState();
}

class _JpPostalCodeFieldState extends State<JpPostalCodeField> {
  late final TextEditingController _ctrl;
  late final ApiClient _api;
  Timer? _debounce;
  bool _isLoading = false;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _api = widget.apiClient ?? const ApiClient();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Only dispose controller if we created it internally.
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Clear previous error on new input.
    if (_fieldError != null) {
      setState(() => _fieldError = null);
    }

    // Extract digits only — formatted text is `###-####`.
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 7) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _lookup(digits));
  }

  Future<void> _lookup(String postalCode) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _fieldError = null;
    });

    try {
      final body = await _api.get(
        '/api/jp/address/lookup',
        queryParameters: {'postal_code': postalCode},
      );

      if (!mounted) return;

      final address = JpAddress.fromJson(body);
      widget.onAddressResolved(address);
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = e.statusCode == 404
          ? '郵便番号が見つかりません'
          : 'エラーが発生しました。もう一度お試しください。';
      setState(() => _fieldError = message);
      widget.onError?.call(message);
    } catch (_) {
      if (!mounted) return;
      const message = 'エラーが発生しました。もう一度お試しください。';
      setState(() => _fieldError = message);
      widget.onError?.call(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DsTextField(
      controller: _ctrl,
      label: widget.label ?? '郵便番号',
      hint: '例：123-4567',
      keyboardType: TextInputType.number,
      inputFormatters: [_PostalCodeFormatter()],
      onChanged: _onChanged,
      suffixIcon: _isLoading ? Icons.hourglass_empty_rounded : null,
      // Show field-level error from lookup; null = no error shown.
      validator: (_) => _fieldError,
      // Helper text guides the user.
      helper: '7桁の郵便番号を入力すると住所が自動入力されます',
    );
  }
}
