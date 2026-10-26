import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.changePassword(
      _oldCtrl.text.trim(),
      _newCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l.chgpwdSuccess : (auth.errorMessage ?? l.chgpwdFailed),
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: DsAppBar(title: l.changePassword),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _oldCtrl,
                obscureText: !_showOld,
                decoration: InputDecoration(
                  labelText: l.chgpwdCurrentLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showOld ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _showOld = !_showOld),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? l.chgpwdRequired : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newCtrl,
                obscureText: !_showNew,
                decoration: InputDecoration(
                  labelText: l.chgpwdNewLabel,
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNew ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.chgpwdRequired;
                  if (v.length < 6) return l.chgpwdMinLength;
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  labelText: l.chgpwdConfirmLabel,
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.chgpwdRequired;
                  if (v != _newCtrl.text) return l.chgpwdMismatch;
                  return null;
                },
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l.changePassword,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
