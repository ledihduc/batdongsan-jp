/// JP 内見リクエスト (viewing request) bottom sheet.
///
/// Tenant selects up to 3 preferred time slots from a date/time picker, adds
/// an optional message, then submits the request to the agent.
///
/// Use [showViewingRequestSheet] to present.
///
/// Route: n/a (push-based DsBottomSheet — no URL).
/// Provider: none — receives [listingId]; calls [IJpViewingRepository.create].
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_viewing.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_viewing_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_viewing_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Shows the viewing request sheet modally and resolves with the created
/// [JpViewing] on success, or null if the user dismissed without submitting.
Future<JpViewing?> showViewingRequestSheet(
  BuildContext context, {
  required int listingId,
  IJpViewingRepository? repository,
}) async {
  return showModalBottomSheet<JpViewing>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ViewingRequestSheetContent(
      listingId: listingId,
      repository: repository ?? MockJpViewingRepository(),
    ),
  );
}

class _ViewingRequestSheetContent extends StatefulWidget {
  const _ViewingRequestSheetContent({
    required this.listingId,
    required this.repository,
  });

  final int listingId;
  final IJpViewingRepository repository;

  @override
  State<_ViewingRequestSheetContent> createState() =>
      _ViewingRequestSheetContentState();
}

class _ViewingRequestSheetContentState
    extends State<_ViewingRequestSheetContent> {
  final List<JpViewingSlot> _slots = [];
  final _messageCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const int _maxSlots = 3;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSlot() async {
    if (_slots.length >= _maxSlots) {
      final l = AppLocalizations.of(context);
      setState(() => _error = l.jp_slots_max_warning);
      return;
    }

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 2)),
      firstDate: now.add(const Duration(hours: 24)),
      lastDate: now.add(const Duration(days: 60)),
      helpText: '希望日を選択',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: '希望時間を選択',
    );
    if (time == null || !mounted) return;

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _slots.add(JpViewingSlot(startAt: start.toIso8601String()));
      _error = null;
    });
  }

  void _removeSlot(int index) {
    setState(() => _slots.removeAt(index));
  }

  Future<void> _submit() async {
    if (_slots.isEmpty) {
      final l = AppLocalizations.of(context);
      setState(() => _error = l.jp_select_slots);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final viewing = await widget.repository.create(
        listingId: widget.listingId,
        proposedSlots: List<JpViewingSlot>.from(_slots),
        message: _messageCtrl.text.trim().isEmpty
            ? null
            : _messageCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(viewing);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'エラーが発生しました。もう一度お試しください。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => DsBottomSheet(
        title: l.jp_viewing_request,
        child: ListView(
          controller: scrollCtrl,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            // Hint
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l.jp_slots_hint,
                style: const TextStyle(fontSize: 13, color: HD.inkMuted),
              ),
            ),
            // Slot list
            ..._slots.asMap().entries.map((e) {
              final idx = e.key;
              final slot = e.value;
              final dt = DateTime.tryParse(slot.startAt);
              final label = dt == null
                  ? slot.startAt
                  : '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: HD.accentTint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HD.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: HD.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l.jp_slot_label(idx + 1)}: $label',
                          style: const TextStyle(
                              color: HD.accent, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeSlot(idx),
                        child: const Icon(Icons.close,
                            size: 16, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Add slot button
            if (_slots.length < _maxSlots)
              TextButton.icon(
                onPressed: _pickSlot,
                icon: const Icon(Icons.add_circle_outline, color: HD.accent),
                label: Text(
                  '希望日時を追加（${_slots.length}/$_maxSlots）',
                  style: const TextStyle(color: HD.accent),
                ),
              ),
            const SizedBox(height: 12),
            // Message
            DsTextField(
              controller: _messageCtrl,
              label: 'メッセージ（任意）',
              hint: 'ご不明点やご要望をご記入ください',
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: HD.accent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            DsButton(
              label: _submitting ? '送信中...' : l.jp_submit,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
