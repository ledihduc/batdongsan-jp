/// JP search facets drawer for filtering rental listings.
///
/// Provides: 間取り multi-select, 家賃 range slider, 面積 range slider,
/// 築年数 max, 駅徒歩 max, flag chips (ペット可/保証会社不要/楽器可/法人契約可).
///
/// Mount inside search_screen.dart when `FeatureFlags.isJapan`.
/// State is held inside the drawer — parent receives filters via [onApply].
///
/// Route: n/a (modal drawer, push-based).
/// Provider: none — stateful widget + callback.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_listing_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Current filter state passed to [onApply].
class JpSearchFilter {
  const JpSearchFilter({
    this.layouts = const [],
    this.minRent,
    this.maxRent,
    this.minAreaM2,
    this.maxAreaM2,
    this.maxBuildingAgeYears,
    this.maxWalkMinutes,
    this.petsOk = false,
    this.noGuarantorRequired = false,
    this.instrumentsOk = false,
    this.corporateOk = false,
  });

  final List<String> layouts;
  final int? minRent;
  final int? maxRent;
  final double? minAreaM2;
  final double? maxAreaM2;
  final int? maxBuildingAgeYears;
  final int? maxWalkMinutes;
  final bool petsOk;
  final bool noGuarantorRequired;
  final bool instrumentsOk;
  final bool corporateOk;

  JpListingSearchParams toSearchParams() => JpListingSearchParams(
        layouts: layouts.isEmpty ? null : layouts,
        minRent: minRent,
        maxRent: maxRent,
        minAreaM2: minAreaM2,
        maxAreaM2: maxAreaM2,
        maxBuildingAgeYears: maxBuildingAgeYears,
        maxWalkMinutes: maxWalkMinutes,
        petsOk: petsOk ? true : null,
        noGuarantorRequired: noGuarantorRequired ? true : null,
        instrumentsOk: instrumentsOk ? true : null,
        corporateOk: corporateOk ? true : null,
      );

  JpSearchFilter copyWith({
    List<String>? layouts,
    int? minRent,
    int? maxRent,
    double? minAreaM2,
    double? maxAreaM2,
    int? maxBuildingAgeYears,
    int? maxWalkMinutes,
    bool? petsOk,
    bool? noGuarantorRequired,
    bool? instrumentsOk,
    bool? corporateOk,
  }) {
    return JpSearchFilter(
      layouts: layouts ?? this.layouts,
      minRent: minRent ?? this.minRent,
      maxRent: maxRent ?? this.maxRent,
      minAreaM2: minAreaM2 ?? this.minAreaM2,
      maxAreaM2: maxAreaM2 ?? this.maxAreaM2,
      maxBuildingAgeYears: maxBuildingAgeYears ?? this.maxBuildingAgeYears,
      maxWalkMinutes: maxWalkMinutes ?? this.maxWalkMinutes,
      petsOk: petsOk ?? this.petsOk,
      noGuarantorRequired: noGuarantorRequired ?? this.noGuarantorRequired,
      instrumentsOk: instrumentsOk ?? this.instrumentsOk,
      corporateOk: corporateOk ?? this.corporateOk,
    );
  }
}

/// Common Japanese floor plan layout codes (full list).
const _kLayouts = ['1R', '1K', '1DK', '1LDK', '2K', '2DK', '2LDK', '3DK', '3LDK', '4LDK+'];

/// P3 enhanced quick-select layout presets — shown as prominent chips.
const _kQuickLayouts = ['1K', '1DK', '1LDK', '2LDK', '3LDK+'];

/// Drawer widget for JP listing search filters.
class JpSearchFacetsDrawer extends StatefulWidget {
  const JpSearchFacetsDrawer({
    super.key,
    required this.onApply,
    this.initialFilter = const JpSearchFilter(),
  });

  final void Function(JpSearchFilter filter) onApply;
  final JpSearchFilter initialFilter;

  @override
  State<JpSearchFacetsDrawer> createState() => _JpSearchFacetsDrawerState();
}

class _JpSearchFacetsDrawerState extends State<JpSearchFacetsDrawer> {
  late JpSearchFilter _filter;

  static const _minRentStep = 10000;
  static const _maxRentCap = 500000;
  static const _maxAreaCap = 200.0;
  static const _maxBuildingAgeCap = 50;
  static const _maxWalkMinCap = 30;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: HD.hairline)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: HD.accent),
                  const SizedBox(width: 8),
                  Text(
                    l.jp_search_facets_title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HD.ink,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text(
                      'リセット',
                      style: TextStyle(color: HD.accent),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  _sectionLabel(l.jp_layout_filter),
                  const SizedBox(height: 8),
                  _buildLayoutSelector(),
                  const SizedBox(height: 20),
                  _sectionLabel(l.jp_rent_range),
                  const SizedBox(height: 4),
                  _buildRentRange(),
                  const SizedBox(height: 20),
                  _sectionLabel(l.jp_area_range),
                  const SizedBox(height: 4),
                  _buildAreaRange(),
                  const SizedBox(height: 20),
                  _sectionLabel(l.jp_building_age_max),
                  const SizedBox(height: 4),
                  _buildBuildingAge(),
                  const SizedBox(height: 20),
                  // P3: Enhanced pets_ok toggle (prominent switch).
                  _sectionLabel(l.jp_facet_pets_ok_label),
                  const SizedBox(height: 4),
                  _buildPetsOkToggle(),
                  const SizedBox(height: 20),
                  // P3: walk_min slider (0-30 min).
                  _sectionLabel(l.jp_facet_walk_min_label),
                  const SizedBox(height: 4),
                  _buildWalkMin(),
                  const SizedBox(height: 20),
                  _sectionLabel('こだわり条件'),
                  const SizedBox(height: 8),
                  _buildFlagChips(l),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Sticky apply button
            Padding(
              padding: const EdgeInsets.all(16),
              child: DsButton(
                label: l.jp_submit,
                onPressed: () {
                  widget.onApply(_filter);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: HD.inkMuted,
      ),
    );
  }

  Widget _buildLayoutSelector() {
    // P3: Show quick-select preset row first, then full list.
    const quickLayouts = _kQuickLayouts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick-select row (5 presets).
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickLayouts.map((layout) {
            final selected = _filter.layouts.contains(layout);
            return FilterChip(
              label: Text(layout,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected ? HD.accent : HD.inkSoft)),
              selected: selected,
              selectedColor: HD.accentTint,
              checkmarkColor: HD.accent,
              side: BorderSide(color: selected ? HD.accent : HD.hairline),
              backgroundColor: HD.paperRaised,
              onSelected: (val) {
                setState(() {
                  final updated = List<String>.from(_filter.layouts);
                  if (val) {
                    updated.add(layout);
                  } else {
                    updated.remove(layout);
                  }
                  _filter = _filter.copyWith(layouts: updated);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Full list (remaining options not in quick-select).
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kLayouts
              .where((layout) => !quickLayouts.contains(layout))
              .map((layout) {
                final selected = _filter.layouts.contains(layout);
                return FilterChip(
                  label: Text(layout),
                  selected: selected,
                  selectedColor: HD.accentTint,
                  checkmarkColor: HD.accent,
                  labelStyle: TextStyle(
                    color: selected ? HD.accent : HD.inkSoft,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: selected ? HD.accent : HD.hairline,
                  ),
                  backgroundColor: HD.paperRaised,
                  onSelected: (val) {
                    setState(() {
                      final updated = List<String>.from(_filter.layouts);
                      if (val) {
                        updated.add(layout);
                      } else {
                        updated.remove(layout);
                      }
                      _filter = _filter.copyWith(layouts: updated);
                    });
                  },
                );
              })
              .toList(),
        ),
      ],
    );
  }

  /// P3: Dedicated pets_ok toggle switch (more prominent than a chip).
  Widget _buildPetsOkToggle() {
    return Material(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HD.hairline),
        ),
        child: SwitchListTile(
          value: _filter.petsOk,
          onChanged: (v) => setState(() => _filter = _filter.copyWith(petsOk: v)),
          activeColor: HD.accent,
          title: Text(
            'ペット可',
            style: HD.body(size: 14),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildRentRange() {
    final minRent = _filter.minRent?.toDouble() ?? 0;
    final maxRent = _filter.maxRent?.toDouble() ?? _maxRentCap.toDouble();
    return Column(
      children: [
        RangeSlider(
          values: RangeValues(minRent, maxRent),
          min: 0,
          max: _maxRentCap.toDouble(),
          divisions: (_maxRentCap ~/ _minRentStep),
          activeColor: HD.accent,
          onChanged: (v) {
            setState(() {
              _filter = _filter.copyWith(
                minRent: v.start.round(),
                maxRent: v.end.round(),
              );
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatYen(_filter.minRent ?? 0),
                style: const TextStyle(fontSize: 12, color: HD.inkSoft)),
            Text(_formatYen(_filter.maxRent ?? _maxRentCap),
                style: const TextStyle(fontSize: 12, color: HD.inkSoft)),
          ],
        ),
      ],
    );
  }

  Widget _buildAreaRange() {
    final minArea = _filter.minAreaM2 ?? 0;
    final maxArea = _filter.maxAreaM2 ?? _maxAreaCap;
    return Column(
      children: [
        RangeSlider(
          values: RangeValues(minArea, maxArea),
          min: 0,
          max: _maxAreaCap,
          divisions: 40,
          activeColor: HD.accent,
          labels: RangeLabels(
            '${minArea.toInt()}㎡',
            '${maxArea.toInt()}㎡',
          ),
          onChanged: (v) {
            setState(() {
              _filter = _filter.copyWith(
                minAreaM2: v.start,
                maxAreaM2: v.end,
              );
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${(_filter.minAreaM2 ?? 0).toInt()}㎡',
                style: const TextStyle(fontSize: 12, color: HD.inkSoft)),
            Text('${(_filter.maxAreaM2 ?? _maxAreaCap).toInt()}㎡',
                style: const TextStyle(fontSize: 12, color: HD.inkSoft)),
          ],
        ),
      ],
    );
  }

  Widget _buildBuildingAge() {
    final age = _filter.maxBuildingAgeYears?.toDouble() ?? _maxBuildingAgeCap.toDouble();
    return Column(
      children: [
        Slider(
          value: age,
          min: 0,
          max: _maxBuildingAgeCap.toDouble(),
          divisions: _maxBuildingAgeCap,
          activeColor: HD.accent,
          onChanged: (v) {
            setState(() {
              _filter = _filter.copyWith(maxBuildingAgeYears: v.round());
            });
          },
        ),
        Text(
          '築${_filter.maxBuildingAgeYears ?? _maxBuildingAgeCap}年以内',
          style: const TextStyle(fontSize: 12, color: HD.inkSoft),
        ),
      ],
    );
  }

  Widget _buildWalkMin() {
    // P3: slider range is 0–30 (0 = no limit).
    final walk = _filter.maxWalkMinutes?.toDouble() ?? _maxWalkMinCap.toDouble();
    final displayMin = _filter.maxWalkMinutes ?? _maxWalkMinCap;
    return Column(
      children: [
        Slider(
          value: walk,
          min: 0,
          max: _maxWalkMinCap.toDouble(),
          divisions: _maxWalkMinCap,
          activeColor: HD.accent,
          onChanged: (v) {
            setState(() {
              _filter = _filter.copyWith(maxWalkMinutes: v.round());
            });
          },
        ),
        Text(
          displayMin == 0 ? '制限なし' : '徒歩$displayMin分以内',
          style: const TextStyle(fontSize: 12, color: HD.inkSoft),
        ),
      ],
    );
  }

  Widget _buildFlagChips(AppLocalizations l) {
    final flags = [
      (l.jp_flag_pets_ok, _filter.petsOk, (bool v) => _filter.copyWith(petsOk: v)),
      (l.jp_flag_no_guarantor, _filter.noGuarantorRequired,
          (bool v) => _filter.copyWith(noGuarantorRequired: v)),
      (l.jp_flag_instruments_ok, _filter.instrumentsOk,
          (bool v) => _filter.copyWith(instrumentsOk: v)),
      (l.jp_flag_corporate_ok, _filter.corporateOk,
          (bool v) => _filter.copyWith(corporateOk: v)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: flags.map((entry) {
        final label = entry.$1;
        final selected = entry.$2;
        final update = entry.$3;
        return FilterChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: selected,
          selectedColor: HD.accentTint,
          checkmarkColor: HD.accent,
          labelStyle: TextStyle(
            color: selected ? HD.accent : HD.inkSoft,
          ),
          side: BorderSide(color: selected ? HD.accent : HD.hairline),
          backgroundColor: HD.paperRaised,
          onSelected: (v) => setState(() => _filter = update(v)),
        );
      }).toList(),
    );
  }

  void _reset() {
    setState(() => _filter = const JpSearchFilter());
  }

  static String _formatYen(int amount) {
    if (amount == 0) return '¥0';
    if (amount >= 10000) return '¥${amount ~/ 10000}万';
    return '¥$amount';
  }
}
