/// JP Admin KPI dashboard — 5 metric cards, prefecture filter, date range picker.
///
/// No chart library for MVP — metric cards only.
/// Route: /admin/jp-kpi (GoRoute, admin role required, JP-gated).
/// Provider: none — [IAdminKpiRepository] injected by constructor.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/admin_kpi.dart';
import 'package:house_booking/data/repositories/jp/mock_admin_kpi_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_admin_kpi_repository.dart';
import 'package:house_booking/features/admin/widgets/jp_kpi_card.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Route: /admin/jp-kpi
class JpKpiDashboardScreen extends StatefulWidget {
  const JpKpiDashboardScreen({super.key, this.repository});

  final IAdminKpiRepository? repository;

  @override
  State<JpKpiDashboardScreen> createState() => _JpKpiDashboardScreenState();
}

class _JpKpiDashboardScreenState extends State<JpKpiDashboardScreen> {
  late final IAdminKpiRepository _repo;

  String _prefecture = '';
  late DateTimeRange _dateRange;
  JpAdminKpi? _kpi;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockAdminKpiRepository();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month - 1, 1),
      end: DateTime(now.year, now.month, 0),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final kpi = await _repo.getKpi(
        prefecture: _prefecture,
        from: _dateRange.start,
        to: _dateRange.end,
      );
      if (mounted) setState(() { _kpi = kpi; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('ja'),
    );
    if (range != null && mounted) {
      setState(() => _dateRange = range);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.jp_kpi_eyebrow,
        title: l.jp_kpi_dashboard_title,
      ),
      body: Column(
        children: [
          // Filter bar
          _FilterBar(
            prefecture: _prefecture,
            dateRange: _dateRange,
            onPrefectureChanged: (v) {
              setState(() => _prefecture = v);
              _load();
            },
            onPickDateRange: _pickDateRange,
            l: l,
          ),
          const Divider(height: 1, color: HD.hairline),
          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: HD.accent))
                : _error != null
                    ? DsErrorState(message: _error!, onRetry: _load)
                    : _kpi == null
                        ? const SizedBox.shrink()
                        : _KpiGrid(kpi: _kpi!, l: l),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.prefecture,
    required this.dateRange,
    required this.onPrefectureChanged,
    required this.onPickDateRange,
    required this.l,
  });

  final String prefecture;
  final DateTimeRange dateRange;
  final void Function(String) onPrefectureChanged;
  final VoidCallback onPickDateRange;
  final AppLocalizations l;

  static const _prefectures = [
    '',
    '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
    '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
    '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県',
    '岐阜県', '静岡県', '愛知県', '三重県',
    '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県',
    '鳥取県', '島根県', '岡山県', '広島県', '山口県',
    '徳島県', '香川県', '愛媛県', '高知県',
    '福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県',
  ];

  static final _dateFormat = DateFormat('yyyy/MM/dd', 'ja_JP');

  @override
  Widget build(BuildContext context) {
    final rangeLabel =
        '${_dateFormat.format(dateRange.start)} – ${_dateFormat.format(dateRange.end)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Prefecture dropdown
          Expanded(
            child: DropdownButtonFormField<String>(
              value: prefecture,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.jp_kpi_prefecture_label,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: HD.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: HD.hairline),
                ),
              ),
              items: _prefectures.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.isEmpty ? l.jp_kpi_all_japan : p,
                    style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) => onPrefectureChanged(v ?? ''),
            ),
          ),
          const SizedBox(width: 10),
          // Date range picker button
          OutlinedButton.icon(
            onPressed: onPickDateRange,
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(rangeLabel, style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: HD.ink,
              side: const BorderSide(color: HD.hairline),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpi, required this.l});

  final JpAdminKpi kpi;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${kpi.prefecture} · ${kpi.periodLabel}',
          style: HD.body(size: 12).copyWith(color: HD.inkMuted),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            JpKpiCard(
              label: l.jp_kpi_active_listings,
              metric: kpi.activeListings,
              icon: Icons.home_outlined,
            ),
            JpKpiCard(
              label: l.jp_kpi_pending_applications,
              metric: kpi.pendingApplications,
              icon: Icons.pending_outlined,
            ),
            JpKpiCard(
              label: l.jp_kpi_active_contracts,
              metric: kpi.activeContracts,
              icon: Icons.description_outlined,
            ),
            JpKpiCard(
              label: l.jp_kpi_avg_days_to_sign,
              metric: kpi.avgDaysToSign,
              icon: Icons.timer_outlined,
            ),
            JpKpiCard(
              label: l.jp_kpi_monthly_revenue,
              metric: kpi.monthlyRevenueYen,
              icon: Icons.currency_yen_outlined,
            ),
          ],
        ),
      ],
    );
  }
}
