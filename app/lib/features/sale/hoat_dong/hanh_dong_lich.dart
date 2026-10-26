import 'package:flutter/material.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/cap_nhat_ket_qua_sheet.dart';
import 'package:house_booking/features/sale/hoat_dong/chi_tiet_don_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/chi_tiet_lich_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/doi_lich_sheet.dart';
import 'package:house_booking/features/sale/hoat_dong/tu_choi_lich_sheet.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Chạy một nút trên lịch xem / đơn đặt phòng — cùng một chỗ cho thẻ danh
/// sách, "Cần xử lý hôm nay" và màn chi tiết. Trả `true` khi dữ liệu có thể đã
/// đổi (màn gọi nên tải lại).
Future<bool> chayHanhDongLich(
  BuildContext context,
  LichSale lich,
  String hanhDong, {
  SaleVanHanhApi api = const SaleVanHanhApi(),
  LichXemApi lichXemApi = const LichXemApi(),
  DateTime? bayGio,
}) async {
  switch (hanhDong) {
    case 'xac_nhan':
      try {
        await api.xacNhanLich(lich.id);
        if (context.mounted) baoSale(context, 'Đã xác nhận lịch xem với khách');
        return true;
      } catch (e) {
        if (context.mounted) {
          baoSale(context, e is ApiException ? e.message : 'Chưa xác nhận được, thử lại nhé.');
        }
        return false;
      }
    case 'tu_choi':
      final ok = await moTuChoiLich(context, appointmentId: lich.id, api: api);
      if (ok && context.mounted) baoSale(context, 'Đã từ chối lịch xem');
      return ok;
    case 'doi_lich':
      final ok = await moDoiLich(context, appointmentId: lich.id, api: lichXemApi);
      if (ok && context.mounted) baoSale(context, 'Đã gửi khung giờ mới cho khách chọn');
      return ok;
    case 'cap_nhat_ket_qua':
      final bd = lich.batDau;
      if (bd != null && bd.isAfter(bayGio ?? DateTime.now())) {
        baoSale(
          context,
          'Cập nhật kết quả được từ giờ hẹn (${gioPhut(bd)} ${ngayThang(bd)})',
        );
        return false;
      }
      final ok = await moCapNhatKetQua(
        context,
        appointmentId: lich.id,
        phongTen: lich.phongTen,
        khachTen: lich.khachTen,
        api: api,
      );
      if (ok && context.mounted) baoSale(context, 'Đã cập nhật kết quả buổi xem');
      return ok;
    default:
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => lich.laDon
              ? ChiTietDonSaleScreen(reservationId: lich.id, api: api)
              : ChiTietLichSaleScreen(
                  appointmentId: lich.id,
                  api: api,
                  lichXemApi: lichXemApi,
                ),
        ),
      );
      return true;
  }
}
