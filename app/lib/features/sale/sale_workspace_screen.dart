import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/sale_crm_v2_api.dart';
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';

/// Workspace riêng của Sale.
///
/// Sale làm việc theo pipeline khách hàng và nguồn hàng được giao. Màn này
/// không dùng `QuanLyScreen`: không có góc "Của tôi", không có thao tác hợp
/// đồng và không hiển thị dữ liệu vận hành của chủ nhà.
class SaleWorkspaceScreen extends StatefulWidget {
  const SaleWorkspaceScreen({
    super.key,
    this.api = const QuanLyApi(),
    this.managementApi = const ManagementReadModelApi(),
    this.crmApi = const SaleCrmV2Api(),
    this.bayGio,
  });

  final QuanLyApi api;
  final ManagementReadModelApi managementApi;
  final SaleCrmV2Api crmApi;
  final DateTime? bayGio;

  @override
  State<SaleWorkspaceScreen> createState() => _SaleWorkspaceScreenState();
}

enum _SaleView { tongQuan, khachHang, lich, nguonHang, giaoDich, hoTro }

class _SaleWorkspaceScreenState extends State<SaleWorkspaceScreen> {
  TongHopQuanLy? _data;
  _SaleView _view = _SaleView.tongQuan;
  String _search = '';
  bool _loading = true;
  String? _error;
  int? _uid;
  bool _canonical = false;
  bool _crmWrites = false;
  SaleCrmDashboard? _crmDashboard;
  List<SaleCrmContact> _crmContacts = const [];
  List<SaleCrmTask> _crmTasks = const [];
  List<SaleCrmProperty> _crmProperties = const [];
  List<SaleCrmDeal> _crmDeals = const [];
  List<SaleStaySupport> _staySupport = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _uid = user.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final capabilities = await widget.managementApi.capabilities();
      if (capabilities.saleCrmV2Enabled) {
        final values = await Future.wait<Object>([
          widget.crmApi.dashboard(),
          widget.crmApi.contacts(),
          widget.crmApi.tasks(status: 'OPEN'),
          widget.crmApi.properties(),
          widget.crmApi.deals(),
          widget.crmApi.staySupport(),
        ]);
        if (!mounted || _uid != user.id) return;
        setState(() {
          _canonical = true;
          _data = null;
          _crmWrites = capabilities.saleCrmV2WritesEnabled;
          _crmDashboard = values[0] as SaleCrmDashboard;
          _crmContacts = values[1] as List<SaleCrmContact>;
          _crmTasks = values[2] as List<SaleCrmTask>;
          _crmProperties = values[3] as List<SaleCrmProperty>;
          _crmDeals = values[4] as List<SaleCrmDeal>;
          _staySupport = values[5] as List<SaleStaySupport>;
          _loading = false;
        });
        return;
      }
      final data = await widget.api.tongHop(GocQuanLy.khachThue);
      if (!mounted || _uid != user.id) return;
      setState(() {
        _data = data;
        _canonical = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Chưa tải được workspace Sale.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return _chuaDangNhap();

    return Scaffold(
      backgroundColor: HD.paper,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(user.name)),
            SliverToBoxAdapter(child: _workspaceNav()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(hasScrollBody: false, child: _loiTai())
            else if (_canonical)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverToBoxAdapter(child: _canonicalBody()),
              )
            else if (_data != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverToBoxAdapter(child: _body(_data!)),
              )
            else
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Chưa có dữ liệu khách hàng.')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(String name) {
    final unread = context.watch<NotificationProvider>().unread;
    return SizedBox(
      // Đủ chỗ cho safe-area và cỡ chữ trợ năng; chiều cao cũ 226px làm
      // tagline bị cắt ở màn Android hẹp.
      height: 252,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/branding/sale_workspace_hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => const ColoredBox(color: HD.accentDeep),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.58),
                  Colors.black.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0, 0.48, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insights_outlined,
                              color: Colors.white,
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SALE WORKSPACE',
                              style: HD.bodyBold(size: 13, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Thông báo',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                        icon: Badge(
                          isLabelVisible: unread > 0,
                          label: Text(unread > 99 ? '99+' : '$unread'),
                          child: const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Điều phối khách\nvà nguồn hàng',
                    style: HD.masthead(size: 28, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Xin chào, $name. Hôm nay cần làm gì?',
                    style: HD.body(
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _pill(
                    'SALE',
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceNav() => Container(
    color: HD.paperRaised,
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _navItem(_SaleView.tongQuan, Icons.dashboard_outlined, 'Tổng quan'),
          _navItem(_SaleView.khachHang, Icons.groups_outlined, 'Khách hàng'),
          _navItem(_SaleView.lich, Icons.calendar_month_outlined, 'Lịch'),
          _navItem(_SaleView.nguonHang, Icons.home_work_outlined, 'Nguồn hàng'),
          if (_canonical)
            _navItem(_SaleView.giaoDich, Icons.handshake_outlined, 'Giao dịch'),
          if (_canonical)
            _navItem(_SaleView.hoTro, Icons.support_agent_outlined, 'Hậu mãi'),
        ],
      ),
    ),
  );

  Widget _navItem(_SaleView view, IconData icon, String label) {
    final selected = _view == view;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : HD.inkMuted,
        ),
        label: Text(label),
        onSelected: (_) => setState(() => _view = view),
        selectedColor: HD.accent,
        backgroundColor: HD.paperSunken,
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: selected ? Colors.white : HD.inkSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _body(TongHopQuanLy data) {
    switch (_view) {
      case _SaleView.khachHang:
        return _khachHang(data);
      case _SaleView.lich:
        return _lich(data);
      case _SaleView.nguonHang:
        return _nguonHang(data);
      case _SaleView.giaoDich:
      case _SaleView.hoTro:
        return _tongQuan(data);
      case _SaleView.tongQuan:
        return _tongQuan(data);
    }
  }

  Widget _canonicalBody() {
    switch (_view) {
      case _SaleView.khachHang:
        return _crmContactList();
      case _SaleView.lich:
        return _crmTaskList(all: true);
      case _SaleView.nguonHang:
        return _crmPropertyList();
      case _SaleView.giaoDich:
        return _crmDealList();
      case _SaleView.hoTro:
        return _crmStayList();
      case _SaleView.tongQuan:
        return _crmOverview();
    }
  }

  Widget _crmOverview() {
    final d = _crmDashboard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Nhịp làm việc hôm nay', ''),
        const SizedBox(height: 10),
        Row(
          children: [
            _metric('Cần làm', d?.openTasks ?? 0, Icons.task_alt, HD.accent),
            _metric(
              'Quá hạn',
              d?.overdueTasks ?? 0,
              Icons.timer_off_outlined,
              HD.negative,
            ),
            _metric(
              'Giao dịch',
              d?.activeDeals ?? 0,
              Icons.handshake_outlined,
              HD.accentAmber,
            ),
            _metric(
              'Nguồn hàng',
              d?.propertyCount ?? 0,
              Icons.apartment_outlined,
              HD.positive,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle('Việc ưu tiên', '${_crmTasks.length} việc mở'),
        const SizedBox(height: 10),
        _crmTaskList(limit: 4),
        const SizedBox(height: 20),
        _sectionTitle('Pipeline giao dịch', 'Sale theo dõi · các bên xác nhận'),
        const SizedBox(height: 10),
        _pipelineBar(),
        const SizedBox(height: 14),
        _privacyNotice(),
      ],
    );
  }

  Widget _crmTaskList({bool all = false, int? limit}) {
    final values = limit == null ? _crmTasks : _crmTasks.take(limit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (all) ...[
          _sectionTitle('Hộp việc Sale', '${_crmTasks.length} việc đang mở'),
          const SizedBox(height: 10),
        ],
        if (values.isEmpty)
          _empty('Không có việc tồn', 'Bạn đang bắt kịp mọi đầu việc.')
        else
          for (final task in values)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HD.r12),
                side: const BorderSide(color: HD.hairline),
              ),
              child: ListTile(
                leading: _IconTile(
                  icon: task.dueAt.isBefore(DateTime.now())
                      ? Icons.priority_high_rounded
                      : Icons.schedule_rounded,
                  color: task.dueAt.isBefore(DateTime.now())
                      ? HD.negative
                      : HD.accent,
                  background: task.dueAt.isBefore(DateTime.now())
                      ? HD.negativeTint
                      : HD.accentTint,
                ),
                title: Text(task.title, style: HD.bodyBold(size: 14)),
                subtitle: Text('Hạn ${_dateTime(task.dueAt)} · ${task.status}'),
                trailing: _crmWrites
                    ? IconButton(
                        tooltip: 'Đánh dấu hoàn tất',
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: HD.positive,
                        ),
                        onPressed: () => _completeTask(task),
                      )
                    : const Icon(Icons.chevron_right),
              ),
            ),
      ],
    );
  }

  Widget _crmContactList() {
    final query = _search.trim().toLowerCase();
    final values = _crmContacts
        .where(
          (item) =>
              query.isEmpty ||
              '${item.name} ${item.phone} ${item.email}'.toLowerCase().contains(
                query,
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Quan hệ đang phụ trách', '${values.length} liên hệ'),
        const SizedBox(height: 10),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm khách hàng hoặc chủ nhà...',
            filled: true,
            fillColor: HD.paperRaised,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        if (values.isEmpty)
          _empty(
            'Chưa có liên hệ',
            'Liên hệ xuất hiện khi Sale được phân công chính thức.',
          )
        else
          for (final contact in values)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: contact.type == 'OWNER'
                      ? const Color(0xffe5f6ef)
                      : HD.accentTint,
                  child: Icon(
                    contact.type == 'OWNER'
                        ? Icons.home_work_outlined
                        : Icons.person_outline,
                  ),
                ),
                title: Text(contact.name, style: HD.bodyBold(size: 15)),
                subtitle: Text(
                  '${contact.type == 'OWNER' ? 'Chủ nhà' : 'Khách hàng'} · ${contact.phone}\n${contact.openTasks} việc đang mở',
                ),
                isThreeLine: true,
                trailing: _crmWrites
                    ? IconButton(
                        tooltip: 'Ghi chú riêng',
                        icon: const Icon(Icons.note_add_outlined),
                        onPressed: () => _addNote(contact),
                      )
                    : const Icon(Icons.chevron_right),
              ),
            ),
        const SizedBox(height: 8),
        _privacyNotice(),
      ],
    );
  }

  Widget _crmPropertyList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Nguồn hàng được giao', '${_crmProperties.length} tòa'),
      const SizedBox(height: 10),
      if (_crmProperties.isEmpty)
        _empty(
          'Chưa có nguồn hàng',
          'Chỉ các tòa đã liên kết Sale mới hiển thị.',
        )
      else
        for (final item in _crmProperties)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            child: ListTile(
              leading: const _IconTile(
                icon: Icons.apartment_rounded,
                color: HD.accent,
                background: HD.accentTint,
              ),
              title: Text(item.name, style: HD.bodyBold(size: 15)),
              subtitle: Text(
                '${item.address}\n${item.roomCount} phòng · ${item.occupiedCount} đang ở · ${item.listedCount} đang rao',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
    ],
  );

  Widget _crmDealList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Pipeline giao dịch', '${_crmDeals.length} hồ sơ'),
      const SizedBox(height: 8),
      Text(
        'Sale theo dõi và chuẩn bị hồ sơ; khách và chủ nhà giữ quyền xác nhận cuối.',
        style: HD.body(size: 13, color: HD.inkMuted),
      ),
      const SizedBox(height: 12),
      _pipelineBar(),
      const SizedBox(height: 12),
      if (_crmDeals.isEmpty)
        _empty('Chưa có giao dịch', 'Khách muốn thuê sẽ tạo hồ sơ tại đây.')
      else
        for (final deal in _crmDeals)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            child: ListTile(
              leading: const _IconTile(
                icon: Icons.handshake_outlined,
                color: HD.accentAmber,
                background: Color(0xfffff4df),
              ),
              title: Text(
                'Hồ sơ #${deal.id} · ${_money(deal.amount)}',
                style: HD.bodyBold(size: 14),
              ),
              subtitle: Text(
                '${_stageLabel(deal.pipelineStage)} · trạng thái giao dịch: ${deal.transactionStatus}',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
    ],
  );

  Widget _crmStayList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Hỗ trợ sau khi vào ở', '${_staySupport.length} hồ sơ'),
      const SizedBox(height: 8),
      Text(
        'Sale được xem, liên hệ, chụp chỉ số và báo sự cố; không quản lý tài khoản nhận tiền của Chủ nhà.',
        style: HD.body(size: 13, color: HD.inkMuted),
      ),
      const SizedBox(height: 12),
      if (_staySupport.isEmpty)
        _empty(
          'Chưa có hồ sơ hậu mãi',
          'Hồ sơ đã thuê/đang ở sẽ xuất hiện tại đây.',
        )
      else
        for (final item in _staySupport)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            child: ListTile(
              leading: const _IconTile(
                icon: Icons.support_agent,
                color: HD.positive,
                background: Color(0xffe7f7ef),
              ),
              title: Text(
                'Hành trình #${item.journeyId}',
                style: HD.bodyBold(size: 14),
              ),
              subtitle: Text(
                'Phòng ${item.roomId ?? '—'} · ${item.status}\n${item.allowedActions.join(' · ')}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HostAppointmentsScreen(),
                ),
              ),
            ),
          ),
    ],
  );

  Widget _pipelineBar() {
    const stages = ['FOLLOW_UP', 'NEGOTIATION', 'PAPERWORK', 'WON', 'LOST'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final stage in stages)
          Chip(
            avatar: CircleAvatar(
              backgroundColor: stage == 'LOST'
                  ? HD.negative
                  : stage == 'WON'
                  ? HD.positive
                  : HD.accent,
              child: Text(
                '${_crmDeals.where((item) => item.pipelineStage == stage).length}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            label: Text(_stageLabel(stage)),
            side: BorderSide.none,
            backgroundColor: HD.paperSunken,
          ),
      ],
    );
  }

  Widget _privacyNotice() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xfffff5e7),
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Row(
      children: [
        const Icon(Icons.lock_outline, color: HD.accentAmber),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Ghi chú CRM là riêng tư, chỉ Sale được phân công mới xem được.',
            style: HD.body(size: 12, color: HD.inkSoft),
          ),
        ),
      ],
    ),
  );

  Future<void> _completeTask(SaleCrmTask task) async {
    try {
      await widget.crmApi.updateTask(task.id, 'DONE');
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa cập nhật được công việc.')),
        );
    }
  }

  Future<void> _addNote(SaleCrmContact contact) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ghi chú riêng · ${contact.name}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nội dung chỉ Sale được phân công nhìn thấy',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await widget.crmApi.addPrivateNote(contact.id, value);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu ghi chú riêng.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chưa lưu được ghi chú.')));
    }
  }

  static String _stageLabel(String value) => switch (value) {
    'NEGOTIATION' => 'Đang thương lượng',
    'PAPERWORK' => 'Hồ sơ & cọc',
    'WON' => 'Đã thuê',
    'LOST' => 'Không chốt được',
    _ => 'Đang theo sát',
  };

  static String _money(int value) {
    final text = value.toString();
    final chunks = <String>[];
    for (var end = text.length; end > 0; end -= 3) {
      chunks.insert(0, text.substring((end - 3).clamp(0, end), end));
    }
    return '${chunks.join('.')}đ';
  }

  static String _dateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Widget _tongQuan(TongHopQuanLy data) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Việc cần làm', 'Ưu tiên hôm nay'),
      const SizedBox(height: 10),
      _taskList(data),
      const SizedBox(height: 20),
      _sectionTitle('Pipeline khách hàng', 'Xem chi tiết'),
      const SizedBox(height: 10),
      _pipeline(data),
      const SizedBox(height: 20),
      _sectionTitle('Lịch sắp tới', 'Mở lịch'),
      const SizedBox(height: 10),
      _calendarList(data),
    ],
  );

  Widget _khachHang(TongHopQuanLy data) {
    final items = _filtered(data.danhSach);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Khách hàng', '${items.length} khách'),
        const SizedBox(height: 10),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm tên khách, phòng hoặc mã lịch...',
            filled: true,
            fillColor: HD.paperRaised,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _empty('Chưa có khách phù hợp', 'Thử đổi từ khóa hoặc bộ lọc.')
        else
          for (final item in items) _customerRow(item),
      ],
    );
  }

  Widget _lich(TongHopQuanLy data) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Lịch làm việc', '${data.lich.length} mốc'),
      const SizedBox(height: 10),
      if (data.lich.isEmpty)
        _empty('Lịch đang trống', 'Các lịch xem mới sẽ xuất hiện ở đây.')
      else
        _calendarList(data, expanded: true),
    ],
  );

  Widget _nguonHang(TongHopQuanLy data) {
    final grouped = <String, List<MucQuanLy>>{};
    for (final item in data.danhSach) {
      grouped
          .putIfAbsent(item.ma.isEmpty ? item.tieuDe : item.ma, () => [])
          .add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Nguồn hàng phụ trách', '${grouped.length} nhóm'),
        const SizedBox(height: 10),
        if (grouped.isEmpty)
          _empty(
            'Chưa có nguồn hàng',
            'Các phòng được giao sẽ xuất hiện ở đây.',
          )
        else
          for (final entry in grouped.entries)
            _inventoryRow(entry.key, entry.value),
      ],
    );
  }

  Widget _taskList(TongHopQuanLy data) {
    final tasks = data.danhSach
        .where((item) => item.canXuLy || item.nhac)
        .take(3)
        .toList();
    if (tasks.isEmpty) {
      return _empty('Không có việc gấp', 'Bạn đang bắt kịp mọi khách hàng.');
    }
    return Column(
      children: [for (final item in tasks) _customerRow(item, task: true)],
    );
  }

  Widget _pipeline(TongHopQuanLy data) => Row(
    children: [
      _metric('Cần xử lý', data.dem.canXuLy, Icons.priority_high, HD.negative),
      _metric('Đã đặt lịch', data.dem.daDat, Icons.event_available, HD.accent),
      _metric(
        'Đang theo dõi',
        data.dem.dangDat,
        Icons.track_changes,
        HD.accentAmber,
      ),
      _metric(
        'Đã xong',
        data.dem.lichSu,
        Icons.check_circle_outline,
        HD.positive,
      ),
    ],
  );

  Widget _metric(String label, int value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconTile(icon, color),
              const SizedBox(height: 8),
              Text('$value', style: HD.bodyBold(size: 22)),
              Text(
                label,
                maxLines: 2,
                style: HD.body(size: 11, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      );

  Widget _customerRow(MucQuanLy item, {bool task = false}) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HD.r12),
      side: const BorderSide(color: HD.hairline),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(HD.r12),
      onTap: () => _open(item),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _itemVisual(item, task: task),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.khach ?? item.tieuDe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.dong.isEmpty ? item.diaChi : item.dong,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: HD.inkMuted),
          ],
        ),
      ),
    ),
  );

  Widget _calendarList(TongHopQuanLy data, {bool expanded = false}) {
    final events = expanded ? data.lich : data.lich.take(3).toList();
    if (events.isEmpty) {
      return _empty('Chưa có lịch sắp tới', 'Lịch xem mới sẽ hiện ở đây.');
    }
    return Column(
      children: [
        for (final event in events)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HD.r12),
              side: const BorderSide(color: HD.hairline),
            ),
            child: ListTile(
              leading: const _IconTile(
                icon: Icons.event_outlined,
                color: HD.accent,
                background: HD.accentTint,
              ),
              title: Text(event.tieuDe, style: HD.bodyBold(size: 14)),
              subtitle: Text(
                event.noi,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openById(event.mucLoai, event.mucId),
            ),
          ),
      ],
    );
  }

  Widget _inventoryRow(String key, List<MucQuanLy> items) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HD.r12),
      side: const BorderSide(color: HD.hairline),
    ),
    child: ListTile(
      leading: const _IconTile(
        icon: Icons.apartment_outlined,
        color: HD.inkSoft,
        background: HD.paperSunken,
      ),
      title: Text(key, style: HD.bodyBold(size: 15)),
      subtitle: Text('${items.length} mục đang theo dõi'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => setState(() => _view = _SaleView.khachHang),
    ),
  );

  List<MucQuanLy> _filtered(List<MucQuanLy> source) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source.where((item) {
      final haystack =
          '${item.khach ?? ''} ${item.tieuDe} ${item.ma} ${item.diaChi}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _open(MucQuanLy item) => _openById(item.loai, item.id);

  Future<void> _openById(String type, int id) async {
    if (type == 'xem_nha' || type == 'hen_chot') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HostAppointmentsScreen()),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mục #$id đang được theo dõi trong pipeline.')),
    );
  }

  Widget _sectionTitle(String title, String action) => Row(
    children: [
      Expanded(child: Text(title, style: HD.bodyBold(size: 18))),
      if (action.isNotEmpty)
        if (title == 'Lịch sắp tới' ||
            title == 'Pipeline khách hàng' ||
            title == 'Việc cần làm')
          TextButton(
            onPressed: () {
              if (title == 'Lịch sắp tới') {
                setState(() => _view = _SaleView.lich);
              } else {
                setState(() => _view = _SaleView.khachHang);
              }
            },
            child: Text(action),
          )
        else
          Text(action, style: HD.body(size: 13, color: HD.inkMuted)),
    ],
  );

  Widget _iconTile(IconData icon, Color color) => _IconTile(
    icon: icon,
    color: color,
    background: color.withValues(alpha: 0.12),
  );

  Widget _itemVisual(MucQuanLy item, {required bool task}) {
    final image = item.anh;
    if (image != null && image.isNotEmpty) {
      final url = image.startsWith('http')
          ? image
          : '${ApiConfig.baseUrl}$image';
      return ClipRRect(
        borderRadius: BorderRadius.circular(HD.r12),
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackVisual(task),
        ),
      );
    }
    return _fallbackVisual(task);
  }

  Widget _fallbackVisual(bool task) => _IconTile(
    icon: task ? Icons.notifications_active_outlined : Icons.person_outline,
    color: task ? HD.accent : HD.inkMuted,
    background: task ? HD.accentTint : HD.paperSunken,
  );

  Widget _pill(String text, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: foreground,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _empty(String title, String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, color: HD.inkMuted, size: 34),
        const SizedBox(height: 8),
        Text(title, style: HD.bodyBold(size: 15)),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: HD.body(size: 13, color: HD.inkMuted),
        ),
      ],
    ),
  );

  Widget _loiTai() => Padding(
    padding: const EdgeInsets.all(32),
    child: _empty(_error ?? 'Có lỗi xảy ra', 'Kéo xuống để thử tải lại.'),
  );

  Widget _chuaDangNhap() => const Scaffold(
    body: Center(child: Text('Đăng nhập để mở workspace Sale.')),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Icon(icon, color: color, size: 23),
  );
}
