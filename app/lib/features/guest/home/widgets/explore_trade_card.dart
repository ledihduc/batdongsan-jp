import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/browse/trade_hub_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Thẻ dẫn sang màn "Mua bán · Cho thuê", chèn giữa dải Reel và feed tin đăng.
///
/// Vì sao cần: feed ở trang này cuộn vô tận theo thứ tự mới nhất — hợp để LƯỚT,
/// không hợp để TÌM. Người đã biết mình cần gì phải mò ra tab Trang chủ rồi mới
/// thấy lối vào màn tổng hợp có bộ lọc. Thẻ này đặt lối đó ngay trên đường
/// cuộn, và tách sẵn ba ngả hay dùng nhất thay vì đổ hết vào một nút.
class ExploreTradeCard extends StatelessWidget {
  const ExploreTradeCard({super.key});

  void _moTrade(BuildContext context, TradeSide ben) {
    // Navigator.push chứ không context.go: màn tổng hợp là sub-flow trong tab,
    // không có URL riêng (luật điều hướng ở CLAUDE.md).
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TradeHubScreen(initialSide: ben)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(HD.s12, 0, HD.s12, HD.s8),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HD.r12),
        child: Stack(
          children: [
            // Minh hoạ nằm DƯỚI chữ và mờ đi: nó là nền trang trí, chữ đè lên
            // vẫn phải đọc được trên máy màn hình hẹp khi hai bên chồng nhau.
            Positioned(
              right: -8,
              top: 6,
              bottom: 0,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/branding/explore_trade.png',
                  fit: BoxFit.contain,
                  // Thiếu tệp thì bỏ trống, không để cả thẻ vỡ vì một ảnh nền.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(HD.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tieuDe(l),
                  const SizedBox(height: 6),
                  Text(
                    l.exploreTradeSubtitle,
                    style: HD.caption().copyWith(height: 1.35),
                  ),
                  const SizedBox(height: HD.s16),
                  _hangNut(context, l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tieuDe(AppLocalizations l) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: l.exploreTradeTitlePlain, style: HD.bodyBold(size: 19)),
        TextSpan(
          text: l.exploreTradeTitleAccent,
          style: HD.bodyBold(size: 19).copyWith(color: HD.accent),
        ),
      ],
    ),
  );

  /// Ba lối tắt + nút chính.
  ///
  /// Màn rộng: một hàng, nút chính ghim mép phải — đúng như thiết kế.
  /// Màn điện thoại: nút chính XUỐNG DÒNG và trải hết bề ngang.
  ///
  /// Vì sao phải tách hai: lòng thẻ trên máy 360dp chỉ còn ~304px, mà riêng ba
  /// lối tắt đã ~260px và nút chính ~140px. Ép chung một hàng thì nút chính
  /// đè mất lối tắt cuối ("Bản đồ" bị cắt còn chữ "B"). Không có cách xếp nào
  /// nhét vừa — nên chỗ hẹp phải xuống dòng, không phải bóp nhỏ tiếp.
  Widget _hangNut(BuildContext context, AppLocalizations l) {
    final tat = [
      _nutPhu(
        Icons.home_work_outlined,
        l.tradeTabBuy,
        () => _moTrade(context, TradeSide.mua),
      ),
      _nutPhu(
        Icons.groups_outlined,
        l.tradeTabSell,
        () => _moTrade(context, TradeSide.ban),
      ),
      _nutPhu(Icons.place_outlined, l.tradeOpenMap, () => context.push('/map')),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // 430 = ba lối tắt (~260) + nút chính (~140) + khoảng thở. Dưới mức
        // này thì dù xếp kiểu gì cũng thiếu chỗ.
        final duRong = c.maxWidth >= 430;
        if (duRong) {
          return Row(
            children: [
              for (final t in tat) ...[t, const SizedBox(width: 6)],
              const Spacer(),
              _nutChinh(context, l),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final t in tat) ...[
                  Expanded(child: t),
                  if (t != tat.last) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: HD.s12),
            _nutChinh(context, l),
          ],
        );
      },
    );
  }

  Widget _nutPhu(IconData icon, String chu, VoidCallback cham) => Material(
    color: HD.paper,
    borderRadius: BorderRadius.circular(HD.r8),
    child: InkWell(
      borderRadius: BorderRadius.circular(HD.r8),
      onTap: cham,
      child: Container(
        height: 34,
        // Nới rộng thêm chút nào ở đây là ba lối tắt hết vừa một hàng cùng nút
        // chính trên máy phổ thông — chúng bị đẩy vào vùng cuộn khuất.
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HD.r8),
          border: Border.all(color: HD.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: HD.accent),
            const SizedBox(width: 5),
            // Chữ cùng màu icon: ba lối tắt là hành động, không phải nhãn mô
            // tả — để chữ đen thì chúng đọc ra như phần tiếp của phụ đề.
            Text(chu, style: HD.body(size: 12, color: HD.accent)),
          ],
        ),
      ),
    ),
  );

  Widget _nutChinh(BuildContext context, AppLocalizations l) => FilledButton(
    onPressed: () => _moTrade(context, TradeSide.mua),
    style: FilledButton.styleFrom(
      backgroundColor: HD.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // Cao hơn ba lối tắt (34) một nhịp: nó là hành động CHÍNH của thẻ, bằng
      // nhau thì bốn nút đọc ra như bốn thứ ngang hàng.
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.exploreTradeCta,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right, size: 16),
      ],
    ),
  );
}
