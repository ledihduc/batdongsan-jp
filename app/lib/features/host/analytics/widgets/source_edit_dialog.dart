import 'package:flutter/material.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/features/host/analytics/widgets/color_swatch_picker.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Add / Edit dialog for a [RevenueSourceModel].
///
/// Separation of concerns: this dialog collects user input and validates it
/// locally, but does NOT call any provider directly. The [onSubmit] callback
/// is responsible for persisting. If [onSubmit] throws, the error string is
/// displayed inline below the text field.
///
/// Usage:
/// ```dart
/// final result = await showDialog<bool>(
///   context: context,
///   builder: (_) => SourceEditDialog(
///     initial: source,          // null → create mode
///     onSubmit: (name, hex) => provider.updateSource(...),
///   ),
/// );
/// ```
class SourceEditDialog extends StatefulWidget {
  const SourceEditDialog({
    super.key,
    this.initial,
    required this.onSubmit,
  });

  /// When non-null, the dialog opens in edit mode with pre-filled values.
  final RevenueSourceModel? initial;

  /// Called with trimmed name + hex on Save. May throw a [String] error message.
  final Future<void> Function(String name, String colorHex) onSubmit;

  @override
  State<SourceEditDialog> createState() => _SourceEditDialogState();
}

class _SourceEditDialogState extends State<SourceEditDialog> {
  late final TextEditingController _nameCtrl;
  late String _selectedHex;
  String? _serverError;
  bool _saving = false;

  bool get _isEditMode => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: _isEditMode ? widget.initial!.displayName : '',
    );
    _selectedHex =
        _isEditMode ? widget.initial!.colorHex : kSourceColorPresets.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Tên nguồn không được để trống';
    if (trimmed.length > 50) return 'Tên tối đa 50 ký tự';
    return null;
  }

  bool get _canSave {
    final trimmed = _nameCtrl.text.trim();
    return trimmed.isNotEmpty && trimmed.length <= 50;
  }

  Future<void> _onSave() async {
    final trimmedName = _nameCtrl.text.trim();
    final nameError = _validateName(trimmedName);
    if (nameError != null) {
      setState(() => _serverError = nameError);
      return;
    }

    setState(() {
      _saving = true;
      _serverError = null;
    });

    try {
      await widget.onSubmit(trimmedName, _selectedHex);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverError = _parseError(e);
          _saving = false;
        });
      }
    }
  }

  /// Extract user-facing message from thrown exception.
  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('revenue_source_name_conflict')) {
      // Backend detail format: "revenue_source_name_conflict: <human text>"
      final idx = msg.indexOf(':');
      if (idx >= 0 && idx < msg.length - 1) {
        return msg.substring(idx + 1).trim();
      }
      return 'Tên nguồn đã tồn tại';
    }
    return 'Lỗi: $msg';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HD.paperRaised,
      title: Text(
        _isEditMode ? 'Sửa nguồn' : 'Thêm nguồn mới',
        style: HD.sectionTitle(),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              key: const Key('source_name_field'),
              controller: _nameCtrl,
              autofocus: true,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Tên nguồn',
                hintText: 'VD: Booking.com, Zalo OA…',
                errorText: _serverError,
                border: const OutlineInputBorder(),
                counterStyle: HD.caption(color: HD.inkMuted),
              ),
              style: HD.body(),
              onChanged: (_) => setState(() => _serverError = null),
            ),
            const SizedBox(height: HD.s16),
            // Color picker
            Text('Màu nhận diện', style: HD.caption(color: HD.inkSoft)),
            const SizedBox(height: HD.s8),
            ColorSwatchPicker(
              selectedHex: _selectedHex,
              onChanged: (hex) => setState(() => _selectedHex = hex),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('source_edit_cancel'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          key: const Key('source_edit_save'),
          onPressed: (_canSave && !_saving) ? _onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: HD.ink,
            foregroundColor: HD.paperRaised,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
