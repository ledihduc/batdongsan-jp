import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/theme/design_tokens.dart';

/// Băng chuyền ảnh — vuốt ngang để xem tiếp.
///
/// Dùng cho ảnh nền dự án ở CẢ hai chỗ: thẻ nhỏ trên trang cá nhân và bìa lớn
/// ở trang chi tiết. Trước đây mỗi chỗ tự vẽ ảnh riêng, nên làm cho thẻ vuốt
/// được thì trang chi tiết vẫn đứng im — hai nơi cùng một dữ liệu mà hành xử
/// khác nhau.
///
/// Một ảnh thì KHÔNG dựng `PageView`. Ở thẻ nhỏ, thẻ nằm trong dải trượt ngang
/// nên một vùng cuộn lồng vào sẽ cướp thao tác vuốt của dải bên ngoài; ở đâu
/// cũng vậy, dựng máy cuộn cho đúng một trang là phí.
class BangChuyenAnh extends StatefulWidget {
  const BangChuyenAnh({
    required this.anh,
    super.key,
    this.coChiSo = true,
    this.kichThuocIconTrong = 30,
    this.mauNenTrong = HD.paperSunken,
    this.mauIconTrong = HD.inkMuted,
    this.memCacheWidth,
  });

  final List<String> anh;

  /// Chấm trang. Không có nó thì ảnh thứ hai trở đi vô hình — người xem không
  /// có lý do gì để thử vuốt một tấm ảnh trông như tĩnh.
  final bool coChiSo;

  /// Khung khi chưa có ảnh nào.
  final double kichThuocIconTrong;
  final Color mauNenTrong;
  final Color mauIconTrong;

  /// Giới hạn bộ nhớ ảnh — thẻ nhỏ không cần giải mã ảnh cỡ đầy đủ.
  final int? memCacheWidth;

  @override
  State<BangChuyenAnh> createState() => _BangChuyenAnhState();
}

class _BangChuyenAnhState extends State<BangChuyenAnh> {
  int _trang = 0;

  @override
  void didUpdateWidget(BangChuyenAnh cu) {
    super.didUpdateWidget(cu);
    // Danh sách ngắn lại mà chỉ số cũ nằm ngoài thì chấm trang trỏ vào hư vô.
    if (_trang >= widget.anh.length) _trang = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.anh.isEmpty) return _khungTrong();
    if (widget.anh.length == 1) return _mot(widget.anh.first);

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.anh.length,
          onPageChanged: (i) => setState(() => _trang = i),
          itemBuilder: (_, i) => _mot(widget.anh[i]),
        ),
        if (widget.coChiSo)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                // Nền mờ: chấm trắng đặt thẳng lên ảnh sáng thì mất tăm.
                color: const Color(0x59000000),
                borderRadius: BorderRadius.circular(HD.rPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.anh.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _trang
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _khungTrong() => Container(
    color: widget.mauNenTrong,
    alignment: Alignment.center,
    child: Icon(
      Icons.apartment_rounded,
      color: widget.mauIconTrong,
      size: widget.kichThuocIconTrong,
    ),
  );

  Widget _mot(String url) => CachedNetworkImage(
    imageUrl: url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url',
    fit: BoxFit.cover,
    memCacheWidth: widget.memCacheWidth,
    placeholder: (_, _) => const ColoredBox(color: HD.paperSunken),
    errorWidget: (_, _, _) => const ColoredBox(color: HD.paperSunken),
  );
}
