import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';

/// Tiến trình thuê 7 bước — MỘT widget cho cả sale (Chi tiết yêu cầu) lẫn
/// khách (Chi tiết đơn thuê), để hai bên nhìn cùng một tiến trình giống hệt.
///
/// Bước xong: vòng xanh đặc; bước đang ở: đỏ; bước chưa tới: vòng xám rỗng.
/// Giờ ở bên phải là mốc đi QUA bước đó (đã đổi sang giờ Việt Nam).
class PipelineThue extends StatelessWidget {
  const PipelineThue({super.key, required this.buoc});

  final List<BuocPipeline> buoc;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: Column(
      children: [
        for (var i = 0; i < buoc.length; i++)
          _Buoc(b: buoc[i], so: i + 1, cuoi: i == buoc.length - 1),
      ],
    ),
  );
}

class _Buoc extends StatelessWidget {
  const _Buoc({required this.b, required this.so, required this.cuoi});

  final BuocPipeline b;
  final int so;
  final bool cuoi;

  @override
  Widget build(BuildContext context) {
    final mau = b.dangO
        ? HD.accent
        : b.xong
        ? HD.positive
        : HD.inkMuted;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: b.xong ? mau : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: mau, width: 1.6),
                ),
                child: Text(
                  '$so',
                  style: HD.bodyBold(
                    size: 11,
                    color: b.xong ? Colors.white : mau,
                  ),
                ),
              ),
              if (!cuoi)
                Expanded(
                  child: Container(
                    width: 2,
                    color: b.xong ? HD.positive : HD.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: cuoi ? 0 : 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      b.nhan,
                      style: b.dangO
                          ? HD.bodyBold(size: 13.5, color: HD.accent)
                          : HD.body(
                              size: 13,
                              color: b.xong ? HD.ink : HD.inkMuted,
                            ),
                    ),
                  ),
                  if (b.luc case final luc?)
                    Text(
                      gioPhut(luc),
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String gioPhut(DateTime d) {
  String h(int n) => n.toString().padLeft(2, '0');
  return '${h(d.day)}/${h(d.month)} ${h(d.hour)}:${h(d.minute)}';
}
