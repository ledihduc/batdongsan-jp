import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Báo cáo ĐIỀU TRA THỊ TRƯỜNG — 10 đối thủ thuê/cho thuê nhà tại VN, phân tích
/// dưới góc nhìn chuyên gia nghiên cứu thị trường (định vị, người dùng, UI/UX,
/// doanh thu, SWOT, khoảng trống & khuyến nghị cho ancu365).
///
/// CHỈ ADMIN xem được (gate ở build + chỉ hiện lối vào trong Admin dashboard).
class MarketResearchScreen extends StatelessWidget {
  const MarketResearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().currentUser?.role;
    if (role != 'admin') {
      return const Scaffold(
        appBar: DsAppBar(title: 'Nghiên cứu thị trường'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Trang này chỉ dành cho quản trị viên.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HD.inkMuted)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        eyebrow: 'Chỉ quản trị',
        title: 'Điều tra thị trường',
        titleAsSerif: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        children: [
          _intro(),
          const SizedBox(height: 20),
          _sectionTitle('1 · Toàn cảnh thị trường'),
          _statRow(),
          const SizedBox(height: 10),
          ..._marketNotes.map(_bullet),
          const SizedBox(height: 24),

          _sectionTitle('2 · Bản đồ định vị — 4 cụm cạnh tranh'),
          ..._clusters.map(_clusterCard),
          const SizedBox(height: 24),

          _sectionTitle('3 · Hồ sơ 10 đối thủ'),
          const Text('Chạm để mở chi tiết từng app.',
              style: TextStyle(color: HD.inkMuted, fontSize: 12)),
          const SizedBox(height: 8),
          ..._competitors.map(_compTile),
          const SizedBox(height: 24),

          _sectionTitle('4 · So sánh năng lực lõi'),
          ..._capabilities.map(_capabilityRow),
          const SizedBox(height: 24),

          _sectionTitle('5 · SWOT của ancu365'),
          _swot(),
          const SizedBox(height: 24),

          _sectionTitle('6 · Khoảng trống & cơ hội'),
          _blueOcean(),
          const SizedBox(height: 12),
          ..._gaps.map(_bullet),
          const SizedBox(height: 24),

          _sectionTitle('7 · Khuyến nghị hành động'),
          ..._recommendations.map(_recCard),
          const SizedBox(height: 24),

          _sourcesFooter(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _intro() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: HD.appGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HD.hairline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.insights_outlined, color: HD.accent, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text('Báo cáo cạnh tranh — sàn thuê/cho thuê VN',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: HD.ink)),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
              'Phân tích 10 ứng dụng đối thủ để định vị ancu365. Kết luận cốt lõi: '
              'thị trường thuê/cho-thuê rất đông và khốc liệt, nhưng KHÔNG đối thủ '
              'nào phủ mảng "Thi công / đơn vị xây dựng" — đây là đại dương xanh '
              'riêng của ancu365. Việc cần làm là vá 3 điểm bắt buộc phải có '
              '(chống tin ảo, chính chủ, minh bạch) rồi khuếch đại lợi thế thi công.',
              style: TextStyle(color: HD.inkSoft, fontSize: 13, height: 1.4)),
        ]),
      );

  Widget _statRow() => Row(children: [
        _stat('47 tỷ\$', 'Quy mô BĐS VN 2025'),
        const SizedBox(width: 8),
        _stat('512 tr\$', 'Proptech VN 2023'),
        const SizedBox(width: 8),
        _stat('+18.7%', 'Tăng trưởng/năm'),
      ]);

  Widget _stat(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
              color: HD.accentTint, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(v,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: HD.accent)),
            const SizedBox(height: 2),
            Text(l,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: HD.inkSoft)),
          ]),
        ),
      );

  // ── Cụm định vị ────────────────────────────────────────────────────────────
  Widget _clusterCard(_Cluster c) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HD.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(c.icon, size: 18, color: HD.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: HD.ink, fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(c.apps,
              style: const TextStyle(color: HD.accent, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(c.note, style: const TextStyle(color: HD.inkSoft, fontSize: 12)),
        ]),
      );

  // ── Thẻ đối thủ ────────────────────────────────────────────────────────────
  Widget _compTile(_Comp c) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HD.hairline)),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(c.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: HD.ink, fontSize: 14)),
            subtitle: Text('${c.cluster} · ${c.scale}',
                style: const TextStyle(color: HD.inkMuted, fontSize: 11)),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              _kv('Định vị', c.positioning),
              _kv('Đối tượng', c.audience),
              _kv('USP', c.usp),
              _kv('Doanh thu', c.monetization),
              const SizedBox(height: 6),
              _prosCons('Điểm mạnh', c.strengths, HD.positive, Icons.add),
              _prosCons('Điểm yếu', c.weaknesses, HD.negative, Icons.remove),
            ],
          ),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$k: ',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: HD.ink, fontSize: 12.5)),
            TextSpan(
                text: v,
                style: const TextStyle(color: HD.inkSoft, fontSize: 12.5, height: 1.35)),
          ]),
        ),
      );

  Widget _prosCons(String t, List<String> items, Color c, IconData ic) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: c, fontSize: 12)),
          const SizedBox(height: 2),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(ic, size: 13, color: c),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(e,
                          style: const TextStyle(color: HD.inkSoft, fontSize: 12))),
                ]),
              )),
        ]),
      );

  // ── So sánh năng lực ───────────────────────────────────────────────────────
  Widget _capabilityRow(_Cap cap) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HD.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cap.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: HD.ink, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Dẫn đầu: ${cap.leaders}',
              style: const TextStyle(color: HD.inkSoft, fontSize: 12)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: cap.ancu.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('ancu365: ${cap.ancu.label}',
                  style: TextStyle(
                      color: cap.ancu.color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      );

  // ── SWOT ───────────────────────────────────────────────────────────────────
  Widget _swot() => Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _swotCell('Điểm mạnh (S)', _swotS, HD.positive),
          const SizedBox(width: 8),
          _swotCell('Điểm yếu (W)', _swotW, HD.negative),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _swotCell('Cơ hội (O)', _swotO, HD.accent),
          const SizedBox(width: 8),
          _swotCell('Thách thức (T)', _swotT, HD.warning),
        ]),
      ]);

  Widget _swotCell(String t, List<String> items, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: c, fontSize: 12)),
            const SizedBox(height: 4),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('• $e',
                      style: const TextStyle(color: HD.inkSoft, fontSize: 11.5, height: 1.3)),
                )),
          ]),
        ),
      );

  Widget _blueOcean() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [HD.accent, HD.accentDeep]),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Row(children: [
            Icon(Icons.workspace_premium, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Đại dương xanh: MẢNG THI CÔNG',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
          SizedBox(height: 6),
          Text(
              '0/10 đối thủ có mảng thi công / kết nối đơn vị xây dựng — nội thất. '
              'ancu365 là app DUY NHẤT ghép "thuê nhà" với "sửa/xây/nội thất", mở '
              'chuỗi giá trị trọn gói thuê → thi công → ở. Đây là điểm khác biệt '
              'khó sao chép nhất và nên là trục thương hiệu chính.',
              style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4)),
        ]),
      );

  // ── Khuyến nghị ────────────────────────────────────────────────────────────
  Widget _recCard(_Rec r) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: r.color, width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: r.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(r.horizon,
                  style: TextStyle(
                      color: r.color, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(r.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: HD.ink, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(r.detail,
              style: const TextStyle(color: HD.inkSoft, fontSize: 12, height: 1.35)),
        ]),
      );

  Widget _sourcesFooter() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: HD.paperSunken, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Nguồn & phương pháp',
              style: TextStyle(fontWeight: FontWeight.bold, color: HD.ink, fontSize: 12)),
          SizedBox(height: 4),
          Text(
              'Tổng hợp từ mô tả sản phẩm công khai, App Store / Google Play, '
              'Batdongsan.com.vn, VnExpress/VnBusiness/Dân trí (proptech), Brands '
              'Vietnam, IKIGROUP (Rencity), TheGioiDiDong (OHANA), Landber, Smartos. '
              'Số quy mô người dùng là ước lượng từ công bố của hãng, dùng để định '
              'hướng chiến lược — không phải số liệu kiểm toán.',
              style: TextStyle(color: HD.inkSoft, fontSize: 11, height: 1.4)),
        ]),
      );

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: HD.sectionTitle()),
      );

  Widget _bullet(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 6, color: HD.accent),
          ),
          Expanded(
              child: Text(t,
                  style: const TextStyle(color: HD.inkSoft, fontSize: 13, height: 1.4))),
        ]),
      );
}

// ── Dữ liệu báo cáo ──────────────────────────────────────────────────────────

const _marketNotes = [
  'Cạnh tranh KHỐC LIỆT: PropertyGuru (mẹ của Batdongsan.com.vn) từng phải "bán mình"; Propzy đã phá sản — bài học đốt tiền không có mô hình bền vững.',
  '4 xu hướng định hình: (1) chống tin ảo & "chính chủ"; (2) đồng bộ phòng trống real-time (PMS); (3) tìm kiếm theo bản đồ/vị trí + street view; (4) Gen-Z ở ghép theo hồ sơ tính cách.',
  'Vốn đổ vào ngành: Rever gọi 10,2 tr\$ (Mekong Capital), Homebase 30 tr\$, Meey Group hệ sinh thái ~1.000 tỷ đồng → sân chơi cần khác biệt rõ, không đối đầu trực diện về "độ lớn kho tin".',
];

class _Cluster {
  final IconData icon;
  final String title, apps, note;
  const _Cluster(this.icon, this.title, this.apps, this.note);
}

const _clusters = [
  _Cluster(Icons.storefront_outlined, 'A · Marketplace rao vặt lớn',
      'Chợ Tốt Nhà · Batdongsan · MuaBan.net · AloNhaDat',
      'Reach khổng lồ, mọi phân khúc. Điểm yếu chung: nhiều tin ảo/môi giới, chất lượng không đồng đều.'),
  _Cluster(Icons.verified_user_outlined, 'B · Trọ minh bạch / quản lý',
      'Rencity · Nhà Trọ 360 · Smartos',
      'Chính chủ, chống tin ảo, đặt lịch xem, đồng bộ real-time. Cung hạn chế nhưng niềm tin cao.'),
  _Cluster(Icons.groups_outlined, 'C · Gen-Z / ở ghép',
      'OHANA · Doong',
      'Sinh viên/người trẻ, tính năng roommate + kiểm duyệt. Ngách hẹp nhưng trung thành.'),
  _Cluster(Icons.map_outlined, 'D · Công nghệ tìm kiếm',
      'Landber',
      'Vẽ tay khoanh vùng trên bản đồ, Street View, định giá & tính chi phí — mạnh về công nghệ.'),
];

class _Comp {
  final String name, cluster, scale, positioning, audience, usp, monetization;
  final List<String> strengths, weaknesses;
  const _Comp(this.name, this.cluster, this.scale, this.positioning,
      this.audience, this.usp, this.monetization, this.strengths, this.weaknesses);
}

const _competitors = [
  _Comp('Chợ Tốt Nhà (Nhà Tốt)', 'Cụm A', 'Chục triệu user (hệ Chợ Tốt)',
      '"Khu chợ" BĐS online lớn nhất VN, mọi phân khúc.',
      'Đại chúng — từ trọ giá rẻ đến nhà nguyên căn.',
      'Lưu lượng khổng lồ, tin mới liên tục mỗi ngày, đang xây hệ thống môi giới.',
      'Đẩy tin/gói VIP + quảng cáo.',
      ['Reach lớn nhất thị trường', 'UX dễ dùng, thương hiệu Chợ Tốt mạnh', 'Tin cập nhật liên tục'],
      ['Nhiều tin ảo/môi giới', 'Chất lượng không đồng đều', 'Thiếu chiều sâu quản lý/vận hành']),
  _Comp('Batdongsan.com.vn', 'Cụm A', '~4 tr user · ~1 tr tin/tháng',
      'Toàn cảnh thị trường, uy tín, thuộc PropertyGuru.',
      'Tầm trung–cao cấp, môi giới chuyên nghiệp.',
      'Bộ lọc chi tiết, dữ liệu & giá thị trường, độ uy tín cao.',
      'Phí đăng tin + gói môi giới + quảng cáo dự án.',
      ['4M+ user, 70M pageview', 'Dữ liệu thị trường sâu', 'Hậu thuẫn vốn PropertyGuru'],
      ['Phí đăng tin cao (đắt cho môi giới nhỏ)', 'Thiên mua bán hơn thuê', 'Công ty mẹ áp lực tài chính']),
  _Comp('Rencity', 'Cụm B', '~1 tr người thuê · 40k+ phòng',
      'Tìm trọ/căn hộ CHÍNH CHỦ, minh bạch.',
      'Người đi thuê trọ & căn hộ đô thị.',
      'Chính chủ + tìm quanh vị trí + chat chủ nhà + ĐẶT LỊCH XEM trên app.',
      'Gói chủ nhà/đẩy tin, hoa hồng.',
      ['1M renters, 40k+ phòng "chính chủ"', 'Trải nghiệm mượt, chống tin ảo tốt', 'Đặt lịch xem tiện'],
      ['Tập trung đô thị lớn, phủ tỉnh hạn chế', 'Không có nhà bán/thi công', 'Cung phụ thuộc chủ nhà']),
  _Comp('OHANA', 'Cụm C', 'Cộng đồng trẻ (100+ user mới/tuần)',
      'Trọ + Ở GHÉP cho người trẻ/sinh viên.',
      'Sinh viên, người trẻ mới đi làm.',
      'Tìm người ở ghép (roommate) + kiểm duyệt tin kỹ trước khi hiển thị.',
      'Gói tin/quảng cáo, freemium.',
      ['Cộng đồng trẻ trung thành', 'Kiểm duyệt → an toàn/ít tin ảo', 'Tính năng ở ghép nổi bật'],
      ['Quy mô nhỏ hơn top', 'Phân khúc hẹp (trọ rẻ/sinh viên)', 'Phủ địa lý giới hạn']),
  _Comp('Smartos Booking', 'Cụm B', 'Ngách căn hộ dịch vụ/trọ cao cấp',
      'Chống tin ảo bằng đồng bộ REAL-TIME từ hệ quản lý chủ nhà (PMS).',
      'Khách thuê căn hộ dịch vụ/trọ cao cấp.',
      'Phòng trống + giá + tiện ích đồng bộ thời gian thực → không tin ảo.',
      'SaaS PMS cho chủ nhà + booking.',
      ['Dữ liệu THẬT theo real-time', 'Tích hợp quản lý vận hành', 'Niềm tin cao'],
      ['Phụ thuộc chủ nhà dùng PMS', 'Cung hạn chế, ít tin đại trà', 'Khó phủ nhanh']),
  _Comp('MuaBan.net', 'Cụm A', 'Lâu đời, dữ liệu lớn toàn quốc',
      'Rao vặt tổng hợp lâu đời, phủ toàn quốc.',
      'Đại chúng, cả tỉnh lẻ.',
      'Dữ liệu lớn, liên hệ trực tiếp người cho thuê, phủ tỉnh rộng.',
      'Đẩy tin/quảng cáo.',
      ['Dữ liệu lớn, phủ tỉnh rộng', 'Thương hiệu lâu đời'],
      ['UX cũ', 'Tin ảo, ít công nghệ mới', 'Trải nghiệm mobile chưa tối ưu']),
  _Comp('Nhà Trọ 360', 'Cụm B', 'Chuyên trọ, thương hiệu vừa',
      'Chuyên biệt tìm & cho thuê nhà trọ.',
      'Người thuê trọ + chủ nhà nhỏ lẻ.',
      'Tìm quanh vị trí + chủ nhà quản lý tin MIỄN PHÍ, trực quan.',
      'Gói nâng cao/quảng cáo.',
      ['Chuyên trọ, trực quan', 'Miễn phí cho chủ nhà', 'Định vị rõ ràng'],
      ['Thương hiệu nhỏ', 'Phủ hạn chế', 'Ít tính năng nâng cao']),
  _Comp('Landber', 'Cụm D', 'Tự nhận #1 app BĐS',
      'Tìm nhà THÔNG MINH trên bản đồ.',
      'Người mua/thuê thích tra cứu theo khu vực.',
      'Vẽ tay khoanh vùng trên map + Street View + định giá + tính chi phí.',
      'Gói môi giới/đẩy tin + dịch vụ định giá.',
      ['Công nghệ tìm kiếm/định giá vượt trội', 'Street View, vẽ bản đồ', 'Định giá theo dữ liệu lân cận'],
      ['Thiên mua bán/định giá', 'Cộng đồng trọ nhỏ hơn', 'Tính năng nặng, học phí UX']),
  _Comp('Doong', 'Cụm C', '1.000+ phòng/tháng',
      'Ở ghép theo HỒ SƠ TÍNH CÁCH.',
      'Người trẻ tìm trọ + ở ghép.',
      'Gợi ý roommate theo tính cách/lối sống → hạn chế xích mích.',
      'Freemium/quảng cáo.',
      ['Matching thông minh theo profile', 'Bảo mật thông tin cá nhân', 'Ngách rõ ràng'],
      ['Quy mô nhỏ (1k+ phòng/tháng)', 'Ngách hẹp', 'Phụ thuộc hiệu ứng mạng']),
  _Comp('AloNhaDat', 'Cụm A', 'Web-first, đang lên mobile',
      'Rao vặt minh bạch, chống tin giả.',
      'Người thuê cần sàng lọc môi giới xấu.',
      'Danh mục phản ánh tin vi phạm / báo cáo tin giả → bảo vệ người thuê.',
      'Đẩy tin/quảng cáo.',
      ['Minh bạch, cơ chế báo tin xấu', 'Sàng lọc môi giới không trung thực'],
      ['Xuất phát web, app kém hiện đại', 'Quy mô nhỏ hơn top', 'Nhận diện thương hiệu thấp']),
];

class _AncuMark {
  final String label;
  final Color color;
  const _AncuMark(this.label, this.color);
}

class _Cap {
  final String name, leaders;
  final _AncuMark ancu;
  const _Cap(this.name, this.leaders, this.ancu);
}

const _has = _AncuMark('Đã có ✓', HD.positive);
const _partial = _AncuMark('Một phần', HD.warning);
const _missing = _AncuMark('Chưa có ✗', HD.negative);
const _unique = _AncuMark('Độc quyền ★', HD.accent);

const _capabilities = [
  _Cap('Đặt lịch xem nhà trên app', 'Rencity', _has),
  _Cap('Thẩm định / sao chất lượng tin', 'Smartos, OHANA (kiểm duyệt)', _has),
  _Cap('Chat trực tiếp chủ nhà', 'Rencity, Chợ Tốt', _has),
  _Cap('Tìm quanh vị trí / bản đồ', 'Landber, Rencity, Nhà Trọ 360', _partial),
  _Cap('Chống tin ảo / chính chủ', 'Smartos (real-time), Rencity', _partial),
  _Cap('Báo cáo tin vi phạm / tin giả', 'AloNhaDat, OHANA', _partial),
  _Cap('Ở ghép (roommate matching)', 'OHANA, Doong', _missing),
  _Cap('Vẽ bản đồ khoanh vùng + Street View', 'Landber', _missing),
  _Cap('PMS quản lý + đồng bộ phòng trống real-time', 'Smartos', _missing),
  _Cap('Mảng THI CÔNG / đơn vị xây dựng — nội thất', 'Không đối thủ nào', _unique),
];

const _swotS = [
  'Super-app BĐS + THI CÔNG (độc nhất VN)',
  'Đã có đặt lịch xem/slot + thẩm định sao chất lượng',
  'Feed cộng đồng + đánh giá 2 chiều',
  'Kiến trúc kỹ thuật hiện đại (Flutter + PostGIS)',
];
const _swotW = [
  'Thương hiệu mới, ít người dùng & tin đăng',
  'Chưa chống tin ảo real-time',
  'Chưa có ở ghép / matching',
  'Bản đồ chưa mạnh bằng Landber',
];
const _swotO = [
  'Đại dương xanh: gói trọn gói thuê → thi công → ở',
  'Ở ghép Gen-Z (OHANA/Doong còn nhỏ)',
  'Minh bạch: báo tin xấu + chính chủ',
  'Phủ tỉnh lẻ (đối thủ mạnh tập trung đô thị)',
];
const _swotT = [
  'Đốt tiền cạnh tranh (Propzy đã chết)',
  'Chợ Tốt / Batdongsan reach khổng lồ',
  'PropertyGuru vốn mạnh',
  'Chi phí thu hút người dùng cao',
];

const _gaps = [
  'PHẢI CÓ để cạnh tranh: badge "Chính chủ" + cơ chế chống tin ảo (học Rencity/Smartos) và nút "Báo tin sai/ảo" (học AloNhaDat/OHANA).',
  'NÊN CÓ để giữ chân Gen-Z: ở ghép/roommate matching theo hồ sơ (OHANA/Doong) — tận dụng feed cộng đồng sẵn có.',
  'TĂNG LỢI THẾ: đẩy mạnh mảng thi công thành thông điệp thương hiệu số 1; gói "thuê xong sửa liền".',
];

class _Rec {
  final String horizon, title, detail;
  final Color color;
  const _Rec(this.horizon, this.title, this.detail, this.color);
}

const _recommendations = [
  _Rec('0–3 THÁNG · QUICK WIN', 'Chống tin ảo + minh bạch',
      'Thêm badge "Chính chủ", nút "Báo tin sai/ảo" + hàng đợi kiểm duyệt. Đây là điểm bắt buộc phải có để tạo niềm tin ngang Rencity/AloNhaDat.',
      HD.positive),
  _Rec('0–3 THÁNG · QUICK WIN', 'Khuếch đại USP Thi công',
      'Đưa thông điệp "app DUY NHẤT ghép thuê nhà với thi công/nội thất" lên trang chủ + onboarding + marketing. Biến khác biệt thành định vị.',
      HD.accent),
  _Rec('3–6 THÁNG · MID', 'Ở ghép cho Gen-Z',
      'Roommate matching theo hồ sơ tính cách/lối sống, dựa trên feed cộng đồng đã có. Mở khoá phân khúc sinh viên (OHANA/Doong đang bỏ ngỏ về quy mô).',
      HD.warning),
  _Rec('3–6 THÁNG · MID', 'Bản đồ & tìm quanh đây mạnh hơn',
      'Nâng trải nghiệm bản đồ (đã có PostGIS): tìm quanh vị trí mượt, cân nhắc vẽ khoanh vùng / street view như Landber.',
      HD.warning),
  _Rec('6–12 THÁNG · BET', 'PMS chủ nhà + phòng trống real-time',
      'Công cụ quản lý cho chủ nhà, đồng bộ phòng trống theo thời gian thực → diệt tin ảo tận gốc (mô hình Smartos) và tạo nguồn cung độc quyền.',
      HD.accent),
  _Rec('6–12 THÁNG · BET', 'Gói trọn gói & mở rộng tỉnh',
      'Sản phẩm "thuê → thi công → nội thất" trọn gói (tận dụng mảng thi công độc quyền) + phủ tỉnh lẻ nơi đối thủ mỏng.',
      HD.accent),
];
