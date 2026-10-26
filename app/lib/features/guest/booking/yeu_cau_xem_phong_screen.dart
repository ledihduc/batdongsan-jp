// ignore_for_file: unused_element

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/guest/booking/cho_sale_xac_nhan_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// MÀN 1 — "Yêu cầu xem phòng" (mockup quy trình KHÁCH THUÊ, 20/09/2026).
///
/// Ảnh căn · giá · địa chỉ · ba thông số → khách tự thêm các khoảng ngày/giờ
/// phù hợp bằng lịch và đồng hồ → gửi yêu cầu → [ChoSaleXacNhanScreen].
///
/// KHUNG 2 TIẾNG ↔ SLOT 1 TIẾNG của server: `booking_slot_service` chỉ nhận
/// slot chuẩn 1 tiếng (08:00-09:00 … 19:00-20:00) và MỘT slot mỗi lịch hẹn.
/// Nên ở đây: mỗi khoảng khách nhập cần giao với ít nhất một slot server còn
/// trống; lịch hẹn giữ slot phù hợp đầu tiên, còn TOÀN BỘ khoảng rảnh chính xác
/// đi trong lời nhắn để sale xếp lịch. Không tự ý đẻ nhiều lịch hẹn.
class YeuCauXemPhongScreen extends StatefulWidget {
  const YeuCauXemPhongScreen({
    super.key,
    this.houseId,
    this.roomId,
    this.api = const LichXemApi(),
    this.layNha,
    this.homNay,
  }) : assert(houseId != null || roomId != null, 'Cần tin hoặc phòng');

  final int? houseId;
  final int? roomId;
  final LichXemApi api;

  /// Lấy thêm ảnh + thông số của TIN (số phòng ngủ, nội thất). Thay được để
  /// test không chạm mạng.
  final Future<HouseModel?> Function(int houseId)? layNha;

  /// Test ghim ngày để hai cột ngày không đổi theo lúc chạy.
  final DateTime? homNay;

  @override
  State<YeuCauXemPhongScreen> createState() => _YeuCauXemPhongScreenState();
}

class _YeuCauXemPhongScreenState extends State<YeuCauXemPhongScreen> {
  ThongTinDatLich? _tin;
  HouseModel? _nha;
  String? _loi;
  bool _dangTai = true;
  bool _dangGui = false;

  late DateTime _ngayDangChon;
  TimeOfDay _gioBatDau = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _gioKetThuc = const TimeOfDay(hour: 10, minute: 0);
  final List<GioDeXuat> _gioDaChon = [];

  /// Khoảng khách nhập → slot chuẩn 1 giờ mà server có thể giữ chỗ.
  final Map<String, String> _slotDat = {};
  bool _dangKiemTraGio = false;

  @override
  void initState() {
    super.initState();
    final goc = widget.homNay ?? DateTime.now();
    final d0 = DateTime(goc.year, goc.month, goc.day);
    _ngayDangChon = d0.add(const Duration(days: 1));
    _nap();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final tin = await widget.api.thongTinDat(
        houseId: widget.houseId,
        roomId: widget.roomId,
      );
      // Thông số phụ (phòng ngủ, nội thất) chỉ có ở TIN. Hỏng thì bỏ qua —
      // thiếu một dòng thông số không đáng chặn cả màn đặt lịch.
      HouseModel? nha;
      if (widget.houseId != null) {
        try {
          final lay =
              widget.layNha ??
              (int id) => ApiHouseRepository().getHouseById(id);
          nha = await lay(widget.houseId!);
        } catch (_) {
          nha = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _tin = tin;
        _nha = nha;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được thông tin căn này. Kéo xuống để thử lại.';
      });
    }
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _thu(DateTime d) =>
      d.weekday == DateTime.sunday ? 'Chủ nhật' : 'Thứ ${d.weekday + 1}';

  static String _ngayThang(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static int _phut(TimeOfDay value) => value.hour * 60 + value.minute;

  static String _hienThiGio(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  String _khoaGio(GioDeXuat value) => '${value.ngay}|${value.gio}';

  Future<void> _chonNgay() async {
    final goc = widget.homNay ?? DateTime.now();
    final dau = DateTime(
      goc.year,
      goc.month,
      goc.day,
    ).add(const Duration(days: 1));
    final ngay = await showDatePicker(
      context: context,
      initialDate: _ngayDangChon.isBefore(dau) ? dau : _ngayDangChon,
      firstDate: dau,
      lastDate: dau.add(const Duration(days: 180)),
      helpText: 'Chọn ngày muốn xem',
      cancelText: 'Hủy',
      confirmText: 'Chọn ngày',
    );
    if (ngay != null && mounted) {
      setState(() => _ngayDangChon = ngay);
    }
  }

  Future<void> _chonGio({required bool batDau}) async {
    final gio = await showTimePicker(
      context: context,
      initialTime: batDau ? _gioBatDau : _gioKetThuc,
      helpText: batDau ? 'Chọn giờ bắt đầu' : 'Chọn giờ kết thúc',
      cancelText: 'Hủy',
      confirmText: 'Chọn giờ',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (gio == null || !mounted) return;
    setState(() {
      if (batDau) {
        _gioBatDau = gio;
        if (_phut(_gioKetThuc) <= _phut(gio)) {
          final end = (_phut(gio) + 60).clamp(0, 23 * 60 + 59);
          _gioKetThuc = TimeOfDay(hour: end ~/ 60, minute: end % 60);
        }
      } else {
        _gioKetThuc = gio;
      }
    });
  }

  /// Chọn slot chuẩn có phần giao lớn nhất với khoảng rảnh khách vừa nhập.
  String? _slotPhuHop(List<KhungGio> slots) {
    final tu = _phut(_gioBatDau);
    final den = _phut(_gioKetThuc);
    String? best;
    var overlapBest = 0;
    for (final slot in slots.where((item) => !item.daCo)) {
      final parts = slot.gio.split('-');
      if (parts.length != 2) continue;
      int parse(String raw) {
        final value = raw.split(':');
        return int.parse(value[0]) * 60 + int.parse(value[1]);
      }

      final slotTu = parse(parts[0]);
      final slotDen = parse(parts[1]);
      final overlap =
          (den < slotDen ? den : slotDen) - (tu > slotTu ? tu : slotTu);
      if (overlap > overlapBest) {
        overlapBest = overlap;
        best = slot.gio;
      }
    }
    return overlapBest >= 30 ? best : null;
  }

  Future<void> _themKhungGio() async {
    if (_dangKiemTraGio) return;
    if (_gioDaChon.length >= 3) {
      setState(() => _loi = 'Bạn chỉ có thể chọn tối đa 3 khung giờ.');
      return;
    }
    if (_phut(_gioKetThuc) - _phut(_gioBatDau) < 30) {
      setState(
        () => _loi = 'Giờ kết thúc phải sau giờ bắt đầu ít nhất 30 phút.',
      );
      return;
    }
    final gio = '${_hienThiGio(_gioBatDau)}-${_hienThiGio(_gioKetThuc)}';
    final value = GioDeXuat(ngay: _iso(_ngayDangChon), gio: gio);
    if (_gioDaChon.any((item) => item == value)) {
      setState(() => _loi = 'Khung giờ này đã có trong danh sách.');
      return;
    }
    setState(() {
      _dangKiemTraGio = true;
      _loi = null;
    });
    try {
      final slots = await widget.api.khungGio(
        value.ngay,
        houseId: widget.houseId,
        roomId: widget.roomId,
      );
      final slot = _slotPhuHop(slots);
      if (slot == null) {
        if (mounted) {
          setState(
            () => _loi = 'Khoảng này chưa có giờ nhận xem. Hãy chọn giờ khác.',
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _gioDaChon.add(value);
        _gioDaChon.sort((a, b) {
          final byDate = a.ngay.compareTo(b.ngay);
          return byDate != 0 ? byDate : a.gio.compareTo(b.gio);
        });
        _slotDat[_khoaGio(value)] = slot;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loi = 'Chưa kiểm tra được giờ trống. Thử lại giúp em.');
      }
    } finally {
      if (mounted) {
        setState(() => _dangKiemTraGio = false);
      }
    }
  }

  Future<void> _gui() async {
    if (_gioDaChon.isEmpty || _dangGui) return;
    final nguoi = context.read<AuthProvider>().currentUser;

    final dau = _gioDaChon.first;
    final slot = _slotDat[_khoaGio(dau)];
    if (slot == null) return;
    final cacKhoang = _gioDaChon
        .map((item) {
          final ngay = DateTime.tryParse(item.ngay);
          return ngay == null
              ? '${item.ngay} ${item.gio}'
              : '${_thu(ngay)} ${_ngayThang(ngay)} ${item.gio.replaceAll('-', ' - ')}';
        })
        .join(' · ');

    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final phieu = await widget.api.datLich(
        houseId: widget.houseId,
        roomId: widget.roomId,
        ngay: dau.ngay,
        gio: slot,
        hinhThuc: 'truc_tiep',
        soNguoi: 1,
        tenKhach: nguoi?.name ?? '',
        sdtKhach: nguoi?.phone ?? '',
        loiNhan: 'Các khung em có thể xem: $cacKhoang',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChoSaleXacNhanScreen(appointmentId: phieu.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = 'Chưa gửi được yêu cầu. Thử lại giúp em.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(
      backgroundColor: HD.accent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: const BackButton(color: Colors.white),
      title: Text(
        'Đặt lịch xem nhà',
        style: HD.bodyBold(size: 17, color: Colors.white),
      ),
    ),
    body: _dangTai
        ? const Center(child: CircularProgressIndicator(color: HD.accent))
        : RefreshIndicator(
            color: HD.accent,
            onRefresh: _nap,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                HD.s16,
                HD.s12,
                HD.s16,
                HD.s24,
              ),
              children: [
                Text(
                  'Yêu cầu xem phòng',
                  style: HD.body(size: 11, color: HD.inkMuted),
                ),
                const SizedBox(height: 4),
                _theCanVaSale(),
                const SizedBox(height: HD.s12),
                Divider(height: 1, color: HD.hairline.withValues(alpha: 0.7)),
                const SizedBox(height: HD.s16),
                Text('Chọn ngày xem nhà', style: HD.bodyBold(size: 15)),
                const SizedBox(height: 2),
                Text(
                  'Chọn ngày và giờ bằng lịch, tối đa 3 khung giờ',
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
                const SizedBox(height: HD.s12),
                _dayStrip(),
                const SizedBox(height: HD.s12),
                Text('Chọn khung giờ', style: HD.bodyBold(size: 14)),
                const SizedBox(height: 2),
                Text(
                  'Bạn có thể chọn tối đa 3 khung giờ',
                  style: HD.body(size: 11.5, color: HD.inkMuted),
                ),
                const SizedBox(height: HD.s8),
                _boChonThoiGian(),
                if (_gioDaChon.isNotEmpty) ...[
                  const SizedBox(height: HD.s12),
                  _danhSachThoiGian(),
                ],
                const SizedBox(height: HD.s16),
                _luuY(),
                if (_loi != null) ...[
                  const SizedBox(height: HD.s12),
                  Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                ],
              ],
            ),
          ),
    bottomNavigationBar: _thanhGui(),
  );

  Widget _theCanVaSale() {
    final t = _tin!.tin;
    final sale = _tin!.sale;
    final url = t.anh;
    return ViewingSectionCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(HD.r8),
                child: SizedBox(
                  width: 116,
                  height: 104,
                  child: url == null || url.isEmpty
                      ? const ColoredBox(
                          color: HD.paperSunken,
                          child: Icon(Icons.apartment, color: HD.inkMuted),
                        )
                      : CachedNetworkImage(
                          imageUrl: url.startsWith('http')
                              ? url
                              : '${ApiConfig.baseUrl}$url',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.tieuDe, maxLines: 2, style: HD.bodyBold(size: 14)),
                    const SizedBox(height: 3),
                    if (t.dienTich != null)
                      Text(
                        '${t.dienTich!.toStringAsFixed(0)} m²',
                        style: HD.body(size: 12, color: HD.inkMuted),
                      ),
                    Text(
                      t.diaChi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                    if ((t.gia ?? 0) > 0)
                      Text(
                        '${PriceFormat.full(t.gia!)}/${t.donVi}',
                        style: HD.bodyBold(size: 14, color: HD.accent),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (sale != null) ...[
            const Divider(height: HD.s20),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: HD.paperSunken,
                  backgroundImage: sale.anh == null || sale.anh!.isEmpty
                      ? null
                      : CachedNetworkImageProvider(
                          sale.anh!.startsWith('http')
                              ? sale.anh!
                              : '${ApiConfig.baseUrl}${sale.anh}',
                        ),
                  child: sale.anh == null || sale.anh!.isEmpty
                      ? const Icon(Icons.person, size: 18, color: HD.inkMuted)
                      : null,
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sale.ten, style: HD.bodyBold(size: 12.5)),
                      Text(
                        'Chuyên viên tư vấn',
                        style: HD.body(size: 11, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: HD.inkMuted),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayStrip() {
    final goc = widget.homNay ?? DateTime.now();
    final first = DateTime(
      goc.year,
      goc.month,
      goc.day,
    ).add(const Duration(days: 1));
    return Row(
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              key: Key('ngay-nhanh-${_iso(first.add(Duration(days: i)))}'),
              onTap: () =>
                  setState(() => _ngayDangChon = first.add(Duration(days: i))),
              borderRadius: BorderRadius.circular(HD.r8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      _iso(_ngayDangChon) == _iso(first.add(Duration(days: i)))
                      ? HD.accent
                      : Colors.white,
                  borderRadius: BorderRadius.circular(HD.r8),
                  border: Border.all(
                    color:
                        _iso(_ngayDangChon) ==
                            _iso(first.add(Duration(days: i)))
                        ? HD.accent
                        : HD.hairline,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _thu(
                        first.add(Duration(days: i)),
                      ).replaceFirst('Thứ ', 'Thứ '),
                      maxLines: 1,
                      style: HD.body(
                        size: 10.5,
                        color:
                            _iso(_ngayDangChon) ==
                                _iso(first.add(Duration(days: i)))
                            ? Colors.white
                            : HD.inkMuted,
                      ),
                    ),
                    Text(
                      _ngayThang(first.add(Duration(days: i))),
                      style: HD.bodyBold(
                        size: 11.5,
                        color:
                            _iso(_ngayDangChon) ==
                                _iso(first.add(Duration(days: i)))
                            ? Colors.white
                            : HD.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _anh() {
    final url = _tin?.tin.anh;
    final so = _nha?.images.length ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(HD.r12),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null || url.isEmpty)
              ColoredBox(
                color: HD.paperSunken,
                child: const Icon(
                  Icons.apartment,
                  color: HD.inkMuted,
                  size: 40,
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: url.startsWith('http')
                    ? url
                    : '${ApiConfig.baseUrl}$url',
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: HD.paperSunken),
                errorWidget: (_, _, _) =>
                    const ColoredBox(color: HD.paperSunken),
              ),
            if (so > 1)
              Positioned(
                right: HD.s8,
                bottom: HD.s8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HD.ink.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(HD.rPill),
                  ),
                  child: Text(
                    '1/$so',
                    style: HD.bodyBold(size: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thongTin() {
    final t = _tin!.tin;
    final gia = t.gia ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.tieuDe, style: HD.bodyBold(size: 17)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: gia > 0 ? PriceFormat.full(gia) : 'Thoả thuận',
                style: HD.bodyBold(size: 16, color: HD.accent),
              ),
              if (gia > 0)
                TextSpan(
                  text: '/${t.donVi}',
                  style: HD.body(size: 12.5, color: HD.accent),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 15,
              color: HD.inkMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                t.diaChi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 12.5, color: HD.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s12),
        Row(
          children: [
            for (final x in _thongSo()) Expanded(child: _oThongSo(x.$1, x.$2)),
          ],
        ),
      ],
    );
  }

  /// Ba thông số dưới địa chỉ. Chỉ in thứ CÓ THẬT trong dữ liệu.
  List<(IconData, String)> _thongSo() {
    final dt = _tin?.tin.dienTich ?? _nha?.area ?? 0;
    final pn = _nha?.bedrooms;
    final tienIch = _nha?.amenities ?? const <String>[];
    return [
      if (dt > 0) (Icons.straighten, '${dt.toStringAsFixed(0)} m²'),
      if (pn != null)
        (Icons.bed_outlined, pn <= 0 ? 'Studio' : '$pn phòng ngủ'),
      if (tienIch.isNotEmpty) (Icons.chair_outlined, tienIch.first),
    ];
  }

  Widget _oThongSo(IconData icon, String chu) => Row(
    children: [
      Icon(icon, size: 15, color: HD.inkMuted),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          chu,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 12.5, color: HD.inkSoft),
        ),
      ),
    ],
  );

  Widget _boChonThoiGian() => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: Column(
      children: [
        InkWell(
          key: const Key('chon-ngay-xem'),
          onTap: _chonNgay,
          borderRadius: BorderRadius.circular(HD.r8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: HD.paper,
              borderRadius: BorderRadius.circular(HD.r8),
              border: Border.all(color: HD.hairline),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: HD.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ngày xem',
                        style: HD.body(size: 11, color: HD.inkMuted),
                      ),
                      Text(
                        '${_thu(_ngayDangChon)}, ${_ngayThang(_ngayDangChon)}/${_ngayDangChon.year}',
                        style: HD.bodyBold(size: 14),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: HD.inkMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: HD.s8),
        Row(
          children: [
            Expanded(
              child: _oChonGio(
                key: const Key('chon-gio-bat-dau'),
                nhan: 'Bắt đầu',
                gio: _gioBatDau,
                onTap: () => _chonGio(batDau: true),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 18, color: HD.inkMuted),
            ),
            Expanded(
              child: _oChonGio(
                key: const Key('chon-gio-ket-thuc'),
                nhan: 'Kết thúc',
                gio: _gioKetThuc,
                onTap: () => _chonGio(batDau: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('them-khung-gio'),
            onPressed: _dangKiemTraGio ? null : _themKhungGio,
            icon: _dangKiemTraGio
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            label: Text(
              _dangKiemTraGio ? 'Đang kiểm tra...' : 'Thêm khung giờ',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: HD.accent,
              side: const BorderSide(color: HD.accent),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _oChonGio({
    required Key key,
    required String nhan,
    required TimeOfDay gio,
    required VoidCallback onTap,
  }) => InkWell(
    key: key,
    onTap: onTap,
    borderRadius: BorderRadius.circular(HD.r8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HD.paper,
        borderRadius: BorderRadius.circular(HD.r8),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 19, color: HD.accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nhan, style: HD.body(size: 10.5, color: HD.inkMuted)),
              Text(_hienThiGio(gio), style: HD.bodyBold(size: 15)),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _danhSachThoiGian() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('Các khung đã thêm', style: HD.bodyBold(size: 13.5)),
          const Spacer(),
          Text(
            '${_gioDaChon.length}',
            style: HD.bodyBold(size: 13, color: HD.accent),
          ),
        ],
      ),
      const SizedBox(height: HD.s8),
      for (final item in _gioDaChon)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            key: Key('khung-da-them-${_khoaGio(item)}'),
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            decoration: BoxDecoration(
              color: HD.accentTint,
              borderRadius: BorderRadius.circular(HD.r8),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: HD.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _moTaKhungMoi(item),
                    style: HD.bodyBold(size: 12.5),
                  ),
                ),
                IconButton(
                  tooltip: 'Xóa khung giờ',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _gioDaChon.remove(item);
                    _slotDat.remove(_khoaGio(item));
                  }),
                  icon: const Icon(Icons.close, color: HD.inkMuted, size: 19),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  String _moTaKhungMoi(GioDeXuat item) {
    final ngay = DateTime.tryParse(item.ngay);
    if (ngay == null) {
      return '${item.ngay} · ${item.gio.replaceAll('-', ' - ')}';
    }
    return '${_thu(ngay)}, ${_ngayThang(ngay)}/${ngay.year} · '
        '${item.gio.replaceAll('-', ' - ')}';
  }

  Widget _luuY() => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite, size: 14, color: HD.accent),
            const SizedBox(width: 4),
            Text('Lưu ý', style: HD.bodyBold(size: 12.5, color: HD.accent)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sau khi gửi yêu cầu, sale sẽ liên hệ chủ nhà và xác nhận lịch xem '
          'sớm nhất cho bạn.',
          style: HD.body(size: 12.5, color: HD.inkSoft),
        ),
      ],
    ),
  );

  Widget _thanhGui() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: SizedBox(
      height: 50,
      child: FilledButton(
        key: const Key('gui-yeu-cau-xem'),
        style: FilledButton.styleFrom(
          backgroundColor: HD.accent,
          disabledBackgroundColor: HD.accent.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HD.r12),
          ),
        ),
        onPressed: _gioDaChon.isEmpty || _dangGui ? null : _gui,
        child: _dangGui
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Gửi yêu cầu xem phòng',
                style: HD.bodyBold(size: 15, color: Colors.white),
              ),
      ),
    ),
  );
}
