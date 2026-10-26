import 'dart:io' show File;
import 'dart:typed_data';
import 'package:house_booking/core/widgets/ds.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/permissions/with_camera_permission.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// CCCD image uploader with preview.
///
/// Picks a photo from gallery (and camera on native).
///
/// Emits the picked [XFile] via [onImageSelected] so the caller can upload
/// it uniformly (we read bytes server-side in the repository).
class CccdUploader extends StatefulWidget {
  const CccdUploader({
    super.key,
    required this.label,
    required this.onImageSelected,
    this.isUploaded = false,
  });

  final String label;
  final void Function(XFile file) onImageSelected;
  final bool isUploaded;

  @override
  State<CccdUploader> createState() => _CccdUploaderState();
}

class _CccdUploaderState extends State<CccdUploader> {
  XFile? _picked;
  Uint8List? _previewBytes;

  Future<void> _pickImage(ImageSource source) async {
    final userId = Provider.of<AuthProvider>(context, listen: false)
            .currentUser
            ?.id
            ?.toString() ??
        '';
    final picked = await withCameraPermission(
      context,
      source: source,
      primingContext: CameraContext.cccdUpload,
      userId: userId,
    );
    if (picked == null) return;

    final finalFile = picked;
    final bytes = await finalFile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _picked = finalFile;
      _previewBytes = bytes;
    });
    widget.onImageSelected(finalFile);
  }

  void _showPicker() {
    // On web, image_picker maps both camera + gallery to the same file input
    // dialog, so showing only "Chọn ảnh" is cleaner. On native we offer both.
    if (kIsWeb) {
      _pickImage(ImageSource.gallery);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HD.r12)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: HD.inkSoft),
              title: Text('Chụp ảnh', style: HD.body(color: HD.ink)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: HD.inkSoft),
              title: Text('Chọn từ thư viện', style: HD.body(color: HD.ink)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    // Web: use bytes (Image.file relies on dart:io which is unavailable).
    // Native: prefer File so the OS-level image cache kicks in.
    if (_previewBytes != null && kIsWeb) {
      return Image.memory(_previewBytes!, fit: BoxFit.cover);
    }
    if (_picked != null && !kIsWeb) {
      return Image.file(File(_picked!.path), fit: BoxFit.cover);
    }
    if (_previewBytes != null) {
      return Image.memory(_previewBytes!, fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = _picked != null;
    final isDone = hasLocal || widget.isUploaded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: HD.bodyBold(size: 13)),
        const SizedBox(height: HD.s8),
        GestureDetector(
          onTap: _showPicker,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: isDone
                  ? HD.positiveTint
                  : HD.paperSunken,
              borderRadius: BorderRadius.circular(HD.r8),
              border: Border.all(
                color: isDone ? HD.positive : HD.hairline,
                width: 1.5,
              ),
            ),
            child: hasLocal
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(HD.r8 - 1),
                    child: _preview(),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle_outline
                            : Icons.add_photo_alternate_outlined,
                        size: 36,
                        color: isDone ? HD.positive : HD.inkMuted,
                      ),
                      const SizedBox(height: HD.s8),
                      Text(
                        isDone ? 'Đã tải lên' : 'Nhấn để tải ảnh',
                        style: HD.body(
                          size: 13,
                          color: isDone ? HD.positive : HD.inkMuted,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
