import 'package:flutter/material.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/kenh_khai_thac_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/host/short_stay/hop_thoai_gia_ngan_han.dart';

/// KÊNH KHAI THÁC — bốn pipeline của một phòng, trong màn chi tiết phòng.
///
/// Vì sao là danh sách chứ không phải một ô chọn: một phòng chạy được NHIỀU
/// kênh cùng lúc. Tháng này cho thuê đêm, tháng sau cho thuê dài hạn, rồi đem
/// bán — và trong lúc đang cho thuê vẫn rao bán được (bán kèm khách thuê).
///
/// Mỗi kênh hiện đúng thứ nghiệp vụ của nó cần: giá kèm ĐƠN VỊ riêng, tham số
/// riêng (số đêm tối thiểu · tiền cọc · kỳ miễn phí sửa chữa), trạng thái riêng.
class MucKenhKhaiThac extends StatefulWidget {
  const MucKenhKhaiThac({super.key, required this.roomId, this.api});

  final int roomId;

  /// Chỉ để test bơm API giả.
  final KenhKhaiThacApi? api;

  @override
  State<MucKenhKhaiThac> createState() => _MucKenhKhaiThacState();
}

class _MucKenhKhaiThacState extends State<MucKenhKhaiThac> {
  KenhKhaiThacApi get _api => widget.api ?? const KenhKhaiThacApi();

  List<KenhKhaiThac> _ds = const [];
  bool _dangTai = true;
  String? _loi;

  static const _thuTu = ['ngan_han', 'dai_han', 'mat_bang', 'ban'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ds = await _api.cuaPhong(widget.roomId);
      if (mounted) setState(() => _ds = ds);
    } catch (_) {
      // Nói rõ HỎNG. Danh sách rỗng đọc thành "phòng chưa mở kênh nào" — một
      // câu trả lời sai mà chủ nhà sẽ tin và đi bật lại từ đầu.
      if (mounted) setState(() => _loi = 'Không tải được kênh khai thác.');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  KenhKhaiThac? _tim(String kenh) {
    for (final k in _ds) {
      if (k.kenh == kenh) return k;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s20, HD.s20, HD.s8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HD.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('KÊNH KHAI THÁC', style: HD.eyebrow(color: HD.accent)),
              ),
              if (_dangTai)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Một phòng chạy được nhiều kênh cùng lúc.',
            style: HD.body(size: 12.5, color: HD.inkMuted),
          ),
          const SizedBox(height: HD.s12),
          if (_loi != null)
            Row(
              children: [
                Expanded(
                  child: Text(_loi!, style: HD.body(size: 13, color: HD.negative)),
                ),
                TextButton(onPressed: _nap, child: const Text('Thử lại')),
              ],
            )
          else
            for (final kenh in _thuTu) _the(kenh, _tim(kenh)),
        ],
      ),
    );
  }

  Widget _the(String kenh, KenhKhaiThac? k) {
    final bat = k != null && k.dangBat;
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s8),
      child: Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: bat ? HD.paperRaised : HD.paper,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: bat ? HD.hairline : HD.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    KenhKhaiThac.nhanKenh[kenh] ?? kenh,
                    style: HD.bodyBold(
                      size: 14.5,
                      color: bat ? HD.ink : HD.inkMuted,
                    ),
                  ),
                ),
                // Ba màu, ba nghĩa: đã chốt (không nhận khách nữa) · đang
                // giữa chừng (giữ chỗ, đã cọc) · đang rao bình thường.
                if (k != null && k.dangBat)
                  _chip(
                    k.tenTrangThai,
                    k.daChot
                        ? HD.negative
                        : k.trangThai == 'dang_rao'
                        ? HD.positive
                        : HD.warning,
                  ),
                Switch.adaptive(
                  value: bat,
                  onChanged: (v) => _bat(kenh, k, v),
                ),
              ],
            ),
            if (bat) ...[
              const SizedBox(height: 2),
              Text(
                '${PriceFormat.compact(k.gia)}${k.hauTo}',
                style: HD.bodyBold(size: 16, color: HD.accent),
              ),
              if (_thamSo(k).isNotEmpty)
                Text(_thamSo(k), style: HD.body(size: 12, color: HD.inkSoft)),
              const SizedBox(height: HD.s8),
              Wrap(
                spacing: HD.s8,
                children: [
                  OutlinedButton(
                    onPressed: () => _suaGia(kenh, k),
                    style: _nho(),
                    child: const Text('Sửa giá'),
                  ),
                  // Ngắn hạn bán BA sản phẩm khác nhau (giờ · qua đêm · ngày),
                  // không phải ba cách viết một con số — nên nó có màn giá
                  // riêng. Phòng chưa khai giá nào ở đây thì KHÔNG hiện trong
                  // tìm kiếm ngắn hạn, nên nút phải nói ra điều đó.
                  if (kenh == 'ngan_han')
                    OutlinedButton(
                      onPressed: () => _giaNganHan(),
                      style: _nho(),
                      child: const Text('Giá giờ / đêm / ngày'),
                    ),
                  if (k.daChot)
                    OutlinedButton(
                      onPressed: () => _raoLai(kenh),
                      style: _nho(),
                      child: const Text('Rao lại'),
                    )
                  else
                    for (final b in KenhKhaiThac.buocTiepTheo[kenh] ?? const [])
                      if (b != k.trangThai)
                        OutlinedButton(
                          onPressed: () => _doiTrangThai(kenh, b),
                          style: _nho(),
                          child: Text(KenhKhaiThac.nhanTrangThai[b] ?? b),
                        ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tham số riêng của từng nghiệp vụ — không kênh nào giống kênh nào.
  String _thamSo(KenhKhaiThac k) {
    final p = <String>[];
    if (k.toiThieu != null) {
      p.add(k.kenh == 'ngan_han'
          ? 'tối thiểu ${k.toiThieu} đêm'
          : 'tối thiểu ${k.toiThieu} tháng');
    }
    if (k.datCoc != null && k.datCoc! > 0) {
      p.add(k.laBan ? 'cọc ${k.datCoc}%' : 'cọc ${k.datCoc} tháng');
    }
    if (k.laMatBang && k.mienPhiThang != null) {
      p.add('miễn phí sửa chữa ${k.mienPhiThang} tháng');
    }
    return p.join(' · ');
  }

  Widget _chip(String chu, Color mau) => Container(
    margin: const EdgeInsets.only(right: HD.s8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Text(chu, style: HD.body(size: 11, color: mau)),
  );

  ButtonStyle _nho() => OutlinedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    minimumSize: const Size(0, 34),
  );

  Future<void> _bat(String kenh, KenhKhaiThac? k, bool v) async {
    if (v && k == null) {
      await _suaGia(kenh, null);
      return;
    }
    await _goi(() => _api.dat(widget.roomId, kenh, gia: k?.gia ?? 0,
        toiThieu: k?.toiThieu,
        datCoc: k?.datCoc,
        mienPhiThang: k?.mienPhiThang,
        dangBat: v));
  }

  /// Ba mức giá lưu trú ngắn hạn — màn riêng, xem `HopThoaiGiaNganHan`.
  Future<void> _giaNganHan() async {
    Map<String, dynamic> banDau = const {};
    try {
      final ds = await const ShortStayApi().rooms();
      banDau = Map<String, dynamic>.from(
        (ds.firstWhere(
              (r) => r['room_id'] == widget.roomId,
              orElse: () => const {},
            )['rates'] as Map?) ??
            const {},
      );
    } catch (_) {
      // Không lấy được giá cũ thì vẫn mở form trống — chặn ở đây nghĩa là
      // chủ nhà không khai được giá chỉ vì một lượt đọc hỏng.
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          HopThoaiGiaNganHan(roomId: widget.roomId, banDau: banDau),
    );
    if (ok == true) _nap();
  }

  Future<void> _suaGia(String kenh, KenhKhaiThac? k) async {
    final gia = TextEditingController(text: k == null ? '' : k.gia.toStringAsFixed(0));
    final toiThieu = TextEditingController(text: k?.toiThieu?.toString() ?? '');
    final coc = TextEditingController(text: k?.datCoc?.toStringAsFixed(0) ?? '');
    final mien = TextEditingController(text: k?.mienPhiThang?.toString() ?? '');
    final hauTo = KenhKhaiThac.hauToDonVi[
        k?.donVi ?? _donViMacDinh(kenh)] ?? '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(KenhKhaiThac.nhanKenh[kenh] ?? kenh),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gia,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Giá$hauTo'),
            ),
            if (kenh != 'ban')
              TextField(
                controller: toiThieu,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: kenh == 'ngan_han'
                      ? 'Số đêm tối thiểu'
                      : 'Số tháng tối thiểu',
                ),
              ),
            TextField(
              controller: coc,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: kenh == 'ban' ? 'Cọc (%)' : 'Cọc (số tháng)',
              ),
            ),
            // Điều khoản CHUẨN của thuê thương mại — luôn được thương lượng.
            // Để trong ghi chú tự do thì không thống kê được, không nhắc hạn được.
            if (kenh == 'mat_bang')
              TextField(
                controller: mien,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Miễn tiền thuê để sửa chữa (tháng)',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _goi(() => _api.dat(
          widget.roomId,
          kenh,
          gia: double.tryParse(gia.text.trim()) ?? 0,
          toiThieu: int.tryParse(toiThieu.text.trim()),
          datCoc: double.tryParse(coc.text.trim()),
          mienPhiThang: int.tryParse(mien.text.trim()),
        ));
  }

  static String _donViMacDinh(String kenh) => switch (kenh) {
    'ngan_han' => 'dem',
    'mat_bang' => 'm2_thang',
    'ban' => 'tong',
    _ => 'thang',
  };

  Future<void> _doiTrangThai(String kenh, String tt) async {
    // Chốt là hành động KHÔNG lùi được bằng một cú bấm: nó gỡ tin của người
    // khác khỏi chợ. Phải hỏi lại.
    if (tt == 'da_ban') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đánh dấu ĐÃ BÁN?'),
          content: const Text(
            'Mọi tin đang rao của phòng này sẽ đóng — kể cả tin do sale khác '
            'đăng — và các kênh còn lại sẽ tắt. Người đăng sẽ được báo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đã bán'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    await _goi(() => _api.doiTrangThai(widget.roomId, kenh, tt), bao: true);
  }

  Future<void> _raoLai(String kenh) =>
      _goi(() => _api.raoLai(widget.roomId, kenh));

  Future<void> _goi(
    Future<KenhKhaiThac> Function() f, {
    bool bao = false,
  }) async {
    try {
      final k = await f();
      if (!mounted) return;
      if (bao && k.soTinDaDong > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã đóng ${k.soTinDaDong} tin đang rao.')),
        );
      }
      await _nap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được. $e')),
      );
    }
  }
}
