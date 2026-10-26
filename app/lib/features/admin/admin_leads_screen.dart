import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lead_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Admin xem danh sách lead "gọi lại" (khách để lại Tên+SĐT không đăng nhập) để
/// chủ động liên hệ/remarketing. Route: push. API: GET /api/admin/leads.
class AdminLeadsScreen extends StatefulWidget {
  const AdminLeadsScreen({super.key, this.api = const LeadApi()});
  final LeadApi api;

  @override
  State<AdminLeadsScreen> createState() => _AdminLeadsScreenState();
}

class _AdminLeadsScreenState extends State<AdminLeadsScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.api.adminList();
      if (mounted) setState(() => _rows = r);
    } catch (_) {
      // giữ danh sách hiện có
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.adminLeadsTitle),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(
                        child: Text(l.adminLeadsEmpty,
                            style: const TextStyle(color: HD.inkSoft))),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _tile(_rows[i]),
                  ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> r) {
    final parts = <String>[
      if ((r['source'] as String?)?.isNotEmpty ?? false) r['source'] as String,
      if ((r['world'] as String?)?.isNotEmpty ?? false) r['world'] as String,
      if ((r['province_code'] as String?)?.isNotEmpty ?? false)
        r['province_code'] as String,
      if ((r['created_at'] as String?)?.isNotEmpty ?? false)
        (r['created_at'] as String).split('T').first,
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(r['name'] as String? ?? '—',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: HD.ink)),
          ),
          SelectableText(r['phone'] as String? ?? '',
              style: const TextStyle(
                  color: HD.accent, fontWeight: FontWeight.w600)),
        ]),
        if (parts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(parts.join(' · '),
              style: const TextStyle(color: HD.inkMuted, fontSize: 12)),
        ],
        if ((r['context'] as String?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 4),
          Text(r['context'] as String,
              style: const TextStyle(color: HD.inkSoft, fontSize: 13)),
        ],
      ]),
    );
  }
}
