import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/demand_post.dart';
import 'package:house_booking/data/services/demand_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Danh sách tin NHU CẦU. Route: không có URL (push trong tab).
/// API: GET /api/demands · /api/demands/mine · PATCH /api/demands/{id}.
///
/// Bốn tab: Tất cả · Cần thuê · Cần mua · Tin của tôi. Tab cuối là tab DUY NHẤT
/// hiện tin đã đóng/hết hạn — người khác không có lý do gì để xem nhu cầu đã
/// nguội, còn chủ tin thì cần thấy để gia hạn.
class DemandListScreen extends StatefulWidget {
  const DemandListScreen({super.key, this.api, this.initialTab = 0});

  /// Chỉ để test bơm API giả.
  final DemandApi? api;
  final int initialTab;

  @override
  State<DemandListScreen> createState() => _DemandListScreenState();
}

class _DemandListScreenState extends State<DemandListScreen>
    with SingleTickerProviderStateMixin {
  DemandApi get _api => widget.api ?? const DemandApi();

  late final TabController _tab = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab,
  );

  List<DemandPost> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _nap();
    });
    _nap();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() => _loading = true);
    try {
      final ds = switch (_tab.index) {
        1 => await _api.list(kind: 'rent'),
        2 => await _api.list(kind: 'buy'),
        3 => await _api.mine(),
        _ => await _api.list(),
      };
      if (mounted) setState(() => _items = ds);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doi(Future<DemandPost> Function() f) async {
    try {
      await f();
      await _nap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final laTabToi = _tab.index == 3;
    final toi = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.demandListTitle,
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l.demandTabAll),
            Tab(text: l.demandTabRent),
            Tab(text: l.demandTabBuy),
            Tab(text: l.demandTabMine),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? DsEmptyState(
              icon: Icons.travel_explore_outlined,
              title: laTabToi ? l.demandEmptyMine : l.demandEmpty,
            )
          : RefreshIndicator(
              onRefresh: _nap,
              child: ListView.separated(
                padding: const EdgeInsets.all(HD.s16),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: HD.s12),
                itemBuilder: (_, i) => _the(_items[i], l, cuaToi: toi),
              ),
            ),
    );
  }

  Widget _the(DemandPost d, AppLocalizations l, {int? cuaToi}) {
    final laCuaToi = cuaToi != null && d.authorId == cuaToi;
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: HD.accentTint,
                backgroundImage: (d.authorAvatar ?? '').isEmpty
                    ? null
                    : NetworkImage(_abs(d.authorAvatar!)),
                child: (d.authorAvatar ?? '').isEmpty
                    ? const Icon(Icons.person, size: 16, color: HD.accent)
                    : null,
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Text(
                  d.authorName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _nhanTrangThai(d, l),
            ],
          ),
          const SizedBox(height: HD.s8),
          Text(
            _tieuDe(d, l),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if ((d.provinceName ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 14, color: HD.inkMuted),
                const SizedBox(width: 4),
                Text(d.provinceName!, style: HD.caption()),
              ],
            ),
          ],
          if ((d.note ?? '').isNotEmpty) ...[
            const SizedBox(height: HD.s8),
            Text(d.note!, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          if (laCuaToi) ...[
            const SizedBox(height: HD.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (d.conHieuLuc)
                  TextButton(
                    onPressed: () => _doi(() => _api.close(d.id)),
                    child: Text(l.demandActionClose),
                  ),
                TextButton(
                  onPressed: () => _doi(() => _api.extend(d.id)),
                  child: Text(l.demandActionExtend),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Tiêu đề dựng TỪ dữ liệu, không có ô "tiêu đề" nào trong form: bắt người
  /// đang tìm nhà tự nghĩ tiêu đề là thêm một rào cản không cần thiết.
  String _tieuDe(DemandPost d, AppLocalizations l) {
    final loai = d.categoryNames.isEmpty
        ? (d.laThue ? l.demandTabRent : l.demandTabBuy)
        : d.categoryNames.join(' · ');
    final tien = _khoangTien(d);
    return tien.isEmpty ? loai : '$loai — $tien';
  }

  String _khoangTien(DemandPost d) {
    String don(double v) {
      if (d.laThue) return '${(v / 1000000).toStringAsFixed(0)} tr';
      return '${(v / 1000000000).toStringAsFixed(1)} tỷ';
    }

    final lo = d.budgetMin, hi = d.budgetMax;
    if (lo == null && hi == null) return '';
    if (lo != null && hi != null) return '${don(lo)} – ${don(hi)}';
    return lo != null ? '≥ ${don(lo)}' : '≤ ${don(hi!)}';
  }

  Widget _nhanTrangThai(DemandPost d, AppLocalizations l) {
    final (nhan, mau) = switch (d) {
      _ when d.status == 'closed' => (l.demandClosed, HD.inkMuted),
      _ when !d.conHieuLuc => (l.demandExpired, HD.inkMuted),
      _ => (
        l.demandDaysLeft(d.expiresAt.difference(DateTime.now().toUtc()).inDays),
        HD.accent,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HD.rPill),
      ),
      child: Text(
        nhan,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mau),
      ),
    );
  }
}

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
