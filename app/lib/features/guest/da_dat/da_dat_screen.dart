import 'package:flutter/material.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/da_dat_api.dart';
import 'package:house_booking/data/services/dang_thue_api.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/features/guest/da_dat/gui_chi_so_sheet.dart';
import 'package:house_booking/features/guest/da_dat/tien_trinh_lich_su.dart';

/// "ĐÃ ĐẶT" v2 — KIỂM SOÁT mọi cam kết của khách (16/09/2026, docs/PLAN-DA-DAT.md).
///
///     [Cần bạn xử lý]  ← chỉ hiện khi có việc: chọn giờ mới · sắp tới giờ
///     Sắp tới · Đang thuê · Lịch sử
///       Sắp tới: đơn phòng + lịch xem + hẹn chốt còn mở, lọc theo loại, nhóm
///                Hôm nay / Ngày mai / Trong 7 ngày / Sau đó
///       Lịch sử: đã xong / đã huỷ / bị từ chối / đã qua giờ, nhóm theo tháng
///     Chạm thẻ → phiếu (tiến trình · đổi giờ · sửa · huỷ · lịch sử thay đổi)
///     Menu ⋯ → mở phiếu và làm ngay việc đó
///
/// Mọi quyết định (mục nào sắp tới, nhãn, bước, việc cần làm, còn sửa được gì)
/// lấy từ `GET /api/guest/da-dat` — app không tự suy từ giờ trên máy khách.
/// Phòng đang thuê dài hạn giữ đường riêng (`/api/guest/dang-thue`).
///
/// Yêu thích không mất: vẫn mở được từ trang Cá nhân.
class DaDatScreen extends StatefulWidget {
  const DaDatScreen({
    super.key,
    this.api,
    this.dangThueApi,
    this.dienNuocApi,
    this.datPhongApi,
    this.lichXemApi,
    this.bayGio,
  });

  /// Chỉ để test bơm API giả.
  final DaDatApi? api;
  final DangThueApi? dangThueApi;
  final DienNuocApi? dienNuocApi;
  final DatPhongApi? datPhongApi;
  final LichXemApi? lichXemApi;

  /// Chỉ để test ghim "bây giờ" khi nhóm Hôm nay / Ngày mai.
  final DateTime? bayGio;

  @override
  State<DaDatScreen> createState() => _DaDatScreenState();
}

const _nhanLoc = {'tat_ca': 'Tất cả', 'dat_phong': 'Đặt phòng', 'xem_nha': 'Xem nhà'};

bool _khopLoc(MucDaDat m, String loc) => switch (loc) {
  'dat_phong' => m.laDatPhong,
  'xem_nha' => !m.laDatPhong,
  _ => true,
};

class _DaDatScreenState extends State<DaDatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  DaDatApi get _api => widget.api ?? const DaDatApi();
  DangThueApi get _dangThue => widget.dangThueApi ?? const DangThueApi();

  TongHopDaDat _th = const TongHopDaDat();
  List<PhongDangThue> _thue = [];
  bool _dangTai = true;
  String? _loi;
  String _locSapToi = 'tat_ca';
  String _locLichSu = 'tat_ca';

  DateTime get _bayGio => widget.bayGio ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    // Hai nguồn độc lập: một bên hỏng không được làm trống bên kia.
    final ket = await Future.wait<Object?>([
      _api.tongHop().then<Object?>((v) => v, onError: (_) => null),
      _dangThue.cuaToi().then<Object?>((v) => v, onError: (_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      if (ket[0] is TongHopDaDat) _th = ket[0] as TongHopDaDat;
      if (ket[1] is List<PhongDangThue>) _thue = ket[1] as List<PhongDangThue>;
      _dangTai = false;
      if (ket[0] == null || ket[1] == null) {
        _loi = 'Có phần chưa tải được. Kéo xuống để thử lại.';
      }
    });
  }

  Future<void> _mo(MucDaDat m, {String? moSan}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => m.laDatPhong
            ? PhieuDatPhongScreen(
                reservationId: m.id,
                api: widget.datPhongApi ?? const DatPhongApi(),
                moSan: moSan,
              )
            : PhieuHenXemScreen(
                appointmentId: m.id,
                api: widget.lichXemApi ?? const LichXemApi(),
                moSan: moSan,
              ),
      ),
    );
    // Trong phiếu khách có thể đã đổi giờ / sửa / huỷ.
    if (mounted) _nap();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(
      backgroundColor: HD.paper,
      surfaceTintColor: HD.paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: HD.s20,
      title: Text(
        'ĐÃ ĐẶT',
        style: HD.eyebrow(color: HD.ink).copyWith(letterSpacing: 1.6),
      ),
      bottom: TabBar(
        controller: _tab,
        labelColor: HD.accent,
        unselectedLabelColor: HD.inkMuted,
        indicatorColor: HD.accent,
        tabs: [
          Tab(text: 'Sắp tới (${_th.sapToi.length})'),
          Tab(text: 'Đang thuê (${_thue.length})'),
          Tab(text: 'Lịch sử (${_th.lichSu.length})'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tab,
      children: [
        _boc(_sapToi()),
        _boc(_danhSachThue()),
        _boc(_lichSu()),
      ],
    ),
  );

  Widget _boc(Widget con) => RefreshIndicator(
    onRefresh: _nap,
    // Kéo-làm-mới vẫn dùng được khi danh sách rỗng — đúng lúc cần thử lại nhất.
    child: _dangTai
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s32),
            children: [
              if (_loi != null) ...[
                Text(_loi!, style: HD.body(size: 13, color: HD.negative)),
                const SizedBox(height: HD.s12),
              ],
              con,
            ],
          ),
  );

  // ── Tab 1: sắp tới ────────────────────────────────────────────────────────

  Widget _sapToi() {
    final can = _th.canXuLy;
    final ds = [for (final m in _th.sapToi) if (_khopLoc(m, _locSapToi)) m];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (can.isNotEmpty) ...[
          _NhanNhom(nhan: 'Cần bạn xử lý', so: can.length, mau: HD.svcAmber),
          for (final m in can) _TheCanXuLy(m: m, onTap: () => _mo(m)),
          const SizedBox(height: HD.s8),
        ],
        _locChip(_th.sapToi, _locSapToi, (v) => setState(() => _locSapToi = v), 'sap-toi'),
        const SizedBox(height: HD.s8),
        if (ds.isEmpty)
          _Rong(
            icon: Icons.event_available_outlined,
            tieuDe: _locSapToi == 'tat_ca' ? 'Chưa có gì sắp tới' : 'Không có mục nào',
            mo: 'Đặt phòng ngắn hạn hoặc hẹn xem nhà từ trang tin đăng — mọi '
                'đơn và lịch sẽ hiện ở đây kèm trạng thái.',
          )
        else
          for (final (nhom, muc) in _nhomTheoNgay(ds)) ...[
            _NhanNhom(nhan: nhom, so: muc.length),
            for (final m in muc) _theMuc(m),
          ],
      ],
    );
  }

  List<(String, List<MucDaDat>)> _nhomTheoNgay(List<MucDaDat> ds) {
    final homNay = DateTime(_bayGio.year, _bayGio.month, _bayGio.day);
    String nhom(MucDaDat m) {
      final t = m.batDau;
      if (t == null) return 'Chưa có giờ';
      final ngay = DateTime(t.year, t.month, t.day);
      final cach = ngay.difference(homNay).inDays;
      if (cach <= 0) return 'Hôm nay';
      if (cach == 1) return 'Ngày mai';
      if (cach <= 7) return 'Trong 7 ngày';
      return 'Sau đó';
    }

    final thuTu = ['Hôm nay', 'Ngày mai', 'Trong 7 ngày', 'Sau đó', 'Chưa có giờ'];
    final map = <String, List<MucDaDat>>{};
    for (final m in ds) {
      map.putIfAbsent(nhom(m), () => []).add(m);
    }
    return [for (final k in thuTu) if (map[k] != null) (k, map[k]!)];
  }

  Widget _locChip(
    List<MucDaDat> tatCa,
    String dang,
    ValueChanged<String> doi,
    String khoa,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final e in _nhanLoc.entries) ...[
          ChoiceChip(
            key: Key('loc-$khoa-${e.key}'),
            label: Text(
              '${e.value} (${tatCa.where((m) => _khopLoc(m, e.key)).length})',
            ),
            selected: dang == e.key,
            onSelected: (_) => doi(e.key),
            showCheckmark: false,
            selectedColor: HD.accentTint,
            labelStyle: HD.bodyBold(
              size: 12.5,
              color: dang == e.key ? HD.accent : HD.inkSoft,
            ),
            side: BorderSide(color: dang == e.key ? HD.accent : HD.hairline),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );

  Widget _theMuc(MucDaDat m) => _TheMuc(
    m: m,
    bayGio: _bayGio,
    onTap: () => _mo(m),
    onChon: (viec) => _mo(m, moSan: viec == 'lich_su' ? null : viec),
  );

  // ── Tab 2: đang thuê ──────────────────────────────────────────────────────

  Widget _danhSachThue() {
    if (_thue.isEmpty) {
      return const _Rong(
        icon: Icons.vpn_key_outlined,
        tieuDe: 'Bạn chưa thuê phòng nào',
        mo: 'Hợp đồng sẽ hiện ở đây khi chủ nhà ghi số điện thoại của bạn vào '
            'sổ người thuê.',
      );
    }
    return Column(
      children: [
        for (final t in _thue) TheThueDaiHan(t: t, onGuiChiSo: () => _guiChiSo(t)),
      ],
    );
  }

  /// Người thuê gửi chỉ số điện nước tháng này — xem [GuiChiSoSheet].
  Future<void> _guiChiSo(PhongDangThue t) async {
    final daGui = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GuiChiSoSheet(
        contractId: t.contractId,
        maPhong: t.maPhong,
        lyDoTraVe: t.chiSoLyDo,
        api: widget.dienNuocApi ?? const DienNuocApi(),
      ),
    );
    if (daGui != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi chỉ số — chờ chủ nhà duyệt.')),
    );
    _nap();
  }

  // ── Tab 3: lịch sử ────────────────────────────────────────────────────────

  Widget _lichSu() {
    final ds = [for (final m in _th.lichSu) if (_khopLoc(m, _locLichSu)) m];
    final nhom = <String, List<MucDaDat>>{};
    for (final m in ds) {
      final t = m.batDau ?? m.capNhatLuc;
      nhom.putIfAbsent(t == null ? 'Không rõ thời gian' : 'Tháng ${t.month}/${t.year}', () => []).add(m);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _locChip(_th.lichSu, _locLichSu, (v) => setState(() => _locLichSu = v), 'lich-su'),
        const SizedBox(height: HD.s8),
        if (ds.isEmpty)
          const _Rong(
            icon: Icons.history,
            tieuDe: 'Chưa có gì trong lịch sử',
            mo: 'Đơn đã trả phòng, lịch đã xem, đơn đã huỷ hoặc bị từ chối sẽ nằm ở '
                'đây — mở ra vẫn xem được toàn bộ lịch sử thay đổi.',
          )
        else
          for (final e in nhom.entries) ...[
            _NhanNhom(nhan: e.key, so: e.value.length),
            for (final m in e.value) _theMuc(m),
          ],
      ],
    );
  }
}

String _ngay(String iso) {
  if (iso.length < 10) return iso;
  return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
}

// ── Thành phần ───────────────────────────────────────────────────────────────

class _NhanNhom extends StatelessWidget {
  const _NhanNhom({required this.nhan, required this.so, this.mau = HD.inkMuted});

  final String nhan;
  final int so;
  final Color mau;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: HD.s12, bottom: HD.s8),
    child: Text(
      '${nhan.toUpperCase()} · $so',
      style: HD.bodyBold(size: 11.5, color: mau).copyWith(letterSpacing: 0.6),
    ),
  );
}

(IconData, String, Color) _loaiMuc(String loai) => switch (loai) {
  'dat_phong' => (Icons.bed_outlined, 'Đặt phòng', HD.accent),
  'hen_chot' => (Icons.handshake_outlined, 'Hẹn chốt', HD.positive),
  _ => (Icons.visibility_outlined, 'Xem nhà', HD.svcBlue),
};

String _hai(int n) => n.toString().padLeft(2, '0');

const _thu = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

class _TheCanXuLy extends StatelessWidget {
  const _TheCanXuLy({required this.m, required this.onTap});

  final MucDaDat m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: InkWell(
      key: Key('can-xu-ly-${m.loai}-${m.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HD.warningTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HD.svcAmber.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                m.trangThai == 'doi_gio' ? Icons.event_repeat : Icons.alarm,
                color: HD.svcAmber,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.canXuLy ?? '', style: HD.bodyBold(size: 13.5, color: HD.ink)),
                  Text(
                    m.tieuDe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkSoft),
                  ),
                ],
              ),
            ),
            Text(m.viec, style: HD.bodyBold(size: 12, color: HD.accent)),
            const Icon(Icons.chevron_right, color: HD.accent),
          ],
        ),
      ),
    ),
  );
}

class _TheMuc extends StatelessWidget {
  const _TheMuc({
    required this.m,
    required this.bayGio,
    required this.onTap,
    required this.onChon,
  });

  final MucDaDat m;
  final DateTime bayGio;
  final VoidCallback onTap;
  final ValueChanged<String> onChon;

  @override
  Widget build(BuildContext context) {
    final (icon, loai, mauLoai) = _loaiMuc(m.loai);
    final mau = mauTong(m.tong);
    final t = m.batDau;
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('muc-${m.loai}-${m.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: HD.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Khối ngày giờ — thứ người ta nhìn đầu tiên.
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: m.dangMo ? HD.accentTint : const Color(0xFFF0F1F4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: t == null
                      ? const Icon(Icons.event_note, color: HD.inkMuted)
                      : Column(
                          children: [
                            Text(
                              _thu[t.weekday - 1],
                              style: HD.bodyBold(size: 10.5, color: HD.inkMuted),
                            ),
                            Text(
                              '${t.day}',
                              style: HD.bodyBold(
                                size: 22,
                                color: m.dangMo ? HD.accent : HD.inkSoft,
                              ),
                            ),
                            Text(
                              'Th${t.month}',
                              style: HD.body(size: 10.5, color: HD.inkMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_hai(t.hour)}:${_hai(t.minute)}',
                              style: HD.bodyBold(size: 12, color: HD.ink),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: mauLoai),
                          const SizedBox(width: 3),
                          Text(loai, style: HD.bodyBold(size: 11, color: mauLoai)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '#${m.ma}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.body(size: 11, color: HD.inkMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.tieuDe,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.bodyBold(size: 15, color: HD.ink),
                      ),
                      if (m.phuDe.isNotEmpty)
                        Text(
                          m.phuDe,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.body(size: 12, color: HD.inkMuted),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          m.hinhThuc,
                          if (m.tien != null) PriceFormat.full(m.tien!),
                        ].where((x) => x.isNotEmpty).join(' · '),
                        style: HD.body(size: 12, color: HD.inkSoft),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: mau.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                m.nhanTrangThai,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HD.bodyBold(size: 11, color: mau),
                              ),
                            ),
                          ),
                          if (m.dangMo && m.cacBuoc.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _VachTienDo(buoc: m.buoc, tong: m.cacBuoc.length),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.capNhatLuc == null
                                  ? ''
                                  : 'Cập nhật ${truoc(m.capNhatLuc, bayGio: bayGio)}',
                              style: HD.body(size: 11, color: HD.inkMuted),
                            ),
                          ),
                          Text(m.viec, style: HD.bodyBold(size: 12, color: HD.accent)),
                        ],
                      ),
                    ],
                  ),
                ),
                _menu(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) => PopupMenuButton<String>(
    key: Key('menu-${m.loai}-${m.id}'),
    tooltip: 'Thao tác',
    icon: const Icon(Icons.more_vert, color: HD.inkMuted, size: 20),
    onSelected: onChon,
    itemBuilder: (_) => [
      if (m.suaDuoc.doiGio)
        PopupMenuItem(
          value: 'doi_gio',
          child: _dongMenu(Icons.event_repeat, m.laDatPhong ? 'Đổi giờ' : 'Đổi lịch'),
        ),
      if (m.suaDuoc.suaThongTin)
        PopupMenuItem(value: 'sua', child: _dongMenu(Icons.edit_outlined, 'Sửa thông tin')),
      if (m.suaDuoc.huy)
        PopupMenuItem(value: 'huy', child: _dongMenu(Icons.event_busy_outlined, 'Huỷ')),
      PopupMenuItem(value: 'lich_su', child: _dongMenu(Icons.history, 'Lịch sử thay đổi')),
    ],
  );

  Widget _dongMenu(IconData icon, String nhan) => Row(
    children: [
      Icon(icon, size: 18, color: HD.inkSoft),
      const SizedBox(width: 10),
      Text(nhan),
    ],
  );
}

/// Vạch tiến độ gọn cho thẻ danh sách — bản đầy đủ có nhãn nằm trong phiếu.
class _VachTienDo extends StatelessWidget {
  const _VachTienDo({required this.buoc, required this.tong});

  final int buoc;
  final int tong;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < tong; i++)
        Container(
          width: 14,
          height: 4,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: i < buoc ? HD.accent : HD.hairline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ],
  );
}

class _The extends StatelessWidget {
  const _The({required this.child});

  final Widget child;
  final VoidCallback? onTap = null;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: HD.hairline),
          borderRadius: BorderRadius.circular(HD.r12),
        ),
        child: child,
      ),
    ),
  );
}


/// Thẻ một phòng đang thuê dài hạn + nút gửi chỉ số điện nước tháng này.
/// Công khai để trang Quản lý (`PhongDangThueScreen`) dùng lại đúng thẻ này —
/// chép sang là hai nơi nói hai kiểu về cùng một trạng thái chỉ số.
class TheThueDaiHan extends StatelessWidget {
  const TheThueDaiHan({super.key, required this.t, this.onGuiChiSo});

  final PhongDangThue t;
  final VoidCallback? onGuiChiSo;

  @override
  Widget build(BuildContext context) => _The(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            if (t.maPhong.isNotEmpty) 'Phòng ${t.maPhong}',
            if (t.tenToa.isNotEmpty) t.tenToa,
          ].join(' · '),
          style: HD.bodyBold(size: 14),
        ),
        if (t.diaChi.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(t.diaChi, style: HD.body(size: 12, color: HD.inkMuted)),
        ],
        const SizedBox(height: HD.s8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${PriceFormat.full(t.tienThue)} / tháng',
                style: HD.bodyBold(size: 14).copyWith(color: HD.accent),
              ),
            ),
            Text(
              'Đến ${_ngay(t.denNgay)}',
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
          ],
        ),
        if (t.datCoc > 0) ...[
          const SizedBox(height: 2),
          Text(
            'Đã cọc ${PriceFormat.full(t.datCoc)}',
            style: HD.body(size: 12, color: HD.inkMuted),
          ),
        ],
        ..._chiSo(),
      ],
    ),
  );

  /// Chỉ số điện nước tháng này + nút gửi. Nói cho người thuê biết chủ nhà đã
  /// làm gì với con số họ gửi — không thì bấm gửi xong là mất dấu.
  List<Widget> _chiSo() {
    if (onGuiChiSo == null) return const [];
    final tt = t.chiSoTrangThai;
    final (String? dong, Color mau) = switch (tt) {
      'cho_duyet' => ('Chỉ số tháng này đang chờ chủ nhà duyệt', HD.svcOrange),
      'thieu_anh' => (
        'Đã gửi nhưng thiếu ảnh công tơ — nên gửi lại kèm ảnh',
        HD.svcOrange,
      ),
      'can_chup_lai' => (
        'Chủ nhà yêu cầu chụp lại: ${t.chiSoLyDo ?? 'ảnh chưa rõ'}',
        HD.negative,
      ),
      'da_duyet' => ('Chỉ số điện nước tháng này đã duyệt', HD.positive),
      _ => (null, HD.inkMuted),
    };
    return [
      const SizedBox(height: HD.s8),
      if (dong != null)
        Row(
          children: [
            Icon(
              tt == 'da_duyet' ? Icons.check_circle : Icons.bolt,
              size: 16,
              color: mau,
            ),
            const SizedBox(width: 4),
            Expanded(child: Text(dong, style: HD.body(size: 12, color: mau))),
          ],
        ),
      // Đã duyệt là đã vào tiền — server trả 409 nếu gửi đè, nên không bày nút.
      if (tt != 'da_duyet')
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onGuiChiSo,
            icon: const Icon(Icons.bolt, size: 18),
            label: Text(
              tt == null || tt == 'chua_gui'
                  ? 'Gửi chỉ số điện nước'
                  : 'Gửi lại chỉ số',
            ),
          ),
        ),
    ];
  }
}

class _Rong extends StatelessWidget {
  const _Rong({required this.icon, required this.tieuDe, this.mo = ''});

  final IconData icon;
  final String tieuDe;
  final String mo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: HD.s40),
    child: Column(
      children: [
        Icon(icon, size: 40, color: HD.inkMuted),
        const SizedBox(height: HD.s12),
        Text(tieuDe, style: HD.bodyBold(size: 15)),
        if (mo.isNotEmpty) ...[
          const SizedBox(height: HD.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HD.s24),
            child: Text(
              mo,
              textAlign: TextAlign.center,
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
          ),
        ],
      ],
    ),
  );
}

