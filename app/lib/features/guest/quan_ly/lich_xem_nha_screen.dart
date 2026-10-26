import 'package:flutter/material.dart';
import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';

/// Lịch xem của khách thuê dài hạn, chia theo trạng thái của dữ liệu máy chủ.
class LichXemNhaScreen extends StatefulWidget {
  const LichXemNhaScreen({super.key, this.api = const QuanLyApi()});

  final QuanLyApi api;

  @override
  State<LichXemNhaScreen> createState() => _LichXemNhaScreenState();
}

class _LichXemNhaScreenState extends State<LichXemNhaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  TongHopQuanLy? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.tongHop(GocQuanLy.cuaToi);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Chưa tải được lịch xem. Kiểm tra mạng rồi thử lại.';
        _loading = false;
      });
    }
  }

  List<MucQuanLy> _items(int tab) {
    final all = _data?.danhSach.where((m) => m.laLichHen).toList() ?? const [];
    return switch (tab) {
      0 => all.where((m) => m.nhom == NhomQuanLy.dangDat).toList(),
      1 => all.where((m) => m.nhom == NhomQuanLy.daDat).toList(),
      _ => all.where((m) => m.nhom == NhomQuanLy.lichSu).toList(),
    };
  }

  Future<void> _open(MucQuanLy item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PhieuHenXemScreen(appointmentId: item.id),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Đang xếp lịch', 'Sắp tới', 'Đã xem'];
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: HD.ink),
        ),
        title: Text(
          'Lịch xem nhà',
          style: HD.bodyBold(size: 19, color: HD.ink),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: HD.accent),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: TabBar(
            controller: _tabs,
            isScrollable: false,
            labelColor: HD.accent,
            unselectedLabelColor: HD.inkMuted,
            indicatorColor: HD.accent,
            indicatorWeight: 3,
            labelStyle: HD.bodyBold(size: 13),
            tabs: [
              for (var i = 0; i < tabs.length; i++)
                Tab(text: '${tabs[i]} (${_items(i).length})'),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _error != null
          ? _errorView()
          : TabBarView(
              controller: _tabs,
              children: [for (var i = 0; i < 3; i++) _list(i)],
            ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: HD.inkMuted),
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: HD.body(size: 14, color: HD.inkMuted),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      ),
    ),
  );

  Widget _list(int tab) {
    final items = _items(tab);
    if (items.isEmpty) {
      final messages = [
        'Lịch đang chờ xếp hoặc chọn giờ sẽ hiện ở đây.',
        'Lịch đã được xác nhận sẽ hiện ở đây.',
        'Các buổi xem đã kết thúc sẽ hiện ở đây.',
      ];
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 150),
            const Icon(
              Icons.event_available_outlined,
              size: 48,
              color: HD.inkMuted,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Chưa có lịch xem',
                style: HD.bodyBold(size: 17, color: HD.ink),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                messages[tab],
                textAlign: TextAlign.center,
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(items[i], tab),
      ),
    );
  }

  Widget _card(MucQuanLy item, int tab) {
    final proposed =
        item.dong.toLowerCase().contains('đề xuất') ||
        item.dong.toLowerCase().contains('chọn giờ');
    final badge = proposed
        ? 'Có giờ đề xuất'
        : tab == 0
        ? 'Đang xếp lịch'
        : tab == 1
        ? 'Đã xác nhận'
        : item.nhan;
    final color = proposed
        ? HD.svcAmber
        : tab == 1
        ? HD.positive
        : HD.accent;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _open(item),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HD.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 86,
                      height: 86,
                      child: item.anh == null || item.anh!.isEmpty
                          ? Container(
                              color: HD.accentTint,
                              child: const Icon(
                                Icons.apartment_rounded,
                                color: HD.accent,
                              ),
                            )
                          : Image.network(
                              item.anh!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: HD.accentTint,
                                child: const Icon(
                                  Icons.apartment_rounded,
                                  color: HD.accent,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.tieuDe,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 16, color: HD.ink),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.diaChi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HD.body(size: 12, color: HD.inkMuted),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge,
                            style: HD.bodyBold(size: 11, color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
                ],
              ),
              if (item.dong.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: HD.paper,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.dong,
                    style: HD.body(size: 13, color: HD.ink),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _open(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.accent,
                    side: const BorderSide(color: HD.accent),
                  ),
                  child: Text(proposed ? 'Chọn giờ xem' : 'Xem chi tiết lịch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
