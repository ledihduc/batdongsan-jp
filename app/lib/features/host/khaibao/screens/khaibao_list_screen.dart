import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/khai_bao_model.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/khaibao/providers/khaibao_provider.dart';
import 'package:house_booking/features/host/khaibao/screens/khaibao_detail_screen.dart';
import 'package:house_booking/features/host/khaibao/widgets/khaibao_deadline_countdown.dart';
import 'package:house_booking/features/host/khaibao/widgets/khaibao_status_badge.dart';

/// 4-tab list of khai báo tạm trú records (pending / overdue / declared / all).
class KhaiBaoListScreen extends StatefulWidget {
  /// If non-null, default tab opens on overdue.
  final bool openOnOverdue;
  const KhaiBaoListScreen({super.key, this.openOnOverdue = false});

  @override
  State<KhaiBaoListScreen> createState() => _KhaiBaoListScreenState();
}

class _KhaiBaoListScreenState extends State<KhaiBaoListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Tab order: 0=pending, 1=overdue, 2=declared, 3=all
  static const _tabStatuses = <String?>['pending', 'overdue', 'declared', null];
  static const _tabLabels = ['Chưa khai', 'Quá hạn', 'Đã khai', 'Tất cả'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.openOnOverdue ? 1 : 0,
    );
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _refresh();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final status = _tabStatuses[_tab.index];
    await context
        .read<KhaiBaoProvider>()
        .fetchList(status: status);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<KhaiBaoProvider>();
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar('KHAI BÁO TẠM TRÚ'),
      body: Column(
        children: [
          Container(
            color: HD.paper,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              labelColor: HD.ink,
              unselectedLabelColor: HD.inkMuted,
              indicatorColor: HD.accent,
              labelStyle: HD.bodyBold(size: 13),
              unselectedLabelStyle: HD.body(size: 13),
              tabs: [for (final l in _tabLabels) Tab(text: l)],
            ),
          ),
          const HDHairline(),
          if (prov.isLoading) const LinearProgressIndicator(),
          if (prov.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(prov.error!,
                  style: HD.caption(color: HD.negative)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _list(prov.records),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<KhaiBaoModel> records) {
    if (records.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text('Không có bản khai báo',
                style: HD.body(color: HD.inkMuted)),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: records.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: HD.hairline),
      itemBuilder: (_, i) => _tile(records[i]),
    );
  }

  Widget _tile(KhaiBaoModel r) {
    final dateLabel = DateFormat('dd/MM/yyyy HH:mm').format(r.checkInAt);
    final subtitleParts = <String>[
      if (r.roomCode != null) 'Phòng ${r.roomCode}',
      if (r.buildingName != null) r.buildingName!,
      'Check-in $dateLabel',
    ];
    return ListTile(
      tileColor: HD.paperRaised,
      title: Row(
        children: [
          Expanded(
            child: Text(r.tenantName ?? '#${r.tenantId}',
                style: HD.bodyBold()),
          ),
          const SizedBox(width: 8),
          KhaiBaoStatusBadge(r.status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitleParts.join(' • '), style: HD.caption()),
            if (r.isActionable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: KhaiBaoDeadlineCountdown(checkInAt: r.checkInAt),
              ),
          ],
        ),
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KhaiBaoDetailScreen(recordId: r.id),
          ),
        );
        if (mounted) _refresh();
      },
    );
  }
}
