import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/building_public_api.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/guest/booking/room_booking_screen.dart';
import 'package:house_booking/features/guest/booking/yeu_cau_xem_phong_screen.dart';
import 'package:house_booking/features/host/property/screens/building_detail_screen.dart';
import 'package:house_booking/features/host/property/widgets/hop_thoai_ma_toa.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Trang dự án công khai — **bảng giá từng phòng**, kiểu trang khách sạn.
/// Route: `/du-an/:id`. API: GET /api/buildings/{id}/public.
///
/// Vì sao không phải một feed bài đăng: cho thuê không cần mỗi phòng một bài.
/// Một dự án 20 phòng mà bắt viết 20 bài thì vừa cực cho người đăng vừa loãng
/// feed cho khách. Ở đây một dự án = một trang, khách so giá các phòng cạnh
/// nhau trong cùng một màn — đúng cái họ đang muốn làm.
class BuildingPublicScreen extends StatefulWidget {
  const BuildingPublicScreen({required this.buildingId, super.key, this.api});

  final int buildingId;

  /// Chỉ để test bơm dữ liệu giả.
  final BuildingPublicApi? api;

  @override
  State<BuildingPublicScreen> createState() => _BuildingPublicScreenState();
}

class _BuildingPublicScreenState extends State<BuildingPublicScreen> {
  BuildingPublicApi get _api => widget.api ?? const BuildingPublicApi();

  DuAnChiTiet? _da;
  bool _dangTai = true;

  /// Mặc định CHỈ hiện phòng còn trống. Khách vào đây để tìm chỗ thuê được;
  /// phòng đã có người là nhiễu. Vẫn cho bật lên xem đủ vì có người muốn biết
  /// mặt bằng giá chung của toà.
  bool _chiConTrong = true;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    final d = await _api.chiTiet(widget.buildingId);
    if (mounted)
      setState(() {
        _da = d;
        _dangTai = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final d = _da;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(title: const Text('Dự án BĐS')),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : d == null
          ? const DsEmptyState(
              icon: Icons.apartment_outlined,
              title: 'Không tìm thấy dự án này',
              subtitle: 'Dự án có thể đã bị gỡ hoặc chuyển sang riêng tư.',
            )
          : _noiDung(d),
      bottomNavigationBar: d == null ? null : _thanhLienHe(d),
    );
  }

  /// Bấm vào một phòng → mở đúng luồng của KÊNH mà phòng đó đang rao.
  ///
  /// Trước đây chỗ này luôn đẩy sang `/dat-phong` (chọn ngày nhận/trả). Nên một
  /// căn hộ cho thuê 5,5tr/THÁNG mở ra màn đặt theo ĐÊM và tính 3 đêm =
  /// 16,5tr. Backend nay cũng đã chặn (409), nhưng để app mở màn rồi mới báo
  /// lỗi là bắt khách điền xong mới biết mình đi nhầm cửa.
  void _chamPhong(DuAnChiTiet d, PhongCongKhai p) {
    final nganHan = p.kenhNganHan;
    if (nganHan != null) {
      context.push(
        '/dat-phong/${p.id}',
        extra: RoomBookingArgs(
          roomId: p.id,
          roomCode: p.ma,
          buildingName: d.ten,
          // Giá của ĐÚNG kênh theo đêm — không phải `p.gia` (có thể là giá
          // tháng của kênh dài hạn khi phòng bật cả hai).
          price: nganHan.gia,
          saleName: d.saleTen ?? '',
        ),
      );
      return;
    }
    // Các kênh còn lại (thuê dài hạn · mặt bằng · bán) không có luồng đặt tự
    // phục vụ — theo nghiên cứu, ba trong bốn loại đều BẮT ĐẦU BẰNG ĐI XEM.
    // Nên bước tiếp theo đúng là đặt lịch xem, không phải đẩy khách sang trang
    // người đăng rồi để họ tự nghĩ ra phải làm gì.
    if (!GuestGate.requireAuth(
      context,
      message: 'Đăng nhập để đặt lịch xem phòng',
    )) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YeuCauXemPhongScreen(roomId: p.id),
      ),
    );
  }

  Widget _noiDung(DuAnChiTiet d) {
    final hien = _chiConTrong
        ? d.phong.where((p) => p.conTrong).toList()
        : d.phong;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Bia(d: d),
        Padding(
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.ten, style: HD.bodyBold(size: 20)),
              if (d.diaChiDay.isNotEmpty) ...[
                const SizedBox(height: HD.s4),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 15,
                      color: HD.inkMuted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        d.diaChiDay,
                        style: HD.body(size: 13.5, color: HD.inkMuted),
                      ),
                    ),
                  ],
                ),
              ],
              if (d.ghiChu != null && d.ghiChu!.trim().isNotEmpty) ...[
                const SizedBox(height: HD.s12),
                Text(d.ghiChu!.trim(), style: HD.body(size: 13.5)),
              ],
              const SizedBox(height: HD.s16),
              _HangSo(d: d),
              const SizedBox(height: HD.s20),
              Row(
                children: [
                  Text('Danh sách phòng', style: HD.bodyBold(size: 16)),
                  const Spacer(),
                  _NutLoc(
                    bat: _chiConTrong,
                    onDoi: () => setState(() => _chiConTrong = !_chiConTrong),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: HD.s12),
        if (hien.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HD.s16,
              vertical: HD.s32,
            ),
            child: Center(
              // Phân biệt CHƯA CÓ PHÒNG NÀO với HẾT PHÒNG TRỐNG. Sale dựng dự
              // án trước rồi gắn tin sau là luồng hợp lệ, nên "hết phòng
              // trống" ở một dự án 0 phòng là câu sai — và nó đuổi khách đi
              // đúng lúc dự án đang chờ được lấp đầy.
              child: Text(
                d.phong.isEmpty
                    ? 'Dự án đang cập nhật danh sách phòng. Liên hệ để được '
                          'báo giá sớm nhất.'
                    : 'Hiện không còn phòng trống',
                textAlign: TextAlign.center,
                style: HD.body(color: HD.inkMuted),
              ),
            ),
          )
        else
          ...hien.map(
            (p) => Padding(
              padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s12),
              child: _HangPhong(
                p: p,
                onTap: p.conTrong ? () => _chamPhong(d, p) : null,
                // Sale của phòng này là chính tôi → dòng tên vẫn hiện (để
                // biết phòng nào của ai khi toà có nhiều sale) nhưng không còn
                // là đường dẫn mở hồ sơ của chính mình.
                onSale: (p.saleId == null || p.saleId == _toi)
                    ? null
                    : () => context.push('/sale/${p.saleId}'),
              ),
            ),
          ),
        const SizedBox(height: HD.s24),
      ],
    );
  }

  Future<void> _moMaBanGiao(DuAnChiTiet d) => showDialog<void>(
    context: context,
    builder: (_) => HopThoaiMaBanGiao(buildingId: d.id, tenToa: d.ten),
  );

  /// Vào SỔ PHÒNG — mặt trong của đúng dự án này.
  ///
  /// Trang này là mặt NGOÀI, dùng chung cho khách. Người phụ trách tới đây từ
  /// dải dự án trên trang cá nhân của mình, và trước đây hết đường: muốn xem
  /// chi tiết phòng phải quay ra, bấm ⚙, vào "Dự án & phòng đang quản lý" rồi
  /// mở lại đúng toà vừa xem. Cả chủ nhà lẫn sale đều mắc.
  void _moSoPhong(DuAnChiTiet d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuildingDetailScreen(
          buildingId: d.id,
          buildingName: d.ten,
          // Trang công khai KHÔNG trả `host_id` — đó là danh tính chủ nhà. Nhưng
          // backend đã trả lời sẵn câu hỏi duy nhất mà màn kia cần ("tôi có
          // đứng tên không"), nên truyền chính id của mình khi câu trả lời là có.
          hostId: d.toiDungTen ? _toi : null,
        ),
      ),
    );
  }

  /// Id người đang xem, `null` khi chưa đăng nhập.
  int? get _toi =>
      Provider.of<AuthProvider>(context, listen: false).currentUser?.id;

  Widget _thanhLienHe(DuAnChiTiet d) {
    final toi = _toi;
    final saleIds = d.phong.map((p) => p.saleId).whereType<int>().toSet();

    // NGƯỜI TRONG NHÀ → không có ai để nhắn.
    //
    // Trước đây thanh này chỉ đọc `saleId` rồi vẽ "Nhắn cho <tên>", không hề
    // biết người đang xem là ai. Nên sale mở dự án của chính mình ra thì thấy
    // "Nhắn cho <tên mình>" — bấm vào là mở hồ sơ của chính mình. Trang này
    // dùng chung cho khách và cho người phụ trách, nên nó phải hỏi "tôi là ai"
    // trước khi mời liên hệ.
    //
    // Điều kiện là `toiQuanLy` (backend hỏi đúng cổng gác của API phòng), KHÔNG
    // phải "tôi là sale của mọi phòng". Cách cũ bỏ sót đúng hai người cần vào
    // nhất: CHỦ NHÀ của toà, và sale chỉ giữ vài phòng trong toà nhiều sale.
    final toiPhuTrach =
        toi != null && saleIds.isNotEmpty && saleIds.every((e) => e == toi);
    if (d.toiQuanLy || toiPhuTrach) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (toiPhuTrach) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 15,
                    color: HD.inkMuted,
                  ),
                  const SizedBox(width: 6),
                  Text('Bạn đang phụ trách dự án này', style: HD.caption()),
                ],
              ),
              const SizedBox(height: HD.s8),
            ],
            // Việc thường xuyên nhất của người trong nhà ở đây là vào xem/sửa
            // phòng, nên nó là nút CHÍNH; mã bàn giao chỉ làm một lần.
            if (d.toiQuanLy) ...[
              DsButton(
                label: 'Mở sổ phòng',
                icon: Icons.grid_view_outlined,
                expand: true,
                onPressed: () => _moSoPhong(d),
              ),
              const SizedBox(height: HD.s8),
            ],
            // Việc TIẾP THEO của sale ở đây là bàn giao cho chủ nhà. Mã vốn chỉ
            // trả về đúng một lần lúc tạo toà, nên đóng app là mất — không có
            // nút này thì sale phải xoá dự án đi dựng lại chỉ để lấy mã.
            //
            // Mã KHÔNG nằm trong dữ liệu trang (trang này công khai): chỉ lấy
            // khi bấm, qua endpoint có kiểm quyền.
            //
            // Hỏi `toiDungTen` chứ KHÔNG suy từ "tôi phụ trách mọi phòng". Hai
            // thứ đó khác nhau ở đúng hai tình huống thường gặp: toà đã bàn
            // giao rồi, và toà do CHỦ NHÀ dựng rồi mời sale vào. Cả hai đều là
            // sale phụ trách mà không đứng tên — trước đây nút vẫn hiện và bấm
            // vào chỉ nhận "Không lấy được mã bàn giao."
            if (d.toiDungTen)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _moMaBanGiao(d),
                  icon: const Icon(Icons.vpn_key_outlined, size: 18),
                  label: const Text('Mã bàn giao cho chủ nhà'),
                ),
              )
            // Nói RÕ vì sao không còn nút, thay vì để một khoảng trống. Sale
            // từng thấy nút ở đây nên im lặng sẽ giống như tính năng hỏng.
            else if (d.daBanGiao == true)
              Text(
                'Đã bàn giao cho chủ nhà',
                textAlign: TextAlign.center,
                style: HD.caption(),
              ),
          ],
        ),
      );
    }

    final saleId = saleIds.length == 1 ? saleIds.first : null;
    final saleTen = saleId == null
        ? null
        : d.phong.firstWhere((p) => p.saleId == saleId).saleTen;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
      child: saleId == null
          ? Text(
              'Chọn Sale ngay dưới phòng bạn quan tâm',
              textAlign: TextAlign.center,
              style: HD.caption(),
            )
          : DsButton(
              label: 'Nhắn cho ${saleTen ?? "Sale phụ trách"}',
              icon: Icons.chat_bubble_outline,
              expand: true,
              onPressed: () => context.push('/sale/$saleId'),
            ),
    );
  }
}

// ── Thành phần ───────────────────────────────────────────────────────────────

class _Bia extends StatelessWidget {
  const _Bia({required this.d});

  final DuAnChiTiet d;

  @override
  Widget build(BuildContext context) {
    // Cùng băng chuyền với thẻ dự án ngoài trang cá nhân. Trước đây chỗ này vẽ
    // riêng một ảnh tĩnh, nên thẻ vuốt được mà mở vào trang chi tiết — nơi có
    // chỗ rộng nhất để xem ảnh — lại đứng im.
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: BangChuyenAnh(
        anh: _anhCua(d),
        kichThuocIconTrong: 48,
        mauNenTrong: HD.accentSoft,
        mauIconTrong: HD.accent,
      ),
    );
  }

  /// `anhBia` chỉ là đường lùi cho dữ liệu cũ chưa có trường `anh`.
  static List<String> _anhCua(DuAnChiTiet d) {
    if (d.anh.isNotEmpty) return d.anh;
    final b = d.anhBia;
    return (b == null || b.isEmpty) ? const [] : [b];
  }
}

/// Ba con số tóm tắt. "Giá từ" chỉ tính trên phòng còn trống — quảng cáo giá
/// của phòng đã có khách là hứa một thứ không bán được.
class _HangSo extends StatelessWidget {
  const _HangSo({required this.d});

  final DuAnChiTiet d;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _o('${d.soPhong}', 'Phòng')),
        const SizedBox(width: HD.s8),
        Expanded(child: _o('${d.soPhongTrong}', 'Còn trống', toMau: true)),
        const SizedBox(width: HD.s8),
        Expanded(
          child: _o(
            d.giaTu == null ? '—' : PriceFormat.compact(d.giaTu!),
            'Giá từ',
          ),
        ),
      ],
    );
  }

  Widget _o(String so, String nhan, {bool toMau = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        children: [
          Text(
            so,
            style: HD
                .bodyBold(size: 18)
                .copyWith(color: toMau ? HD.accent : HD.ink),
          ),
          const SizedBox(height: 2),
          Text(nhan, style: HD.caption()),
        ],
      ),
    );
  }
}

class _NutLoc extends StatelessWidget {
  const _NutLoc({required this.bat, required this.onDoi});

  final bool bat;
  final VoidCallback onDoi;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onDoi,
      borderRadius: BorderRadius.circular(HD.rPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: 5),
        decoration: BoxDecoration(
          color: bat ? HD.accentSoft : HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.rPill),
          border: Border.all(color: bat ? HD.accent : HD.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              bat ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: bat ? HD.accent : HD.inkMuted,
            ),
            const SizedBox(width: 5),
            Text(
              'Chỉ còn trống',
              style: HD
                  .body(size: 12.5, color: bat ? HD.accent : HD.inkMuted)
                  .copyWith(
                    fontWeight: bat ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một phòng: ảnh vuông · mã + diện tích/sức chứa · giá bên phải.
/// Bố cục này để mắt chạy dọc cột giá bên phải mà so được, không phải đọc
/// từng dòng — đó là việc khách thực sự làm trên trang có nhiều phòng.
class _HangPhong extends StatelessWidget {
  const _HangPhong({required this.p, this.onTap, this.onSale});

  final PhongCongKhai p;
  final VoidCallback? onTap;
  final VoidCallback? onSale;

  @override
  Widget build(BuildContext context) {
    final phu = [
      if (p.dienTich != null && p.dienTich! > 0)
        '${p.dienTich!.toStringAsFixed(0)}m²',
      '${p.sucChua} người',
    ].join(' · ');

    return Opacity(
      opacity: p.conTrong ? 1 : .55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HD.r8),
        child: Container(
          padding: const EdgeInsets.all(HD.s8),
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(HD.r8),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: p.anh.isEmpty
                      ? Container(
                          color: HD.paperSunken,
                          child: const Icon(
                            Icons.meeting_room_outlined,
                            color: HD.inkMuted,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: _abs(p.anh.first),
                          fit: BoxFit.cover,
                          memCacheWidth: 220,
                          placeholder: (_, _) =>
                              const ColoredBox(color: HD.paperSunken),
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: HD.paperSunken),
                        ),
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Phòng ${p.ma}', style: HD.bodyBold(size: 15)),
                    const SizedBox(height: 2),
                    Text(phu, style: HD.body(size: 12.5, color: HD.inkMuted)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.conTrong ? HD.accentSoft : HD.paperSunken,
                        borderRadius: BorderRadius.circular(HD.rPill),
                      ),
                      child: Text(
                        p.conTrong ? 'Còn trống' : 'Đã thuê',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.conTrong ? HD.accent : HD.inkMuted,
                        ),
                      ),
                    ),
                    if (p.saleTen != null && p.saleTen!.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: onSale,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 13,
                              color: HD.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Sale phụ trách: ${p.saleTen}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HD.caption().copyWith(
                                  color: onSale == null
                                      ? HD.inkMuted
                                      : HD.accent,
                                ),
                              ),
                            ),
                            if (onSale != null)
                              const Icon(
                                Icons.chevron_right,
                                size: 15,
                                color: HD.accent,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: HD.s8),
              _CotGia(p: p),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giá của phòng — **một dòng cho mỗi kênh đang bật**.
///
/// Trước đây chỗ này in cứng "/tháng" cho mọi phòng. Phòng chạy homestay
/// 350k/đêm vẫn hiện "350k/tháng", và màn đặt phòng thì nhân giá ấy với số đêm.
/// Đơn vị KHÔNG phải chi tiết trang trí — nó là phần nghĩa của con số.
///
/// Nhiều kênh thì xếp dọc, kênh nào cũng ghi rõ đơn vị: khách phải đọc được
/// "5,5tr/tháng · 400k/đêm" mà không phải đoán cái nào là cái nào.
class _CotGia extends StatelessWidget {
  const _CotGia({required this.p});

  final PhongCongKhai p;

  @override
  Widget build(BuildContext context) {
    if (p.kenh.isEmpty) {
      // Chưa cấu hình kênh nào — KHÔNG bịa đơn vị. Dữ liệu cũ rơi vào đây.
      return Text(
        p.gia > 0 ? PriceFormat.compact(p.gia) : 'Thoả thuận',
        style: HD.bodyBold(size: 16).copyWith(color: HD.accent),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in p.kenh) ...[
          if (k != p.kenh.first) const SizedBox(height: 3),
          if (k.products.isNotEmpty)
            ...k.products.map(
              (p) => Text(
                '${p['label']}: ${PriceFormat.compact((p['unit_price'] as num).toDouble())}/${p['unit']}',
                style: HD.caption(),
              ),
            )
          else
            Text(
              k.gia > 0 ? PriceFormat.compact(k.gia) : 'Thoả thuận',
              style: HD.bodyBold(size: 16).copyWith(color: HD.accent),
            ),
          if (k.products.isEmpty && k.gia > 0 && k.hauTo.isNotEmpty)
            Text(k.hauTo, style: HD.caption()),
        ],
      ],
    );
  }
}

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
