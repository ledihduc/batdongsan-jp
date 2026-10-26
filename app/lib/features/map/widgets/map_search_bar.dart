import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/planning_search_hit_model.dart';
import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Chiều cao của các khối nổi ở hàng trên cùng bản đồ (ô tìm kiếm + chú giải).
const double kMapTopBarHeight = 44;

/// Thanh tìm địa điểm nổi trên bản đồ (kiểu Google Maps).
///
/// Dùng lại đúng endpoint tìm địa điểm mà màn quy hoạch đang gọi
/// (`GET /api/planning/search`, proxy Nominatim) — không dựng dịch vụ mới.
class MapSearchBar extends StatefulWidget {
  const MapSearchBar({required this.onPick, super.key});

  /// Chọn một kết quả → nơi dùng tự dời bản đồ tới đó.
  final void Function(LatLng point, String label) onPick;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final _svc = PlanningService();
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  CancelToken? _token;
  List<SearchHit> _hits = const [];
  bool _dangTim = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _token?.cancel('dispose');
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.length < 3) {
      // Dưới 3 ký tự Nominatim trả về rác — đừng bắn request lẫn đừng hiện
      // danh sách.
      setState(() {
        _hits = const [];
        _dangTim = false;
      });
      return;
    }
    // Gõ tới đâu huỷ request cũ tới đó, tránh kết quả cũ về sau đè kết quả mới.
    _debounce = Timer(const Duration(milliseconds: 350), () => _tim(trimmed));
  }

  Future<void> _tim(String q) async {
    _token?.cancel('new search');
    _token = CancelToken();
    setState(() => _dangTim = true);
    try {
      final r = await _svc.search(q, limit: 6, cancelToken: _token);
      if (!mounted) return;
      setState(() {
        _hits = r;
        _dangTim = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hits = const [];
        _dangTim = false;
      });
    }
  }

  void _chon(SearchHit h) {
    _focus.unfocus();
    _ctrl.text = h.displayName;
    setState(() => _hits = const []);
    widget.onPick(LatLng(h.lat, h.lon), h.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(24),
          elevation: 3,
          child: SizedBox(
            // Cùng chiều cao với chú giải bên cạnh — hai khối đứng chung một
            // hàng mà lệch cao thì nhìn như đặt nhầm chỗ.
            height: kMapTopBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.search, size: 20, color: HD.inkMuted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: (v) {
                        final t = v.trim();
                        if (t.length >= 3) _tim(t);
                      },
                      style: HD.body(size: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        // Theme của app đặt RIÊNG enabledBorder/focusedBorder
                        // (khung vuông có viền). Chỉ set `border` là không đủ —
                        // các trường null vẫn lấy giá trị từ theme, nên phải tắt
                        // TỪNG cái, kèm filled:false để không có nền chữ nhật.
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        hintText: l.mapSearchHint,
                        // Ô hẹp lại khi đứng cùng hàng với chú giải — cắt bằng
                        // "…" thay vì để chữ tràn ra ngoài viền.
                        hintMaxLines: 1,
                        hintStyle: HD
                            .body(size: 14)
                            .copyWith(color: HD.inkMuted),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_dangTim)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_ctrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: HD.inkMuted,
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _hits = const []);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_hits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: HD.paperRaised,
              borderRadius: BorderRadius.circular(HD.r8),
              elevation: 3,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _hits.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: HD.hairline),
                  itemBuilder: (_, i) {
                    final h = _hits[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: HD.inkMuted,
                      ),
                      title: Text(
                        h.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 13),
                      ),
                      onTap: () => _chon(h),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
