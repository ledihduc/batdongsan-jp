import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/services/admin_api_service.dart';
import 'package:house_booking/features/admin/admin_trusted_mark_screen.dart';
import 'package:house_booking/features/admin/planning/risky_listings_screen.dart';
import 'package:house_booking/features/admin/verification_queue_screen.dart';
import 'package:house_booking/features/admin/market_research_screen.dart';
import 'package:house_booking/features/admin/reel_moderation_screen.dart';
import 'package:house_booking/features/admin/admin_leads_screen.dart';
import 'package:house_booking/features/admin/admin_service_requests_screen.dart';
import 'package:house_booking/features/guest/profile/settings_screen.dart'
    show logoutFlow;
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AdminApiService _adminApiService = AdminApiService();
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;

  final _statuses = const ['pending_review', 'published', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTab(0);
      _fetchUsers();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _refreshTab(_tabController.index);
  }

  Future<void> _refreshTab(int i) async {
    await Provider.of<HouseProvider>(context, listen: false)
        .fetchHousesByStatus(_statuses[i]);
  }

  Future<void> _fetchUsers() async {
    setState(() => _loadingUsers = true);
    try {
      _users = await _adminApiService.getUsers();
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hp = Provider.of<HouseProvider>(context);
    final pendingCount =
        hp.adminHouses.where((h) => h.status == 'pending_review').length;

    return Scaffold(
      appBar: DsAppBar(
        title: l.adminHomeTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            // Dùng chung luồng logout (xác nhận + xoá phiên + điều hướng /login).
            // Trước đây gọi auth.logout() trần, không điều hướng → dưới guestBrowse
            // admin kẹt lại trong app khi không ở route /admin.
            onPressed: () => logoutFlow(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: HD.inkMuted,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l.adminHomePending),
                  // KHÔNG gắn với tab đang mở: số tin chờ duyệt là số toàn
                  // cục, ẩn nó khi admin sang tab khác là giấu mất việc cần làm.
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    _badge(pendingCount),
                  ],
                ],
              ),
            ),
            Tab(text: l.adminHomeApproved),
            Tab(text: l.adminHomeRejected),
          ],
        ),
      ),
      body: Column(
        children: [
          _statsBar(),
          _congCuBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _housesList('pending', hp),
                _housesList('approved', hp),
                _housesList('rejected', hp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsBar() {
    final l = AppLocalizations.of(context);
    final hp = Provider.of<HouseProvider>(context);
    final statusLabels = [
      l.adminHomePending,
      l.adminHomePublished,
      l.adminHomeRejected,
    ];
    return Container(
      color: HD.paperRaised,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _statChip(
              Icons.people_outline,
              _loadingUsers ? '…' : '${_users.length}',
              l.adminHomeUsers,
              HD.accent),
          const SizedBox(width: 8),
          _statChip(
              Icons.home_work_outlined,
              '${hp.adminHouses.length}',
              statusLabels[_tabController.index],
              HD.positive),
        ],
      ),
    );
  }

  /// Hàng lối tắt tới các công cụ quản trị — cuộn NGANG, kiểu hàng shortcut
  /// của Facebook.
  ///
  /// Trước đây đây là 5 [ListTile] full-width xếp chồng: ~360px, cộng thanh
  /// thống kê là ~430px chrome trên màn ~700px — hàng đợi duyệt tin (việc admin
  /// thực sự vào đây để làm) bị đẩy khỏi màn đầu. Nay ~96px.
  ///
  /// Mỗi tile cũ còn có MỘT nền pastel riêng (5 mã màu hard-code khác nhau, sót
  /// từ theme đỏ cũ). Nhấn mọi thứ thì không gì nổi — nay dùng chung nền trắng,
  /// chỉ icon mang màu ngữ nghĩa.
  Widget _congCuBar() {
    final l = AppLocalizations.of(context);
    final congCu = <_CongCu>[
      _CongCu(Icons.slow_motion_video, l.adminHomeToolModerateReel, HD.accent,
          () => const ReelModerationScreen()),
      _CongCu(Icons.verified_outlined, l.adminHomeToolVerifyQueue, HD.positive,
          () => const VerificationQueueScreen()),
      _CongCu(Icons.warning_amber, l.adminHomeToolPlanningRisk, HD.warning,
          () => const RiskyListingsScreen()),
      _CongCu(Icons.workspace_premium, l.adminHomeToolTrustedMark, HD.accentDeep,
          () => const AdminTrustedMarkScreen()),
      _CongCu(Icons.insights_outlined, l.adminHomeToolMarketResearch, HD.neutral,
          () => const MarketResearchScreen()),
      _CongCu(Icons.contact_phone_outlined, l.adminLeadsTitle, HD.positive,
          () => const AdminLeadsScreen()),
      _CongCu(Icons.handyman_outlined, l.svcReqTitle, HD.accent,
          () => const AdminServiceRequestsScreen()),
    ];

    return Container(
      color: HD.paperRaised,
      margin: const EdgeInsets.only(top: 1, bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: congCu.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _congCuTile(congCu[i]),
        ),
      ),
    );
  }

  Widget _congCuTile(_CongCu c) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => c.man()),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: HD.paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(c.icon, size: 24, color: c.mau),
            const SizedBox(height: 6),
            Text(
              c.nhan,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: HD.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }






  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: HD.inkSoft)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: HD.negative,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$n',
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _housesList(String status, HouseProvider hp) {
    final l = AppLocalizations.of(context);
    if (hp.adminLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = hp.adminHouses;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  status == 'pending'
                      ? Icons.inbox_outlined
                      : status == 'approved'
                          ? Icons.check_circle_outline
                          : Icons.block,
                  size: 56,
                  color: HD.inkMuted),
              const SizedBox(height: 12),
              Text(
                status == 'pending'
                    ? l.adminHomeEmptyPending
                    : status == 'approved'
                        ? l.adminHomeEmptyApproved
                        : l.adminHomeEmptyRejected,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: HD.ink),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => hp.fetchHousesByStatus(status),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _houseCard(list[i], status, hp),
      ),
    );
  }

  Widget _houseCard(HouseModel h, String status, HouseProvider hp) {
    final l = AppLocalizations.of(context);
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/house/${h.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: h.images.isNotEmpty
                      ? Image.network(
                          h.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: HD.paperSunken,
                            child: const Icon(Icons.home_outlined,
                                color: HD.inkMuted),
                          ),
                        )
                      : Container(
                          color: HD.paperSunken,
                          child: const Icon(Icons.home_outlined,
                              color: HD.inkMuted),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.adminHomeHost(h.hostName ?? '?'),
                          style: const TextStyle(
                              fontSize: 11, color: HD.inkSoft),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${h.district}, ${h.city}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: HD.inkMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${h.priceCompactLabel} · ${h.area.toStringAsFixed(0)} m²',
                          style: const TextStyle(
                            fontSize: 12,
                            color: HD.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (status == 'pending')
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close, color: HD.negative),
                        label: Text(l.adminHomeReject,
                            style: const TextStyle(color: HD.negative)),
                        onPressed: () => _setStatus(h, 'rejected', hp),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: HD.negative),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: Text(l.adminHomeApprove),
                        onPressed: () => _setStatus(h, 'approved', hp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HD.positive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (status == 'rejected')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextButton.icon(
                  icon: const Icon(Icons.restore),
                  label: Text(l.adminHomeReapprove),
                  onPressed: () => _setStatus(h, 'approved', hp),
                ),
              ),
            if (status == 'approved')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextButton.icon(
                  icon: const Icon(Icons.block, color: HD.negative),
                  label: Text(l.adminHomeUnpublish,
                      style: const TextStyle(color: HD.negative)),
                  onPressed: () => _setStatus(h, 'rejected', hp),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptRejectReason() {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.adminHomeRejectReasonTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l.adminHomeRejectReasonHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isEmpty) return; // lý do bắt buộc
              Navigator.pop(ctx, t);
            },
            child: Text(l.adminHomeReject),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(
      HouseModel h, String status, HouseProvider hp) async {
    final l = AppLocalizations.of(context);
    String? reason;
    if (status == 'rejected') {
      reason = await _promptRejectReason();
      if (reason == null) return; // hủy — không làm gì
    }
    final ok = await hp.setHouseStatus(h.id!, status, reason: reason);
    if (!mounted) return;
    final successMsg = status == 'approved'
        ? l.adminHomeMsgApproved
        : status == 'rejected'
            ? l.adminHomeMsgRejected
            : l.adminHomeMsgUpdated;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? successMsg : l.adminHomeMsgFailed),
        backgroundColor: ok ? HD.positive : HD.negative,
      ),
    );
  }

}

/// Một lối tắt trong hàng công cụ quản trị.
class _CongCu {
  const _CongCu(this.icon, this.nhan, this.mau, this.man);
  final IconData icon;
  final String nhan;
  final Color mau;
  final Widget Function() man;
}
