/// JP property info edit section for the listing edit form.
///
/// Provides form inputs for 間取り, 専有面積, 築年数, 構造, 階数, 向き, 入居可能日.
/// Mount in the host/sales listing edit screen when `FeatureFlags.isJapan`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_property_info.dart';
import 'package:house_booking/l10n/app_localizations.dart';

const _kLayouts = [
  '1R', '1K', '1DK', '1LDK', '2K', '2DK', '2LDK',
  '3DK', '3LDK', '4LDK', '4LDK+',
];

const _kStructures = [
  JpStructure.rc,
  JpStructure.wood,
  JpStructure.steel,
  JpStructure.src,
];

const _kOrientations = [
  JpOrientation.n, JpOrientation.ne, JpOrientation.e, JpOrientation.se,
  JpOrientation.s, JpOrientation.sw, JpOrientation.w, JpOrientation.nw,
];

class JpPropertyInfoEditSection extends StatefulWidget {
  const JpPropertyInfoEditSection({
    super.key,
    required this.onChanged,
    this.initialInfo,
  });

  final void Function(Map<String, dynamic> values) onChanged;
  final JpPropertyInfo? initialInfo;

  @override
  State<JpPropertyInfoEditSection> createState() =>
      _JpPropertyInfoEditSectionState();
}

class _JpPropertyInfoEditSectionState
    extends State<JpPropertyInfoEditSection> {
  String _layout = '1K';
  JpStructure _structure = JpStructure.rc;
  JpOrientation _orientation = JpOrientation.unknown;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _floorCtrl;
  late final TextEditingController _totalFloorsCtrl;
  String? _availableFrom;

  @override
  void initState() {
    super.initState();
    final info = widget.initialInfo;
    _layout = info?.layout ?? '1K';
    _structure = info?.structure ?? JpStructure.rc;
    _orientation = info?.orientation ?? JpOrientation.unknown;
    _areaCtrl = TextEditingController(
        text: info?.floorAreaM2.toStringAsFixed(1) ?? '');
    _yearCtrl = TextEditingController(
        text: info?.buildingYear.toString() ?? '');
    _floorCtrl = TextEditingController(
        text: info?.floorNumber?.toString() ?? '');
    _totalFloorsCtrl = TextEditingController(
        text: info?.totalFloors?.toString() ?? '');
    _availableFrom = info?.availableFrom;

    for (final c in [_areaCtrl, _yearCtrl, _floorCtrl, _totalFloorsCtrl]) {
      c.addListener(_notify);
    }
  }

  @override
  void dispose() {
    for (final c in [_areaCtrl, _yearCtrl, _floorCtrl, _totalFloorsCtrl]) {
      c.removeListener(_notify);
      c.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged({
      'layout': _layout,
      'floor_area_m2': double.tryParse(_areaCtrl.text) ?? 0,
      'building_year': int.tryParse(_yearCtrl.text) ?? 0,
      'structure': jpStructureToString(_structure),
      'floor_number': int.tryParse(_floorCtrl.text),
      'total_floors': int.tryParse(_totalFloorsCtrl.text),
      'orientation': jpOrientationToString(_orientation),
      'available_from': _availableFrom,
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: '入居可能日を選択',
    );
    if (picked != null) {
      setState(() {
        _availableFrom =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DsFormSection(
      title: '物件情報',
      children: [
        // 間取り
        DropdownButtonFormField<String>(
          value: _layout,
          decoration: InputDecoration(
            labelText: l.jp_layout,
            border: const OutlineInputBorder(),
          ),
          items: _kLayouts
              .map((lt) => DropdownMenuItem(value: lt, child: Text(lt)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _layout = v);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        // 専有面積
        DsTextField(
          controller: _areaCtrl,
          label: '${l.jp_floor_area}（㎡）',
          hint: '45.0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return '面積を入力してください';
            final n = double.tryParse(v);
            if (n == null || n <= 0) return '正の数値を入力してください';
            return null;
          },
        ),
        // 築年数
        DsTextField(
          controller: _yearCtrl,
          label: l.jp_building_year,
          hint: '2015',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return '築年を入力してください';
            final n = int.tryParse(v);
            if (n == null || n < 1900 || n > DateTime.now().year) {
              return '1900〜${DateTime.now().year}の範囲で入力してください';
            }
            return null;
          },
        ),
        // 構造
        DropdownButtonFormField<JpStructure>(
          value: _structure,
          decoration: InputDecoration(
            labelText: '構造',
            border: const OutlineInputBorder(),
          ),
          items: _kStructures
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(_structureLabel(s, l)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _structure = v);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        // 階数
        Row(
          children: [
            Expanded(
              child: DsTextField(
                controller: _floorCtrl,
                label: l.jp_floor,
                hint: '3',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DsTextField(
                controller: _totalFloorsCtrl,
                label: '総階数',
                hint: '10',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        // 向き
        DropdownButtonFormField<JpOrientation>(
          value: _orientation,
          decoration: InputDecoration(
            labelText: '向き',
            border: const OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: JpOrientation.unknown,
              child: Text('指定なし'),
            ),
            ..._kOrientations.map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(_orientationLabel(o, l)),
              ),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _orientation = v);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        // 入居可能日
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: HD.hairline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available_outlined,
                    size: 18, color: HD.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _availableFrom ?? l.jp_available_from,
                    style: TextStyle(
                      color:
                          _availableFrom != null ? HD.ink : HD.inkMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: HD.inkMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _structureLabel(JpStructure s, AppLocalizations l) {
    switch (s) {
      case JpStructure.rc:
        return l.jp_structure_rc;
      case JpStructure.wood:
        return l.jp_structure_wood;
      case JpStructure.steel:
        return l.jp_structure_steel;
      case JpStructure.src:
        return l.jp_structure_src;
      case JpStructure.unknown:
        return '不明';
    }
  }

  static String _orientationLabel(JpOrientation o, AppLocalizations l) {
    switch (o) {
      case JpOrientation.n:
        return l.jp_orientation_n;
      case JpOrientation.ne:
        return l.jp_orientation_ne;
      case JpOrientation.e:
        return l.jp_orientation_e;
      case JpOrientation.se:
        return l.jp_orientation_se;
      case JpOrientation.s:
        return l.jp_orientation_s;
      case JpOrientation.sw:
        return l.jp_orientation_sw;
      case JpOrientation.w:
        return l.jp_orientation_w;
      case JpOrientation.nw:
        return l.jp_orientation_nw;
      case JpOrientation.unknown:
        return '不明';
    }
  }
}
