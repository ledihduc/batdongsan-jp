import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';

/// Dải tin đăng MỚI NHẤT, cuộn ngang — dùng ở trang chủ.
///
/// Vì sao cần: trước đây cuộn hết trang chủ không thấy một tin nhà nào, thứ
/// "sống" duy nhất là avatar người bán. Trang được xem nhiều nhất mà không
/// trưng ra sản phẩm thì người vào lần đầu không biết app có gì để xem.
///
/// Fail-silent như mọi mục khác ở trang chủ: lỗi mạng chỉ làm dải này biến
/// mất, không bao giờ chặn cả trang.
class LatestListingsStrip extends StatefulWidget {
  const LatestListingsStrip({super.key, this.repo, this.soLuong = 8});

  /// Chỉ để test bơm dữ liệu giả.
  final ApiHouseRepository? repo;

  final int soLuong;

  @override
  State<LatestListingsStrip> createState() => _LatestListingsStripState();
}

class _LatestListingsStripState extends State<LatestListingsStrip> {
  ApiHouseRepository get _repo => widget.repo ?? ApiHouseRepository();

  List<HouseModel> _tin = const [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final ds = await _repo.getHouses(limit: widget.soLuong);
      if (mounted) setState(() => _tin = ds);
    } catch (_) {
      if (mounted) setState(() => _tin = const []);
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dangTai) return const _KhungCho();
    // Không có tin thì ẩn hẳn dải, kể cả tiêu đề: một tiêu đề "Tin tức" đứng
    // trên khoảng trắng còn tệ hơn là không có mục nào.
    if (_tin.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _tin.length,
        separatorBuilder: (_, _) => const SizedBox(width: HD.s12),
        itemBuilder: (_, i) => _the(_tin[i]),
      ),
    );
  }

  Widget _the(HouseModel h) {
    return InkWell(
      onTap: () => context.push('/house/${h.id}'),
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 104, width: double.infinity, child: _anh(h)),
            Padding(
              padding: const EdgeInsets.all(HD.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${h.district}, ${h.city}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.caption(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    h.priceCompactLabel,
                    style: HD.bodyBold(size: 14, color: HD.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _anh(HouseModel h) {
    if (h.images.isEmpty) {
      return Container(
        color: HD.paperSunken,
        child: const Icon(Icons.home_outlined, color: HD.inkMuted, size: 28),
      );
    }
    final url = h.images.first;
    return CachedNetworkImage(
      imageUrl: url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url',
      fit: BoxFit.cover,
      // Ảnh chỉ hiện ở 168px bề ngang — tải đúng cỡ đó thay vì giải mã ảnh gốc
      // vài nghìn pixel cho tám thẻ cùng lúc.
      memCacheWidth: 400,
      placeholder: (_, _) => Container(color: HD.paperSunken),
      errorWidget: (_, _, _) => Container(
        color: HD.paperSunken,
        child: const Icon(Icons.broken_image_outlined, color: HD.inkMuted),
      ),
    );
  }
}

/// Khung chờ giữ ĐÚNG chiều cao của dải thật: nếu để nó cao 0 thì lúc dữ liệu
/// về, mọi thứ bên dưới bị đẩy xuống 208px ngay dưới ngón tay người đang cuộn.
class _KhungCho extends StatelessWidget {
  const _KhungCho();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: HD.s12),
        itemBuilder: (_, _) => Container(
          width: 168,
          decoration: BoxDecoration(
            color: HD.paperSunken,
            borderRadius: BorderRadius.circular(HD.r12),
          ),
        ),
      ),
    );
  }
}
