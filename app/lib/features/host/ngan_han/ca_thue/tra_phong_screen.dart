import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/ca_thue_chung.dart';

/// CHECK-OUT & QUYẾT TOÁN — dựng theo mockup "Quy trình check-out" (12/09/2026).
///
/// Bốn việc của lúc khách rời, đúng thứ tự người trực làm:
///
///   1. Đối chiếu giờ thực ở với gói đã đặt (ở lố thì GHI phụ thu, có nút).
///   2. Kiểm phòng nhanh — ba mục, ghi thẳng vào ca thuê.
///   3. Quyết toán: thu thêm hay hoàn cọc, bằng tiền mặt hay chuyển khoản.
///   4. Mở lịch dọn phòng (khoá phòng N phút) rồi mới trả về bảng trống.
///
/// Số tiền KHÔNG do màn tự cộng: `con_lai` từ server đã gồm cọc, phụ thu và
/// mọi lần thu trước đó. Màn chỉ điền sẵn ô thu/hoàn theo con số ấy.
class TraPhongScreen extends StatefulWidget {
  const TraPhongScreen({
    super.key,
    required this.reservationId,
    this.api = const CaThueApi(),
  });

  final int reservationId;
  final CaThueApi api;

  @override
  State<TraPhongScreen> createState() => _TraPhongScreenState();
}

class _TraPhongScreenState extends State<TraPhongScreen> {
  /// Ba mục kiểm phòng — ghi vào `ghi_chu_kiem_phong` của ca.
  static const _mucKiem = [
    ('dien', 'Thiết bị điện & điều hoà', 'Đã tắt nguồn, điều khiển để tại bàn', Icons.power_settings_new),
    ('khoa', 'Khoá & thẻ từ phòng', 'Đã thu hồi đủ chìa/thẻ', Icons.badge_outlined),
    ('taisan', 'Tài sản & nội thất', 'Ga, tường, thiết bị không hư hỏng', Icons.chair_outlined),
  ];

  static const _mocDon = [0, 30, 60, 90];

  CaThue? _ca;
  bool _dangTai = false;
  bool _dangLam = false;
  String? _loi;

  final Set<String> _daKiem = {};
  final _ghiChuKiem = TextEditingController();
  final _soTien = TextEditingController();
  String _hinhThuc = 'tien_mat';
  int _phutDon = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  @override
  void dispose() {
    _ghiChuKiem.dispose();
    _soTien.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ca = await widget.api.lay(widget.reservationId);
      if (!mounted) return;
      setState(() {
        _ca = ca;
        _soTien.text = (ca.tien?.conLai ?? 0).abs().toStringAsFixed(0);
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _loi = e is ApiException ? e.message : 'Không tải được ca thuê',
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _ghiQuaGio(CaThue ca, DeXuatQuaGio q) async {
    setState(() => _dangLam = true);
    try {
      await widget.api.themPhuThu(
        ca.id,
        ten: q.ten,
        donGia: q.donGia ?? 0,
        soLuong: q.soGio.toDouble(),
        loai: 'qua_gio',
      );
      _bao('Đã ghi phụ thu quá giờ.');
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không ghi được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  String? _kiemPhong() {
    final thieu = _mucKiem.where((m) => !_daKiem.contains(m.$1)).toList();
    final phan = <String>[
      if (thieu.isEmpty)
        'Kiểm phòng: đạt cả ${_mucKiem.length} mục'
      else
        'Kiểm phòng: chưa đạt ${thieu.map((e) => e.$2.toLowerCase()).join(', ')}',
      if (_ghiChuKiem.text.trim().isNotEmpty) _ghiChuKiem.text.trim(),
    ];
    return phan.join(' · ');
  }

  Future<void> _xacNhan(CaThue ca) async {
    final con = ca.tien?.conLai ?? 0;
    final so = double.tryParse(_soTien.text.trim().replaceAll('.', '')) ?? 0;
    setState(() => _dangLam = true);
    try {
      await widget.api.traPhong(
        ca.id,
        thuThem: con > 0 ? so : 0,
        hoanLai: con < 0 ? so : 0,
        hinhThuc: _hinhThuc,
        phutDon: _phutDon,
        kiemPhong: _kiemPhong(),
      );
      if (!mounted) return;
      _bao(
        _phutDon > 0
            ? 'Đã trả phòng ${ca.phong.ma}. Phòng khoá dọn ${doDai(_phutDon)}.'
            : 'Đã trả phòng ${ca.phong.ma}.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _bao(e is ApiException ? e.message : 'Không trả phòng được');
        setState(() => _dangLam = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ca = _ca;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        title: Text('Trả phòng & quyết toán', style: HD.bodyBold(size: 16)),
      ),
      body: ca == null
          ? Center(
              child: _dangTai
                  ? const CircularProgressIndicator()
                  : Text(
                      _loi ?? 'Không có dữ liệu',
                      style: HD.body(color: HD.inkMuted),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, 24),
              children: [
                _theDau(ca),
                const SizedBox(height: HD.s12),
                _theGio(ca),
                if (ca.deXuatQuaGio != null && ca.xemTaiChinh) ...[
                  const SizedBox(height: HD.s12),
                  _theQuaGio(ca, ca.deXuatQuaGio!),
                ],
                const SizedBox(height: HD.s12),
                _theKiemPhong(),
                if (ca.xemTaiChinh && ca.tien != null) ...[
                  const SizedBox(height: HD.s12),
                  _theQuyetToan(ca),
                ],
                const SizedBox(height: HD.s12),
                _theDonPhong(ca),
              ],
            ),
      bottomNavigationBar: ca == null ? null : _thanhDuoi(ca),
    );
  }

  Widget _theDau(CaThue ca) => TheCa(
    tieuDe: 'ĐANG KIỂM TRA PHÒNG',
    phai: Text(
      ca.maDat.isEmpty ? '#${ca.id}' : '#${ca.maDat}',
      style: HD.body(size: 11, color: HD.inkMuted),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: HD.accentTint,
            borderRadius: BorderRadius.circular(HD.r12),
          ),
          child: const Icon(Icons.inventory_2_outlined, color: HD.accent, size: 21),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phòng ${ca.phong.ma}',
                style: HD.bodyBold(size: 16, color: HD.ink),
              ),
              Text(
                [
                  if (ca.phong.tang != null) 'Tầng ${ca.phong.tang}',
                  if (ca.phong.hang != null) ca.phong.hang!,
                  if (ca.khachTen != null) ca.khachTen!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 11.5, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _theGio(CaThue ca) {
    final thuc = ca.bayGio.isAfter(ca.ra) ? ca.bayGio : ca.ra;
    final tongPhut = thuc.difference(ca.vao).inMinutes;
    final loPhut = thuc.difference(ca.ra).inMinutes;
    return TheCa(
      tieuDe: 'GIỜ THỰC Ở',
      cham: HD.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ONhanh(
                  nhan: 'Nhận phòng',
                  so: gioPhut(ca.vao),
                  phu: ngayTuongDoi(ca.vao, ca.bayGio),
                  icon: Icons.login,
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: ONhanh(
                  nhan: 'Rời phòng',
                  so: gioPhut(thuc),
                  phu: ngayTuongDoi(thuc, ca.bayGio),
                  icon: Icons.logout,
                  mau: loPhut > 0 ? HD.negative : HD.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          HangTien(
            'Gói đã đặt: ${gioPhut(ca.vao)} → ${gioPhut(ca.ra)}',
            doDai(ca.tienDo.tongPhut),
            icon: Icons.done_all,
          ),
          HangTien(
            'Tổng thời gian thực ở',
            doDai(tongPhut),
            dam: true,
            mau: loPhut > 0 ? HD.negative : HD.ink,
            phu: loPhut > 0 ? 'Vượt gói ${doDai(loPhut)}' : 'Đúng gói',
            icon: Icons.schedule,
          ),
        ],
      ),
    );
  }

  Widget _theQuaGio(CaThue ca, DeXuatQuaGio q) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HD.negativeTint,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HD.negative.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.timer_off_outlined, color: HD.negative, size: 22),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ở lố ${doDai(q.phut)} — chưa tính tiền',
                style: HD.bodyBold(size: 13.5, color: HD.negative),
              ),
              Text(
                q.deXuat == null
                    ? 'Chưa có giá theo giờ để tính phụ thu.'
                    : 'Đề xuất ${tien(q.deXuat!)} (${q.soGio} giờ chẵn)',
                style: HD.body(size: 11.5, color: HD.inkSoft),
              ),
            ],
          ),
        ),
        if (q.deXuat != null)
          FilledButton(
            key: const Key('tra-phong-ghi-qua-gio'),
            onPressed: _dangLam ? null : () => _ghiQuaGio(ca, q),
            style: FilledButton.styleFrom(
              backgroundColor: HD.negative,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: HD.bodyBold(size: 12),
            ),
            child: const Text('Ghi'),
          ),
      ],
    ),
  );

  Widget _theKiemPhong() => TheCa(
    tieuDe: 'CHECKLIST KIỂM PHÒNG NHANH',
    cham: HD.positive,
    phai: Text(
      '${_daKiem.length}/${_mucKiem.length} mục đạt',
      key: const Key('tra-phong-so-muc'),
      style: HD.body(size: 11, color: HD.inkMuted),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in _mucKiem)
          InkWell(
            key: Key('tra-phong-kiem-${m.$1}'),
            onTap: () => setState(
              () => _daKiem.contains(m.$1)
                  ? _daKiem.remove(m.$1)
                  : _daKiem.add(m.$1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(
                    _daKiem.contains(m.$1)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: _daKiem.contains(m.$1)
                        ? HD.positive
                        : HD.hairlineStrong,
                  ),
                  const SizedBox(width: HD.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.$2,
                          style: HD.bodyBold(size: 13, color: HD.ink),
                        ),
                        Text(
                          m.$3,
                          style: HD.body(size: 11, color: HD.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(m.$4, size: 17, color: HD.inkMuted),
                ],
              ),
            ),
          ),
        const SizedBox(height: HD.s8),
        TextField(
          key: const Key('tra-phong-ghi-chu-kiem'),
          controller: _ghiChuKiem,
          maxLines: 2,
          style: HD.body(size: 13),
          decoration: InputDecoration(
            hintText: 'Ghi chú kiểm phòng: ga dính vết mực, thiếu 1 khăn…',
            hintStyle: HD.body(size: 12, color: HD.inkMuted),
            filled: true,
            fillColor: HD.paperSunken,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _theQuyetToan(CaThue ca) {
    final t = ca.tien!;
    final hoan = t.conLai < 0;
    return TheCa(
      tieuDe: 'QUYẾT TOÁN CHI PHÍ',
      cham: HD.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HangTien('Tiền phòng (${ca.nhanKieu.toLowerCase()})', tien(t.tienPhong)),
          for (final p in ca.phuThu)
            HangTien(
              p.ten,
              '+${tien(p.thanhTien)}',
              phu: p.soLuong == 1
                  ? null
                  : '${tien(p.donGia)} × ${p.soLuong.toStringAsFixed(0)}',
            ),
          if (t.coc > 0)
            HangTien('Cọc giữ phòng', '-${tien(t.coc)}', mau: HD.positive),
          for (final x in ca.thanhToan)
            HangTien(
              x.ghiChu ?? (x.laHoan ? 'Đã hoàn khách' : 'Đã thu'),
              '${x.laHoan ? '+' : '-'}${tien(x.soTien)}',
              phu: x.hinhThuc == 'tien_mat' ? 'Tiền mặt' : 'Chuyển khoản',
              mau: x.laHoan ? HD.warning : HD.positive,
            ),
          const Divider(height: 18, color: HD.hairline),
          Container(
            padding: const EdgeInsets.all(HD.s12),
            decoration: BoxDecoration(
              color: hoan ? HD.positiveTint : HD.accentTint,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hoan
                        ? 'Khách được hoàn lại'
                        : (t.conLai == 0 ? 'Đã thu đủ' : 'Khách phải trả thêm'),
                    style: HD.bodyBold(size: 13, color: HD.ink),
                  ),
                ),
                Text(
                  tien(t.conLai),
                  key: const Key('tra-phong-con-lai'),
                  style: HD.bodyBold(
                    size: 19,
                    color: hoan ? HD.positive : HD.accent,
                  ),
                ),
              ],
            ),
          ),
          if (t.conLai != 0) ...[
            const SizedBox(height: HD.s12),
            Text(
              hoan ? 'Hoàn cho khách bằng' : 'Thu thêm bằng',
              style: HD.body(size: 11.5, color: HD.inkMuted),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _nutHinhThuc(
                    'tien_mat',
                    'Tiền mặt',
                    Icons.local_atm,
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: _nutHinhThuc(
                    'chuyen_khoan',
                    'Chuyển khoản',
                    Icons.qr_code_2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HD.s12),
            TextField(
              key: const Key('tra-phong-so-tien'),
              controller: _soTien,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: HD.bodyBold(size: 16),
              decoration: InputDecoration(
                labelText: hoan ? 'Số tiền hoàn khách' : 'Số tiền thu thêm',
                suffixText: 'đ',
                filled: true,
                fillColor: HD.paperSunken,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nutHinhThuc(String ma, String chu, IconData icon) {
    final chon = _hinhThuc == ma;
    return InkWell(
      key: Key('tra-phong-ht-$ma'),
      onTap: () => setState(() => _hinhThuc = ma),
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: chon ? HD.accentTint : HD.paperSunken,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(
            color: chon ? HD.accent : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 19, color: chon ? HD.accent : HD.inkMuted),
            const SizedBox(height: 3),
            Text(
              chu,
              style: HD.bodyBold(size: 12, color: chon ? HD.accent : HD.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _theDonPhong(CaThue ca) => TheCa(
    tieuDe: 'ĐIỀU PHỐI DỌN PHÒNG',
    cham: HD.pinStayShort,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Phòng bị khoá không nhận khách trong lúc dọn — ca sau không thể '
          'nhận vào phòng chưa thay ga.',
          style: HD.body(size: 11.5, color: HD.inkMuted),
        ),
        const SizedBox(height: HD.s12),
        Wrap(
          spacing: HD.s8,
          children: [
            for (final p in _mocDon)
              ChoiceChip(
                key: Key('tra-phong-don-$p'),
                selected: _phutDon == p,
                onSelected: (_) => setState(() => _phutDon = p),
                label: Text(
                  p == 0 ? 'Không khoá' : doDai(p),
                  style: HD.body(size: 12),
                ),
                selectedColor: HD.accentSoft,
              ),
          ],
        ),
        if (_phutDon > 0) ...[
          const SizedBox(height: HD.s8),
          Row(
            children: [
              const Icon(
                Icons.cleaning_services,
                size: 15,
                color: HD.pinStayShort,
              ),
              const SizedBox(width: 6),
              Text(
                'Dự kiến dọn xong ${gioPhut(ca.bayGio.add(Duration(minutes: _phutDon)))}',
                style: HD.bodyBold(size: 12, color: HD.inkSoft),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _thanhDuoi(CaThue ca) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: SizedBox(
      height: 52,
      child: FilledButton.icon(
        key: const Key('tra-phong-xac-nhan'),
        onPressed: _dangLam || !ca.dangO ? null : () => _xacNhan(ca),
        icon: const Icon(Icons.task_alt, size: 19),
        label: Text(
          ca.dangO
              ? 'Xác nhận trả phòng & mở dọn dẹp'
              : 'Ca này đã trả phòng',
          style: HD.bodyBold(size: 14, color: Colors.white),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: HD.positive,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HD.r12),
          ),
        ),
      ),
    ),
  );
}
