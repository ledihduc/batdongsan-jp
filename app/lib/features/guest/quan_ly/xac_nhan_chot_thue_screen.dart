import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/deal_api.dart';

/// Xác nhận đề nghị chốt thuê dài hạn do chủ nhà gửi.
class XacNhanChotThueScreen extends StatefulWidget {
  const XacNhanChotThueScreen({
    super.key,
    this.dealId,
    this.api = const DealApi(),
  });
  final int? dealId;
  final DealApi api;

  @override
  State<XacNhanChotThueScreen> createState() => _XacNhanChotThueScreenState();
}

class _XacNhanChotThueScreenState extends State<XacNhanChotThueScreen> {
  List<DealModel> _ds = const [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final ds = await widget.api.cuaToi();
      if (mounted) {
        setState(() {
          _ds = ds
              .where(
                (x) =>
                    (widget.dealId == null || x.id == widget.dealId) &&
                    (x.trangThai == 'awaiting_guest' ||
                        x.trangThai == 'confirmed'),
              )
              .toList();
          _dangTai = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _dangTai = false);
      }
    }
  }

  Future<void> _xacNhan(DealModel d) async {
    try {
      await widget.api.xacNhanKhach(d.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã đồng ý thuê. Hợp đồng nháp đang chờ chủ nhà hoàn tất.',
          ),
        ),
      );
      _nap();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không xác nhận được, vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: DsAppBar(title: 'Xác nhận chốt thuê dài hạn'),
    body: RefreshIndicator(
      onRefresh: _nap,
      child: _dangTai
          ? const Center(child: CircularProgressIndicator())
          : _ds.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 130),
                Icon(Icons.check_circle_outline, size: 56, color: HD.positive),
                SizedBox(height: 12),
                Center(child: Text('Chưa có đề nghị chốt thuê cần xác nhận.')),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _ds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _card(_ds[i]),
            ),
    ),
  );

  Widget _card(DealModel d) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe2e8f0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.handshake_outlined, color: HD.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(d.tenDoiTuong, style: HD.bodyBold(size: 17))),
            _pill(
              d.trangThai == 'awaiting_guest'
                  ? 'Chờ bạn xác nhận'
                  : 'Đã đồng ý thuê',
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Chủ nhà đã chốt đề nghị thuê dài hạn cho phòng này. Kiểm tra lại thông tin trước khi xác nhận.',
        ),
        if (d.soTien > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Giá thuê dự kiến: ${_money(d.soTien)}đ/tháng',
            style: HD.bodyBold(size: 14, color: HD.accent),
          ),
        ],
        const SizedBox(height: 14),
        if (d.trangThai == 'awaiting_guest')
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _xacNhan(d),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Đồng ý thuê'),
            ),
          )
        else
          const Row(
            children: [
              Icon(Icons.description_outlined, color: HD.positive),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hợp đồng nháp đã được tạo. Chủ nhà sẽ hoàn tất thông tin trước khi kích hoạt.',
                ),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _pill(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: HD.warningTint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(s, style: HD.bodyBold(size: 11, color: HD.svcAmber)),
  );
  String _money(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => '.');
}
