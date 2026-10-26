import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Khách quan tâm của chủ nhà — 2 nhóm:
/// - MỤC TIÊU: khách đã đặt lịch xem (ý định cao).
/// - TIỀM NĂNG: khách wishlist nhưng chưa đặt lịch (nuôi dưỡng).
///
/// Nguồn dữ liệu: `GET /api/host/leads` (read-only, không migration).
class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final ApiClient _client = const ApiClient();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _target = const [];
  List<Map<String, dynamic>> _potential = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _client.get('/api/host/leads');
      final target = (res['target'] as Map?)?['leads'] as List? ?? const [];
      final potential =
          (res['potential'] as Map?)?['leads'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _target = target.cast<Map<String, dynamic>>();
        _potential = potential.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: HD.paper,
        appBar: DsAppBar(
          title: l.hLeadsTitle,
          bottom: TabBar(
            labelColor: HD.ink,
            unselectedLabelColor: HD.ink.withValues(alpha: 0.5),
            indicatorColor: HD.accent,
            tabs: [
              Tab(text: l.hLeadsTabTarget(_target.length)),
              Tab(text: l.hLeadsTabPotential(_potential.length)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.hLeadsLoadError(_error!),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _LeadsList(
                        rows: _target,
                        emptyMessage: l.hLeadsEmptyTarget,
                        onRefresh: _load,
                      ),
                      _LeadsList(
                        rows: _potential,
                        emptyMessage: l.hLeadsEmptyPotential,
                        onRefresh: _load,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _LeadsList extends StatelessWidget {
  const _LeadsList({
    required this.rows,
    required this.emptyMessage,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> rows;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(emptyMessage, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _LeadCard(row: rows[i]),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.row});

  final Map<String, dynamic> row;

  String _initial(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    return name.trim().substring(0, 1).toUpperCase();
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  ({String label, Color color}) _signalBadge(
    AppLocalizations l,
    String? signal,
    String? status,
  ) {
    if (signal == 'viewing') {
      final s = (status ?? '').toLowerCase();
      if (s == 'confirmed' || s == 'done' || s == 'completed') {
        return (label: l.hLeadsBadgeBooked, color: HD.accent);
      }
      return (label: l.hLeadsBadgeBookViewing, color: HD.accent);
    }
    return (label: l.hLeadsBadgeSaved, color: HD.ink);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = row['name'] as String? ?? l.hLeadsDefaultName;
    final houseTitle = row['house_title'] as String? ?? l.hLeadsDefaultHouse;
    final houseId = row['house_id'];
    final date = _formatDate(row['date'] as String?);
    final badge = _signalBadge(
      l,
      row['signal'] as String?,
      row['status'] as String?,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: HD.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: HD.accentSoft,
              child: Text(
                _initial(name),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: HD.ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badge.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badge.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    houseId != null ? '$houseTitle (#$houseId)' : houseTitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: HD.ink.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: HD.ink.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
