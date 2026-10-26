import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';

/// Nút "!" tròn nhỏ ở cuối một dòng chú giải — mở lời giải thích ngắn.
///
/// Ba cách dùng, cùng một nội dung:
///   • Rê chuột vào  → hiện, rời chuột → mất  (máy tính)
///   • Chạm vào      → GHIM lại, đọc bao lâu tuỳ ý  (điện thoại, và cả chuột)
///   • Chạm ra ngoài → mất
///
/// Không dùng [Tooltip] của Material vì nó chỉ hiện khi rê chuột hoặc nhấn giữ,
/// tự tắt sau vài giây, và không có cách bấm-để-giữ — đọc một câu dài sẽ hụt.
class LegendHelpDot extends StatefulWidget {
  const LegendHelpDot({
    required this.text,
    required this.semanticLabel,
    super.key,
  });

  final String text;

  /// Nhãn cho trình đọc màn hình — người khiếm thị không "rê chuột" được.
  final String semanticLabel;

  @override
  State<LegendHelpDot> createState() => _LegendHelpDotState();
}

class _LegendHelpDotState extends State<LegendHelpDot> {
  final _link = LayerLink();
  final _cong = OverlayPortalController();

  /// Đang giữ vì người dùng CHẠM (khác với chỉ đang rê chuột qua).
  bool _ghim = false;

  void _hien() => _cong.show();

  void _an() {
    _ghim = false;
    _cong.hide();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _cong,
        overlayChildBuilder: (_) => Stack(
          children: [
            // Lớp chắn trong suốt để "chạm ra ngoài là mất". CHỈ dựng khi đang
            // ghim bằng cú chạm — nếu dựng cả lúc chỉ rê chuột, nó sẽ nằm đè
            // lên chính cái chấm và làm chuột "rời khỏi" ngay lập tức.
            if (_ghim)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(_an),
                ),
              ),
            CompositedTransformFollower(
              link: _link,
              // Mở sang TRÁI: chú giải nằm sát mép phải màn hình, mở sang phải
              // sẽ lòi ra ngoài.
              targetAnchor: Alignment.centerLeft,
              followerAnchor: Alignment.centerRight,
              offset: const Offset(-8, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: HD.ink,
                    borderRadius: BorderRadius.circular(HD.r8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.text,
                    style: HD.caption().copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: Semantics(
          label: widget.semanticLabel,
          button: true,
          child: MouseRegion(
            cursor: SystemMouseCursors.help,
            onEnter: (_) => _hien(),
            onExit: (_) {
              // Chạm để ghim rồi thì rê chuột ra không được tắt — người dùng
              // đang cố ý giữ nó lại để đọc.
              if (!_ghim) _cong.hide();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _ghim = !_ghim;
                _ghim ? _hien() : _cong.hide();
              }),
              child: Padding(
                // Vùng chạm rộng hơn chấm để ngón tay bấm trúng.
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: HD.inkMuted, width: 1.2),
                  ),
                  child: Text(
                    '!',
                    style: HD.caption().copyWith(
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.bold,
                      color: HD.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
