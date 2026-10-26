import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';

/// Chủ nhà cấu hình khung giờ nhận đặt xem nhà: chọn thứ trong tuần + chọn
/// các khung giờ (1 tiếng) sẽ tiếp khách. Chưa cấu hình = mở mặc định tất cả.
class HostAvailabilityScreen extends StatefulWidget {
  final int houseId;
  final String? houseTitle;
  const HostAvailabilityScreen({
    super.key,
    required this.houseId,
    this.houseTitle,
  });

  @override
  State<HostAvailabilityScreen> createState() => _HostAvailabilityScreenState();
}

class _HostAvailabilityScreenState extends State<HostAvailabilityScreen> {
  final Set<int> _weekdays = {};
  final Set<String> _slots = {};
  List<String> _allSlots = const [];
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider =
        Provider.of<ViewingAppointmentProvider>(context, listen: false);
    await provider.loadHostAvailability(widget.houseId);
    final cfg = provider.hostAvailability;
    if (cfg == null || !mounted) return;
    setState(() {
      _weekdays
        ..clear()
        ..addAll(cfg.weekdays);
      _slots
        ..clear()
        ..addAll(cfg.slots);
      _allSlots = cfg.allSlots;
      _seeded = true;
    });
  }

  Future<void> _save() async {
    final provider =
        Provider.of<ViewingAppointmentProvider>(context, listen: false);
    final weekdays = _weekdays.toList()..sort();
    final slots = _allSlots.where(_slots.contains).toList();
    final ok = await provider.saveHostAvailability(
        widget.houseId, weekdays, slots);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? l.hAvailSavedToast
            : (provider.availabilityError ?? l.hAvailSaveFailed)),
        backgroundColor: ok ? HD.positive : Theme.of(context).colorScheme.error,
      ),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = Provider.of<ViewingAppointmentProvider>(context);
    final loading = provider.availabilityLoading && !_seeded;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: widget.houseTitle,
        title: l.hAvailTitle,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _intro(),
                  const SizedBox(height: 20),
                  _sectionTitle(l.hAvailWeekdaysSection),
                  const SizedBox(height: 10),
                  _weekdayPicker(),
                  const SizedBox(height: 24),
                  _sectionTitle(l.hAvailSlotsSection),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _slots.addAll(_allSlots)),
                        child: Text(l.hAvailSelectAll),
                      ),
                      TextButton(
                        onPressed: () => setState(_slots.clear),
                        child: Text(l.hAvailDeselect),
                      ),
                    ],
                  ),
                  _slotPicker(),
                  const SizedBox(height: 16),
                  if (_weekdays.isEmpty || _slots.isEmpty) _emptyWarning(),
                  const SizedBox(height: 24),
                  provider.availabilitySaving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _save,
                          child: Text(l.hAvailSave),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _intro() {
    final l = AppLocalizations.of(context);
    final isDefault = _weekdays.length == 7 && _slots.length == _allSlots.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HD.positiveTint.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HD.positive.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_available_outlined, color: HD.positive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDefault ? l.hAvailIntroDefault : l.hAvailIntroCustom,
              style: const TextStyle(
                  color: HD.ink, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: HD.ink,
        ),
      );

  Widget _weekdayPicker() {
    final l = AppLocalizations.of(context);
    final labels = [
      l.hAvailMon,
      l.hAvailTue,
      l.hAvailWed,
      l.hAvailThu,
      l.hAvailFri,
      l.hAvailSat,
      l.hAvailSun,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (i) {
        final selected = _weekdays.contains(i);
        return FilterChip(
          selected: selected,
          label: Text(labels[i]),
          onSelected: (val) => setState(() {
            if (val) {
              _weekdays.add(i);
            } else {
              _weekdays.remove(i);
            }
          }),
        );
      }),
    );
  }

  Widget _slotPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allSlots.map((slot) {
        final selected = _slots.contains(slot);
        return FilterChip(
          selected: selected,
          label: Text(slot.replaceAll('-', ' - ')),
          onSelected: (val) => setState(() {
            if (val) {
              _slots.add(slot);
            } else {
              _slots.remove(slot);
            }
          }),
        );
      }).toList(),
    );
  }

  Widget _emptyWarning() {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.negativeTint.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.negative.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: HD.negative, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.hAvailEmptyWarning,
              style: const TextStyle(color: HD.negative, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
