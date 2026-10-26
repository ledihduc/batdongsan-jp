import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/tong_quan/tong_quan_chu_nha_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';

import 'dashboard/host_dashboard_tokens.dart';

/// Tab Cá nhân của chủ nhà = TRANG CHỦ QUẢN LÝ ([TongQuanChuNhaScreen]).
///
/// File này chỉ là lớp keo: đọc provider (tên, ảnh, số thông báo chưa đọc) rồi
/// đưa xuống màn tổng quan dạng tham số — để màn đó test được mà không phải
/// dựng cả cây provider. Thanh điều hướng dưới là của app, không nằm ở đây.
///
/// Bố cục cũ ("TÀI SẢN CHO THUÊ" + danh sách toà) không mất: nút "Quản lý tài
/// sản" mở đúng danh sách toà đó.
class HostHomeScreen extends StatefulWidget {
  const HostHomeScreen({super.key, this.onMoCaiDat});

  /// Mở màn cài đặt (đổi mật khẩu, ngôn ngữ, đăng xuất…).
  ///
  /// Chỉ có giá trị khi màn này ĐỨNG LÀM tab Cá nhân của chủ nhà. Chủ nhà không
  /// có trang hồ sơ công khai như sale — trang của họ LÀ khu quản lý toà — nên
  /// nếu không có lối này thì họ không còn đường nào tới cài đặt và đăng xuất.
  /// Mở từ chỗ khác (trong menu) thì để null, khỏi có hai lối trùng.
  final VoidCallback? onMoCaiDat;

  @override
  State<HostHomeScreen> createState() => _HostHomeScreenState();
}

class _HostHomeScreenState extends State<HostHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    await Future.wait([
      // Chấm đỏ trên chuông phải đúng ngay khi mở, không đợi vào màn thông báo.
      Provider.of<NotificationProvider>(context, listen: false).fetch(user.id!),
      Provider.of<ViewingAppointmentProvider>(
        context,
        listen: false,
      ).fetchAppointments(user.id!, 'host'),
      Provider.of<HouseProvider>(
        context,
        listen: false,
      ).fetchMyHouses(user.id!),
    ]);
    if (!mounted) return;
    await Provider.of<BuildingProvider>(
      context,
      listen: false,
    ).fetchBuildings();
    if (!mounted) return;
    Provider.of<ContractProvider>(
      context,
      listen: false,
    ).fetchExpiringContracts(days: 30);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final uid = user?.id;
    final lichCho = context
        .watch<ViewingAppointmentProvider>()
        .appointments
        .where((b) => b.status == 'pending')
        .length;
    return Scaffold(
      backgroundColor: HD.paper,
      body: SafeArea(
        bottom: false,
        child: TongQuanChuNhaScreen(
          ten: user?.name ?? '',
          anhDaiDien: user?.avatarPath,
          soChuaDoc: context.watch<NotificationProvider>().unread,
          // Một người có thể VỪA là sale VỪA quản lý toà của chính mình. Không
          // chừa đường về trang cá nhân thì nhận bàn giao một toà là mất luôn
          // trang họ gửi cho khách.
          onMoTrangCaNhan: widget.onMoCaiDat == null || uid == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BrokerProfileScreen(
                      userId: uid,
                      name: user?.name,
                      avatarPath: user?.avatarPath,
                      laChuTrang: true,
                    ),
                  ),
                ),
          onMoCaiDat: widget.onMoCaiDat,
          soLichHenCho: lichCho,
          onMoLichHen: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HostAppointmentsScreen()),
            );
            if (mounted) _refresh();
          },
        ),
      ),
    );
  }
}
