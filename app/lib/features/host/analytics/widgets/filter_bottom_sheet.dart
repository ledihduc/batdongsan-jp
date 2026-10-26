import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/analytics/widgets/filter_chip_group.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/report_provider.dart';

/// Room type options shown in the filter bottom sheet.
const List<String> _kRoomTypes = ['Phòng trọ', 'Homestay'];

/// Shows the filter bottom sheet and updates [DrillProvider] on apply.
///
/// Returns the applied [FilterState] (or null if dismissed / reset).
Future<FilterState?> showFilterBottomSheet(BuildContext context) async {
  return showModalBottomSheet<FilterState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HD.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => const _FilterBottomSheetContent(),
  );
}

class _FilterBottomSheetContent extends StatefulWidget {
  const _FilterBottomSheetContent();

  @override
  State<_FilterBottomSheetContent> createState() =>
      _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<_FilterBottomSheetContent> {
  late FilterState _draft;

  @override
  void initState() {
    super.initState();
    // Initialize draft from existing filter state.
    _draft = context.read<DrillProvider>().filter;
  }

  void _onApply() {
    context.read<DrillProvider>().updateFilter(_draft);
    // Track filter applied with non-PII dimension counts.
    Provider.of<TelemetryService>(context, listen: false).track(
      'filter_applied',
      props: {
        'source_ids': _draft.sourceIds,
        'building_ids': _draft.buildingIds,
      },
    );
    Navigator.of(context).pop(_draft);
  }

  void _onReset() {
    setState(() => _draft = const FilterState.empty());
    context.read<DrillProvider>().clearFilter();
    Navigator.of(context).pop(const FilterState.empty());
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _draft.dateRange,
      locale: const Locale('vi'),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: HD.ink),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() => _draft = _draft.copyWith(dateRange: range));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Buildings from BuildingProvider (may be empty if not loaded).
    final buildings = context.watch<BuildingProvider>().buildings;
    final buildingOptions = buildings
        .map((b) => (id: b.id, label: b.name))
        .toList();

    // Sources from ReportProvider.
    final sources =
        context.watch<ReportProvider>().sources ?? const <RevenueSourceModel>[];
    final sourceOptions = sources
        .map((s) => (id: s.id, label: s.name))
        .toList();

    final dateRangeText = _draft.dateRange == null
        ? l.hAnalyticsFilterSelectPeriod
        : '${_formatDate(_draft.dateRange!.start)} → ${_formatDate(_draft.dateRange!.end)}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle indicator.
            Container(
              margin: const EdgeInsets.only(top: HD.s8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HD.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header.
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: HD.s16, vertical: HD.s12),
              child: Row(
                children: [
                  Text(l.hAnalyticsFilterTitle, style: HD.sectionTitle()),
                  const Spacer(),
                  if (!_draft.isEmpty)
                    Text(
                      l.hAnalyticsFilterActive,
                      style: HD.caption(color: HD.accent)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: HD.hairline),
            // Scrollable body.
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                    HD.s16, HD.s12, HD.s16, HD.s12),
                children: [
                  // Buildings.
                  if (buildingOptions.isNotEmpty) ...[
                    FilterChipGroup(
                      label: l.hAnalyticsFilterBuilding,
                      options: buildingOptions,
                      selected: Set<int>.from(_draft.buildingIds),
                      onChanged: (sel) => setState(
                        () => _draft = _draft.copyWith(
                          buildingIds: sel.toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: HD.s16),
                  ],
                  // Sources.
                  if (sourceOptions.isNotEmpty) ...[
                    FilterChipGroup(
                      label: l.hAnalyticsFilterSource,
                      options: sourceOptions,
                      selected: Set<int>.from(_draft.sourceIds),
                      onChanged: (sel) => setState(
                        () => _draft = _draft.copyWith(
                          sourceIds: sel.toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: HD.s16),
                  ],
                  // Room type (single-select string chip group).
                  Text(
                    l.hAnalyticsFilterRoomType,
                    style: HD.caption(color: HD.inkSoft)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: HD.s4),
                  Wrap(
                    spacing: HD.s8,
                    runSpacing: HD.s4,
                    children: _kRoomTypes.map((rt) {
                      final isSelected = _draft.roomType == rt;
                      return FilterChip(
                        key: Key('room_type_$rt'),
                        label: Text(
                          rt,
                          style: HD.caption(
                            color: isSelected ? HD.paperRaised : HD.ink,
                          ).copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (checked) {
                          setState(() {
                            _draft = _draft.copyWith(
                              roomType: checked ? rt : null,
                              clearRoomType: !checked,
                            );
                          });
                        },
                        selectedColor: HD.ink,
                        checkmarkColor: HD.paperRaised,
                        backgroundColor: HD.paper,
                        side: BorderSide(
                            color: isSelected ? HD.ink : HD.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: HD.s16),
                  // Date range.
                  Text(
                    l.hAnalyticsFilterPeriod,
                    style: HD.caption(color: HD.inkSoft)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: HD.s4),
                  OutlinedButton.icon(
                    key: const Key('date_range_button'),
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(
                      dateRangeText,
                      style: HD.caption(color: HD.ink),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HD.ink,
                      side: const BorderSide(color: HD.hairline),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  if (_draft.dateRange != null) ...[
                    const SizedBox(height: HD.s4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(
                          () => _draft = _draft.copyWith(clearDateRange: true),
                        ),
                        child: Text(
                          l.hAnalyticsFilterClearPeriod,
                          style: HD.caption(color: HD.inkMuted),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // "Quản lý nguồn" CTA — navigates to source management screen.
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: HD.s16, vertical: HD.s4),
              child: TextButton.icon(
                key: const Key('manage_sources_btn'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/host/analytics/sources');
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text(l.hAnalyticsFilterManageSources),
              ),
            ),
            // Footer buttons.
            const Divider(height: 1, color: HD.hairline),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: HD.s16, vertical: HD.s12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('filter_reset_btn'),
                        onPressed: _onReset,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HD.inkSoft,
                          side: const BorderSide(color: HD.hairline),
                          minimumSize: const Size(0, 48),
                        ),
                        child: Text(l.hAnalyticsFilterReset),
                      ),
                    ),
                    const SizedBox(width: HD.s12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        key: const Key('filter_apply_btn'),
                        onPressed: _onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HD.ink,
                          foregroundColor: HD.paperRaised,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(l.hAnalyticsFilterApply),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
