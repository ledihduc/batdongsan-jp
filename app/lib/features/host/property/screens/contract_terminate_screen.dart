import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/permissions/role_guard.dart';
import 'package:house_booking/core/permissions/with_camera_permission.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Screen: Move-out flow (C5/C6) — pick actual end date, refund amount,
/// damage note, and damage photos.
class ContractTerminateScreen extends StatefulWidget {
  final int contractId;

  const ContractTerminateScreen({super.key, required this.contractId});

  @override
  State<ContractTerminateScreen> createState() =>
      _ContractTerminateScreenState();
}

class _ContractTerminateScreenState extends State<ContractTerminateScreen> {
  String? _actualEndDate;
  final _refundCtrl = TextEditingController();
  final _damageNoteCtrl = TextEditingController();
  bool _saving = false;

  // Damage photos (C3)
  final List<String> _damagePhotoUrls = [];
  bool _uploadingPhoto = false;

  static final _fmt = DateFormat('dd/MM/yyyy');
  static final _iso = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _refundCtrl.dispose();
    _damageNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('vi'),
    );
    if (picked == null) return;
    setState(() => _actualEndDate = _iso.format(picked));
  }

  Future<void> _pickDamagePhoto() async {
    final l = AppLocalizations.of(context);
    final userId = Provider.of<AuthProvider>(context, listen: false)
            .currentUser
            ?.id
            ?.toString() ??
        '';
    final picked = await withCameraPermission(
      context,
      source: ImageSource.gallery,
      primingContext: CameraContext.contractTerminatePhoto,
      userId: userId,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      // XFile.readAsBytes() is web-safe — works without dart:io.
      final bytes = await picked.readAsBytes();
      final client = ApiClient();
      final url = await client.uploadImage(bytes, picked.name);
      if (mounted) setState(() => _damagePhotoUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.hContractTermUploadFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (!RoleGuard.enforceHost(context, action: l.hContractTermActionEnd)) {
      return;
    }
    if (_actualEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hContractTermPickDateFirst)),
      );
      return;
    }

    // H1: confirmation dialog before destructive terminate
    final ok = await showDsConfirm(
      context: context,
      eyebrow: l.hContractTermEnd,
      title: l.hContractTermConfirmTitle,
      message: l.hContractTermConfirmMessage,
      confirmLabel: l.hContractTermEnd,
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    final provider = context.read<ContractProvider>();
    final result = await provider.terminateContract(
      widget.contractId,
      actualEndDate: _actualEndDate!,
      depositRefundAmount: double.tryParse(_refundCtrl.text) ?? 0,
      damageNote: _damageNoteCtrl.text.trim().isEmpty
          ? null
          : _damageNoteCtrl.text.trim(),
      damagePhotos: List<String>.from(_damagePhotoUrls),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hContractTermDoneEnded)),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? l.hContractTermFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.hContractTermMoveOut, eyebrow: l.hContractTermEnd),
      body: ListView(
        padding: const EdgeInsets.all(HD.s16),
        children: [
          Text(
            l.hContractTermIntro,
            style: HD.body(color: HD.inkSoft),
          ),
          const SizedBox(height: HD.s16),

          // Actual end date — read-only text field with date picker
          DsTextField(
            label: l.hContractTermActualEndDate,
            hint: _actualEndDate == null
                ? l.hContractTermPickDate
                : _fmt.format(DateTime.parse(_actualEndDate!)),
            prefixIcon: Icons.calendar_today_outlined,
            readOnly: true,
            onTap: _pickDate,
          ),
          const SizedBox(height: HD.s12),

          DsTextField(
            controller: _refundCtrl,
            label: l.hContractTermRefundAmount,
            helper: l.hContractTermRefundHelper,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: HD.s12),

          DsTextField(
            controller: _damageNoteCtrl,
            label: l.hContractTermDamageNote,
            helper: l.hContractTermDamageNoteHelper,
            maxLines: 3,
          ),
          const SizedBox(height: HD.s16),

          // Damage photos (C3)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.hContractTermDamagePhotos, style: HD.bodyBold()),
              DsButton(
                label: l.hContractTermAddPhoto,
                icon: Icons.add_photo_alternate_outlined,
                variant: DsButtonVariant.ghost,
                size: DsButtonSize.compact,
                onPressed: _uploadingPhoto ? null : _pickDamagePhoto,
              ),
            ],
          ),
          if (_uploadingPhoto)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: HD.s8),
              child: LinearProgressIndicator(
                color: HD.accent,
                backgroundColor: HD.hairline,
              ),
            ),
          if (_damagePhotoUrls.isNotEmpty) ...[
            const SizedBox(height: HD.s8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _damagePhotoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: HD.s8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(HD.r4),
                      child: Image.network(
                        _damagePhotoUrls[i],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _damagePhotoUrls.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: HD.negative,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: HD.paperRaised,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: HD.s24),
          DsButton(
            label: l.hContractTermConfirmMoveOut,
            variant: DsButtonVariant.destructive,
            expand: true,
            isLoading: _saving,
            onPressed: (_saving || _uploadingPhoto) ? null : _submit,
          ),
        ],
      ),
    );
  }
}
