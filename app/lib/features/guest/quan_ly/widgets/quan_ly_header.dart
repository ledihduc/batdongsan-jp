import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';

/// Đầu trang "Quản lý": lời chào · logo + chữ "Quản lý" · chuông, trên nền minh
/// hoạ thành phố + gợn sóng — cùng công thức với đầu trang chủ
/// (`ServiceHubScreen._Header`) để hai màn đọc ra là một bộ.
///
/// Công tắc hai góc ([ChonGocQuanLy]) VẮT NGANG mép dưới ảnh như ảnh mẫu: nửa
/// trên đè lên minh hoạ, nửa dưới nằm trên nền trang.
///
/// BẪY đã dính: đặt công tắc `bottom: -nửa` cho nó thò RA NGOÀI khung Stack.
/// `Clip.none` chỉ cho VẼ ra ngoài — Flutter không hit-test phần nằm ngoài khung
/// cha, nên nửa dưới công tắc bấm không ăn (test bấm vào giữa công tắc là trượt).
/// Nay Stack tự chứa trọn công tắc: ảnh nền chỉ phủ tới [nuaCongTac] trên đáy,
/// công tắc nằm ở đáy Stack — cả hai nửa đều trong khung, đều bấm được.
class QuanLyHeader extends StatelessWidget {
  const QuanLyHeader({
    super.key,
    required this.goc,
    required this.onDoiGoc,
    this.ten,
    this.anhDaiDien,
    this.soChuaDoc = 0,
    this.onThongBao,
  });

  final GocQuanLy goc;
  final ValueChanged<GocQuanLy> onDoiGoc;
  final String? ten;
  final String? anhDaiDien;
  final int soChuaDoc;
  final VoidCallback? onThongBao;

  static const String _anhNen = 'assets/branding/hero_bg.jpg';

  /// Chiều cao công tắc, cố định — cần biết trước vì nó tràn nửa xuống dưới.
  static const double _caoCongTac = 52;

  /// Phần công tắc nằm DƯỚI mép ảnh nền (đã tính trong chiều cao của header).
  static const double nuaCongTac = _caoCongTac / 2;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: nuaCongTac,
          child: Image.asset(
            _anhNen,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            // Thiếu tệp ảnh thì rơi về nền đỏ trơn — không vỡ màn vì một ảnh.
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(gradient: HD.accentGradient),
            ),
          ),
        ),
        // Phủ đỏ ĐẬM DẦN LÊN TRÊN: vùng trên của ảnh nền quá sáng để chữ trắng
        // đọc được (xem lý do đầy đủ ở đầu trang chủ). Phần dưới để lộ minh hoạ.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: nuaCongTac,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HD.accent,
                  HD.accent.withValues(alpha: 0.85),
                  HD.accent.withValues(alpha: 0.0),
                ],
                stops: const [0, 0.42, 0.8],
              ),
            ),
          ),
        ),
        // Mép dưới ảnh (gợn sóng trắng) hoà dần vào màu nền trang. Không có lớp
        // này thì chỗ ảnh dừng lại thành một bậc trắng→xám cứng thò ra hai bên
        // công tắc — thấy rõ trên ảnh chụp thật 18/09/2026.
        Positioned(
          left: 0,
          right: 0,
          bottom: nuaCongTac,
          height: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [HD.paper.withValues(alpha: 0), HD.paper],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            // Đáy chừa đúng chiều cao công tắc: đây là thứ làm Stack đủ cao để
            // chứa trọn nó (xem BẪY ở đầu lớp).
            padding: const EdgeInsets.fromLTRB(
              HD.s16,
              HD.s8,
              HD.s8,
              _caoCongTac,
            ),
            child: ConstrainedBox(
              // Chừa đáy cho ngôi nhà + gợn sóng trắng của ảnh nền hiện ra —
              // co theo nội dung thì công tắc đè mất phần minh hoạ.
              constraints: const BoxConstraints(minHeight: 150),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _loiChao()),
                  _giua(),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _chuong(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: HD.s16,
          right: HD.s16,
          bottom: 0,
          height: _caoCongTac,
          child: ChonGocQuanLy(goc: goc, onDoi: onDoiGoc),
        ),
      ],
    );
  }

  Widget _loiChao() {
    final coAnh = anhDaiDien != null && anhDaiDien!.isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          backgroundImage: coAnh
              ? CachedNetworkImageProvider(
                  anhDaiDien!.startsWith('http')
                      ? anhDaiDien!
                      : '${ApiConfig.baseUrl}$anhDaiDien',
                )
              : null,
          child: coAnh ? null : const Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: HD.s8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Xin chào,',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 12,
                ),
              ),
              Text(
                (ten == null || ten!.trim().isEmpty) ? 'Khách' : ten!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _giua() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HD.r8),
        ),
        child: const BrandLogo.mark(size: 28),
      ),
      const SizedBox(height: 2),
      RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: Brand.logoPart1,
              style: HD.masthead(size: 15, color: Colors.white),
            ),
            TextSpan(
              text: Brand.logoPart2,
              style: HD.mastheadItalic(size: 15, color: Colors.white),
            ),
          ],
        ),
      ),
      const SizedBox(height: HD.s4),
      const Text(
        'Quản lý',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
    ],
  );

  Widget _chuong() => IconButton(
    key: const Key('quan-ly-thong-bao'),
    tooltip: 'Thông báo',
    onPressed: onThongBao,
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none, color: Colors.white, size: 28),
        // Chấm CHỈ khi có thông báo chưa đọc — chấm cố định là nói dối. Màu hổ
        // phách chứ không đỏ: đỏ trên đầu trang đỏ thì chỉ còn thấy viền trắng,
        // trông như một vòng rỗng (ảnh chụp thật 18/09/2026).
        if (soChuaDoc > 0)
          Positioned(
            right: 2,
            top: 1,
            child: Container(
              key: const Key('quan-ly-cham-chua-doc'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: HD.accentAmber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Đầu trang nghiệp vụ riêng cho Sale.
///
/// Sale theo dõi khách và lịch hẹn, không vận hành tài sản hay quyết định hợp
/// đồng. Vì vậy màn này không có công tắc "Của tôi | Khách thuê" và cũng không
/// dùng đầu trang quản lý nhà của chủ nhà.
class SaleQuanLyHeader extends StatelessWidget {
  const SaleQuanLyHeader({
    super.key,
    this.ten,
    this.anhDaiDien,
    this.soChuaDoc = 0,
    this.onThongBao,
  });

  final String? ten;
  final String? anhDaiDien;
  final int soChuaDoc;
  final VoidCallback? onThongBao;

  @override
  Widget build(BuildContext context) {
    final coAnh = anhDaiDien != null && anhDaiDien!.isNotEmpty;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HD.paperRaised,
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s8, HD.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: HD.accentTint,
                    backgroundImage: coAnh
                        ? CachedNetworkImageProvider(
                            anhDaiDien!.startsWith('http')
                                ? anhDaiDien!
                                : '${ApiConfig.baseUrl}$anhDaiDien',
                          )
                        : null,
                    child: coAnh
                        ? null
                        : const Icon(Icons.person_outline, color: HD.accent),
                  ),
                  const SizedBox(width: HD.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (ten == null || ten!.trim().isEmpty) ? 'Sale' : ten!,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 16),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: HD.accentTint,
                                borderRadius: BorderRadius.circular(HD.rPill),
                              ),
                              child: const Text(
                                'SALE',
                                style: TextStyle(
                                  color: HD.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: HD.s8),
                            Expanded(
                              child: Text(
                                'Chăm sóc và theo dõi khách hàng',
                                overflow: TextOverflow.ellipsis,
                                style: HD.body(size: 12, color: HD.inkMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('sale-quan-ly-thong-bao'),
                    tooltip: 'Thông báo',
                    onPressed: onThongBao,
                    icon: Badge(
                      isLabelVisible: soChuaDoc > 0,
                      label: Text(soChuaDoc > 99 ? '99+' : '$soChuaDoc'),
                      child: const Icon(Icons.notifications_none, size: 27),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HD.s20),
              const Text(
                'Công việc khách hàng',
                style: TextStyle(
                  color: HD.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: HD.s4),
              Text(
                'Lịch xem, yêu cầu đổi giờ và các khách đang cần bạn hỗ trợ.',
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Công tắc "Của tôi" | "Khách thuê". Bên đang chọn là viên đỏ chữ trắng.
class ChonGocQuanLy extends StatelessWidget {
  const ChonGocQuanLy({super.key, required this.goc, required this.onDoi});

  final GocQuanLy goc;
  final ValueChanged<GocQuanLy> onDoi;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12 + 4),
      boxShadow: [
        BoxShadow(
          color: HD.ink.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        for (final g in GocQuanLy.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: g == goc,
              child: InkWell(
                key: Key('goc-${g.ma}'),
                borderRadius: BorderRadius.circular(HD.r12),
                onTap: g == goc ? null : () => onDoi(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: g == goc ? HD.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(HD.r12),
                  ),
                  child: Text(
                    g.nhan,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: g == goc ? Colors.white : HD.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
