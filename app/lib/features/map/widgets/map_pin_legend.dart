import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/map/utils/pin_kind.dart';
import 'package:house_booking/features/map/widgets/legend_help_dot.dart';
import 'package:house_booking/features/map/widgets/map_search_bar.dart'
    show kMapTopBarHeight;
import 'package:house_booking/l10n/app_localizations.dart';

/// Chú giải MÀU PIN — kiêm luôn BỘ LỌC nhanh theo loại tin.
///
/// Bốn màu pin vô nghĩa nếu không nói cho người dùng biết màu nào là gì. Và khi
/// đã liệt kê đủ bốn loại ngay đó thì ô tích là chỗ tự nhiên nhất để bật/tắt
/// từng loại — không bắt người dùng mở màn Bộ lọc chỉ để giấu tin bán đi.
///
/// Mặc định TÍCH HẾT: bản đồ phải hiện đủ mọi thứ cho tới khi người dùng chủ
/// động bỏ bớt.
class MapPinLegend extends StatefulWidget {
  const MapPinLegend({
    required this.enabled,
    required this.onToggle,
    super.key,
  });

  /// Các loại đang được hiển thị (xem [PinKind]).
  final Set<String> enabled;

  /// Bấm vào một dòng → đảo trạng thái loại đó.
  final ValueChanged<String> onToggle;

  @override
  State<MapPinLegend> createState() => _MapPinLegendState();
}

class _MapPinLegendState extends State<MapPinLegend> {
  /// MỞ SẴN khi vào bản đồ: bốn màu pin chỉ có nghĩa khi người dùng đọc được
  /// chú giải, mà thu gọn thì phải bấm mới thấy — hầu hết sẽ không bấm. Ai thấy
  /// vướng vẫn thu lại được.
  bool _mo = true;

  Color _mau(String kind) => switch (kind) {
    PinKind.stayShort => HD.pinStayShort,
    PinKind.business => HD.pinBusiness,
    PinKind.sale => HD.pinSale,
    _ => HD.pinStayLong,
  };

  String _nhan(String kind, AppLocalizations l) => switch (kind) {
    PinKind.stayShort => l.mapLegendStayShort,
    PinKind.business => l.mapLegendBusiness,
    PinKind.sale => l.mapLegendSale,
    _ => l.mapLegendStayLong,
  };

  String _moTa(String kind, AppLocalizations l) => switch (kind) {
    PinKind.stayShort => l.mapLegendStayShortDesc,
    PinKind.business => l.mapLegendBusinessDesc,
    PinKind.sale => l.mapLegendSaleDesc,
    _ => l.mapLegendStayLongDesc,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: HD.paperRaised.withValues(alpha: 0.94),
      // Bo tròn bằng ô tìm kiếm bên cạnh để hai khối đọc ra là một bộ.
      borderRadius: BorderRadius.circular(kMapTopBarHeight / 2),
      elevation: 2,
      child: ConstrainedBox(
        // Thu gọn thì cao ĐÚNG BẰNG ô tìm kiếm; mở ra thì dài xuống dưới.
        constraints: const BoxConstraints(minHeight: kMapTopBarHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Center(widthFactor: 1, child: _mo ? _dayDu(l) : _gon(l)),
        ),
      ),
    );
  }

  Widget _tieuDe(AppLocalizations l, {required bool mo}) {
    return InkWell(
      onTap: () => setState(() => _mo = !_mo),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.mapLegendTitle,
            style: mo ? HD.bodyBold(size: 12) : HD.caption(),
          ),
          const SizedBox(width: 4),
          Icon(
            mo ? Icons.expand_less : Icons.expand_more,
            size: 14,
            color: HD.inkMuted,
          ),
        ],
      ),
    );
  }

  Widget _gon(AppLocalizations l) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dạng gọn chỉ hiện chấm của các loại ĐANG BẬT — nhìn là biết mình đang
        // lọc, không phải mở ra mới nhớ.
        for (final k in PinKind.all)
          if (widget.enabled.contains(k)) ...[
            _cham(_mau(k)),
            const SizedBox(width: 4),
          ],
        const SizedBox(width: 2),
        _tieuDe(l, mo: false),
      ],
    );
  }

  Widget _dayDu(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _tieuDe(l, mo: true),
        const SizedBox(height: HD.s8),
        for (final k in PinKind.all) _dong(k, _nhan(k, l), _moTa(k, l), l),
      ],
    );
  }

  Widget _dong(String kind, String label, String moTa, AppLocalizations l) {
    final bat = widget.enabled.contains(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chỉ phần ô tích + nhãn mới bật/tắt loại. Nút "!" nằm NGOÀI vùng
          // chạm đó — bấm để đọc giải thích không được vô tình ẩn mất pin.
          //
          // `Flexible` chứ KHÔNG phải `Expanded`: ở bản đồ nhà, chú giải là con
          // KHÔNG có flex của một Row, nên nó nhận ràng buộc bề rộng VÔ HẠN.
          // `Expanded` (fit tight) trong ngữ cảnh đó là mâu thuẫn — RenderFlex
          // ném "children have non-zero flex but incoming width constraints are
          // unbounded" ngay lượt dựng đầu, vì `_mo` mặc định là true nên bảng
          // luôn mở sẵn. Bản release nuốt assertion nên lỗi này đi lọt.
          Flexible(
            child: InkWell(
              onTap: () => widget.onToggle(kind),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ô tích tự vẽ thay vì Checkbox: Checkbox của Material kéo theo
                  // vùng chạm 48dp cố định, làm chú giải cao gấp đôi bản đồ cần.
                  Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: bat ? _mau(kind) : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: bat ? _mau(kind) : HD.inkMuted,
                        width: 1.5,
                      ),
                    ),
                    child: bat
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _cham(_mau(kind)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: HD.caption().copyWith(
                      color: bat ? null : HD.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          LegendHelpDot(
            text: moTa,
            semanticLabel: '${l.mapLegendHelp}: $label',
          ),
        ],
      ),
    );
  }

  Widget _cham(Color color) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
  );
}
