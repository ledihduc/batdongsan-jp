import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/permissions/with_camera_permission.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Giới hạn kích thước file upload: 5 MB (security — phòng tránh abuse).
const _kMaxImageBytes = 5 * 1024 * 1024;

/// Màn hình báo cáo dữ liệu quy hoạch sai (US-08).
///
/// Nhận [parcelId] từ caller (ParcelDetailSheet hoặc PlanningWarningModal).
/// Không yêu cầu Provider — PlanningService + ApiClient khởi tạo cục bộ.
class ReportErrorScreen extends StatefulWidget {
  final String parcelId;

  const ReportErrorScreen({required this.parcelId, super.key});

  @override
  State<ReportErrorScreen> createState() => _ReportErrorScreenState();
}

class _ReportErrorScreenState extends State<ReportErrorScreen> {
  final _reasonCtrl = TextEditingController();
  final _service = PlanningService();
  final _api = const ApiClient();

  String? _imageUrl;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Image picker + upload
  // ---------------------------------------------------------------------------

  Future<void> _pickImage() async {
    final l = AppLocalizations.of(context);
    final userId = Provider.of<AuthProvider>(context, listen: false)
            .currentUser
            ?.id
            ?.toString() ??
        '';
    final file = await withCameraPermission(
      context,
      source: ImageSource.camera,
      primingContext: CameraContext.reportErrorPhoto,
      userId: userId,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();

    // Security: kiểm tra kích thước trước khi upload.
    if (bytes.length > _kMaxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.planErrImageTooLarge)),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final url = await _api.uploadImage(bytes, file.name);
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.planErrUploadFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _clearImage() => setState(() => _imageUrl = null);

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final reason = _reasonCtrl.text.trim();
    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.planErrMinLength)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.reportParcelError(
        parcelId: widget.parcelId,
        reason: reason,
        imageUrl: _imageUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.planErrSuccessMsg),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.planErrSubmitFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: DsAppBar(title: l.planErrTitle),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parcel ID display — monospace để dễ đọc mã
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: HD.paperSunken,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop_outlined,
                      size: 16, color: HD.inkMuted),
                  const SizedBox(width: 8),
                  Text(
                    l.planErrParcelId(widget.parcelId),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: HD.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reason field
            TextField(
              controller: _reasonCtrl,
              maxLines: 5,
              maxLength: 500, // Pydantic max_length=500 ở backend
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: l.planErrReasonLabel,
                hintText: l.planErrReasonHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Image picker row
            Row(
              children: [
                OutlinedButton.icon(
                  icon: Icon(
                    _imageUrl != null
                        ? Icons.check_circle_outline
                        : Icons.camera_alt_outlined,
                    size: 18,
                  ),
                  label: Text(_imageUrl != null
                      ? l.planErrImageAttached
                      : l.planErrAttachImage),
                  onPressed: _uploading ? null : _pickImage,
                ),
                if (_uploading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.planErrUploading,
                    style: const TextStyle(fontSize: 12, color: HD.inkMuted),
                  ),
                ],
                if (_imageUrl != null && !_uploading)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: l.planErrRemoveImage,
                    onPressed: _clearImage,
                  ),
              ],
            ),

            const Spacer(),

            // Submit button — full width
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_submitting || _uploading) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l.planErrSubmit),
              ),
            ),

            // Safe area bottom padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
