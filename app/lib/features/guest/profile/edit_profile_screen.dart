import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/permissions/with_camera_permission.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _api = const ApiClient();

  String? _avatarUrl;
  XFile? _pickedFile;
  Uint8List? _pickedBytes;
  DateTime? _birthday;

  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    _nameCtrl.text = user.name;
    _emailCtrl.text = user.email;
    _phoneCtrl.text = user.phone;
    _bioCtrl.text = user.bio ?? '';
    _idNumberCtrl.text = user.idNumber ?? '';
    _avatarUrl = user.avatarPath;
    if (user.birthday != null && user.birthday!.isNotEmpty) {
      try {
        _birthday = DateTime.parse(user.birthday!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final userId =
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.id?.toString() ??
        '';
    // withCameraPermission wraps the priming check + picker call.
    // maxWidth/imageQuality not forwarded — image_picker default is acceptable
    // for avatar (caller can apply transformations post-pick if needed).
    final file = await withCameraPermission(
      context,
      source: ImageSource.gallery,
      primingContext: CameraContext.profileAvatar,
      userId: userId,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedFile = file;
      _pickedBytes = bytes;
      _isUploading = true;
    });
    try {
      final url = await _api.uploadImage(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).editProfUploadError(e.toString()),
          ),
        ),
      );
    }
  }

  /// Đổi ẢNH BÌA chủ nhà (chỉ role=host). Upload → PATCH host cover_path.
  Future<void> _pickCover() async {
    final userId =
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.id?.toString() ??
        '';
    final file = await withCameraPermission(
      context,
      source: ImageSource.gallery,
      primingContext: CameraContext.profileAvatar,
      userId: userId,
    );
    if (file == null) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await _api.uploadImage(bytes, file.name);
      if (!mounted) return;
      final ok = await context.read<HostProfileProvider>().updateCover(url);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? l.editProfCoverChanged : l.editProfCoverChangeFailed,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).editProfUploadError(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: AppLocalizations.of(context).editProfPickBirthday,
      locale: const Locale('vi'),
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  int? get _age {
    if (_birthday == null) return null;
    final now = DateTime.now();
    var y = now.year - _birthday!.year;
    final hadBday =
        now.month > _birthday!.month ||
        (now.month == _birthday!.month && now.day >= _birthday!.day);
    if (!hadBday) y -= 1;
    return y < 0 ? null : y;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_isUploading) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.editProfWaitUpload)));
      return;
    }

    setState(() => _isSaving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser!;

    final birthdayIso = _birthday == null
        ? null
        : '${_birthday!.year.toString().padLeft(4, '0')}-'
              '${_birthday!.month.toString().padLeft(2, '0')}-'
              '${_birthday!.day.toString().padLeft(2, '0')}';

    final newEmail = _emailCtrl.text.trim();
    final ok = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      avatarPath: _avatarUrl,
      email: newEmail == user.email ? null : newEmail,
      birthday: birthdayIso,
      bio: _bioCtrl.text.trim(),
      idNumber: _idNumberCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.editProfSaved), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      final msg = auth.errorMessage ?? l.editProfUpdateFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('Email đã được sử dụng') ? l.editProfEmailInUse : msg,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: l.editProfEyebrow, title: l.editProfile),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Section 1 — Avatar
              _buildAvatar(),
              // Ảnh bìa CHỈ cho chủ nhà (host) — member thường không có.
              if (Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).currentUser?.role ==
                  'host') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickCover,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(l.editProfChangeCover),
                ),
              ],
              const SizedBox(height: 32),

              // Section 2 — Thông tin cá nhân
              _sectionTitle(l.editProfSectionPersonal),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l.editProfFullName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.editProfRequired : null,
              ),
              const SizedBox(height: 14),
              _birthdayField(),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l.loginEmail,
                  helperText: l.editProfEmailHelper,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l.editProfRequired;
                  final ok = RegExp(
                    r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$',
                  ).hasMatch(v.trim());
                  if (!ok) return l.editProfEmailInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.editProfPhone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 28),

              // Section 3 — Giới thiệu
              _sectionTitle(l.editProfSectionIntro),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 4,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l.editProfBioLabel,
                  hintText: l.editProfBioHint,
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.info_outline),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Section 4 — Xác thực
              _sectionTitle(l.editProfSectionVerify),
              TextFormField(
                controller: _idNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.editProfIdNumber,
                  helperText: l.editProfIdHelper,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          l.editProfSave,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: HD.accentTint,
          backgroundImage: _pickedBytes != null
              ? (kIsWeb
                    ? MemoryImage(_pickedBytes!) as ImageProvider
                    : FileImage(File(_pickedFile!.path)))
              : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? NetworkImage(_avatarUrl!)
                    : null),
          child:
              (_avatarUrl == null || _avatarUrl!.isEmpty) &&
                  _pickedBytes == null
              ? const Icon(Icons.person, size: 48)
              : null,
        ),
        if (_isUploading)
          const Positioned.fill(
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isUploading ? null : _pickAvatar,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _birthdayField() {
    final l = AppLocalizations.of(context);
    final age = _age;
    final txt = _birthday == null
        ? l.editProfNotSelected
        : '${_birthday!.day.toString().padLeft(2, '0')}/'
              '${_birthday!.month.toString().padLeft(2, '0')}/'
              '${_birthday!.year}';
    return InkWell(
      onTap: _pickBirthday,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l.editProfBirthday,
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
          helperText: age == null ? null : l.editProfAge(age),
        ),
        child: Text(
          txt,
          style: TextStyle(color: _birthday == null ? HD.inkMuted : HD.ink),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: HD.inkMuted,
        ),
      ),
    ),
  );
}
