import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Editorial Cockpit — global design tokens.
///
/// One palette, one type scale, one spacing grid for all 76 screens.
/// Vietnamese broadsheet typography meets professional property terminal.
///
/// Naming: short class `HD` kept for backward compat with ~80 existing
/// call sites that already adopted these tokens scoped to host dashboard.
/// Now promoted to the single source of truth for the whole app.
class HD {
  HD._();

  // ── Palette — hệ màu kiểu Facebook (đổi 19/07/2026 theo yêu cầu) ──────────
  //
  // LỊCH SỬ QUAN TRỌNG: trước đây app dùng đỏ #DC2626 làm màu chủ đạo, và đã
  // có một đợt "tiết chế đỏ" (2026-07-12) để đỏ không tràn nền. Nay đổi sang
  // xanh Facebook theo yêu cầu rõ ràng của chủ dự án.
  //
  // TÊN TOKEN GIỮ NGUYÊN (paper/ink/accent…) nên ~80 nơi gọi tự đổi màu theo,
  // không phải sửa từng màn. Muốn quay lại đỏ thì chỉ cần đổi các hằng trong
  // khối này — xem giá trị cũ ghi ngay cạnh mỗi dòng.

  /// Nền trang — xám lạnh #F0F2F5 đúng nền feed Facebook. Card trắng nổi lên
  /// trên nền này chính là thứ tạo cảm giác "giống FB" nhiều nhất, hơn cả màu
  /// nút. (Cũ: #FFF5F5 hồng rất nhạt.)
  static const Color paper = Color(0xFFF0F2F5);

  /// Mặt card — trắng tinh, nổi trên [paper].
  static const Color paperRaised = Color(0xFFFFFFFF);

  /// Mặt chìm — ô nhập, nút phụ, vùng lồng nhau. #E4E6EB là xám nút phụ của FB.
  /// (Cũ: #FCE9E9.)
  static const Color paperSunken = Color(0xFFE4E6EB);

  /// Chữ chính — #050505, gần đen tuyệt đối như FB. (Cũ: navy #0B1C30.)
  static const Color ink = Color(0xFF050505);

  /// Chữ phụ — tiêu đề phụ, nội dung đỡ.
  static const Color inkSoft = Color(0xFF3A3B3C);

  /// Chữ mờ — chú thích, thời gian đăng, nhãn nhỏ. #65676B là màu metadata của
  /// FB, đạt 4.6:1 trên nền trắng (WCAG AA cho chữ thường).
  ///
  /// ⚠️  KHÔNG ghép [inkMuted] với [paperSunken] — tương phản tụt dưới chuẩn.
  ///    Trên nền chìm hãy dùng [inkSoft].
  static const Color inkMuted = Color(0xFF65676B);

  /// Đường kẻ 1px — #CED0D4, đúng màu divider của FB. (Cũ: #F2DADA hồng.)
  static const Color hairline = Color(0xFFCED0D4);

  /// Đường kẻ đậm — chia mục, viền modal.
  static const Color hairlineStrong = Color(0xFFBEC3C9);

  // ── Accent — ĐỎ thương hiệu ───────────────────────────────────────────────
  //
  // ĐỔI 24/08/2026 theo yêu cầu chủ dự án: màu chủ đạo toàn app quay lại ĐỎ
  // (#E31B23, lấy từ bản thiết kế màn tổng hợp dịch vụ). Tên token giữ nguyên
  // nên ~80 call site tự đổi theo. Giá trị xanh FB cũ ghi cạnh mỗi dòng.
  /// Màu chủ đạo — #E31B23. Nút chính, liên kết, biểu tượng đang chọn. Đạt
  /// ~4.4:1 với chữ trắng → đủ cho chữ đậm/≥18px; nút nhỏ chữ trắng dùng
  /// [accentDeep]. (Cũ: xanh #1877F2.)
  static const Color accent = Color(0xFFE31B23);

  /// Đỏ đậm hơn — trạng thái nhấn/hover, và chữ trắng trên nền nhỏ (6.6:1).
  /// (Cũ: #0B5FCC.)
  static const Color accentDeep = Color(0xFFB01218);

  /// Đỏ nhạt — nền vùng nhấn mạnh, banner thông báo. (Cũ: #D8E6FB.)
  static const Color accentSoft = Color(0xFFFBDCDD);

  /// Đỏ nhạt nhất — hàng đang chọn, quầng focus. (Cũ: #EBF2FE.)
  static const Color accentTint = Color(0xFFFDF0F1);

  /// Vàng hổ phách phụ trợ — cặp tương phản với đỏ trong bản thiết kế hub
  /// (nút "Cần thuê", chuông thông báo). Alias của [warning] để chỉ có MỘT
  /// nguồn vàng trong hệ.
  static const Color accentAmber = warning;

  /// Gradient nền — gần như phẳng, chuyển từ nền feed sang trắng. FB không
  /// dùng gradient nền; giữ ở đây để các màn cũ gọi [appGradient] không vỡ,
  /// nhưng làm nó gần như vô hình.
  static const LinearGradient appGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0F2F5), Color(0xFFF7F8FA), Color(0xFFFFFFFF)],
    stops: [0.0, 0.38, 1.0],
  );

  /// Gradient đỏ cho header/hero. (Cũ: xanh #3B8BF5→#0B5FCC.)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4B52), Color(0xFFE31B23), Color(0xFFB01218)],
  );

  // ── Status — earthy, not slack ───────────────────────────────────────────
  /// Positive / success — earthy green.
  static const Color positive = Color(0xFF31A24C);  // xanh lá FB

  /// Positive tint background.
  static const Color positiveTint = Color(0xFFE3F1E7);

  // ── Nhận diện THẾ GIỚI ────────────────────────────────────────────────────
  // App có hai mảng nghiệp vụ tách bạch: Bất động sản và Thi công. Trước đây
  // cả hai dùng chung y hệt một bảng màu xanh nên người dùng mở app không biết
  // mình đang ở nửa nào — nội dung khác nhau nhưng "vỏ" giống hệt.
  //
  // Xanh [accent] vẫn là màu THƯƠNG HIỆU dùng chung; Thi công có thêm một màu
  // nhấn riêng dùng ở những chỗ báo "bạn đang ở đâu": tab đang chọn, nút đăng,
  // nhãn thế giới trên thanh tiêu đề, đầu menu bên.

  // ĐỒNG BỘ MÀU (theo yêu cầu chủ dự án): thế giới Xây dựng DÙNG CHUNG xanh FB
  // với BĐS — bỏ màu nâu riêng để toàn app một tông. Giữ TÊN token
  // `construction*` để ~25 call site không phải sửa; phân biệt hai thế giới nay
  // dựa vào ICON + NHÃN, không phải màu. (Cũ: cam đất #B45309 — xem git nếu muốn
  // khôi phục.)
  static const Color construction = accent;
  static const Color constructionDeep = accentDeep;
  static const Color constructionTint = accentTint;

  /// Màu nhấn theo thế giới. [laThiCong] = đang ở nửa Thi công.
  /// Gom vào một hàm để mọi nơi lấy cùng một nguồn — tránh chỗ nhớ đổi chỗ quên.
  static Color worldAccent(bool laThiCong) => laThiCong ? construction : accent;

  static Color worldAccentDeep(bool laThiCong) =>
      laThiCong ? constructionDeep : accentDeep;

  static Color worldTint(bool laThiCong) =>
      laThiCong ? constructionTint : accentTint;

  /// Warning — burnt amber. Aligned with terracotta family.
  /// Darkened from #B87333 (3.76:1) → #955A22 (5.53:1 on white text) for WCAG AA.
  static const Color warning = Color(0xFFF7B928);  // vàng FB

  /// Warning tint background.
  static const Color warningTint = Color(0xFFFDF3DC);

  /// Negative / risk — quá hạn, hành động phá huỷ (xoá, huỷ, chặn).
  ///
  /// ĐỔI 24/08/2026 sau khi màu thương hiệu thành ĐỎ: giá trị cũ #E41E3F chỉ
  /// lệch [accent] #E31B23 đúng 2 đơn vị ở kênh G — mắt thường KHÔNG phân biệt
  /// nổi, nên nút "Xoá tài khoản" trông y hệt nút hành động chính. Nay đẩy sang
  /// mận thẫm: khác cả SẮC (magenta hơn) lẫn ĐỘ SÁNG, vẫn đọc ra "nguy hiểm",
  /// và tương phản 8.6:1 với chữ trắng.
  ///
  /// ⚠️ Nguy hiểm ≠ thương hiệu: đừng gán [accent] cho nút phá huỷ để "cho đồng
  ///    bộ" — đó chính là lỗi vừa sửa.
  static const Color negative = Color(0xFF9F1239);

  /// Negative tint background.
  static const Color negativeTint = Color(0xFFFCE4EC);

  /// Neutral chip — for "draft", "pending review" states.
  static const Color neutral = Color(0xFF65676B);
  static const Color neutralTint = Color(0xFFE4E6EB);

  /// Danger tint (alias) — semantic name for negativeTint when the visual
  /// role is "destructive action background" rather than "past-due status".
  static const Color dangerTint = negativeTint;

  // ── Pin bản đồ theo NHÓM BĐS (chốt 24/08/2026) ───────────────────────────
  //
  // Bốn màu, đọc được ý nghĩa ngay trên bản đồ:
  //   xanh lá   = cho thuê · lưu trú DÀI HẠN   (stay_long)
  //   vàng hổ phách = cho thuê · lưu trú NGẮN HẠN (stay_short)
  //   xanh dương= cho thuê · KINH DOANH         (business)
  //   đỏ đậm    = tin BÁN (mọi nhóm) — 45% tin đang là tin bán nên nó phải là
  //               một màu riêng, không lẫn vào 3 màu trên
  // Đỏ [accent] (#E31B23) KHÔNG dùng để phân loại — dành riêng cho pin ĐANG
  // CHỌN; [pinSale] cố ý dùng tông đỏ ĐẬM hơn (#C62828) để hai thứ không lẫn.
  //
  // Vàng trong bảng gốc (#FFD400) bị đẩy tối lại thành #C77C00 để chữ trắng
  // trên pin giá còn đạt tương phản (~4.6:1); giữ nguyên sẽ không đọc nổi.
  static const Color pinStayLong = Color(0xFF2E7D32);
  static const Color pinStayShort = Color(0xFFC77C00);
  static const Color pinBusiness = Color(0xFF2C6BD6);
  static const Color pinSale = Color(0xFFC62828);

  /// Màu pin cho một tin. [isSale] THẮNG nhóm — người mua/người thuê là hai
  /// nhu cầu tách bạch, nhìn màu phải biết ngay tin này bán hay cho thuê.
  /// Nhóm lạ/rỗng → rơi về [pinStayLong] (đa số tin là nhà ở dài hạn).
  static Color pinColorFor(String? groupKey, {required bool isSale}) {
    if (isSale) return pinSale;
    switch (groupKey) {
      case 'stay_short':
        return pinStayShort;
      case 'business':
        return pinBusiness;
      default:
        return pinStayLong;
    }
  }

  /// Icon theo nhóm — pin tin BÁN dùng chung một màu đỏ nên phải nhờ icon để
  /// vẫn phân biệt được loại hình.
  static IconData pinIconFor(String? groupKey) {
    switch (groupKey) {
      case 'stay_short':
        return Icons.vpn_key;
      case 'business':
        return Icons.storefront;
      default:
        return Icons.home;
    }
  }

  // ── Bảng màu ICON DỊCH VỤ ────────────────────────────────────────────────
  //
  // Vì sao lệch khỏi luật "một màu thương hiệu": danh mục có 20 dịch vụ xếp
  // thành lưới. Tô đỏ hết thì 20 ô trông y hệt nhau, mắt phải ĐỌC từng nhãn
  // mới tìm được thứ cần — màu là thứ duy nhất giúp nhận ra "cái xanh nước là
  // sửa nước" sau vài lần dùng.
  //
  // Đỏ thương hiệu vẫn giữ vai trò riêng: hành động chính, tab đang chọn, giá
  // tiền. Ở đây màu chỉ để PHÂN LOẠI, không phải để nhấn mạnh.
  //
  // Mọi màu đều đạt tương phản ≥4.5:1 trên nền trắng, dùng cho cả icon lẫn
  // chữ nếu cần.
  static const Color svcAmber = Color(0xFFD97706);
  static const Color svcBlue = Color(0xFF0284C7);
  static const Color svcTeal = Color(0xFF0D9488);
  static const Color svcCyan = Color(0xFF0891B2);
  static const Color svcIndigo = Color(0xFF4F46E5);
  static const Color svcGreen = Color(0xFF16A34A);
  static const Color svcOrange = Color(0xFFEA580C);
  static const Color svcLime = Color(0xFF65A30D);
  static const Color svcViolet = Color(0xFF7C3AED);
  static const Color svcPink = Color(0xFFDB2777);
  static const Color svcBrown = Color(0xFF92400E);
  static const Color svcPurple = Color(0xFF9333EA);
  static const Color svcRose = Color(0xFFE11D48);
  static const Color svcEmerald = Color(0xFF059669);
  static const Color svcFuchsia = Color(0xFFC026D3);

  /// Nền của ô icon: chính màu đó pha rất nhạt. Dùng alpha thay vì khai báo 15
  /// màu nhạt nữa — sửa một màu là nền tự theo, không bao giờ lệch nhau.
  static Color svcTint(Color c) => c.withValues(alpha: 0.12);

  // ── Calendar heatmap palette (occupancy, homestay calendar) ──────────────
  // Grouped intentionally so the same visual meaning uses the same token.
  // Dark mode variants live in [HDDark] once introduced.

  /// Empty cell — nothing scheduled. Matches [paperSunken] for density.
  static const Color calendarVacant = Color(0xFFE4E6EB);

  /// Booked (pending payment) — soft accent tone.
  static const Color calendarBooked = Color(0xFFD8E6FB);

  /// Paid / confirmed — earthy green (aligned with [positive]).
  static const Color calendarPaid = Color(0xFFE3F1E7);

  /// Overdue — negative tint (aligned with [negative]).
  static const Color calendarOverdue = Color(0xFFFCE4E8);

  /// Blocked / unavailable — neutral tint.
  static const Color calendarBlocked = Color(0xFFE4E6EB);

  // ── Chart palette (analytics home, revenue trend, source management) ─────
  /// Current-period series — brand accent for primary line.
  static const Color chartCurrent = accent;

  /// Previous-period comparison series — muted ink.
  static const Color chartPrevious = Color(0xFF8A8D91);

  /// Rolling average / benchmark series — warm amber.
  static const Color chartAverage = warning;

  /// Positive delta indicator (row backgrounds, sparkline fills).
  static const Color chartPositive = positive;

  /// Negative delta indicator (row backgrounds, sparkline fills).
  static const Color chartNegative = negative;

  // ── Compat aliases (will be removed in phase 12 if unused) ───────────────
  /// Legacy alias for masthead red. Same value as [accent] now.
  /// @Deprecated kept so old code compiles; remove in cleanup phase.
  static const Color mastheadRed = accent;

  // ── Typography ───────────────────────────────────────────────────────────
  // MỘT font cho TOÀN HỆ THỐNG: **Hanken Grotesk** (24/08/2026, theo bản thiết
  // kế của chủ dự án). Trước đây trộn 3 họ: Instrument Serif (masthead/số lớn),
  // Be Vietnam Pro (thân), JetBrains Mono (bảng số) — nay bỏ hết, phân cấp chỉ
  // dựa vào CỠ + ĐỘ ĐẬM, giống hệt bản HTML mẫu.
  //
  // Hanken Grotesk có đủ subset `vietnamese` (đã kiểm dấu ạ/ả/ề/ỗ/ữ/ơ/ă/Đ) nên
  // thay được Be Vietnam Pro mà không vỡ dấu tiếng Việt.
  // Font nạp từ `assets/google_fonts/` (main.dart tắt runtime fetching) — thêm
  // cỡ/đậm mới thì phải TẢI THÊM file .ttf đúng tên, không có là chữ biến mất.

  static TextStyle eyebrow({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        height: 1.2,
        color: color ?? inkMuted,
      );

  static TextStyle masthead({Color? color, double size = 36}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -0.5,
        color: color ?? ink,
      );

  static TextStyle mastheadItalic({Color? color, double size = 36}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        height: 1.05,
        letterSpacing: -0.5,
        color: color ?? ink,
      );

  static TextStyle sectionTitle({Color? color, double size = 22}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: color ?? ink,
      );

  static TextStyle body({Color? color, double size = 14}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color ?? inkSoft,
      );

  static TextStyle bodyBold({Color? color, double size = 14}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color ?? ink,
      );

  static TextStyle caption({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.2,
        color: color ?? inkMuted,
      );

  static TextStyle tabular({Color? color, double size = 13}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: -0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? ink,
      );

  static TextStyle bigNumeral({Color? color, double size = 48}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 0.95,
        letterSpacing: -1,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? ink,
      );

  static TextStyle buttonLabel({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.0,
        color: color ?? paperRaised,
      );

  static TextStyle navLabel({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.1,
        color: color ?? inkMuted,
      );

  // ── Density presets ──────────────────────────────────────────────────────
  //
  // Use one preset per screen family so vertical rhythm reads consistent:
  //  - Dense:     s8–s12   → tabular data, contract lists, invoice rows
  //  - Balanced:  s16–s20  → card grids, property list, dashboards
  //  - Spacious:  s24+     → onboarding, empty states, marketing surfaces

  // ── Spacing scale (4pt grid) ─────────────────────────────────────────────
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s56 = 56;
  static const double s64 = 64;
  static const double s80 = 80;

  // ── Edges ────────────────────────────────────────────────────────────────
  static const EdgeInsets gutterX = EdgeInsets.symmetric(horizontal: s20);
  static const EdgeInsets gutterXTight = EdgeInsets.symmetric(horizontal: s16);
  static const EdgeInsets gutterXLoose = EdgeInsets.symmetric(horizontal: s24);

  // ── Radius — mostly sharp, gently rounded for actions ────────────────────
  /// Sharp — default for surfaces, dividers, hairline elements.
  static const double r0 = 0;

  /// Small — chips, status pills.
  static const double r4 = 4;

  /// Medium — buttons, text fields.
  static const double r8 = 8;

  /// Large — cards, modal sheets.
  static const double r12 = 12;

  /// Pill — segmented controls, search bars.
  static const double rPill = 999;

  // ── Elevation — tinted inner shadow, no neon glow ────────────────────────
  /// Inner shadow for sunken fields (replaces Material's filled fill).
  static List<BoxShadow> get sunkenShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.06),
          offset: const Offset(0, 1),
          blurRadius: 2,
          spreadRadius: 0,
        ),
      ];

  /// Subtle drop for floating elements (FAB, bottom sheets).
  static List<BoxShadow> get floatShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.08),
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: ink.withValues(alpha: 0.04),
          offset: const Offset(0, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];

  /// Modal — heavier for dialogs over scrim.
  static List<BoxShadow> get modalShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.18),
          offset: const Offset(0, 12),
          blurRadius: 32,
          spreadRadius: 0,
        ),
      ];

  // ── Breakpoints ──────────────────────────────────────────────────────────
  /// Phone portrait — single column.
  static const double bpPhone = 600;

  /// Tablet portrait — 2 columns, side rail.
  static const double bpTablet = 900;

  /// Tablet landscape / desktop — 3 columns, persistent rail.
  static const double bpDesktop = 1200;

  // ── Motion ───────────────────────────────────────────────────────────────
  static const Duration motionInstant = Duration(milliseconds: 90);
  static const Duration motionShort = Duration(milliseconds: 220);
  static const Duration motionMedium = Duration(milliseconds: 420);
  static const Duration motionLong = Duration(milliseconds: 680);
  static const Curve curveExpressive = Curves.easeOutCubic;
  static const Curve curveStandard = Curves.easeInOutCubic;
}

/// Nền gradient đỏ→trắng cho trang. Bọc quanh [Scaffold] (đặt scaffold
/// `backgroundColor: Colors.transparent`) để nền trang sáng, nổi sắc đỏ.
class HDGradientBackground extends StatelessWidget {
  const HDGradientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: HD.appGradient),
      child: child,
    );
  }
}

/// Hairline divider — 1px warm rule. Use everywhere a Material [Divider]
/// would feel too heavy.
class HDHairline extends StatelessWidget {
  const HDHairline({
    super.key,
    this.indent = 0,
    this.color,
    this.strong = false,
  });

  final double indent;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: indent),
      color: color ?? (strong ? HD.hairlineStrong : HD.hairline),
    );
  }
}

/// Vertical hairline rule.
class HDVHairline extends StatelessWidget {
  const HDVHairline({super.key, this.height = 16, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      color: color ?? HD.hairline,
    );
  }
}
