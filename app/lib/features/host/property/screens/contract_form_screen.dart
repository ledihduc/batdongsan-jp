import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/permissions/with_camera_permission.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/property/widgets/tenant_input_row.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';

import 'contract_form_billing_section.dart';
import 'contract_form_parties_section.dart';

/// Screen: Create a new contract for a room.
///
/// Supports multiple tenants (C8 roommates) — add/remove rows dynamically.
/// All per-tenant state lives in [TenantRowData] owned by this screen,
/// keyed by UUID to prevent state corruption when a middle row is removed (C4).
class ContractFormScreen extends StatefulWidget {
  final int roomId;
  final double? initialMonthlyRent;

  const ContractFormScreen({
    super.key,
    required this.roomId,
    this.initialMonthlyRent,
  });

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rentCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  // Monotonically increasing counter used to generate stable, unique IDs
  // for tenant rows without needing an external uuid package.
  int _nextRowId = 0;

  String? _startDate;
  String? _endDate;
  bool _saving = false;

  // Handover photos (C2)
  final List<String> _handoverPhotoUrls = [];
  bool _uploadingPhoto = false;

  static final _fmt = DateFormat('dd/MM/yyyy');
  static final _iso = DateFormat('yyyy-MM-dd');

  // Tenant rows — owner holds all per-tenant state (C4 fix)
  late final List<TenantRowData> _tenantRows;

  @override
  void initState() {
    super.initState();
    if ((widget.initialMonthlyRent ?? 0) > 0) {
      _rentCtrl.text = (widget.initialMonthlyRent ?? 0).toStringAsFixed(0);
    }
    // Seed first row as primary
    _tenantRows = [TenantRowData(uuid: '${_nextRowId++}', initialPrimary: true)];
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    for (final row in _tenantRows) {
      row.dispose();
    }
    super.dispose();
  }

  // ── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart
        ? (_startDate != null ? DateTime.parse(_startDate!) : DateTime.now())
        : (_endDate != null
            ? DateTime.parse(_endDate!)
            : DateTime.now().add(const Duration(days: 365)));
    final first = isStart
        ? DateTime.now()
        : (_startDate != null ? DateTime.parse(_startDate!) : DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: const Locale('vi'),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = _iso.format(picked);
        // H8: if new start >= existing end, clear end so user must re-pick
        if (_endDate != null &&
            !picked.isBefore(DateTime.parse(_endDate!))) {
          _endDate = null;
        }
      } else {
        _endDate = _iso.format(picked);
      }
    });
  }

  // ── Handover photo upload (C2) ────────────────────────────────────────────

  Future<void> _pickHandoverPhoto() async {
    final userId = Provider.of<AuthProvider>(context, listen: false)
            .currentUser
            ?.id
            ?.toString() ??
        '';
    final picked = await withCameraPermission(
      context,
      source: ImageSource.gallery,
      primingContext: CameraContext.contractPhoto,
      userId: userId,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      // XFile.readAsBytes() is web-safe — works without dart:io.
      final bytes = await picked.readAsBytes();
      final client = ApiClient();
      final url = await client.uploadImage(bytes, picked.name);
      if (mounted) setState(() => _handoverPhotoUrls.add(url));
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.hContractFormPhotoUploadFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── CCCD photo upload (per tenant, C2) ───────────────────────────────────

  Future<void> _pickCccdPhoto(TenantRowData row, bool isFront) async {
    final userId = Provider.of<AuthProvider>(context, listen: false)
            .currentUser
            ?.id
            ?.toString() ??
        '';
    final picked = await withCameraPermission(
      context,
      source: ImageSource.gallery,
      primingContext: CameraContext.contractPhoto,
      userId: userId,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final client = ApiClient();
      final url = await client.uploadImage(bytes, picked.name);
      if (mounted) {
        setState(() {
          if (isFront) {
            row.cccdFrontUrl = url;
          } else {
            row.cccdBackUrl = url;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.hContractFormCccdUploadFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Tenant management ─────────────────────────────────────────────────────

  void _addTenant() {
    setState(() {
      _tenantRows.add(
          TenantRowData(uuid: '${_nextRowId++}', initialPrimary: false));
    });
  }

  void _removeTenant(int index) {
    setState(() {
      _tenantRows[index].dispose(); // dispose controllers of removed row only
      _tenantRows.removeAt(index);
    });
  }

  /// When user sets row [index] as primary, clear all others.
  void _onTenantChanged(int index) {
    final row = _tenantRows[index];
    if (row.isPrimary) {
      // Ensure single primary (C4 fix)
      for (var i = 0; i < _tenantRows.length; i++) {
        if (i != index && _tenantRows[i].isPrimary) {
          _tenantRows[i].isPrimary = false;
        }
      }
    }
    setState(() {}); // trigger rebuild
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final l = AppLocalizations.of(context);

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hContractFormSelectDates)),
      );
      return;
    }

    // H8: enforce start < end
    final start = DateTime.parse(_startDate!);
    final end = DateTime.parse(_endDate!);
    if (!start.isBefore(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hContractFormEndAfterStart)),
      );
      return;
    }

    // Validate exactly 1 primary
    final primaryCount = _tenantRows.where((r) => r.isPrimary).length;
    if (primaryCount != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hContractFormOnePrimary)),
      );
      return;
    }

    final emptyName = _tenantRows.any(
        (r) => r.fullNameCtrl.text.trim().isEmpty);
    if (emptyName) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hContractFormTenantNameRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<ContractProvider>();
    final result = await provider.createContract(
      roomId: widget.roomId,
      startDate: _startDate!,
      endDate: _endDate!,
      monthlyRent: double.tryParse(_rentCtrl.text) ?? 0,
      deposit: double.tryParse(_depositCtrl.text) ?? 0,
      handoverPhotos: List<String>.from(_handoverPhotoUrls),
      tenants: _tenantRows.map((r) => r.toMap()).toList(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hContractFormCreated)),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? l.hContractFormCreateFailed)),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primaryCount = _tenantRows.where((r) => r.isPrimary).length;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
          title: l.hContractFormTitle, eyebrow: l.hContractFormEyebrow),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(HD.s16),
          children: [
            // Date pickers
            Row(
              children: [
                Expanded(
                  child: ContractFormDatePicker(
                    label: l.hContractFormStartDate,
                    value: _startDate != null
                        ? _fmt.format(DateTime.parse(_startDate!))
                        : null,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: ContractFormDatePicker(
                    label: l.hContractFormEndDate,
                    value: _endDate != null
                        ? _fmt.format(DateTime.parse(_endDate!))
                        : null,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HD.s12),

            DsTextField(
              controller: _rentCtrl,
              label: l.hContractFormMonthlyRent,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return l.hContractFormRentInvalid;
                return null;
              },
            ),
            const SizedBox(height: HD.s12),

            DsTextField(
              controller: _depositCtrl,
              label: l.hContractFormDeposit,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: HD.s16),
            const HDHairline(),
            const SizedBox(height: HD.s16),

            // Handover photos section (C2)
            ContractFormHandoverPhotos(
              photoUrls: _handoverPhotoUrls,
              isUploading: _uploadingPhoto,
              onAddPhoto: _pickHandoverPhoto,
              onRemovePhoto: (i) => setState(() => _handoverPhotoUrls.removeAt(i)),
            ),
            const SizedBox(height: HD.s16),
            const HDHairline(),
            const SizedBox(height: HD.s16),

            // Tenants section
            ContractFormTenantsSection(
              tenantRows: _tenantRows,
              primaryCount: primaryCount,
              onAddTenant: _addTenant,
              onChanged: _onTenantChanged,
              onRemove: _removeTenant,
              onPickCccdFront: (row) => _pickCccdPhoto(row, true),
              onPickCccdBack: (row) => _pickCccdPhoto(row, false),
            ),

            const SizedBox(height: HD.s24),
            DsButton(
              label: l.hContractFormSubmit,
              expand: true,
              isLoading: _saving,
              onPressed: (_saving || _uploadingPhoto) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
