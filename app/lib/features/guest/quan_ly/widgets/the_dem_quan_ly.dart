import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';

/// Khoá của thẻ "Sắp tới" — không phải một nhóm của danh sách mà là lối vào
/// lịch đầy đủ, nên tách khỏi các khoá [NhomQuanLy].
const String kTheSapToi = 'sap_toi';

/// Bốn thẻ số ở đầu trang Quản lý: Đã đặt · Đang đặt · Đang ở · Sắp tới.
///
/// Ba thẻ đầu LỌC danh sách bên dưới theo đúng nhóm đó — con số trên thẻ và số
/// dòng hiện ra khi bấm phải khớp nhau, nên cùng đọc từ `dem` server trả. Thẻ
/// "Sắp tới" mở lịch đầy đủ.
class TheDemQuanLy extends StatelessWidget {
  const TheDemQuanLy({
    super.key,
    required this.dem,
    required this.onChon,
    this.dangChon,
  });

  final DemQuanLy dem;
  final ValueChanged<String> onChon;

  /// Thẻ đang được dùng làm bộ lọc — viền đậm để người dùng biết vì sao danh
  /// sách đang ngắn lại.
  final String? dangChon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, t) in _cacThe(dem).indexed) ...[
        if (i > 0) const SizedBox(width: HD.s8),
        Expanded(
          child: _The(
            t: t,
            chon: dangChon == t.khoa,
            onTap: () => onChon(t.khoa),
          ),
        ),
      ],
    ],
  );

  static List<_DuLieuThe> _cacThe(DemQuanLy d) => [
    _DuLieuThe(
      NhomQuanLy.daDat,
      'Đã đặt',
      d.daDat,
      Icons.event_available,
      HD.accent,
    ),
    _DuLieuThe(
      NhomQuanLy.dangDat,
      'Đang đặt',
      d.dangDat,
      Icons.schedule,
      HD.svcOrange,
    ),
    _DuLieuThe(
      NhomQuanLy.dangO,
      'Đang ở',
      d.dangO,
      Icons.home_rounded,
      HD.svcGreen,
    ),
    _DuLieuThe(
      kTheSapToi,
      'Sắp tới',
      d.sapToi,
      Icons.calendar_month,
      HD.svcBlue,
    ),
  ];
}

class _DuLieuThe {
  const _DuLieuThe(this.khoa, this.nhan, this.so, this.icon, this.mau);

  final String khoa;
  final String nhan;
  final int so;
  final IconData icon;
  final Color mau;
}

class _The extends StatelessWidget {
  const _The({required this.t, required this.chon, required this.onTap});

  final _DuLieuThe t;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${t.nhan}: ${t.so}',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('the-dem-${t.khoa}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(HD.r12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(HD.s8, HD.s12, HD.s4, HD.s12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                t.mau.withValues(alpha: 0.10),
                t.mau.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(
              color: t.mau.withValues(alpha: chon ? 0.9 : 0.14),
              width: chon ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: t.mau.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(t.icon, size: 19, color: t.mau),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${t.so}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: t.mau,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HD.s8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.nhan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: HD.inkSoft),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: HD.inkSoft),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
