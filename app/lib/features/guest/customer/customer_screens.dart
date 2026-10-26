import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/chat/conversations_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/features/guest/customer/customer_journey_store.dart';
import 'package:house_booking/features/guest/demand/demand_list_screen.dart';
import 'package:house_booking/features/guest/quan_ly/phong_dang_thue_screen.dart';
import 'package:house_booking/features/guest/profile/edit_profile_screen.dart';
import 'package:house_booking/features/guest/profile/settings_screen.dart';
import 'package:house_booking/features/guest/wishlist/wishlist_screen.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.onOpenManage,
    this.api = const QuanLyApi(),
    this.store = const CustomerJourneyStore(),
    this.managementApi,
    this.viewingV2Api = const ViewingV2Api(),
  });

  final VoidCallback onOpenManage;
  final QuanLyApi api;
  final CustomerJourneyStore store;
  final ManagementReadModelApi? managementApi;
  final ViewingV2Api viewingV2Api;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  TongHopQuanLy? _summary;
  Map<int, CustomerJourneyEntry> _journey = const {};
  int? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.id == null) return;
    final uid = user!.id!;
    TongHopQuanLy? summary;
    Map<int, CustomerJourneyEntry> journey = const {};
    try {
      summary = await widget.api.tongHop(GocQuanLy.cuaToi);
    } catch (_) {}
    try {
      final capabilities = await widget.managementApi?.capabilities();
      if (capabilities == null) {
        journey = await widget.store.read(uid);
      } else if (capabilities.viewingV2Enabled) {
        final viewings = await widget.viewingV2Api.list(
          mode: ViewingMode.customer,
        );
        journey = _canonicalDecisions(viewings);
      } else {
        journey = await widget.store.read(uid);
      }
    } catch (_) {}
    if (!mounted) return;
    if (uid != context.read<AuthProvider>().currentUser?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
      return;
    }
    setState(() {
      _summary = summary;
      _journey = journey;
      _loadedUserId = uid;
    });
  }

  Future<void> _open(Widget page) => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => page),
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    if (_loadedUserId != null && user.id != _loadedUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final summary = _summary;
    final appointmentCount = summary == null
        ? 0
        : summary.danhSach
              .where((m) => m.laLichHen && m.nhom != NhomQuanLy.lichSu)
              .length;
    final considering = _journey.values
        .where((e) => e.decision == CustomerDecision.considering)
        .length;
    final wants = _journey.values
        .where((e) => e.decision == CustomerDecision.wantToRent)
        .length;
    final rented =
        summary?.danhSach
            .where((m) => m.laThueDaiHan && m.nhom == NhomQuanLy.dangO)
            .length ??
        0;

    return ColoredBox(
      color: HD.paper,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _CustomerProfileHeader(
              user: user,
              onSettings: () => _open(const SettingsScreen()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _CustomerStat(
                    value: '$appointmentCount',
                    label: 'Lịch xem',
                    icon: Icons.calendar_month_rounded,
                  ),
                  const SizedBox(width: 8),
                  _CustomerStat(
                    value: '$considering',
                    label: 'Cân nhắc',
                    icon: Icons.hourglass_bottom_rounded,
                    tint: HD.warning,
                  ),
                  const SizedBox(width: 8),
                  _CustomerStat(
                    value: '$wants',
                    label: 'Muốn thuê',
                    icon: Icons.favorite_rounded,
                  ),
                  const SizedBox(width: 8),
                  _CustomerStat(
                    value: '$rented',
                    label: 'Đang ở',
                    icon: Icons.home_rounded,
                    tint: HD.positive,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _CustomerSection(
              title: 'Tiện ích nhanh',
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.45,
                children: [
                  _CustomerQuickAction(
                    icon: Icons.dashboard_customize_rounded,
                    label: 'Quản lý của tôi',
                    onTap: widget.onOpenManage,
                  ),
                  _CustomerQuickAction(
                    icon: Icons.favorite_rounded,
                    label: 'Bài đã lưu',
                    onTap: () => _open(const WishlistScreen()),
                    color: const Color(0xffdb2636),
                  ),
                  _CustomerQuickAction(
                    icon: Icons.post_add_rounded,
                    label: 'Nhu cầu đã đăng',
                    onTap: () => _open(const DemandListScreen()),
                    color: const Color(0xff1475d1),
                  ),
                  _CustomerQuickAction(
                    icon: Icons.support_agent_rounded,
                    label: 'Hỗ trợ',
                    onTap: () => _open(const ConversationsScreen()),
                    color: const Color(0xff117b52),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _CustomerSection(
              title: 'Tài khoản & dịch vụ',
              child: Column(
                children: [
                  _CustomerMenuItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Thông tin cá nhân',
                    onTap: () => _open(const EditProfileScreen()),
                  ),
                  _CustomerMenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Thông báo',
                    onTap: () => _open(const NotificationsScreen()),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: HD.inkMuted,
                    ),
                  ),
                  _CustomerMenuItem(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Mã giới thiệu',
                    onTap: () => _showReferral(context, user),
                  ),
                  _CustomerMenuItem(
                    icon: Icons.shield_outlined,
                    title: 'Chính sách & điều khoản',
                    onTap: () => _open(const SettingsScreen()),
                    last: true,
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Future<void> _showReferral(BuildContext context, UserModel user) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mã giới thiệu'),
        content: const Text(
          'Chương trình giới thiệu chưa được mở nên hiện chưa có mã giới thiệu khả dụng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({
    super.key,
    this.initialTab = 0,
    this.api = const QuanLyApi(),
    this.store = const CustomerJourneyStore(),
    this.managementApi,
    this.viewingV2Api = const ViewingV2Api(),
  });

  final int initialTab;
  final QuanLyApi api;
  final CustomerJourneyStore store;
  final ManagementReadModelApi? managementApi;
  final ViewingV2Api viewingV2Api;

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    'Lịch xem',
    'Đang cân nhắc',
    'Muốn thuê',
    'Đang ở',
    'Lịch sử',
  ];
  late final TabController _tabController;
  TongHopQuanLy? _summary;
  Map<int, CustomerJourneyEntry> _journey = const {};
  bool _loading = true;
  String? _error;
  int? _userId;
  bool _viewingV2Enabled = false;
  bool _viewingV2WritesEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(
          length: _tabs.length,
          vsync: this,
          initialIndex: widget.initialTab.clamp(0, _tabs.length - 1),
        )..addListener(() {
          if (!_tabController.indexIsChanging && mounted) setState(() {});
        });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    final uid = user?.id;
    if (uid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.api.tongHop(GocQuanLy.cuaToi);
      Map<int, CustomerJourneyEntry> decisions;
      var v2Enabled = false;
      var v2WritesEnabled = false;
      try {
        final capabilities = await widget.managementApi?.capabilities();
        if (capabilities == null) {
          decisions = await widget.store.read(uid);
        } else {
          v2Enabled = capabilities.viewingV2Enabled;
          v2WritesEnabled = capabilities.viewingV2WritesEnabled;
          if (v2Enabled) {
            if (v2WritesEnabled) await _migrateLocal(uid);
            decisions = _canonicalDecisions(
              await widget.viewingV2Api.list(mode: ViewingMode.customer),
            );
          } else {
            decisions = await widget.store.read(uid);
          }
        }
      } catch (_) {
        // Compatibility: backend cũ hoặc cohort chưa bật tiếp tục dùng dữ
        // liệu legacy/local; không làm hỏng màn Hoạt động đang chạy.
        decisions = await widget.store.read(uid);
      }
      if (!mounted) return;
      if (uid != context.read<AuthProvider>().currentUser?.id) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _load());
        return;
      }
      setState(() {
        _userId = uid;
        _summary = summary;
        _journey = decisions;
        _viewingV2Enabled = v2Enabled;
        _viewingV2WritesEnabled = v2WritesEnabled;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Chưa tải được hành trình của bạn. Kiểm tra mạng rồi thử lại.';
        _loading = false;
      });
    }
  }

  Future<void> _migrateLocal(int userId) async {
    final local = await widget.store.read(userId);
    for (final item in local.entries) {
      final decision = item.value;
      try {
        await widget.viewingV2Api.submitResult(
          item.key,
          status: switch (decision.decision) {
            CustomerDecision.notSuitable => 'DECLINED',
            CustomerDecision.considering => 'CONSIDERING',
            CustomerDecision.wantToRent => 'INTERESTED',
          },
          reasonCode: decision.decision == CustomerDecision.notSuitable
              ? 'OTHER'
              : null,
          reasonNote: decision.feedback.isEmpty ? null : decision.feedback,
        );
        await widget.store.remove(userId, item.key);
      } catch (_) {
        // Keep the unsent entry as a draft and retry on the next refresh.
      }
    }
  }

  List<MucQuanLy> _items(int tab) {
    final all = _summary?.danhSach ?? const <MucQuanLy>[];
    final decisions = _journey;
    return switch (tab) {
      0 =>
        all
            .where(
              (m) =>
                  m.laLichHen &&
                  m.nhom != NhomQuanLy.lichSu &&
                  !_hasDecision(m, decisions),
            )
            .toList(),
      1 =>
        all
            .where(
              (m) =>
                  m.laLichHen &&
                  decisions[m.id]?.decision == CustomerDecision.considering,
            )
            .toList(),
      2 =>
        all
            .where(
              (m) =>
                  m.laLichHen &&
                  decisions[m.id]?.decision == CustomerDecision.wantToRent,
            )
            .toList(),
      3 =>
        all.where((m) => m.laThueDaiHan && m.nhom == NhomQuanLy.dangO).toList(),
      _ =>
        all
            .where(
              (m) =>
                  m.nhom == NhomQuanLy.lichSu ||
                  (m.laLichHen &&
                      decisions[m.id]?.decision ==
                          CustomerDecision.notSuitable),
            )
            .toList(),
    };
  }

  bool _hasDecision(MucQuanLy item, Map<int, CustomerJourneyEntry> decisions) =>
      decisions.containsKey(item.id);

  List<int> _counts() => [
    _items(0).length,
    _items(1).length,
    _items(2).length,
    _items(3).length,
    _items(4).length,
  ];

  Future<void> _openItem(MucQuanLy item, int tab) async {
    if (item.laLichHen) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PhieuHenXemScreen(appointmentId: item.id),
        ),
      );
    } else if (item.laThueDaiHan && tab == 3) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PhongDangThueScreen(contractId: item.id),
        ),
      );
    } else {
      return;
    }
    if (mounted) _load();
  }

  Future<void> _openResult(MucQuanLy item) async {
    final uid = _userId;
    if (uid == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CustomerViewingResultScreen(
          item: item,
          userId: uid,
          store: widget.store,
          viewingV2Api: widget.viewingV2Api,
          serverEnabled: _viewingV2Enabled,
          serverWritesEnabled: _viewingV2WritesEnabled,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user?.id != _userId && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final counts = _counts();
    return ColoredBox(
      color: HD.paper,
      child: Column(
        children: [
          const _CustomerMasthead(compact: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý của tôi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: HD.ink,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Theo dõi hành trình thuê nhà của bạn',
                        style: TextStyle(fontSize: 13, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Làm mới',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: HD.accent),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: HD.accent,
              unselectedLabelColor: HD.inkMuted,
              indicatorColor: HD.accent,
              indicatorWeight: 3,
              labelStyle: HD.bodyBold(size: 13),
              tabs: [
                for (var i = 0; i < _tabs.length; i++)
                  Tab(text: '${_tabs[i]} (${counts[i]})'),
              ],
            ),
          ),
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                _CustomerCountCard(
                  number: '${counts[0]}',
                  label: 'Lịch xem',
                  icon: Icons.calendar_month_rounded,
                  color: HD.accent,
                ),
                _CustomerCountCard(
                  number: '${counts[1]}',
                  label: 'Đang cân nhắc',
                  icon: Icons.hourglass_bottom_rounded,
                  color: HD.warning,
                ),
                _CustomerCountCard(
                  number: '${counts[2]}',
                  label: 'Muốn thuê',
                  icon: Icons.favorite_rounded,
                  color: HD.accent,
                ),
                _CustomerCountCard(
                  number: '${counts[3]}',
                  label: 'Đang ở',
                  icon: Icons.home_rounded,
                  color: HD.positive,
                ),
                _CustomerCountCard(
                  number: '${counts[4]}',
                  label: 'Lịch sử',
                  icon: Icons.history_rounded,
                  color: HD.inkMuted,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: HD.accent),
                  )
                : _error != null
                ? _CustomerError(message: _error!, onRetry: _load)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      for (var tab = 0; tab < _tabs.length; tab++)
                        _tabContent(tab),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabContent(int tab) {
    final items = _items(tab);
    if (items.isEmpty) {
      final empty = [
        (
          'Chưa có lịch xem nào',
          'Khi bạn đặt lịch xem nhà, lịch sẽ được lưu tại đây.',
          Icons.event_available_outlined,
        ),
        (
          'Chưa có nhà đang cân nhắc',
          'Những căn bạn đang xem xét sẽ xuất hiện ở đây.',
          Icons.hourglass_empty_rounded,
        ),
        (
          'Chưa có căn muốn thuê',
          'Chọn “Muốn thuê” sau buổi xem để theo dõi tại đây.',
          Icons.favorite_border_rounded,
        ),
        (
          'Bạn chưa có phòng đang ở',
          'Khi thuê nhà thành công, thông tin phòng sẽ hiển thị ở đây.',
          Icons.home_outlined,
        ),
        (
          'Chưa có lịch sử',
          'Các lịch xem và giao dịch đã kết thúc sẽ được lưu tại đây.',
          Icons.history_rounded,
        ),
      ][tab];
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 70),
          Icon(empty.$3, size: 42, color: HD.inkMuted),
          const SizedBox(height: 12),
          Center(child: Text(empty.$1, style: HD.bodyBold(size: 16))),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 6, 32, 24),
            child: Text(
              empty.$2,
              textAlign: TextAlign.center,
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _journeyCard(items[i], tab),
      ),
    );
  }

  Widget _journeyCard(MucQuanLy item, int tab) {
    final decision = _journey[item.id]?.decision;
    final status = decision?.label ?? item.nhan;
    final color = switch (decision) {
      CustomerDecision.considering => HD.warning,
      CustomerDecision.wantToRent => HD.accent,
      CustomerDecision.notSuitable => HD.inkMuted,
      null => item.nhom == NhomQuanLy.daDat ? HD.positive : HD.accent,
    };
    final past = item.batDau != null && item.batDau!.isBefore(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openItem(item, tab),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PropertyThumb(url: item.anh, width: 96, height: 88),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.tieuDe,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: HD.bodyBold(size: 15),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _StatusBadge(
                              text: status.isEmpty ? _tabs[tab] : status,
                              color: color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        if (item.ma.isNotEmpty)
                          Text(
                            item.ma,
                            style: HD.body(size: 12, color: HD.inkMuted),
                          ),
                        if (item.diaChi.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.diaChi,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HD.body(size: 12, color: HD.inkMuted),
                          ),
                        ],
                        if (item.batDau != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _dateTime(item),
                            style: HD.bodyBold(size: 12, color: color),
                          ),
                        ] else if (item.dong.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.dong,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HD.body(size: 12, color: HD.inkMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
                ],
              ),
            ),
          ),
          if (tab == 0 && past && item.laLichHen)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openResult(item),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Cập nhật kết quả sau xem'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.accent,
                    side: const BorderSide(color: HD.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _dateTime(MucQuanLy item) {
    final date = item.batDau!;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final start =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final end = item.ketThuc;
    final endText = end == null
        ? ''
        : ' – ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$start$endText · $dateText';
  }
}

class CustomerViewingResultScreen extends StatefulWidget {
  const CustomerViewingResultScreen({
    super.key,
    required this.item,
    required this.userId,
    this.store = const CustomerJourneyStore(),
    this.viewingV2Api = const ViewingV2Api(),
    this.serverEnabled = false,
    this.serverWritesEnabled = false,
  });
  final MucQuanLy item;
  final int userId;
  final CustomerJourneyStore store;
  final ViewingV2Api viewingV2Api;
  final bool serverEnabled;
  final bool serverWritesEnabled;

  @override
  State<CustomerViewingResultScreen> createState() =>
      _CustomerViewingResultScreenState();
}

class _CustomerViewingResultScreenState
    extends State<CustomerViewingResultScreen> {
  CustomerDecision? _decision;
  final Set<String> _issues = {};
  final _feedback = TextEditingController();
  bool _saving = false;
  static const _issueOptions = [
    'Thông tin BĐS không đúng',
    'Sale hỗ trợ chưa tốt',
    'Lịch hẹn có vấn đề',
    'Vấn đề khác',
  ];

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final decision = _decision;
    if (decision == null || _saving) return;
    setState(() => _saving = true);
    try {
      final entry = CustomerJourneyEntry(
        decision: decision,
        issues: _issues.toList(),
        feedback: _feedback.text.trim(),
        updatedAt: DateTime.now(),
      );
      if (widget.serverEnabled && widget.serverWritesEnabled) {
        await widget.viewingV2Api.submitResult(
          widget.item.id,
          status: switch (decision) {
            CustomerDecision.notSuitable => 'DECLINED',
            CustomerDecision.considering => 'CONSIDERING',
            CustomerDecision.wantToRent => 'INTERESTED',
          },
          reasonCode: decision == CustomerDecision.notSuitable ? 'OTHER' : null,
          reasonNote: entry.feedback.isEmpty ? null : entry.feedback,
        );
        for (final issue in _issues) {
          await widget.viewingV2Api.reportIssue(
            widget.item.id,
            issueCode: _issueCode(issue),
            detail: entry.feedback.isEmpty ? null : entry.feedback,
          );
        }
        await widget.store.remove(widget.userId, widget.item.id);
      } else {
        // Compatibility-only draft for cohorts that still use the old API.
        await widget.store.save(widget.userId, widget.item.id, entry);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(
      title: const Text('Kết quả sau xem'),
      backgroundColor: HD.paper,
      surfaceTintColor: Colors.transparent,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PropertySummary(item: widget.item),
        const SizedBox(height: 18),
        Text('Bạn thấy căn này thế nào?', style: HD.bodyBold(size: 20)),
        const SizedBox(height: 10),
        for (final option in [
          (
            CustomerDecision.notSuitable,
            Icons.sentiment_dissatisfied_rounded,
            'Không phù hợp',
            'Không tiếp tục căn này',
            HD.inkMuted,
            const Color(0xffeef0f3),
          ),
          (
            CustomerDecision.considering,
            Icons.sentiment_neutral_rounded,
            'Đang cân nhắc',
            'Tôi cần thêm thời gian',
            HD.warning,
            HD.warningTint,
          ),
          (
            CustomerDecision.wantToRent,
            Icons.favorite_rounded,
            'Muốn thuê',
            'Nhờ Sale hỗ trợ bước tiếp theo',
            HD.accent,
            HD.accentTint,
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _DecisionTile(
              decision: option.$1,
              icon: option.$2,
              title: option.$3,
              subtitle: option.$4,
              color: option.$5,
              tint: option.$6,
              selected: _decision == option.$1,
              onTap: () => setState(() => _decision = option.$1),
            ),
          ),
        const SizedBox(height: 16),
        Text('Báo cáo vấn đề (nếu có)', style: HD.bodyBold(size: 18)),
        const SizedBox(height: 5),
        Text(
          'Chọn nội dung cần Sale hỗ trợ xem lại.',
          style: HD.body(size: 13, color: HD.inkMuted),
        ),
        const SizedBox(height: 8),
        for (final issue in _issueOptions)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: HD.accent,
            title: Text(issue, style: HD.body(size: 14)),
            value: _issues.contains(issue),
            onChanged: (value) => setState(
              () => value == true ? _issues.add(issue) : _issues.remove(issue),
            ),
          ),
        TextField(
          controller: _feedback,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Nhập ý kiến của bạn (không bắt buộc)...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: HD.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: HD.hairline),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _decision == null || _saving ? null : _save,
          icon: const Icon(Icons.send_rounded),
          label: Text(_saving ? 'Đang lưu...' : 'Lưu kết quả'),
          style: FilledButton.styleFrom(
            backgroundColor: HD.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.serverEnabled && widget.serverWritesEnabled
              ? 'Kết quả được lưu trên hệ thống và đồng bộ cho Sale, Chủ nhà theo đúng quyền.'
              : 'Kết quả đang được giữ dưới dạng bản nháp trên thiết bị cho đến khi luồng mới được bật.',
          textAlign: TextAlign.center,
          style: HD.body(size: 11, color: HD.inkMuted),
        ),
      ],
    ),
  );
}

Map<int, CustomerJourneyEntry> _canonicalDecisions(
  List<CanonicalViewing> viewings,
) => {
  for (final item in viewings)
    if (item.resultStatus case final status
        when status == 'CONSIDERING' ||
            status == 'INTERESTED' ||
            status == 'DECLINED')
      item.id: CustomerJourneyEntry(
        decision: switch (item.resultStatus) {
          'INTERESTED' => CustomerDecision.wantToRent,
          'DECLINED' => CustomerDecision.notSuitable,
          _ => CustomerDecision.considering,
        },
        issues: item.issues.map((issue) => issue.code).toList(),
        feedback: item.resultReasonNote ?? '',
        updatedAt: item.cancelledAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      ),
};

String _issueCode(String label) => switch (label) {
  'Thông tin BĐS không đúng' => 'WRONG_INFORMATION',
  'Sale hỗ trợ chưa tốt' => 'POOR_SUPPORT',
  'Lịch hẹn có vấn đề' => 'LATE_ARRIVAL',
  _ => 'OTHER',
};

class CustomerRentalScreen extends StatelessWidget {
  const CustomerRentalScreen({super.key, required this.item});
  final MucQuanLy item;

  @override
  Widget build(BuildContext context) =>
      PhongDangThueScreen(contractId: item.id);
}

class _CustomerProfileHeader extends StatelessWidget {
  const _CustomerProfileHeader({required this.user, required this.onSettings});
  final UserModel user;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
    decoration: BoxDecoration(
      color: HD.accent,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      boxShadow: [
        BoxShadow(
          color: HD.accent.withValues(alpha: .18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CustomerMasthead(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(url: user.avatarPath, name: user.name, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cá nhân',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tài khoản khách',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Cài đặt',
                onPressed: onSettings,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .16),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.settings_outlined, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(
                icon: Icons.calendar_month_rounded,
                text: 'Thành viên từ ${_monthYear(user.createdAt)}',
              ),
              _HeaderChip(
                icon: user.phone.isEmpty
                    ? Icons.phone_disabled_rounded
                    : Icons.phone_iphone_rounded,
                text: user.phone.isEmpty
                    ? 'Chưa thêm số điện thoại'
                    : 'Đã thêm số điện thoại',
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _monthYear(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 300),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: .18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CustomerMasthead extends StatelessWidget {
  const _CustomerMasthead({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Image.asset(
          'assets/branding/logo_mark.png',
          width: compact ? 32 : 34,
          height: compact ? 32 : 34,
          errorBuilder: (_, _, _) => const Icon(
            Icons.home_work_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VuaNhà',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tìm đúng nhà, sống đúng chất',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        if (!compact)
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
            ),
          ),
      ],
    );
    if (!compact) return row;
    return Container(
      color: HD.accent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: row,
        ),
      ),
    );
  }
}

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: HD.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _CustomerStat extends StatelessWidget {
  const _CustomerStat({
    required this.value,
    required this.label,
    required this.icon,
    this.tint = HD.accent,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(height: 5),
          Text(value, style: HD.bodyBold(size: 18)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.body(size: 10, color: HD.inkMuted),
          ),
        ],
      ),
    ),
  );
}

class _CustomerQuickAction extends StatelessWidget {
  const _CustomerQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = HD.accent,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: HD.hairline),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 12, color: HD.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CustomerMenuItem extends StatelessWidget {
  const _CustomerMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.last = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool last;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Column(
      children: [
        ListTile(
          minLeadingWidth: 30,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HD.accent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: HD.accent, size: 20),
          ),
          title: Text(title, style: HD.body(size: 14, color: HD.ink)),
          trailing:
              trailing ??
              const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
          onTap: onTap,
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.only(left: 58),
            child: Divider(height: 1, color: HD.hairline),
          ),
      ],
    ),
  );
}

class _CustomerCountCard extends StatelessWidget {
  const _CustomerCountCard({
    required this.number,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String number;
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(number, style: HD.bodyBold(size: 19)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 10, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PropertyThumb extends StatelessWidget {
  const _PropertyThumb({
    required this.url,
    required this.width,
    required this.height,
  });
  final String? url;
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) {
    final full = url == null || url!.isEmpty ? null : _fullImageUrl(url!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: full == null
            ? const _PropertyFallback()
            : CachedNetworkImage(
                imageUrl: full,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const _PropertyFallback(),
                placeholder: (_, _) => const _PropertyFallback(),
              ),
      ),
    );
  }
}

class _PropertyFallback extends StatelessWidget {
  const _PropertyFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xffe8eaee),
    child: Center(
      child: Icon(Icons.home_work_outlined, color: HD.inkMuted, size: 30),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: HD.bodyBold(size: 10, color: color),
    ),
  );
}

class _PropertySummary extends StatelessWidget {
  const _PropertySummary({required this.item});
  final MucQuanLy item;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        _PropertyThumb(url: item.anh, width: 100, height: 90),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.tieuDe, style: HD.bodyBold(size: 16)),
              if (item.diaChi.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(item.diaChi, style: HD.body(size: 12, color: HD.inkMuted)),
              ],
              if (item.ma.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(item.ma, style: HD.body(size: 12, color: HD.inkMuted)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({
    required this.decision,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.tint,
    required this.selected,
    required this.onTap,
  });
  final CustomerDecision decision;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? tint : Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : HD.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HD.bodyBold(size: 15, color: color)),
                  Text(subtitle, style: HD.body(size: 12, color: HD.inkMuted)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.size});
  final String url;
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final image = url.isEmpty ? null : _fullImageUrl(url);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white24,
      foregroundImage: image == null ? null : NetworkImage(image),
      child: image == null
          ? Text(
              name.isEmpty ? 'K' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

String _fullImageUrl(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

class _CustomerError extends StatelessWidget {
  const _CustomerError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: HD.inkMuted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: HD.body(size: 14, color: HD.inkMuted),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
