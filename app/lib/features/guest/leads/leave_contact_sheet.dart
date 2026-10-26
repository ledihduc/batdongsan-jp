import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lead_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Bottom-sheet "Để lại SĐT, chúng tôi gọi lại" — thu Tên + SĐT (không cần
/// login) tại khoảnh khắc giá trị. [source] cho biết ngữ cảnh (save_home,
/// booking_consult, contact_host, provider_interest…) để admin tư vấn đúng.
/// POST /api/leads. TÁCH khỏi RFQ báo giá thi công (showRfqSheet).
Future<void> showLeaveContactSheet(
  BuildContext context, {
  required String source,
  String? note,
  String? world,
  String? provinceCode,
  LeadApi api = const LeadApi(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HD.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _LeadForm(
        source: source,
        presetNote: note,
        world: world,
        provinceCode: provinceCode,
        api: api,
      ),
    ),
  );
}

class _LeadForm extends StatefulWidget {
  const _LeadForm({
    required this.source,
    required this.api,
    this.presetNote,
    this.world,
    this.provinceCode,
  });
  final String source;
  final String? presetNote;
  final String? world;
  final String? provinceCode;
  final LeadApi api;

  @override
  State<_LeadForm> createState() => _LeadFormState();
}

class _LeadFormState extends State<_LeadForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.presetNote != null) _note.text = widget.presetNote!;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.length < 9) {
      setState(() => _error = l.leadValidation);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.submit(
        name: name,
        phone: phone,
        source: widget.source,
        note: _note.text,
        world: widget.world,
        provinceCode: widget.provinceCode,
      );
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _error = l.leadSendError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_done) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: HD.positive,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              l.leadSuccessTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: HD.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.leadSuccessBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HD.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(l.leadClose),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HD.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.leadSheetTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: HD.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l.leadSheetSubtitle,
              style: const TextStyle(color: HD.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _field(_name, l.leadFieldName, TextInputType.name),
            const SizedBox(height: 10),
            _field(
              _phone,
              l.leadFieldPhone,
              TextInputType.phone,
              digitsOnly: true,
            ),
            const SizedBox(height: 10),
            _field(_note, l.leadFieldNote, TextInputType.multiline, lines: 2),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: HD.negative)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.leadSubmit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    TextInputType type, {
    int lines = 1,
    bool digitsOnly = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLines: lines,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: HD.paperRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HD.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HD.hairline),
        ),
      ),
    );
  }
}
