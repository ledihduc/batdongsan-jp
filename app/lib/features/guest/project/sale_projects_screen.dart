import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/services/location_input_service.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/services/du_an_gan_tin_api.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/screens/building_detail_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/house_provider.dart';

/// Danh sách dự án (toà nhà) của tài khoản sale. Route: push (không cần URL).
/// Provider: BuildingProvider (khai báo sẵn ở main.dart).
/// API: GET/POST /api/host/buildings.
///
/// Vì sao KHÔNG dùng lại `BuildingListScreen`: màn đó là một danh sách phẳng
/// chỉ có tên + địa chỉ, dựng theo phong cách "sổ báo" của bảng điều khiển chủ
/// nhà. Với sale ôm chục dự án thì mọi dòng nhìn như nhau, không lướt được.
/// Ở đây mỗi dự án là một thẻ **nói được số liệu** (bao nhiêu phòng, còn trống
/// mấy) và có ô tìm khi danh sách dài.
class SaleProjectsScreen extends StatefulWidget {
  const SaleProjectsScreen({super.key});

  @override
  State<SaleProjectsScreen> createState() => _SaleProjectsScreenState();
}

class _SaleProjectsScreenState extends State<SaleProjectsScreen> {
  final _oTim = TextEditingController();

  /// Ngưỡng hiện ô tìm. Dưới mức này thì mắt quét nhanh hơn gõ, thêm ô tìm chỉ
  /// tốn một hàng và làm màn trông phức tạp hơn thực tế.
  static const _nguongTim = 6;

  /// Hướng dẫn ngắn về cách quản lý tòa dùng chung.
  bool _hienNhac = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BuildingProvider>().fetchBuildings();
    });
  }

  @override
  void dispose() {
    _oTim.dispose();
    super.dispose();
  }

  List<BuildingModel> _loc(List<BuildingModel> ds) {
    final q = _oTim.text.trim().toLowerCase();
    if (q.isEmpty) return ds;
    return ds.where((b) {
      final kho = '${b.name} ${b.address} ${b.district} ${b.city}'
          .toLowerCase();
      return kho.contains(q);
    }).toList();
  }

  Future<void> _taoMoi() async {
    final kq = await showModalBottomSheet<_FormKetQua>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SheetTaoDuAn(),
    );
    if (kq == null || !mounted) return;

    final p = context.read<BuildingProvider>();
    final tao = await p.createBuilding(
      name: kq.ten,
      address: kq.diaChi,
      // `district` để trống có chủ đích: cấp quận/huyện không còn tồn tại từ
      // 01/07/2025. Cột vẫn còn trong DB để đọc dữ liệu cũ, nhưng không ghi mới.
      ward: kq.phuong,
      city: kq.tinh,
    );
    if (!mounted) return;
    if (tao != null) {
      // createBuilding trả về bản ghi vừa ghi, chưa kèm số phòng — nạp lại để
      // thẻ mới không hiện "0 phòng" sai trong khi thực ra là chưa đếm.
      await p.fetchBuildings();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tao != null ? 'Đã thêm tòa BĐS' : (p.error ?? 'Tạo không được'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BuildingProvider>();
    final tatCa = p.buildings;
    final ds = _loc(tatCa);

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        title: const Text('Dự án BĐS của tôi'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () => p.fetchBuildings(),
          ),
        ],
      ),
      floatingActionButton: tatCa.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _taoMoi,
              backgroundColor: HD.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Thêm tòa BĐS'),
            ),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: () => p.fetchBuildings(),
        child: _than(p, tatCa, ds),
      ),
    );
  }

  Widget _than(
    BuildingProvider p,
    List<BuildingModel> tatCa,
    List<BuildingModel> ds,
  ) {
    if (p.isLoading && tatCa.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(HD.s16),
        children: const [
          DsRowSkeleton(),
          SizedBox(height: HD.s12),
          DsRowSkeleton(),
          SizedBox(height: HD.s12),
          DsRowSkeleton(),
        ],
      );
    }
    if (p.error != null && tatCa.isEmpty) {
      return DsErrorState(message: p.error!, onRetry: () => p.fetchBuildings());
    }
    if (tatCa.isEmpty) return _KhiTrong(onTao: _taoMoi);

    return ListView(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (_hienNhac) ...[
          const _HuongDanToa(),
          const SizedBox(height: HD.s12),
        ],
        if (tatCa.length >= _nguongTim) ...[
          _OTim(controller: _oTim, onDoi: () => setState(() {})),
        ],
        const SizedBox(height: HD.s12),
        if (ds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HD.s32),
            child: Center(
              child: Text(
                'Không có dự án nào khớp "${_oTim.text.trim()}"',
                style: HD.body(color: HD.inkMuted),
              ),
            ),
          )
        else
          ...ds.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: HD.s12),
              child: _TheDuAn(
                b: b,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: context.read<BuildingProvider>(),
                      child: BuildingDetailScreen(
                        buildingId: b.id,
                        buildingName: b.name,
                        hostId: b.hostId,
                      ),
                    ),
                  ),
                ),
                claimCode: b.claimCode,
                onGanTin: () => _moGanTin(b),
              ),
            ),
          ),
      ],
    );
  }

  /// Mở khay chọn TIN ĐÃ ĐĂNG để gắn vào dự án [b].
  ///
  /// Chỉ liệt kê tin CHƯA thuộc dự án nào (`sourceRoomId == null`): cột tương
  /// ứng ở backend là UNIQUE nên gắn lần hai bị từ chối — bày ra rồi mới báo
  /// lỗi là bắt người dùng đoán, thà lọc trước.
  ///
  /// Tin bán theo HẠNG PHÒNG cũng có `sourceRoomId == null` nhưng KHÔNG gắn
  /// được: nó đã thuộc một toà qua hạng, gắn thêm là sinh ra một phòng ma
  /// trùng với phòng thật (server trả 409).
  Future<void> _moGanTin(BuildingModel b) async {
    final hp = context.read<HouseProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.id;
    if (uid == null) return;

    if (hp.myHouses.isEmpty) await hp.fetchMyHouses(uid);
    if (!mounted) return;

    final chuaGan = hp.myHouses
        .where((h) => h.sourceRoomId == null && h.loaiPhongId == null)
        .toList();
    final chon = await showModalBottomSheet<HouseModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetChonTin(duAn: b.name, tin: chuaGan),
    );
    if (chon?.id == null || !mounted) return;

    try {
      final ma = await const DuAnGanTinApi().gan(
        duAnId: b.id,
        tinId: chon!.id!,
      );
      if (!mounted) return;
      AppFeedback.success(context, 'Đã gắn vào ${b.name} — phòng $ma');
      await context.read<BuildingProvider>().fetchBuildings();
      await hp.fetchMyHouses(uid);
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Gắn không được: $e');
    }
  }
}

class _HuongDanToa extends StatelessWidget {
  const _HuongDanToa();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.accentSoft,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.accent.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 19, color: HD.accent),
          const SizedBox(width: HD.s8),
          Expanded(
            child: Text(
              'Một tòa dùng chung cho nhiều Sale và Chủ nhà. Bạn chỉ thêm hoặc quản lý những phòng mình phụ trách.',
              style: HD.body(size: 12.5, color: HD.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thẻ dự án ────────────────────────────────────────────────────────────────

/// Một dự án. Bố cục: **bìa ảnh** → tên + địa chỉ → **thanh lấp đầy** → mã.
///
/// Bìa là thứ làm danh sách lướt được: không có ảnh thì mọi thẻ chỉ khác nhau
/// ở dòng chữ, mắt phải ĐỌC từng thẻ thay vì nhận ra. Dự án chưa có ảnh phòng
/// nào thì vẽ nền màu theo id — vẫn khác nhau, vẫn nhận ra được.
class _TheDuAn extends StatelessWidget {
  const _TheDuAn({
    required this.b,
    required this.onTap,
    required this.onGanTin,
    this.claimCode,
  });

  final BuildingModel b;
  final VoidCallback onTap;
  final String? claimCode;

  /// Mở khay chọn tin đã đăng để gắn vào dự án này.
  final VoidCallback onGanTin;

  @override
  Widget build(BuildContext context) {
    final diaChi = [
      b.address,
      b.district,
      b.city,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Material(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Bia(b: b),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HD.s16,
                HD.s12,
                HD.s16,
                HD.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 16.5),
                  ),
                  if (diaChi.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: HD.inkMuted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            diaChi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HD.body(size: 12.5, color: HD.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: HD.s12),
                  _LapDay(tong: b.soPhong, trong: b.soPhongTrong),
                  if (claimCode != null) ...[
                    const SizedBox(height: HD.s12),
                    _MoiChuNha(ma: claimCode!),
                  ],
                  const SizedBox(height: HD.s12),
                  // GẮN TIN ĐÃ ĐĂNG — chiều ngược của luồng mặc định.
                  //
                  // Luồng gốc chỉ đi được một chiều: dựng dự án → thêm phòng →
                  // đăng lên chợ. Ai đăng tin lẻ trước rồi mới dựng dự án thì
                  // tin đó đứng ngoài vĩnh viễn. Nút này để thứ tự làm việc
                  // không còn bị ép: cái nào trước cũng được.
                  DsButton(
                    label: 'Gắn tin đã đăng',
                    icon: Icons.playlist_add,
                    variant: DsButtonVariant.secondary,
                    size: DsButtonSize.compact,
                    expand: true,
                    onPressed: onGanTin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoiChuNha extends StatelessWidget {
  const _MoiChuNha({required this.ma});

  final String ma;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: ma));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chép mã để gửi cho Chủ nhà')),
        );
      },
      borderRadius: BorderRadius.circular(HD.r8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: HD.accentSoft,
          borderRadius: BorderRadius.circular(HD.r8),
        ),
        child: Row(
          children: [
            const Icon(Icons.key_outlined, size: 18, color: HD.accent),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mời Chủ nhà xác nhận', style: HD.bodyBold(size: 13)),
                  const SizedBox(height: 2),
                  Text(
                    'Mã $ma · chạm để chép gửi qua Zalo/SMS',
                    style: HD.caption(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.copy_outlined, size: 18, color: HD.accent),
          ],
        ),
      ),
    );
  }
}

/// Bìa 16:6 — đủ để nhận ra, không cao đến mức một màn chỉ vừa hai dự án.
class _Bia extends StatelessWidget {
  const _Bia({required this.b});

  final BuildingModel b;

  /// Nền thay ảnh, chọn theo id để cùng một dự án luôn ra cùng một màu — đổi
  /// màu mỗi lần tải lại thì mắt không nhớ được thẻ nào là thẻ nào.
  static const _nen = [
    Color(0xFF8E3B46),
    Color(0xFF2F5D62),
    Color(0xFF4A4E7C),
    Color(0xFF7A5C3E),
    Color(0xFF3E6B4F),
  ];

  @override
  Widget build(BuildContext context) {
    final anh = b.anhBia;
    return AspectRatio(
      aspectRatio: 16 / 6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (anh != null && anh.isNotEmpty)
            CachedNetworkImage(
              imageUrl: anh,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: HD.paper),
              // Ảnh hỏng KHÔNG được để lộ ô vỡ — quay về nền màu như khi
              // không có ảnh.
              errorWidget: (_, _, _) => _NenChu(b: b, mau: _mau),
            )
          else
            _NenChu(b: b, mau: _mau),
          // Vệt tối chân bìa để chữ trắng (nếu có) và mép thẻ không chói.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x33000000)],
              ),
            ),
          ),
          if (b.soPhongTrong > 0)
            Positioned(
              top: HD.s8,
              right: HD.s8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HD.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: HD.accent,
                  borderRadius: BorderRadius.circular(HD.rPill),
                ),
                child: Text(
                  'Còn ${b.soPhongTrong} phòng',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color get _mau => _nen[b.id % _nen.length];
}

class _NenChu extends StatelessWidget {
  const _NenChu({required this.b, required this.mau});

  final BuildingModel b;
  final Color mau;

  @override
  Widget build(BuildContext context) {
    final chu = b.name.trim().isEmpty ? '?' : b.name.trim()[0].toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [mau, Color.lerp(mau, Colors.black, .25)!],
        ),
      ),
      child: Center(
        child: Text(
          chu,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: .22),
          ),
        ),
      ),
    );
  }
}

/// Thanh lấp đầy — bao nhiêu phòng đã có khách. Một thanh nói nhanh hơn ba con
/// số: liếc là biết dự án nào đang ế.
class _LapDay extends StatelessWidget {
  const _LapDay({required this.tong, required this.trong});

  final int tong;
  final int trong;

  @override
  Widget build(BuildContext context) {
    if (tong == 0) {
      return Row(
        children: [
          const Icon(Icons.add_circle_outline, size: 14, color: HD.inkMuted),
          const SizedBox(width: HD.s4),
          Text(
            'Chưa có phòng nào — mở dự án để thêm',
            style: HD.body(size: 12.5, color: HD.inkMuted),
          ),
        ],
      );
    }
    final daThue = tong - trong;
    final ti = daThue / tong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$daThue/$tong phòng đã thuê', style: HD.bodyBold(size: 12.5)),
            const Spacer(),
            Text(
              '${(ti * 100).round()}%',
              style: HD.body(size: 12.5, color: HD.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: HD.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(HD.rPill),
          child: LinearProgressIndicator(
            value: ti,
            minHeight: 6,
            backgroundColor: HD.accentSoft,
            valueColor: const AlwaysStoppedAnimation(HD.accent),
          ),
        ),
      ],
    );
  }
}

// ── Phụ trợ ──────────────────────────────────────────────────────────────────

class _OTim extends StatelessWidget {
  const _OTim({required this.controller, required this.onDoi});

  final TextEditingController controller;
  final VoidCallback onDoi;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onDoi(),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Tìm theo tên hoặc khu vực',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onDoi();
                },
              ),
        filled: true,
        fillColor: HD.paperRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.r12),
          borderSide: const BorderSide(color: HD.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.r12),
          borderSide: const BorderSide(color: HD.hairline),
        ),
      ),
    );
  }
}

class _KhiTrong extends StatelessWidget {
  const _KhiTrong({required this.onTao});

  final VoidCallback onTao;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(HD.s24, 72, HD.s24, HD.s24),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: HD.accentSoft,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              size: 34,
              color: HD.accent,
            ),
          ),
        ),
        const SizedBox(height: HD.s20),
        Text(
          'Chưa có dự án nào',
          textAlign: TextAlign.center,
          style: HD.bodyBold(size: 18),
        ),
        const SizedBox(height: HD.s8),
        Text(
          'Gom các phòng cùng một toà vào một dự án để khách xem một lượt, và '
          'để bàn giao cho chủ nhà bằng mã khi chốt được.',
          textAlign: TextAlign.center,
          style: HD.body(size: 13.5, color: HD.inkMuted),
        ),
        const SizedBox(height: HD.s20),
        DsButton(label: 'Tạo dự án đầu tiên', expand: true, onPressed: onTao),
      ],
    );
  }
}

// ── Sheet tạo dự án ──────────────────────────────────────────────────────────

class _FormKetQua {
  const _FormKetQua(this.ten, this.diaChi, this.phuong, this.tinh);
  final String ten;

  /// Số nhà + tên đường — phần DUY NHẤT còn gõ tay, vì không có danh mục nào
  /// để đối chiếu.
  final String diaChi;

  /// Phường/xã. Cơ cấu hành chính 2 cấp (01/07/2025) đã bỏ cấp quận/huyện, nên
  /// đây là cấp dưới tỉnh, không phải "quận".
  final String phuong;
  final String tinh;
}

class _SheetTaoDuAn extends StatefulWidget {
  const _SheetTaoDuAn();

  @override
  State<_SheetTaoDuAn> createState() => _SheetTaoDuAnState();
}

class _SheetTaoDuAnState extends State<_SheetTaoDuAn> {
  final _ten = TextEditingController();
  final _diaChi = TextEditingController();

  // Tỉnh/phường CHỌN từ danh mục nhà nước (`ChonDiaBan`), không gõ tay — gõ tay
  // thì "TP.HCM"/"Tp Hồ Chí Minh"/"Sài Gòn" thành ba khu vực khác nhau khi lọc.
  AdminUnit? _tinh;
  AdminUnit? _phuong;

  @override
  void dispose() {
    _ten.dispose();
    _diaChi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duoi = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: duoi),
      child: Container(
        decoration: const BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.vertical(top: Radius.circular(HD.r12)),
        ),
        padding: const EdgeInsets.fromLTRB(HD.s20, HD.s12, HD.s20, HD.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HD.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: HD.s16),
            Text('Dự án mới', style: HD.bodyBold(size: 18)),
            const SizedBox(height: HD.s16),
            _O(c: _ten, nhan: 'Tên dự án *', goiY: 'Vinhomes Grand Park — S1'),
            const SizedBox(height: HD.s12),
            _O(c: _diaChi, nhan: 'Số nhà, tên đường', goiY: 'Nguyễn Xiển'),
            const SizedBox(height: HD.s12),
            // Xếp DỌC chứ không hai cột: tên phường/xã sau sáp nhập dài hơn
            // hẳn ("Phường An Khánh", "Xã Đông Thạnh"), nhét nửa bề ngang là
            // cắt cụt đúng phần phân biệt chúng với nhau.
            ChonDiaBan(
              tinh: _tinh,
              phuong: _phuong,
              onChanged: (t, p) => setState(() {
                _tinh = t;
                _phuong = p;
              }),
            ),
            const SizedBox(height: HD.s20),
            DsButton(
              label: 'Tạo dự án',
              expand: true,
              onPressed: _ten.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      _FormKetQua(
                        _ten.text.trim(),
                        _diaChi.text.trim(),
                        _phuong?.name ?? '',
                        _tinh?.name ?? '',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _O({
    required TextEditingController c,
    required String nhan,
    String? goiY,
  }) {
    return TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        labelText: nhan,
        hintText: goiY,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ── Khay chọn tin để gắn vào dự án ───────────────────────────────────────────

/// Chọn MỘT tin đã đăng để gắn vào dự án.
///
/// Chọn một lần một tin chứ không cho tick nhiều: mỗi lần gắn sinh ra một
/// phòng mới trong dự án, và người bán cần thấy ngay phòng đó ra mã gì. Gắn
/// hàng loạt thì kết quả là một nắm "P04…P09" không ai đối chiếu nổi với tin
/// nào — muốn gắn tiếp thì mở lại khay, vẫn nhanh.
class _SheetChonTin extends StatelessWidget {
  const _SheetChonTin({required this.duAn, required this.tin});

  final String duAn;
  final List<HouseModel> tin;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: tin.isEmpty ? 0.4 : 0.66,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.vertical(top: Radius.circular(HD.r12)),
        ),
        child: Column(
          children: [
            const SizedBox(height: HD.s12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HD.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(HD.s20, HD.s16, HD.s20, HD.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gắn tin vào dự án', style: HD.bodyBold(size: 18)),
                  const SizedBox(height: 3),
                  Text(
                    duAn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 13, color: HD.inkSoft),
                  ),
                ],
              ),
            ),
            const HDHairline(),
            Expanded(
              child: tin.isEmpty
                  ? _khongCoTin()
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(vertical: HD.s8),
                      itemCount: tin.length,
                      separatorBuilder: (_, _) => const HDHairline(),
                      itemBuilder: (_, i) => _dong(context, tin[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Trạng thái rỗng nói rõ đây KHÔNG phải lỗi: chưa có tin lẻ nào để gắn là
  /// chuyện bình thường, và vẫn còn đường đi tiếp (thêm phòng trong dự án).
  Widget _khongCoTin() => Center(
    child: Padding(
      padding: const EdgeInsets.all(HD.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: HD.inkMuted),
          const SizedBox(height: HD.s12),
          Text(
            'Không có tin lẻ nào để gắn',
            style: HD.bodyBold(size: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HD.s4),
          Text(
            'Mọi tin của bạn đã thuộc một dự án, hoặc bạn chưa đăng tin nào. '
            'Cách khác: mở dự án rồi thêm phòng trực tiếp.',
            style: HD.body(size: 12.5, color: HD.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _dong(BuildContext context, HouseModel h) {
    final diaChi = [h.district, h.city].where((s) => s.isNotEmpty).join(', ');
    final anh = h.images.isNotEmpty ? h.images.first : null;
    return InkWell(
      onTap: () => Navigator.pop(context, h),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s20,
          vertical: HD.s12,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(HD.r8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: anh == null
                    ? const ColoredBox(
                        color: HD.paperSunken,
                        child: Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: HD.inkMuted,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: anh.startsWith('http')
                            ? anh
                            : '${ApiConfig.baseUrl}$anh',
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const ColoredBox(
                          color: HD.paperSunken,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 20,
                            color: HD.inkMuted,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (h.price > 0) PriceFormat.compact(h.price),
                      if (diaChi.isNotEmpty) diaChi,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: HD.s8),
            const Icon(Icons.add_circle_outline, color: HD.accent, size: 22),
          ],
        ),
      ),
    );
  }
}
