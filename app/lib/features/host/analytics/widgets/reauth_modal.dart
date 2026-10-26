import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/features/host/analytics/services/export_service.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Modal dialog for re-authentication before sensitive exports.
///
/// On confirm: calls [ExportService.requestReauth] with the entered password.
/// On success: pops with the reauth token string.
/// On 401 (wrong password): shows inline error.
/// On other errors: shows a SnackBar and pops.
///
/// [ExportService] is resolved from the Provider tree (registered in main.dart).
/// Constructor-injected [exportService] is retained for test scaffolding only.
class ReauthModal extends StatefulWidget {
  const ReauthModal({
    super.key,
    ExportService? exportService,
  }) : _exportService = exportService; // ignore: prefer_initializing_formals

  /// Non-null only in test scaffolds. Production code uses Provider.
  final ExportService? _exportService;

  @override
  State<ReauthModal> createState() => _ReauthModalState();
}

class _ReauthModalState extends State<ReauthModal> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String? _inlineError;
  bool _obscureText = true;

  /// Resolves [ExportService] from Provider; falls back to injected instance in tests.
  ExportService get _service =>
      widget._exportService ??
      Provider.of<ExportService>(context, listen: false);

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _inlineError = null;
    });

    try {
      final token = await _service.requestReauth(_passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop(token);
    } on WrongPasswordException {
      if (!mounted) return;
      setState(() {
        _inlineError = 'Mật khẩu không đúng';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kết nối: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác thực lại'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Để bảo vệ dữ liệu nhạy cảm, vui lòng nhập lại mật khẩu để xuất file kế toán.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('reauth_password_field'),
              controller: _passwordController,
              obscureText: _obscureText,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                errorText: _inlineError,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureText = !_obscureText),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
              onFieldSubmitted: (_) => _loading ? null : _onConfirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('reauth_cancel_btn'),
          onPressed: _loading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          key: const Key('reauth_confirm_btn'),
          onPressed: _loading ? null : _onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: HD.ink,
            foregroundColor: HD.paperRaised,
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text('Xác nhận'),
        ),
      ],
    );
  }
}
