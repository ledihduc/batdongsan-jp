import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/service_api.dart';
import 'package:house_booking/features/guest/service/service_request_sheet.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Danh mục DỊCH VỤ NHÀ CỬA. Route: không có URL (push trong tab).
/// API: GET /api/services.
///
/// MỘT hành vi duy nhất khi chạm: mở form đặt dịch vụ. Bản trước còn nhánh thứ
/// hai dẫn sang danh bạ nhà thầu, nhưng mảng thi công đã được gỡ khỏi sản phẩm
/// — giữ lại nhánh đó chỉ để dẫn khách tới một danh sách rỗng.
class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key, this.api});

  /// Chỉ để test bơm API giả.
  final ServiceApi? api;

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

/// Một KHU dịch vụ: tiêu đề + mô tả ngắn + danh sách slug thuộc khu đó.
class _Khu {
  const _Khu(this.icon, this.khoa, this.mau, this.ten, this.moTa, this.slugs);

  final IconData icon;

  /// Khoá dùng để tra ảnh minh hoạ `assets/services/group_<khoa>.png`.
  final String khoa;
  final Color mau;
  final String Function(AppLocalizations) ten;
  final String Function(AppLocalizations) moTa;
  final List<String> slugs;
}

/// Phân nhóm nằm ở FE chứ không ở backend, có chủ ý: đây là cách SẮP XẾP cho
/// người đọc, không phải thuộc tính của dịch vụ. Đổi cách nhóm là đổi một danh
/// sách ở đây, không phải chạy migration.
///
/// Thứ tự khu đi từ việc LÀM THƯỜNG XUYÊN tới việc làm một lần trong đời: dọn
/// dẹp hằng tuần → hỏng thì sửa → làm nhà vài năm một lần → mua bán nhà.
/// Thứ hay cần nhất nằm nơi ngón tay chạm tới trước.
const List<_Khu> _cacKhu = [
  _Khu(
    Icons.cleaning_services_rounded,
    'home_care',
    HD.svcGreen,
    _tenHomeCare,
    _moTaHomeCare,
    ['cleaning', 'moving', 'pest_control', 'hourly_helper'],
  ),
  _Khu(Icons.handyman_rounded, 'repair', HD.svcAmber, _tenRepair, _moTaRepair, [
    'electric',
    'plumbing',
    'unclog',
    'ac_repair',
    'appliance_repair',
  ]),
  _Khu(
    Icons.architecture_rounded,
    'design_build',
    HD.svcPink,
    _tenDesignBuild,
    _moTaDesignBuild,
    // 'build' (Xây dựng) ĐÃ BỎ: 'turnkey' (Thi công trọn gói) là cùng một
    // việc, để cả hai thì người dùng phải đoán chúng khác nhau chỗ nào.
    //
    // 'fengshui' chuyển từ nhóm "Mua bán & pháp lý" sang đây: xem hướng, xem
    // tuổi là việc người ta làm TRƯỚC KHI xây và sửa, cùng lúc với thiết kế —
    // không phải lúc sang tên sổ.
    ['design', 'turnkey', 'fengshui', 'interior', 'painting', 'waterproofing'],
  ),
  // ĐÃ BỎ khu "Mua bán & pháp lý" (định giá · sang tên · vay vốn · kiểm định).
  // Bốn dịch vụ đó cũng đã tắt ở `construction_services`, nên không rơi xuống
  // "Dịch vụ khác" — bỏ nhóm mà để dịch vụ sống thì chúng vẫn hiện, chỉ là
  // hiện ở cuối.
];

/// Màu riêng cho từng dịch vụ. Tra theo SLUG chứ không theo tên icon: tên icon
/// có thể trùng giữa hai dịch vụ khác hẳn nhau, còn slug thì duy nhất.
Color _mauDichVu(String slug) => switch (slug) {
  'electric' => HD.svcAmber,
  'plumbing' => HD.svcBlue,
  'unclog' => HD.svcTeal,
  'ac_repair' => HD.svcCyan,
  'appliance_repair' => HD.svcIndigo,
  'cleaning' => HD.svcGreen,
  'moving' => HD.svcOrange,
  'pest_control' => HD.svcLime,
  'hourly_helper' => HD.svcViolet,
  'design' => HD.svcPink,
  'turnkey' => HD.accent,
  'interior' => HD.svcPurple,
  'painting' => HD.svcRose,
  'waterproofing' => HD.svcBlue,
  'fengshui' => HD.svcFuchsia,
  // Năm slug dưới đây ĐÃ TẮT ở danh mục (migration 0091) nên không còn hiện
  // trong catalog — nhưng `service_requests` cũ vẫn trỏ tới chúng, và màn
  // "Đơn của tôi" tra bảng này để tô màu. Bỏ đi là đơn cũ mất màu riêng.
  'build' => HD.svcBrown,
  'valuation' => HD.svcEmerald,
  'legal_transfer' => HD.svcIndigo,
  'home_loan' => HD.svcTeal,
  'inspection' => HD.svcAmber,
  // Dịch vụ mới chưa xếp màu vẫn hiện, chỉ là mang màu thương hiệu.
  _ => HD.accent,
};

String _tenDesignBuild(AppLocalizations l) => l.svcGroupDesignBuild;
String _moTaDesignBuild(AppLocalizations l) => l.svcGroupDesignBuildHint;
String _tenRepair(AppLocalizations l) => l.svcGroupRepair;
String _moTaRepair(AppLocalizations l) => l.svcGroupRepairHint;
String _tenHomeCare(AppLocalizations l) => l.svcGroupHomeCare;
String _moTaHomeCare(AppLocalizations l) => l.svcGroupHomeCareHint;

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  ServiceApi get _api => widget.api ?? const ServiceApi();

  List<Map<String, dynamic>> _services = const [];
  bool _loading = true;

  final _timCtl = TextEditingController();
  String _tuKhoa = '';

  @override
  void dispose() {
    _timCtl.dispose();
    super.dispose();
  }

  /// Lọc theo tên VÀ mô tả: người dùng gõ "tắc" thì phải ra "Thông tắc", mà gõ
  /// "bồn cầu" — chữ chỉ có trong mô tả — cũng phải ra.
  List<Map<String, dynamic>> get _ketQua {
    final q = _tuKhoa.trim().toLowerCase();
    if (q.isEmpty) return _services;
    return _services.where((s) {
      final ten = ((s['name'] as String?) ?? '').toLowerCase();
      final mo = ((s['description'] as String?) ?? '').toLowerCase();
      return ten.contains(q) || mo.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final ds = await _api.danhMuc();
      if (mounted) setState(() => _services = ds);
    } catch (_) {
      if (mounted) setState(() => _services = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cham(Map<String, dynamic> s) {
    showServiceRequestSheet(
      context,
      serviceSlug: (s['slug'] as String?) ?? '',
      serviceName: (s['name'] as String?) ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      // KHÔNG dùng AppBar riêng: nó là một dải xám nằm ngay trên dải đỏ, hai
      // thanh tiêu đề chồng nhau và chỗ giáp ranh cắt ngang rất thô. Tiêu đề
      // chuyển hẳn vào trong dải đỏ để đầu trang là MỘT khối liền.
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
          ? DsEmptyState(icon: Icons.handyman_outlined, title: l.svcReqEmpty)
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _dauTrang(l),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HD.s16,
                    HD.s16,
                    HD.s16,
                    HD.s24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _ketQua.isEmpty
                        ? [
                            const SizedBox(height: HD.s24),
                            DsEmptyState(
                              icon: Icons.search_off,
                              title: l.svcNoMatch,
                              subtitle: l.svcNoMatchHint,
                            ),
                          ]
                        : _theoKhu(l),
                  ),
                ),
              ],
            ),
    );
  }

  /// Khối đầu trang: nền đỏ + minh hoạ, lời mời, và ô TÌM.
  ///
  /// Bản trước chỉ có thanh tiêu đề và một dòng chữ mờ — với 20 dịch vụ xếp
  /// thành 4 khu, người dùng phải cuộn và đọc hết mới biết có thứ mình cần hay
  /// không. Ô tìm cắt thẳng qua chuyện đó.
  Widget _dauTrang(AppLocalizations l) {
    // Màn này vừa là một TAB (không có gì để quay lại) vừa được mở chồng từ
    // trang chủ (có). Hỏi Navigator thay vì đoán, nếu không thì hoặc thừa một
    // mũi tên chết, hoặc thiếu lối ra.
    final coBack = Navigator.of(context).canPop();
    return Container(
      width: double.infinity,
      // TRÀN SÁT VIỀN: không lề, không bo góc. Bản trước là một thẻ nổi có lề
      // hai bên — nhìn ra cái hộp dán lên trang chứ không phải phần đầu của
      // chính trang. Màu đỏ chạy hết chiều ngang thì nó là NỀN, không phải một
      // thành phần nằm trên nền.
      decoration: const BoxDecoration(gradient: HD.accentGradient),
      padding: EdgeInsets.fromLTRB(
        HD.s16,
        MediaQuery.of(context).padding.top + HD.s12,
        HD.s16,
        HD.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (coBack)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              _vienNhat(Icons.home_rounded, l.svcCatalogTitle, dam: true),
            ],
          ),
          const SizedBox(height: HD.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.svcHeroTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.svcHeroSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.94),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              // Minh hoạ 104px CAO HƠN HẲN khối chữ bên trái (tiêu đề + một
              // dòng phụ đề ≈ 56px), nên nó kéo cả hàng giãn ra và để lại một
              // mảng đỏ trống dưới chữ. Hạ xuống 82 cho hai bên cao xấp xỉ
              // nhau, ô tìm nhờ đó lùi lên hơn 20px.
              SizedBox(
                width: 82,
                height: 82,
                child: Image.asset(
                  'assets/services/group_repair.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          _oTim(l),
          const SizedBox(height: HD.s12),
          Row(
            children: [
              _vienNhat(Icons.grid_view_rounded, l.svcCount(_services.length)),
              const SizedBox(width: HD.s8),
              _vienNhat(
                Icons.people_alt_rounded,
                l.svcGroupCount(_cacKhu.length),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Viên bo tròn nền mờ, viền trắng nhạt — dùng cho chip tiêu đề và hai viên
  /// thống kê. Nền mờ thay vì trắng đặc: trắng đặc trên nền đỏ hút mắt ngang
  /// với ô tìm kiếm, mà đây chỉ là thông tin phụ.
  Widget _vienNhat(IconData icon, String chu, {bool dam = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(HD.rPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            chu,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: dam ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _oTim(AppLocalizations l) {
    return TextField(
      controller: _timCtl,
      onChanged: (v) => setState(() => _tuKhoa = v),
      textInputAction: TextInputAction.search,
      style: HD.body(size: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: l.svcSearchHint,
        hintStyle: HD.body(size: 14).copyWith(color: HD.inkMuted),
        // Kính lúp ĐỎ, không xám: nó là thứ duy nhất có màu trên ô trắng nên
        // mắt bắt được ngay đây là chỗ gõ tìm.
        prefixIcon: const Icon(Icons.search, color: HD.accent, size: 22),
        suffixIcon: _tuKhoa.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: HD.inkMuted,
                onPressed: () {
                  _timCtl.clear();
                  setState(() => _tuKhoa = '');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.rPill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.rPill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.rPill),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Chia dịch vụ về các khu. Slug không thuộc khu nào rơi vào "Dịch vụ khác"
  /// — thêm dịch vụ mới ở backend mà quên xếp nhóm thì nó vẫn HIỆN, chỉ là hiện
  /// ở cuối; im lặng nuốt mất mới là hỏng.
  List<Widget> _theoKhu(AppLocalizations l) {
    final conLai = {for (final s in _ketQua) (s['slug'] as String? ?? ''): s};
    final out = <Widget>[];

    for (final khu in _cacKhu) {
      final ds = <Map<String, dynamic>>[];
      for (final slug in khu.slugs) {
        final s = conLai.remove(slug);
        if (s != null) ds.add(s);
      }
      // Khu rỗng thì KHÔNG vẽ thẻ trống: người dùng không cần biết app dự tính
      // có nhóm nào mà chưa có dịch vụ nào trong đó.
      if (ds.isEmpty) continue;
      out.add(
        _theKhu(khu.icon, khu.khoa, khu.mau, khu.ten(l), khu.moTa(l), ds, l),
      );
      out.add(const SizedBox(height: HD.s16));
    }

    if (conLai.isNotEmpty) {
      out.add(
        _theKhu(
          Icons.more_horiz,
          'other',
          HD.inkMuted,
          l.svcGroupOther,
          '',
          conLai.values.toList(),
          l,
        ),
      );
    }
    return out;
  }

  /// Một khu = MỘT thẻ trắng riêng: đầu thẻ nói khu này là gì và có bao nhiêu
  /// dịch vụ, dưới là lưới. Trước đây 14 dịch vụ nằm chung một lưới phẳng,
  /// người dùng phải tự đọc hết mới biết cái mình cần nằm ở đâu.
  /// Một KHU = một thẻ trắng nổi.
  ///
  /// Bản trước lồng khung trong khung: thẻ trắng viền xám, bên trong lại là các
  /// ô trắng viền xám. Hai lớp viền cùng màu nằm sát nhau làm mọi thứ phẳng lì
  /// và rẻ tiền. Nay thẻ dùng BÓNG ĐỔ để tách khỏi nền, còn từng dịch vụ bỏ hẳn
  /// khung — chip màu đã đủ làm ranh giới.
  Widget _theKhu(
    IconData icon,
    String khoa,
    Color mau,
    String ten,
    String moTa,
    List<Map<String, dynamic>> ds,
    AppLocalizations l,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dải đầu thẻ nhuộm nhạt theo màu khu: tách phần "đây là khu gì" khỏi
          // phần "chọn dịch vụ nào", mà không cần thêm một đường kẻ nữa.
          Container(
            width: double.infinity,
            color: HD.svcTint(mau),
            padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s12),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Image.asset(
                    'assets/services/group_$khoa.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        color: mau,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: Colors.white, size: 21),
                    ),
                  ),
                ),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ten, style: HD.bodyBold(size: 15)),
                      if (moTa.isNotEmpty)
                        Text(
                          moTa,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.caption(),
                        ),
                    ],
                  ),
                ),
                Text(
                  l.svcCount(ds.length),
                  style: HD.caption().copyWith(
                    color: mau,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(HD.s12, HD.s16, HD.s12, HD.s16),
            child: _luoi(ds),
          ),
        ],
      ),
    );
  }

  Widget _luoi(List<Map<String, dynamic>> ds) {
    return LayoutBuilder(
      builder: (context, c) {
        const khoang = HD.s8;
        // 4 cột khi đủ rộng: chip đã to và đặc màu, 3 cột làm hàng thưa thớt và
        // hàng cuối trống hoác khi khu có 5 dịch vụ.
        final cot = c.maxWidth >= 360 ? 4 : 3;
        final rong = (c.maxWidth - khoang * (cot - 1)) / cot;
        return Wrap(
          spacing: khoang,
          runSpacing: khoang,
          children: [for (final s in ds) SizedBox(width: rong, child: _o(s))],
        );
      },
    );
  }

  Widget _o(Map<String, dynamic> s) {
    final slug = (s['slug'] as String?) ?? '';
    final mau = _mauDichVu(slug);
    return InkWell(
      borderRadius: BorderRadius.circular(HD.r12),
      onTap: () => _cham(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HD.s8, horizontal: 4),
        child: Column(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Image.asset(
                'assets/services/$slug.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                // Thiếu ảnh thì rơi về chip màu vẽ bằng mã. Dịch vụ mới thêm ở
                // backend vẫn hiện tử tế trước khi ai đó vẽ icon cho nó.
                errorBuilder: (_, _, _) => _chip(s, mau),
              ),
            ),
            const SizedBox(height: HD.s8),
            Text(
              (s['name'] as String?) ?? '',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: HD.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(Map<String, dynamic> s, Color mau) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: mau,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: mau.withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(_icon(s['icon'] as String?), color: Colors.white, size: 26),
    );
  }

  /// Backend trả TÊN icon (chuỗi) chứ không phải codepoint — Flutter web build
  /// với tree-shake icon nên tra động bằng `IconData(hex)` sẽ ra ô vuông trống.
  /// Vì vậy map tường minh; slug lạ rơi về icon chung.
  static IconData _icon(String? ten) => switch (ten) {
    // Dùng bộ `_rounded` chứ không phải `_outlined`: ở cỡ 22px trong ô
    // tròn, nét mảnh của outlined nhìn gãy và nhợt; bản bo tròn đặc nét,
    // đọc ra hình ngay cả trên màn hình dày điểm ảnh.
    'bolt' => Icons.bolt_rounded,
    'water_drop' => Icons.water_drop_rounded,
    'plumbing' => Icons.plumbing_rounded,
    'ac_unit' => Icons.ac_unit_rounded,
    'kitchen' => Icons.kitchen_rounded,
    'cleaning_services' => Icons.cleaning_services_rounded,
    'local_shipping' => Icons.local_shipping_rounded,
    'format_paint' => Icons.format_paint_rounded,
    'umbrella' => Icons.umbrella_rounded,
    'pest_control' => Icons.pest_control_rounded,
    'schedule' => Icons.schedule_rounded,
    'design_services' => Icons.design_services_rounded,
    'construction' => Icons.construction_rounded,
    'chair' => Icons.chair_rounded,
    'architecture' => Icons.architecture_rounded,
    // Nhóm dịch vụ quanh một thương vụ nhà đất (0080). Vài cái đổi hẳn
    // hình cho sát nghĩa hơn tên icon mà backend gửi:
    //   gavel (búa toà án → gợi kiện tụng)  → giấy tờ đã ký
    //   auto_fix_high (đũa phép)            → ngôi sao lấp lánh
    //   handyman (cái búa) cho trọn gói     → ngôi nhà đang xây
    'price_check' => Icons.sell_rounded,
    'gavel' => Icons.assignment_turned_in_rounded,
    'account_balance' => Icons.account_balance_rounded,
    'fact_check' => Icons.fact_check_rounded,
    'photo_camera' => Icons.photo_camera_rounded,
    'explore' => Icons.explore_rounded,
    'auto_fix_high' => Icons.auto_awesome_rounded,
    'handyman' => Icons.home_work_rounded,
    _ => Icons.handyman_rounded,
  };
}
