import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';

/// Giá điện · nước · dịch vụ MẶC ĐỊNH cho cả toà.
///
/// Vì sao đặt ở toà chứ không bắt khai từng phòng: một toà 20 phòng xài chung
/// công tơ tổng thì cùng một giá — bắt gõ 20 lần là cách chắc chắn để có 20 con
/// số lệch nhau. Phòng ngoại lệ vẫn khai riêng được trong tờ khai phòng.
///
/// Trước đây đơn giá không được lưu ở đâu cả: nó là ô nhập trên màn chốt lô hoá
/// đơn, điền sẵn 3.500/15.000, gõ lại mỗi tháng.
class HopThoaiGiaToa extends StatefulWidget {
  const HopThoaiGiaToa({
    super.key,
    required this.buildingId,
    this.giaDien,
    this.giaNuoc,
    this.phiDichVu,
  });

  final int buildingId;
  final double? giaDien;
  final double? giaNuoc;
  final double? phiDichVu;

  @override
  State<HopThoaiGiaToa> createState() => _HopThoaiGiaToaState();
}

class _HopThoaiGiaToaState extends State<HopThoaiGiaToa> {
  late final _dien = TextEditingController(text: _text(widget.giaDien));
  late final _nuoc = TextEditingController(text: _text(widget.giaNuoc));
  late final _dichVu = TextEditingController(text: _text(widget.phiDichVu));

  bool _dangLuu = false;
  String? _loi;

  static String _text(double? v) => v == null ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    _dien.dispose();
    _nuoc.dispose();
    _dichVu.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    final ok = await context.read<BuildingProvider>().updateBuilding(
      widget.buildingId,
      giaDien: double.tryParse(_dien.text.trim()),
      giaNuoc: double.tryParse(_nuoc.text.trim()),
      phiDichVu: double.tryParse(_dichVu.text.trim()),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _dangLuu = false;
        _loi = 'Không lưu được. Thử lại sau.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Giá điện nước mặc định'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Áp cho mọi phòng chưa khai giá riêng. Phòng ngoại lệ vẫn sửa được '
            'trong tờ khai phòng.',
            style: HD.body(size: 13, color: HD.inkSoft),
          ),
          const SizedBox(height: HD.s12),
          _o(_dien, 'Giá điện (đ/kWh)', '3500'),
          const SizedBox(height: HD.s8),
          _o(_nuoc, 'Giá nước (đ/m³)', '15000'),
          const SizedBox(height: HD.s8),
          _o(_dichVu, 'Phí dịch vụ (đ/tháng)', '0'),
          if (_loi != null) ...[
            const SizedBox(height: HD.s8),
            Text(_loi!, style: HD.body(size: 13, color: HD.negative)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _dangLuu ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: _dangLuu ? null : _luu,
          child: Text(_dangLuu ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    );
  }

  Widget _o(TextEditingController c, String nhan, String goiY) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: nhan,
      // Gợi ý là hằng số hệ thống đang dùng khi không ai khai gì — cho người
      // nhập biết mình đang thay thế con số nào.
      hintText: 'Mặc định $goiY',
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
