import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/planning/utils/zone_color_resolver.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Một mục trong chú giải quy hoạch: màu + tên loại đất + số thửa.
class ZoneLegendEntry {
  const ZoneLegendEntry({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;
}

/// Gom các thửa GeoJSON đang hiển thị thành danh sách chú giải.
///
/// Gom theo TÊN loại đất (không theo màu) vì nguồn tỉnh đôi khi cho cùng một
/// loại hai mã màu lệch nhau vài đơn vị — gom theo màu sẽ đẻ ra hai dòng trùng
/// tên. Sắp theo số thửa giảm dần: loại phủ nhiều diện tích nhất phải đọc trước.
List<ZoneLegendEntry> buildZoneLegend(
  List<Map<String, dynamic>> features, {
  int limit = 8,
}) {
  final counts = <String, int>{};
  final colors = <String, Color>{};
  for (final f in features) {
    final props = (f['properties'] as Map?)?.cast<String, dynamic>();
    if (props == null) continue;
    final name = (props['zone_name'] as String?)?.trim();
    final code = (props['zone_code'] as String?)?.trim();
    final label = (name != null && name.isNotEmpty)
        ? name
        : (code != null && code.isNotEmpty ? code : null);
    if (label == null) continue;
    counts[label] = (counts[label] ?? 0) + 1;
    colors.putIfAbsent(
      label,
      () => parseZoneHex(props['zone_color'] as String?),
    );
  }
  final sorted = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return [
    for (final label in sorted.take(limit))
      ZoneLegendEntry(
        color: colors[label]!,
        label: label,
        count: counts[label]!,
      ),
  ];
}

/// Chú giải cho LỚP QUY HOẠCH — giải nghĩa các mảng màu đang phủ trên bản đồ.
///
/// Chú giải pin ([MapPinLegend]) chỉ nói về tin đăng; các mảng màu quy hoạch
/// trước đây không có chú thích nào, người dùng không biết màu nào là đất ở,
/// màu nào là cây xanh hay giao thông.
///
/// Mặc định THU GỌN (khác thanh độ mờ vốn luôn hiện) vì đây là thứ tra một lần
/// rồi thôi, không phải thao tác liên tục.
class PlanningZoneLegend extends StatefulWidget {
  const PlanningZoneLegend({
    required this.features,
    this.rasterSource = false,
    super.key,
  });

  /// Các feature GeoJSON đang vẽ trên bản đồ (provider.bboxFeatures).
  final List<Map<String, dynamic>> features;

  /// true khi lớp đang hiển thị là raster tile của tỉnh — không có dữ liệu loại
  /// đất kèm theo nên KHÔNG bịa màu, chỉ hướng dẫn chạm vào thửa.
  final bool rasterSource;

  @override
  State<PlanningZoneLegend> createState() => _PlanningZoneLegendState();
}

class _PlanningZoneLegendState extends State<PlanningZoneLegend> {
  bool _mo = false;

  /// Kết quả gom loại đất, chỉ tính lại khi danh sách thửa THỰC SỰ đổi.
  /// Màn quy hoạch dựng lại mỗi lần kéo bản đồ; quét lại vài nghìn thửa ở mỗi
  /// lần dựng là đủ để thấy giật.
  List<ZoneLegendEntry> _cache = const [];
  List<Map<String, dynamic>>? _cacheFor;

  List<ZoneLegendEntry> _entries() {
    if (widget.rasterSource) return const [];
    if (identical(_cacheFor, widget.features)) return _cache;
    _cache = buildZoneLegend(widget.features);
    _cacheFor = widget.features;
    return _cache;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entries = _entries();

    return Material(
      color: HD.paperRaised.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(HD.r8),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(HD.r8),
        onTap: () => setState(() => _mo = !_mo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.palette_outlined,
                        size: 14, color: HD.inkMuted),
                    const SizedBox(width: 4),
                    Text(l.planningZoneLegendTitle, style: HD.caption()),
                    const SizedBox(width: 4),
                    Icon(_mo ? Icons.expand_less : Icons.expand_more,
                        size: 14, color: HD.inkMuted),
                  ],
                ),
                if (_mo) ...[
                  const SizedBox(height: HD.s8),
                  if (widget.rasterSource)
                    Text(l.planningZoneLegendRasterNote, style: HD.caption())
                  else if (entries.isEmpty)
                    Text(l.planningZoneLegendEmpty, style: HD.caption())
                  else
                    for (final e in entries) _dong(e),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dong(ZoneLegendEntry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ô màu vẽ ĐÚNG như polygon trên bản đồ (cùng alpha, cùng viền) để
          // mắt đối chiếu được ngay.
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: e.color.withValues(alpha: kZoneFillAlpha),
              border: Border.all(
                color: e.color.withValues(alpha: 0.9),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(e.label, style: HD.caption())),
        ],
      ),
    );
  }
}
