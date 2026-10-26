import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/sale/widgets/sale_chung.dart';

/// Khay CHỌN CĂN cho một yêu cầu (23/09/2026).
///
/// Hai nguồn, đúng quyết định của chủ dự án: phòng trong **toà liên kết** của
/// sale và **bài đăng của chính sale**. Không cho gắn tin của người khác —
/// sale không nắm giá lẫn tình trạng phòng của tin đó, gắn vào là hứa hộ.
///
/// Gắn căn KHÔNG đẩy tiến trình: hệ thống không gửi gì cho khách (sale gửi
/// qua Zalo/gọi điện), nên đây thuần tuý là ghi lại mình đã đưa căn nào.
///
/// API: GET /api/sale/yeu-cau/{id}/nguon-can · POST .../can
class ChonCanSheet extends StatefulWidget {
  const ChonCanSheet({
    super.key,
    required this.yeuCauId,
    this.api = const SaleYeuCauApi(),
  });

  final int yeuCauId;
  final SaleYeuCauApi api;

  @override
  State<ChonCanSheet> createState() => _ChonCanSheetState();
}

class _ChonCanSheetState extends State<ChonCanSheet> {
  final _tim = TextEditingController();
  NguonCanSale? _nguon;
  bool _dangTai = true;
  bool _dangGan = false;
  bool _coThayDoi = false;
  String? _loi;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _tim.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    try {
      final n = await widget.api.nguonCan(widget.yeuCauId, q: _tim.text.trim());
      if (!mounted) return;
      setState(() {
        _nguon = n;
        _dangTai = false;
        _loi = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = e is ApiException ? e.message : 'Chưa tải được danh sách căn';
      });
    }
  }

  Future<void> _gan(CanCoTheGan c) async {
    if (_dangGan || c.daGan) return;
    setState(() => _dangGan = true);
    try {
      await widget.api.ganCan(
        widget.yeuCauId,
        houseId: c.houseId,
        roomId: c.roomId,
      );
      _coThayDoi = true;
      await _nap();
      if (!mounted) return;
      setState(() => _dangGan = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã thêm ${c.ten}')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGan = false;
        _loi = e is ApiException ? e.message : 'Chưa thêm được căn';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _nguon;
    final ds = n == null
        ? const <CanCoTheGan>[]
        : (_tab == 0 ? n.toaLienKet : n.baiDang);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_coThayDoi);
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: HD.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HD.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chọn căn cho khách',
                        style: HD.bodyBold(size: 16),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(_coThayDoi),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const Key('sale-tim-can'),
                  controller: _tim,
                  onSubmitted: (_) => _nap(),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo mã phòng, tên toà, địa chỉ…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: HD.paperRaised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(HD.rPill),
                      borderSide: const BorderSide(color: HD.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(HD.rPill),
                      borderSide: const BorderSide(color: HD.hairline),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(width: 16),
                  SaleChipLoc(
                    nhan: 'Toà liên kết',
                    so: n?.toaLienKet.length ?? 0,
                    chon: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  SaleChipLoc(
                    nhan: 'Bài đăng của tôi',
                    so: n?.baiDang.length ?? 0,
                    chon: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _dangTai
                    ? const Center(
                        child: CircularProgressIndicator(color: HD.accent),
                      )
                    : ListView(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          if (_loi != null)
                            SaleBaoLoi(loi: _loi!, onThuLai: _nap),
                          if (ds.isEmpty)
                            SaleRong(
                              icon: _tab == 0
                                  ? Icons.apartment_outlined
                                  : Icons.article_outlined,
                              tieuDe: _tab == 0
                                  ? 'Chưa có phòng nào trong toà liên kết'
                                  : 'Bạn chưa có bài đăng nào',
                              mo: _tab == 0
                                  ? 'Nhận mã mời từ chủ nhà để được giao toà, '
                                        'rồi quay lại chọn phòng cho khách.'
                                  : 'Đăng tin ở tab Tin tức, tin của bạn sẽ '
                                        'hiện ở đây để gắn vào yêu cầu.',
                            ),
                          for (final c in ds) _the(c),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _the(CanCoTheGan c) {
    final khoa = c.houseId != null ? 'tin-${c.houseId}' : 'phong-${c.roomId}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key('sale-can-$khoa'),
        borderRadius: BorderRadius.circular(HD.r12),
        onTap: c.daGan ? null : () => _gan(c),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.daGan ? HD.paperSunken : HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.ten,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 13.5),
                    ),
                    if (c.diaChi.isNotEmpty)
                      Text(
                        c.diaChi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 11.5, color: HD.inkMuted),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      c.gia > 0
                          ? saleTien(c.gia, hau: '/tháng')
                          : 'Chưa khai giá',
                      style: HD.bodyBold(
                        size: 13,
                        color: c.gia > 0 ? HD.accent : HD.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (c.daGan)
                const SaleNhan(chu: 'Đã thêm', mau: HD.positive)
              else
                const Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: HD.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
