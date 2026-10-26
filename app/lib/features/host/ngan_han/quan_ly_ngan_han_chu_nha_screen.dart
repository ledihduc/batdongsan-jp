import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_bookings_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_operations_role.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_rooms_screen.dart';
import 'package:house_booking/features/host/ngan_han/lich_ngan_han_screen.dart';

/// Lối vào ngắn hạn cấp Chủ nhà.
///
/// Trước đây lịch chỉ mở từ chi tiết từng tòa nên bị chôn sâu. Màn này giữ các
/// màn vận hành hiện có nhưng gom chúng thành một workspace có thể mở trực tiếp
/// từ Hoạt động: đơn đặt phòng, giá/khoá phòng và lịch của từng tòa.
class QuanLyNganHanChuNhaScreen extends StatefulWidget {
  const QuanLyNganHanChuNhaScreen({
    super.key,
    this.api = const TongQuanChuNhaApi(),
  });

  final TongQuanChuNhaApi api;

  @override
  State<QuanLyNganHanChuNhaScreen> createState() =>
      _QuanLyNganHanChuNhaScreenState();
}

class _QuanLyNganHanChuNhaScreenState extends State<QuanLyNganHanChuNhaScreen> {
  TongQuanChuNha? _data;
  bool _loading = true;
  String? _error;

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
      final data = await widget.api.lay();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa tải được danh sách tòa ngắn hạn.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff7f9fc),
    appBar: AppBar(
      title: const Text('Quản lý ngắn hạn'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      color: HD.accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _hero(),
          const SizedBox(height: 14),
          _quickActions(),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lịch theo tòa',
                  style: HD.bodyBold(size: 18, color: HD.ink),
                ),
              ),
              Text(
                '${_data?.nganHan.length ?? 0} tòa',
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(42),
              child: Center(child: CircularProgressIndicator(color: HD.accent)),
            )
          else if (_error != null)
            _message(
              icon: Icons.cloud_off_rounded,
              text: _error!,
              action: 'Thử lại',
              onTap: _load,
            )
          else if ((_data?.nganHan ?? const <KhoiNganHan>[]).isEmpty)
            _message(
              icon: Icons.calendar_month_outlined,
              text:
                  'Chưa có tòa bật kênh ngắn hạn. Lối quản lý vẫn được giữ để '
                  'bạn quay lại ngay sau khi cấu hình phòng.',
            )
          else
            for (final building in _data!.nganHan) ...[
              _buildingCard(building),
              const SizedBox(height: 10),
            ],
        ],
      ),
    ),
  );

  Widget _hero() => Container(
    key: const Key('owner-short-stay-hero'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xffef1728), Color(0xffff5966)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2aef1728),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lịch & đặt phòng ngắn hạn',
                style: HD.bodyBold(size: 20, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Theo dõi phòng theo giờ, ngày; xử lý nhận và trả phòng.',
                style: HD.body(size: 13, color: const Color(0xffffe8ea)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.calendar_view_week_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ],
    ),
  );

  Widget _quickActions() => Row(
    children: [
      Expanded(
        child: _actionCard(
          key: const Key('owner-short-stay-bookings'),
          icon: Icons.receipt_long_rounded,
          title: 'Đơn đặt phòng',
          subtitle: 'Duyệt · nhận · trả',
          color: HD.accent,
          onTap: () => _open(
            const ShortStayBookingsScreen(
              operations: true,
              operationsRole: ShortStayOperationsRole.owner,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _actionCard(
          key: const Key('owner-short-stay-inventory'),
          icon: Icons.meeting_room_outlined,
          title: 'Giá & khóa phòng',
          subtitle: 'Tồn kho và mức giá',
          color: const Color(0xff2563d9),
          onTap: () => _open(const ShortStayRoomsScreen()),
        ),
      ),
    ],
  );

  Widget _actionCard({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => Material(
    key: key,
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe6eaf0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(title, style: HD.bodyBold(size: 14, color: HD.ink)),
            const SizedBox(height: 2),
            Text(subtitle, style: HD.body(size: 11.5, color: HD.inkMuted)),
          ],
        ),
      ),
    ),
  );

  Widget _buildingCard(KhoiNganHan building) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: Key('owner-short-stay-building-${building.buildingId}'),
      onTap: () => _open(LichNganHanScreen(buildingId: building.buildingId)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe6eaf0)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xffffecee),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.apartment_rounded, color: HD.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    building.ten,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 15, color: HD.ink),
                  ),
                  if (building.diaChi.isNotEmpty)
                    Text(
                      building.diaChi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    '${building.dangSuDung} đang ở · ${building.trong} phòng trống',
                    style: HD.body(size: 12, color: const Color(0xff087f4f)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
          ],
        ),
      ),
    ),
  );

  Widget _message({
    required IconData icon,
    required String text,
    String? action,
    VoidCallback? onTap,
  }) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe6eaf0)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 38, color: HD.inkMuted),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: HD.body(size: 13, color: HD.inkMuted),
        ),
        if (action != null && onTap != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onTap, child: Text(action)),
        ],
      ],
    ),
  );
}
