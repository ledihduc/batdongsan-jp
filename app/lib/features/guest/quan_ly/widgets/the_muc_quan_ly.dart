import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';

/// Màu + icon theo TÔNG server trả (`tong`): huy hiệu và dòng trạng thái dùng
/// chung để hai chỗ không bao giờ nói hai màu khác nhau về cùng một mục.
(Color, IconData) kieuTong(String tong) => switch (tong) {
  'do' => (HD.accent, Icons.event_available),
  'cam' => (HD.svcOrange, Icons.schedule),
  'xanh' => (HD.svcGreen, Icons.home_rounded),
  'lam' => (HD.svcBlue, Icons.groups_rounded),
  _ => (HD.inkMuted, Icons.history),
};

/// Nhãn + màu của LOẠI THUÊ — cùng bộ màu với chú giải bản đồ (`HD.pin*`),
/// để "ngắn hạn" là một màu ở mọi nơi trong app. `null` = không vẽ thẻ.
(String, Color)? kieuKenh(String? kenh) => switch (kenh) {
  'ngan_han' => ('Ngắn hạn', HD.pinStayShort),
  'dai_han' => ('Dài hạn', HD.pinStayLong),
  'mat_bang' => ('Mặt bằng', HD.pinBusiness),
  'ban' => ('Mua bán', HD.pinSale),
  _ => null,
};

IconData _iconLoai(String loai) => switch (loai) {
  'dat_phong' => Icons.bed_outlined,
  'thue_dai_han' => Icons.apartment_outlined,
  _ => Icons.home_work_outlined,
};

/// Thẻ một mục trong "Danh sách quản lý": ảnh · tên · địa chỉ · trạng thái ·
/// huy hiệu nhóm.
class TheMucQuanLy extends StatelessWidget {
  const TheMucQuanLy({super.key, required this.m, this.onTap});

  final MucQuanLy m;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (mau, icon) = kieuTong(m.tong);
    // "Cần bạn xử lý" (chọn giờ mới, chờ bạn xác nhận…) tô cam ĐẬM cả dòng:
    // đó là thứ duy nhất trên thẻ đòi người dùng làm gì đó. "Sắp tới hạn"
    // (hết hạn hợp đồng, sắp trả phòng) chỉ tô cam, không đậm.
    final mauDong = m.canXuLy || m.nhac ? HD.svcOrange : HD.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s12),
      child: Material(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12 + 4),
        elevation: 0,
        child: InkWell(
          key: Key('muc-${m.loai}-${m.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(HD.r12 + 4),
          child: Ink(
            padding: const EdgeInsets.all(HD.s12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HD.r12 + 4),
              boxShadow: [
                BoxShadow(
                  color: HD.ink.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _anh(),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              m.tieuDe,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: HD.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: HD.s8),
                          _HuyHieu(nhan: m.nhan, mau: mau, icon: icon),
                        ],
                      ),
                      if (m.diaChi.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _dong(
                          Icons.location_on_outlined,
                          m.diaChi,
                          HD.inkMuted,
                          HD.inkMuted,
                        ),
                      ],
                      if (m.khach != null) ...[
                        const SizedBox(height: 2),
                        _dong(
                          Icons.person_outline,
                          'Khách: ${m.khach}',
                          HD.inkMuted,
                          HD.inkSoft,
                        ),
                      ],
                      if (m.dong.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _dong(icon, m.dong, mau, mauDong, dam: m.canXuLy),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: HD.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _anh() {
    final url = m.anh;
    final nen = Container(
      color: HD.paperSunken,
      alignment: Alignment.center,
      child: Icon(_iconLoai(m.loai), color: HD.inkMuted, size: 30),
    );
    final loai = kieuKenh(m.kenh);
    return ClipRRect(
      borderRadius: BorderRadius.circular(HD.r12),
      child: SizedBox(
        width: 92,
        height: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null || url.isEmpty)
              nen
            else
              CachedNetworkImage(
                imageUrl: url.startsWith('http')
                    ? url
                    : '${ApiConfig.baseUrl}$url',
                fit: BoxFit.cover,
                memCacheWidth: 240,
                placeholder: (_, _) => nen,
                errorWidget: (_, _, _) => nen,
              ),
            // Loại thuê: nền ĐẶC chữ trắng, nằm trên ảnh — tách hẳn khỏi huy
            // hiệu trạng thái (nền nhạt, góc phải) để không đọc lẫn hai thứ.
            if (loai != null)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  key: Key('kenh-${m.loai}-${m.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: loai.$2,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(HD.r8),
                    ),
                  ),
                  child: Text(
                    loai.$1,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dong(
    IconData i,
    String chu,
    Color mauIcon,
    Color mauChu, {
    bool dam = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(i, size: 15, color: mauIcon),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          chu,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: mauChu,
            fontWeight: dam ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ],
  );
}

class _HuyHieu extends StatelessWidget {
  const _HuyHieu({required this.nhan, required this.mau, required this.icon});

  final String nhan;
  final Color mau;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: mau),
        const SizedBox(width: 4),
        Text(
          nhan,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: mau,
          ),
        ),
      ],
    ),
  );
}
