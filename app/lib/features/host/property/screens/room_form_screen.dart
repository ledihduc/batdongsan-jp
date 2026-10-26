import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/image_grid_uploader.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/kenh_khai_thac_api.dart';
import 'package:house_booking/data/services/tien_ich_phong.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';

/// Tờ khai phòng mới. Mở bằng `Navigator.push` từ sổ phòng của toà.
/// Provider: `RoomProvider`. API: POST /api/host/buildings/{id}/rooms.
///
/// Ba nhóm lựa chọn ở đầu form, BẮT BUỘC chọn một. Nó không phải trang trí:
/// mỗi nhóm mở ra một kênh khai thác khác nhau, với đơn vị giá khác nhau
/// (tháng · m²/tháng · đêm · tổng) và bộ tham số khác nhau. Trước đây form
/// không hỏi gì cả nên phòng tạo ra **không thuộc kênh nào** — không ra chợ
/// được, và chủ nhà không có cách nào biết vì sao.
///
/// Vì sao ba thẻ mà hệ thống có bốn kênh: "thuê dài hạn" và "mặt bằng kinh
/// doanh" giống nhau ở thứ chủ nhà nghĩ tới trước (cho thuê theo tháng, có
/// điện nước dịch vụ) và chỉ khác ở cách tính giá. Hỏi gộp rồi hỏi tiếp một
/// câu ngắn thì đúng cách người ta phân loại hơn là bày bốn thẻ ngang nhau.
enum LoaiKhaiThac { thue, nganHan, muaBan }

class RoomFormScreen extends StatefulWidget {
  const RoomFormScreen({super.key, required this.buildingId, this.phong});

  final int buildingId;

  /// Không null = SỬA phòng đang có. Null = khai phòng mới.
  ///
  /// Dùng chung một màn cho cả hai vì đó là cùng một tờ khai: tách ra hai màn
  /// là hai bộ ô nhập rồi lệch nhau dần, và ô mới thêm sẽ chỉ có ở một bên.
  final RoomModel? phong;

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _maCtrl = TextEditingController();
  final _giaCtrl = TextEditingController();
  final _dienTichCtrl = TextEditingController();
  final _sucChuaCtrl = TextEditingController(text: '1');
  final _toiThieuCtrl = TextEditingController();
  final _cocCtrl = TextEditingController();
  final _mienPhiCtrl = TextEditingController();
  final _giaDienCtrl = TextEditingController();
  final _giaNuocCtrl = TextEditingController();
  final _phiDichVuCtrl = TextEditingController();
  final _ghiChuCtrl = TextEditingController();
  final _tangCtrl = TextEditingController();

  /// Slug hướng (`RoomModel.nhanHuong`); `null` = chưa khai.
  String? _huong;

  LoaiKhaiThac? _loai;
  /// Chỉ có nghĩa khi `_loai == thue`: nhà ở (`dai_han`) hay mặt bằng.
  bool _laMatBang = false;

  final Set<String> _dichVu = {};
  final Set<String> _doDac = {};
  final List<UploadImage> _anh = [];

  bool _dangLuu = false;

  RoomModel? get _goc => widget.phong;
  bool get _laSua => _goc != null;

  @override
  void initState() {
    super.initState();
    final p = _goc;
    if (p == null) return;
    _maCtrl.text = p.code;
    _giaCtrl.text = p.basePrice == 0 ? '' : p.basePrice.toStringAsFixed(0);
    _dienTichCtrl.text = p.areaM2?.toStringAsFixed(0) ?? '';
    _sucChuaCtrl.text = p.capacity.toString();
    _ghiChuCtrl.text = p.note ?? '';
    // Ô TRỐNG nghĩa là "theo giá toà", `0` nghĩa là miễn phí — nên chỉ điền
    // khi phòng thực sự có khai riêng, kể cả khi khai bằng 0.
    _giaDienCtrl.text = p.giaDien?.toStringAsFixed(0) ?? '';
    _giaNuocCtrl.text = p.giaNuoc?.toStringAsFixed(0) ?? '';
    _phiDichVuCtrl.text = p.phiDichVu?.toStringAsFixed(0) ?? '';
    _dichVu.addAll(p.dichVuGom);
    _doDac.addAll(p.doTrongPhong);
    _anh.addAll(p.images.map(UploadImage.existing));
    _tangCtrl.text = p.tang ?? '';
    _huong = p.huong;
  }

  @override
  void dispose() {
    for (final c in [
      _maCtrl,
      _giaCtrl,
      _dienTichCtrl,
      _sucChuaCtrl,
      _toiThieuCtrl,
      _cocCtrl,
      _mienPhiCtrl,
      _giaDienCtrl,
      _giaNuocCtrl,
      _phiDichVuCtrl,
      _ghiChuCtrl,
      _tangCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Khoá kênh gửi lên server. `null` khi chưa chọn — nút lưu bị chặn trước đó.
  String? get _kenh => switch (_loai) {
    LoaiKhaiThac.thue => _laMatBang ? 'mat_bang' : 'dai_han',
    LoaiKhaiThac.nganHan => 'ngan_han',
    LoaiKhaiThac.muaBan => 'ban',
    null => null,
  };

  /// Điện · nước · dịch vụ CHỈ hỏi cho thuê theo tháng.
  ///
  /// Ngắn hạn tính điện nước theo đêm và thường gộp vào giá phòng; mua bán thì
  /// người mua trả tiền điện của chính họ sau khi sang tên. Bày ba ô đó ra ở
  /// hai kênh này là hỏi một câu không có câu trả lời đúng.
  ///
  /// Khi SỬA thì luôn hỏi, không gác theo kênh nữa: phòng đang tồn tại chạy
  /// được nhiều kênh cùng lúc, nên gác theo một kênh là khoá mất ô nhập của
  /// những kênh còn lại.
  bool get _hoiTienIch => _laSua || _loai == LoaiKhaiThac.thue;

  double? _so(TextEditingController c) {
    final t = c.text.trim();
    // Rỗng → `null` = theo giá toà. Gõ `0` → `0` = miễn phí. Hai thứ khác nhau.
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll('.', '').replaceAll(',', ''));
  }

  Future<void> _luu() async {
    if (_laSua) return _luuSua();
    if (_loai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn loại khai thác trước')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _dangLuu = true);

    final provider = context.read<RoomProvider>();
    final ketQua = await provider.createRoom(
      widget.buildingId,
      code: _maCtrl.text.trim(),
      areaM2: _so(_dienTichCtrl),
      capacity: int.tryParse(_sucChuaCtrl.text) ?? 1,
      basePrice: _so(_giaCtrl) ?? 0,
      note: _ghiChuCtrl.text.trim().isEmpty ? null : _ghiChuCtrl.text.trim(),
      images: [
        for (final a in _anh)
          if (a.url != null) a.url!,
      ],
      kenh: _kenh,
      toiThieu: int.tryParse(_toiThieuCtrl.text.trim()),
      datCoc: _so(_cocCtrl),
      mienPhiThang: _laMatBang ? int.tryParse(_mienPhiCtrl.text.trim()) : null,
      giaDien: _hoiTienIch ? _so(_giaDienCtrl) : null,
      giaNuoc: _hoiTienIch ? _so(_giaNuocCtrl) : null,
      phiDichVu: _hoiTienIch ? _so(_phiDichVuCtrl) : null,
      dichVuGom: _hoiTienIch ? _dichVu.toList() : const [],
      doTrongPhong: _doDac.toList(),
      tang: _tangCtrl.text.trim().isEmpty ? null : _tangCtrl.text.trim(),
      huong: _huong,
    );

    if (!mounted) return;
    setState(() => _dangLuu = false);
    if (ketQua != null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Tạo phòng thất bại')),
      );
    }
  }

  /// Lưu thay đổi. KHÔNG đụng tới kênh khai thác — kênh có vòng đời riêng
  /// (đang rao · giữ chỗ · đã bán) và sửa nó ở đây là đổi trạng thái bán hàng
  /// bằng một tờ khai thông tin phòng. Kênh sửa ở mục "Kênh khai thác".
  Future<void> _luuSua() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _dangLuu = true);

    final provider = context.read<RoomProvider>();
    final ok = await provider.updateRoom(
      _goc!.id,
      code: _maCtrl.text.trim(),
      areaM2: _so(_dienTichCtrl),
      capacity: int.tryParse(_sucChuaCtrl.text) ?? 1,
      basePrice: _so(_giaCtrl) ?? 0,
      note: _ghiChuCtrl.text.trim(),
      images: [
        for (final a in _anh)
          if (a.url != null) a.url!,
      ],
      giaDien: _so(_giaDienCtrl),
      giaNuoc: _so(_giaNuocCtrl),
      phiDichVu: _so(_phiDichVuCtrl),
      dichVuGom: _dichVu.toList(),
      doTrongPhong: _doDac.toList(),
      // Ô để trống khi SỬA nghĩa là "bỏ giá riêng, quay về giá toà" — phải gửi
      // `null` tường minh, chứ bỏ khoá đi thì PATCH giữ nguyên giá cũ và người
      // dùng xoá mãi không được.
      xoaGiaTienIch: true,
      // Tầng / hướng để trống khi SỬA = xoá — gửi `null` tường minh.
      tang: _tangCtrl.text.trim().isEmpty ? null : _tangCtrl.text.trim(),
      huong: _huong,
      guiViTri: true,
    );

    if (!mounted) return;
    setState(() => _dangLuu = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Lưu thất bại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paper,
        surfaceTintColor: HD.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: HD.ink,
        iconTheme: const IconThemeData(color: HD.ink, size: 20),
        shape: const Border(bottom: BorderSide(color: HD.hairline)),
        titleSpacing: 0,
        title: Text(
          _laSua ? 'SỬA PHÒNG' : 'TỜ KHAI PHÒNG MỚI',
          style: HD.eyebrow(color: HD.ink).copyWith(letterSpacing: 1.6),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: HD.s24),
          children: [
            if (!_laSua) _mucLoaiKhaiThac(),
            if (_laSua || _loai != null) ...[
              _mucThongTinPhong(),
              if (_hoiTienIch) ...[_mucTienIch(), _mucDichVuGom()],
              _mucDoTrongPhong(),
              _mucAnh(),
              DsFormSection(
                title: 'Ghi chú',
                helper: 'Việc riêng của bạn — khách không nhìn thấy.',
                children: [
                  DsTextField(
                    controller: _ghiChuCtrl,
                    label: 'Ghi chú',
                    maxLines: 3,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(HD.s20, HD.s8, HD.s20, HD.s12),
        child: DsButton(
          label: _laSua ? 'Lưu thay đổi' : 'Tạo phòng',
          expand: true,
          isLoading: _dangLuu,
          onPressed: _dangLuu ? null : _luu,
        ),
      ),
    );
  }

  // ── Mục 1: loại khai thác ─────────────────────────────────────────────────

  Widget _mucLoaiKhaiThac() => DsFormSection(
    title: 'Loại khai thác',
    helper: 'Chọn một. Có thể mở thêm kênh khác sau, ở chi tiết phòng.',
    children: [
      _TheLoai(
        nhan: 'Cho thuê dài hạn / kinh doanh',
        mo: 'Theo tháng, có hợp đồng, có điện nước dịch vụ',
        chon: _loai == LoaiKhaiThac.thue,
        onTap: () => setState(() => _loai = LoaiKhaiThac.thue),
      ),
      // Câu hỏi phụ chỉ hiện sau khi đã chọn — hỏi trước là bắt người ta quyết
      // một thứ họ chưa biết có cần quyết không.
      if (_loai == LoaiKhaiThac.thue)
        Padding(
          padding: const EdgeInsets.only(left: HD.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cho thuê để làm gì?', style: HD.caption()),
              const SizedBox(height: HD.s8),
              Wrap(
                spacing: HD.s8,
                children: [
                  ChoiceChip(
                    label: const Text('Nhà ở'),
                    selected: !_laMatBang,
                    onSelected: (_) => setState(() => _laMatBang = false),
                  ),
                  ChoiceChip(
                    label: const Text('Mặt bằng kinh doanh'),
                    selected: _laMatBang,
                    onSelected: (_) => setState(() => _laMatBang = true),
                  ),
                ],
              ),
            ],
          ),
        ),
      _TheLoai(
        nhan: 'Ở ngắn hạn',
        mo: 'Theo đêm, khách tự đặt như khách sạn',
        chon: _loai == LoaiKhaiThac.nganHan,
        onTap: () => setState(() => _loai = LoaiKhaiThac.nganHan),
      ),
      _TheLoai(
        nhan: 'Mua bán',
        mo: 'Bán đứt, khách đặt lịch xem rồi cọc',
        chon: _loai == LoaiKhaiThac.muaBan,
        onTap: () => setState(() => _loai = LoaiKhaiThac.muaBan),
      ),
    ],
  );

  // ── Mục 2: thông tin phòng ────────────────────────────────────────────────

  Widget _mucThongTinPhong() {
    // Giá phải đi kèm ĐƠN VỊ. Ghi trơ "Giá thuê (VNĐ)" cho cả bốn kênh chính là
    // thứ đã đẻ ra lỗi lấy giá THÁNG nhân với số ĐÊM.
    //
    // Khi SỬA thì không gắn hậu tố: phòng đang tồn tại chạy được nhiều kênh
    // cùng lúc, gắn đơn vị của một kênh lên con số này là nói sai với các kênh
    // còn lại. Giá thật của từng kênh nằm ở mục "Kênh khai thác".
    final donVi = switch (_kenh) {
      'ngan_han' => 'dem',
      'mat_bang' => 'm2_thang',
      'ban' => 'tong',
      null => null,
      _ => 'thang',
    };
    final hauTo = donVi == null
        ? ''
        : (KenhKhaiThac.hauToDonVi[donVi] ?? '');

    return DsFormSection(
      title: 'Thông tin phòng',
      children: [
        DsTextField(
          controller: _maCtrl,
          label: 'Mã phòng *',
          hint: 'P01, A-101…',
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Vui lòng nhập mã phòng'
              : null,
        ),
        DsTextField(
          controller: _giaCtrl,
          label: 'Giá$hauTo',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        DsTextField(
          controller: _dienTichCtrl,
          label: 'Diện tích (m²)',
          keyboardType: TextInputType.number,
        ),
        DsTextField(
          controller: _sucChuaCtrl,
          label: 'Sức chứa (người)',
          keyboardType: TextInputType.number,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return (n == null || n < 1) ? 'Tối thiểu 1 người' : null;
          },
        ),
        // Hồ sơ phòng ghi "Tầng 1 · Hướng Đông Nam" — hai ô này là nguồn.
        DsTextField(
          controller: _tangCtrl,
          label: 'Tầng',
          hint: '1, 2, Trệt, Lửng…',
        ),
        DropdownButtonFormField<String?>(
          key: const ValueKey('chon-huong'),
          initialValue: _huong,
          decoration: const InputDecoration(labelText: 'Hướng phòng'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Chưa khai')),
            for (final e in RoomModel.nhanHuong.entries)
              DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _huong = v),
        ),
        // Ba ô dưới là tham số của KÊNH, không phải của phòng — nên chỉ hỏi
        // lúc khai mới (khi vừa chọn đúng một kênh). Sửa sau thì sửa ở mục
        // "Kênh khai thác", nơi có cả trạng thái và nút rao lại.
        if (!_laSua && _loai != LoaiKhaiThac.muaBan)
          DsTextField(
            controller: _toiThieuCtrl,
            label: _loai == LoaiKhaiThac.nganHan
                ? 'Số đêm tối thiểu'
                : 'Số tháng tối thiểu',
            keyboardType: TextInputType.number,
          ),
        if (!_laSua)
          DsTextField(
            controller: _cocCtrl,
            label: _loai == LoaiKhaiThac.muaBan ? 'Cọc (%)' : 'Cọc (số tháng)',
            keyboardType: TextInputType.number,
          ),
        // Kỳ miễn tiền thuê để bên thuê sửa chữa là điều khoản chuẩn của thuê
        // thương mại và luôn được thương lượng. Không có ô này thì nó nằm trong
        // ghi chú tự do — không thống kê được, không nhắc hạn được.
        if (!_laSua && _laMatBang && _loai == LoaiKhaiThac.thue)
          DsTextField(
            controller: _mienPhiCtrl,
            label: 'Miễn tiền thuê để sửa chữa (tháng)',
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }

  // ── Mục 3: điện nước dịch vụ ──────────────────────────────────────────────

  Widget _mucTienIch() => DsFormSection(
    title: 'Điện nước dịch vụ',
    helper: 'Bỏ trống = tính theo giá chung của toà. Gõ 0 = miễn phí.',
    children: [
      DsTextField(
        controller: _giaDienCtrl,
        label: 'Giá điện (đ/kWh)',
        hint: 'Bỏ trống = theo toà',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      DsTextField(
        controller: _giaNuocCtrl,
        label: 'Giá nước (đ/m³)',
        hint: 'Bỏ trống = theo toà',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      DsTextField(
        controller: _phiDichVuCtrl,
        label: 'Phí dịch vụ (đ/tháng)',
        hint: 'Bỏ trống = theo toà',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
      ),
    ],
  );

  Widget _mucDichVuGom() {
    // Chỉ hỏi khi có thu tiền dịch vụ. Bày danh sách "gồm những gì" khi phí
    // bằng 0 là mời người ta khai một thứ không ai trả tiền.
    // Khi SỬA thì luôn hỏi: phòng để trống ô phí dịch vụ là đang theo giá TOÀ,
    // mà toà vẫn có thể đang thu — ẩn đi thì chủ nhà không sửa nổi danh sách
    // "gồm những gì" của chính khoản họ đang thu.
    final phi = _so(_phiDichVuCtrl);
    if (!_laSua && (phi == null || phi <= 0)) return const SizedBox.shrink();
    return DsFormSection(
      title: 'Phí dịch vụ gồm',
      helper: 'Người thuê trả khoản này để được những gì.',
      children: [_chip(kDichVuGom, _dichVu)],
    );
  }

  // ── Mục 4: đồ trong phòng ─────────────────────────────────────────────────

  Widget _mucDoTrongPhong() => DsFormSection(
    title: 'Đồ trong phòng',
    helper: 'Đồ có sẵn, không tính tiền thêm.',
    children: [_chip(kDoTrongPhong, _doDac)],
  );

  Widget _chip(Map<String, String> tu, Set<String> daChon) => Wrap(
    spacing: HD.s8,
    runSpacing: HD.s8,
    children: [
      for (final e in tu.entries)
        FilterChip(
          label: Text(e.value),
          selected: daChon.contains(e.key),
          onSelected: (c) => setState(
            () => c ? daChon.add(e.key) : daChon.remove(e.key),
          ),
        ),
    ],
  );

  // ── Mục 5: ảnh ────────────────────────────────────────────────────────────

  Widget _mucAnh() => DsFormSection(
    title: 'Ảnh phòng',
    helper: 'Không bắt buộc. Ảnh đầu tiên làm ảnh bìa.',
    children: [
      ImageGridUploader(
        images: _anh,
        uploadFn: const ApiClient().uploadImage,
        onChanged: () => setState(() {}),
      ),
    ],
  );
}

/// Một thẻ chọn loại khai thác. To và có mô tả, cố ý: đây là quyết định đổi
/// hẳn phần còn lại của form, không phải một dòng radio trong danh sách.
class _TheLoai extends StatelessWidget {
  const _TheLoai({
    required this.nhan,
    required this.mo,
    required this.chon,
    required this.onTap,
  });

  final String nhan;
  final String mo;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.r8),
      child: Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          border: Border.all(color: chon ? HD.accent : HD.hairline),
          color: chon ? HD.accentSoft : null,
          borderRadius: BorderRadius.circular(HD.r8),
        ),
        child: Row(
          children: [
            Icon(
              chon ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: chon ? HD.accent : HD.inkMuted,
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nhan,
                    style: HD.bodyBold(size: 14).copyWith(
                      color: chon ? HD.accent : HD.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(mo, style: HD.body(size: 12, color: HD.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
