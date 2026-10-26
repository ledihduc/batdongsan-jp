import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/guest/project/building_claim_screen.dart';
import 'package:house_booking/features/host/property/widgets/chon_cach_them_toa.dart';
import 'package:house_booking/features/host/property/widgets/hop_thoai_ma_toa.dart';
import 'package:house_booking/data/services/location_input_service.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/screens/building_detail_screen.dart';
import 'package:house_booking/features/host/journey/xac_nhan_coc_chu_nha_screen.dart';
import 'package:house_booking/features/host/property/screens/owner_building_management_screen.dart';

/// Screen: List of buildings owned by the current host.
///
/// Designed to be embedded inside the Host Dashboard "Nhà trọ" tab. Renders
/// chrome-less (no AppBar/FAB) — the parent Scaffold provides the surface.
class BuildingListScreen extends StatefulWidget {
  const BuildingListScreen({
    super.key,
    this.readOnly = false,
    this.overviewApi = const TongQuanChuNhaApi(),
    this.journeyApi = const RentalJourneyApi(),
  });

  /// Chế độ dành cho Sale: chỉ xem các tòa/phòng được phân công, không hiện
  /// thao tác tạo tòa hoặc mời một Sale khác.
  final bool readOnly;
  final TongQuanChuNhaApi overviewApi;
  final RentalJourneyApi journeyApi;

  @override
  State<BuildingListScreen> createState() => _BuildingListScreenState();
}

class _BuildingListScreenState extends State<BuildingListScreen> {
  TongQuanChuNha? _overview;
  bool _overviewLoading = false;

  /// Hồ sơ thuê ĐANG CHỜ CHÍNH CHỦ NHÀ bấm chốt (đủ hợp đồng + hai minh chứng
  /// cọc). Đây là đường vào duy nhất từ màn chủ nhà hay mở nhất: trước đây màn
  /// duyệt hồ sơ chỉ tới được từ work-queue hoặc màn kết quả buổi xem, nên
  /// người có quyền chốt gần như không bao giờ tìm thấy nó.
  List<RentalJourney> _choChot = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final buildings = context.read<BuildingProvider>().fetchBuildings();
    if (widget.readOnly) {
      await buildings;
      return;
    }
    if (mounted) setState(() => _overviewLoading = true);
    _napChoChot();
    try {
      final result = await Future.wait<dynamic>([
        buildings,
        widget.overviewApi.lay(),
      ]);
      if (mounted) setState(() => _overview = result[1] as TongQuanChuNha);
    } catch (_) {
      // Sổ tòa vẫn dùng được nếu phần số liệu tổng quan tạm thời lỗi.
    } finally {
      if (mounted) setState(() => _overviewLoading = false);
    }
  }

  Future<void> _napChoChot() async {
    try {
      final ds = await widget.journeyApi.list(view: 'owner');
      if (!mounted) return;
      setState(() {
        _choChot = [
          for (final hs in ds)
            if (hs.can(RentalJourneyAction.confirmRental)) hs,
        ];
      });
    } catch (_) {
      // Sổ toà vẫn dùng được nếu phần hồ sơ thuê tạm lỗi.
    }
  }

  /// Bấm "+ THÊM TOÀ NHÀ" → hỏi ĐƯỜNG NÀO trước.
  ///
  /// Hai đường dẫn tới hai trạng thái khác hẳn nhau: có mã của sale nghĩa là
  /// toà + phòng (có khi cả tin đăng) đã dựng sẵn — nhập mã là nhận lại công
  /// việc đó. Trước đây nút này chỉ có đường "tự tạo", nên chủ nhà nào được
  /// sale đưa mã cũng phải tự tạo một toà TRÙNG, còn toà thật của sale nằm lại
  /// đó mồ côi.
  Future<void> _themToaNha() async {
    final cach = await chonCachThemToa(context);
    if (cach == null || !mounted) return;
    if (cach == CachThemToa.nhapMa) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BuildingClaimScreen()),
      );
      if (mounted) await context.read<BuildingProvider>().fetchBuildings();
      return;
    }
    await _showCreateDialog();
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<_BuildingFormResult>(
      context: context,
      builder: (_) => const _CreateBuildingDialog(),
    );

    if (result == null) return;
    if (!mounted) return;

    final provider = context.read<BuildingProvider>();
    final created = await provider.createBuilding(
      name: result.name,
      address: result.address,
      city: result.city,
      ward: result.ward,
    );

    if (!mounted) return;
    // Tạo xong thì mời sale NGAY, không chôn trong menu: chủ nhà vừa dựng toà
    // là lúc họ đang nghĩ tới việc cho thuê, không phải ba ngày sau.
    if (created?.id != null) {
      await showDialog<void>(
        context: context,
        builder: (_) =>
            HopThoaiMaMoiSale(buildingId: created!.id, tenToa: created.name),
      );
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HD.ink,
        content: Text(
          created != null
              ? 'Đã tạo tòa nhà'
              : (provider.error ?? 'Tạo thất bại'),
          style: HD.body(color: HD.paperRaised),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BuildingProvider>();

    if (!widget.readOnly) return _ownerBody(provider);

    return Container(
      color: HD.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListHeader(
            count: provider.buildings.length,
            onAdd: widget.readOnly ? null : _themToaNha,
            onRefresh: _refresh,
          ),
          Expanded(child: _body(provider)),
        ],
      ),
    );
  }

  Widget _ownerBody(BuildingProvider provider) {
    if (provider.isLoading && provider.buildings.isEmpty) {
      return const ColoredBox(
        color: Color(0xfff7f9fc),
        child: Center(child: DsRowSkeleton()),
      );
    }
    if (provider.error != null && provider.buildings.isEmpty) {
      return ColoredBox(
        color: const Color(0xfff7f9fc),
        child: DsErrorState(message: provider.error!, onRetry: _refresh),
      );
    }

    final overview = _overview;
    final totalRooms =
        overview?.soPhong ??
        provider.buildings.fold<int>(0, (sum, b) => sum + b.soPhong);
    final occupiedRooms =
        overview?.phongDaThue ??
        provider.buildings.fold<int>(
          0,
          (sum, b) => sum + (b.soPhong - b.soPhongTrong).clamp(0, b.soPhong),
        );
    final taskCount = overview == null
        ? 0
        : overview.daiHan.fold<int>(
            0,
            (sum, block) => sum + block.phongNo + block.yeuCauDienNuoc,
          );

    return ColoredBox(
      color: const Color(0xfff7f9fc),
      child: RefreshIndicator(
        color: HD.accent,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _OwnerPortfolioHero(),
            const SizedBox(height: 18),
            Text('Tổng quan', style: HD.sectionTitle()),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _OwnerMetric(
                    icon: Icons.apartment_rounded,
                    value: '${provider.buildings.length}',
                    label: 'Tòa nhà',
                    color: const Color(0xff2875df),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OwnerMetric(
                    icon: Icons.bed_rounded,
                    value: '$occupiedRooms',
                    label: 'Phòng khai thác',
                    color: const Color(0xff078a59),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OwnerMetric(
                    icon: Icons.bar_chart_rounded,
                    value: _compactMoney(overview?.doanhThuThang ?? 0),
                    label: 'Doanh thu tháng',
                    color: const Color(0xff078a59),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OwnerMetric(
                    icon: Icons.assignment_late_outlined,
                    value: '$taskCount',
                    label: 'Việc cần xử lý',
                    color: HD.accent,
                  ),
                ),
              ],
            ),
            if (_overviewLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2, color: HD.accent),
            ],
            // Không vẽ thẻ rỗng: chỉ hiện khi THẬT SỰ có hồ sơ chờ bạn bấm.
            if (_choChot.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TheChoChot(
                danhSach: _choChot,
                onMo: (hs) async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => XacNhanCocChuNhaScreen(journeyId: hs.id),
                    ),
                  );
                  await _napChoChot();
                },
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Tòa nhà của bạn', style: HD.sectionTitle()),
                ),
                TextButton.icon(
                  key: const Key('owner-add-building'),
                  onPressed: _themToaNha,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                  label: const Text('Thêm tòa nhà'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff078a59),
                  ),
                ),
              ],
            ),
            if (provider.buildings.isEmpty)
              _OwnerEmpty(onAdd: _themToaNha)
            else
              for (final building in provider.buildings) ...[
                _OwnerBuildingCard(
                  building: building,
                  summary: overview,
                  onTap: () => _openOwnerBuilding(building),
                  onInviteSale: building.saleId == null
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) => HopThoaiMaMoiSale(
                            buildingId: building.id,
                            tenToa: building.name,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
              ],
            if (totalRooms > 0)
              _OwnerPortfolioFooter(
                totalRooms: totalRooms,
                occupiedRooms: occupiedRooms,
              ),
          ],
        ),
      ),
    );
  }

  void _openOwnerBuilding(BuildingModel building) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<BuildingProvider>(),
          child: OwnerBuildingManagementScreen(
            buildingId: building.id,
            buildingName: building.name,
            address: [
              building.address,
              building.district,
              building.city,
            ].where((value) => value.isNotEmpty).join(' · '),
            hostId: building.hostId,
          ),
        ),
      ),
    );
  }

  Widget _body(BuildingProvider provider) {
    if (provider.isLoading && provider.buildings.isEmpty) {
      return const Center(child: DsRowSkeleton());
    }
    if (provider.error != null && provider.buildings.isEmpty) {
      return DsErrorState(
        message: provider.error!,
        onRetry: () => provider.fetchBuildings(),
      );
    }
    if (provider.buildings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(HD.s20, HD.s32, HD.s20, HD.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.readOnly
                  ? 'Chưa có tòa nhà được phân công.'
                  : 'Sổ tòa nhà còn để trống.',
              style: HD.sectionTitle(),
            ),
            const SizedBox(height: HD.s8),
            Text(
              widget.readOnly
                  ? 'Khi Chủ nhà phân công, danh sách phòng đang ở sẽ xuất hiện tại đây.'
                  : 'Anh chị thêm tòa nhà / dãy trọ đầu tiên để bắt đầu quản lý phòng và hợp đồng.',
              style: HD.body(),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(height: HD.s16),
              _AddBuildingButton(onTap: _themToaNha, primary: true),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: HD.accent,
      backgroundColor: HD.paperRaised,
      onRefresh: () => provider.fetchBuildings(),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: provider.buildings.length + 1,
        itemBuilder: (_, i) {
          if (i == provider.buildings.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: HD.s32),
              child: _Colophon(),
            );
          }
          final b = provider.buildings[i];
          return _BuildingRow(
            index: i + 1,
            name: b.name,
            address: [
              b.address,
              b.district,
              b.city,
            ].where((s) => s.isNotEmpty).join(' · '),
            // Toà chưa có sale → mời một người. KHÔNG đưa `claimCode` xuống nữa:
            // đó là mã BÀN GIAO QUYỀN SỞ HỮU, chiều ngược hẳn với việc chủ nhà
            // muốn làm ở màn này (xem `_MoiSale`).
            chuaCoSale: !widget.readOnly && b.saleId == null,
            onMoiSale: widget.readOnly
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        HopThoaiMaMoiSale(buildingId: b.id, tenToa: b.name),
                  ),
            onTap: () {
              final screen = widget.readOnly
                  ? BuildingDetailScreen(
                      buildingId: b.id,
                      buildingName: b.name,
                      hostId: b.hostId,
                    )
                  : OwnerBuildingManagementScreen(
                      buildingId: b.id,
                      buildingName: b.name,
                      address: [
                        b.address,
                        b.district,
                        b.city,
                      ].where((value) => value.isNotEmpty).join(' · '),
                      hostId: b.hostId,
                    );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<BuildingProvider>(),
                    child: screen,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _compactMoney(double value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)} tỷ';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)} tr';
  }
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return value.toStringAsFixed(0);
}

class _OwnerPortfolioHero extends StatelessWidget {
  const _OwnerPortfolioHero();

  @override
  Widget build(BuildContext context) => Container(
    height: 144,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1400513a),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/branding/owner-building-list-v1.webp',
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xffe9f8f3), Color(0xe8e9f8f3), Color(0x18e9f8f3)],
              stops: [0, .46, .76],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 150, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Quản lý tòa nhà của bạn',
                maxLines: 2,
                style: HD.bodyBold(size: 17, color: const Color(0xff087f55)),
              ),
              const SizedBox(height: 7),
              Text(
                'Tổng quan tài sản, doanh thu và vận hành hiệu quả',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 12, color: const Color(0xff49645c)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OwnerMetric extends StatelessWidget {
  const _OwnerMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 120,
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffe2e8ef)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 18,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: HD.bodyBold(size: 15)),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: HD.caption().copyWith(fontSize: 9.5, height: 1.1),
        ),
      ],
    ),
  );
}

class _OwnerBuildingCard extends StatelessWidget {
  const _OwnerBuildingCard({
    required this.building,
    required this.summary,
    required this.onTap,
    this.onInviteSale,
  });

  final BuildingModel building;
  final TongQuanChuNha? summary;
  final VoidCallback onTap;
  final VoidCallback? onInviteSale;

  @override
  Widget build(BuildContext context) {
    final buildingSummary = summary?.toaNha
        .where((item) => item.buildingId == building.id)
        .firstOrNull;
    final longTerm = summary?.daiHan
        .where((item) => item.buildingId == building.id)
        .firstOrNull;
    final shortTerm = summary?.nganHan
        .where((item) => item.buildingId == building.id)
        .firstOrNull;
    final total = buildingSummary?.tong ?? building.soPhong;
    final vacant = buildingSummary == null
        ? building.soPhongTrong
        : (buildingSummary.tong - buildingSummary.daThue).clamp(
            0,
            buildingSummary.tong,
          );
    final occupancy =
        buildingSummary?.tyLe ??
        (total == 0 ? 0 : (((total - vacant) / total) * 100).round());
    final address = [
      building.address,
      building.district,
      building.city,
    ].where((value) => value.isNotEmpty).join(', ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('owner-building-${building.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe2e8ef)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 78,
                      height: 68,
                      child: _BuildingThumbnail(url: building.anhBia),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                building.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HD.bodyBold(size: 15),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: HD.inkMuted,
                            ),
                          ],
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HD.body(size: 11, color: HD.inkMuted),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _StatusDot(
                              active: buildingSummary?.hoatDong ?? total > 0,
                            ),
                            if (onInviteSale != null) ...[
                              const Spacer(),
                              InkWell(
                                onTap: onInviteSale,
                                child: Text(
                                  'Mời sale',
                                  style: HD.bodyBold(
                                    size: 11,
                                    color: HD.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xffedf0f4)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _SmallMetric('$total', 'phòng')),
                  Expanded(
                    child: _SmallMetric('${longTerm?.tong ?? 0}', 'dài hạn'),
                  ),
                  Expanded(
                    child: _SmallMetric('${shortTerm?.tong ?? 0}', 'ngắn hạn'),
                  ),
                  Expanded(child: _SmallMetric('$vacant', 'trống')),
                  Expanded(
                    child: _SmallMetric(
                      '$occupancy%',
                      'khai thác',
                      color: const Color(0xff078a59),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildingThumbnail extends StatelessWidget {
  const _BuildingThumbnail({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/branding/owner-building-list-v1.webp',
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: active ? const Color(0xffe4f8ee) : const Color(0xfff1f3f5),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? const Color(0xff08a466) : HD.inkMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          active ? 'Đang hoạt động' : 'Chưa khai thác',
          style: HD.bodyBold(
            size: 10,
            color: active ? const Color(0xff087f55) : HD.inkMuted,
          ),
        ),
      ],
    ),
  );
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric(this.value, this.label, {this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: HD.bodyBold(size: 12, color: color)),
      const SizedBox(height: 2),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HD.caption().copyWith(fontSize: 8.5),
      ),
    ],
  );
}

class _OwnerEmpty extends StatelessWidget {
  const _OwnerEmpty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe2e8ef)),
    ),
    child: Column(
      children: [
        const Icon(Icons.apartment_rounded, size: 36, color: Color(0xff078a59)),
        const SizedBox(height: 10),
        Text('Chưa có tòa nhà', style: HD.bodyBold(size: 15)),
        const SizedBox(height: 5),
        Text(
          'Thêm tòa đầu tiên hoặc nhận tòa bằng mã từ Sale.',
          textAlign: TextAlign.center,
          style: HD.body(size: 12, color: HD.inkMuted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Thêm tòa nhà'),
        ),
      ],
    ),
  );
}

class _OwnerPortfolioFooter extends StatelessWidget {
  const _OwnerPortfolioFooter({
    required this.totalRooms,
    required this.occupiedRooms,
  });

  final int totalRooms;
  final int occupiedRooms;

  @override
  Widget build(BuildContext context) {
    final rate = totalRooms == 0 ? 0 : (occupiedRooms / totalRooms).clamp(0, 1);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffe9f8f3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: Color(0xff078a59),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng quan sơ bộ', style: HD.bodyBold(size: 13)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: rate.toDouble(),
                    minHeight: 5,
                    backgroundColor: Colors.white,
                    color: const Color(0xff08a466),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$occupiedRooms/$totalRooms phòng đang được khai thác',
                  style: HD.caption().copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xff078a59)),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.count,
    required this.onAdd,
    required this.onRefresh,
  });

  final int count;
  final VoidCallback? onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s16, HD.s12, HD.s12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: Row(
        children: [
          Text('SỔ TÒA NHÀ', style: HD.eyebrow(color: HD.accent)),
          const SizedBox(width: HD.s8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(border: Border.all(color: HD.hairline)),
            child: Text(
              count.toString().padLeft(2, '0'),
              style: HD.tabular(color: HD.inkSoft, size: 10),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: HD.inkMuted),
            onPressed: onRefresh,
            visualDensity: VisualDensity.compact,
          ),
          if (onAdd != null) ...[
            const SizedBox(width: HD.s4),
            _AddBuildingButton(onTap: onAdd!),
          ],
        ],
      ),
    );
  }
}

class _AddBuildingButton extends StatelessWidget {
  const _AddBuildingButton({required this.onTap, this.primary = false});
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s12,
          vertical: HD.s8,
        ),
        decoration: BoxDecoration(color: primary ? HD.accent : HD.ink),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: HD.paperRaised),
            const SizedBox(width: HD.s4),
            Text(
              'THÊM TOÀ NHÀ',
              style: HD.eyebrow(color: HD.paperRaised).copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingRow extends StatelessWidget {
  const _BuildingRow({
    required this.index,
    required this.name,
    required this.address,
    required this.onTap,
    this.chuaCoSale = false,
    this.onMoiSale,
  });

  final int index;
  final String name;
  final String address;

  /// Chưa ai phụ trách bán/cho thuê toà này.
  final bool chuaCoSale;

  final VoidCallback? onMoiSale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      highlightColor: HD.paperRaised,
      splashColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s20,
          vertical: HD.s16,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HD.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: HD.bigNumeral(color: HD.accent, size: 28),
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: HD.bodyBold(size: 15)),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: HD.s4),
                    Text(address, style: HD.body(size: 12, color: HD.inkMuted)),
                  ],
                  if (chuaCoSale && onMoiSale != null) ...[
                    const SizedBox(height: HD.s8),
                    _MoiSale(onTap: onMoiSale!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: HD.s8),
            const Padding(
              padding: EdgeInsets.only(top: HD.s4),
              child: Icon(Icons.arrow_outward, size: 16, color: HD.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lối mời SALE về phụ trách toà — việc TIẾP THEO của chủ nhà sau khi dựng
/// xong sổ phòng.
///
/// Chỗ này trước đây in thẳng `claim_code` với nhãn "Mã bàn giao". Sai hai lần:
///
///   1. Đó là mã để NGƯỜI KHÁC nhận QUYỀN SỞ HỮU toà — chìa khoá nhà mình, đặt
///      sẵn một nút chép vào clipboard.
///   2. Chủ nhà đọc nhãn "Mã bàn giao", tưởng là mã để giao cho sale, chép gửi
///      đi — và sale nhập vào thì nhận "Mã không đúng hoặc đã được dùng", vì
///      màn nhận toà tra `ma_moi_sale` chứ không tra `claim_code`.
///
/// Nay mở đúng hộp thoại sinh `ma_moi_sale`, nên mã hiện ra luôn là mã mà màn
/// bên kia chấp nhận. Mã cũng KHÔNG còn nằm trong dữ liệu danh sách — chỉ lấy
/// khi bấm.
class _MoiSale extends StatelessWidget {
  const _MoiSale({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.r8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: HD.s4),
        decoration: BoxDecoration(
          color: HD.accentSoft,
          borderRadius: BorderRadius.circular(HD.r8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_add_alt_1_outlined,
              size: 13,
              color: HD.accent,
            ),
            const SizedBox(width: HD.s4),
            Text(
              'Mời sale',
              style: HD.bodyBold(size: 11).copyWith(color: HD.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colophon — small typographic flourish at the bottom of the list,
/// the way a newspaper section ends with "— hết —".
class _Colophon extends StatelessWidget {
  const _Colophon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(width: 24, height: 1, color: HD.hairline),
          const SizedBox(height: HD.s8),
          Text('— hết sổ —', style: HD.caption()),
        ],
      ),
    );
  }
}

// ── Create-building dialog (editorial chrome) ────────────────────────────────

class _BuildingFormResult {
  final String name;

  /// Số nhà + tên đường — phần duy nhất gõ tay.
  final String address;

  /// Tên tỉnh/thành và phường/xã CHỌN từ danh mục 2 cấp (01/07/2025), không gõ
  /// tay. Không có trường quận/huyện vì cấp đó đã bị bãi bỏ.
  final String city;
  final String ward;

  const _BuildingFormResult({
    required this.name,
    required this.address,
    required this.city,
    required this.ward,
  });
}

class _CreateBuildingDialog extends StatefulWidget {
  const _CreateBuildingDialog();

  @override
  State<_CreateBuildingDialog> createState() => _CreateBuildingDialogState();
}

class _CreateBuildingDialogState extends State<_CreateBuildingDialog> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  AdminUnit? _tinh;
  AdminUnit? _phuong;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: HD.caption(),
    filled: true,
    fillColor: HD.paperRaised,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: HD.hairline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: HD.hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: const BorderSide(color: HD.ink, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: HD.s12,
      vertical: HD.s12,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HD.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(HD.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TỜ KHAI MỚI', style: HD.eyebrow(color: HD.accent)),
            const SizedBox(height: HD.s4),
            Text('Thêm tòa nhà', style: HD.sectionTitle()),
            const SizedBox(height: HD.s8),
            Container(width: 32, height: 1, color: HD.hairline),
            const SizedBox(height: HD.s20),
            TextField(
              controller: _nameCtrl,
              decoration: _dec('Tên tòa nhà *'),
              style: HD.body(color: HD.ink),
            ),
            const SizedBox(height: HD.s12),
            TextField(
              controller: _addressCtrl,
              decoration: _dec('Số nhà, tên đường'),
              style: HD.body(color: HD.ink),
            ),
            const SizedBox(height: HD.s12),
            ChonDiaBan(
              tinh: _tinh,
              phuong: _phuong,
              onChanged: (t, p) => setState(() {
                _tinh = t;
                _phuong = p;
              }),
            ),
            const SizedBox(height: HD.s24),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Hủy', style: HD.bodyBold(color: HD.inkSoft)),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      context,
                      _BuildingFormResult(
                        name: name,
                        address: _addressCtrl.text.trim(),
                        city: _tinh?.name ?? '',
                        ward: _phuong?.name ?? '',
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HD.s16,
                      vertical: HD.s12,
                    ),
                    decoration: const BoxDecoration(color: HD.accent),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KÝ DUYỆT',
                          style: HD
                              .eyebrow(color: HD.paperRaised)
                              .copyWith(fontSize: 11),
                        ),
                        const SizedBox(width: HD.s8),
                        const Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: HD.paperRaised,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Hồ sơ chờ bạn chốt" — chủ nhà bấm là khách vào ở, hợp đồng hiệu lực.
class _TheChoChot extends StatelessWidget {
  const _TheChoChot({required this.danhSach, required this.onMo});

  final List<RentalJourney> danhSach;
  final void Function(RentalJourney) onMo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HD.accentTint,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.accent.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_reg, size: 19, color: HD.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hồ sơ chờ bạn chốt · ${danhSach.length}',
                  style: HD.bodyBold(size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Bấm chốt là hợp đồng hiệu lực và phòng chuyển sang "đang thuê". '
            'Thiếu hợp đồng / minh chứng cọc thì bổ sung sau ở mục Hợp đồng.',
            style: HD.body(size: 12, color: HD.inkSoft),
          ),
          const SizedBox(height: 10),
          for (final hs in danhSach)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: Key('owner-ho-so-cho-chot-${hs.id}'),
                borderRadius: BorderRadius.circular(HD.r12),
                onTap: () => onMo(hs),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(HD.r12),
                    border: Border.all(color: HD.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hs.subject.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.bodyBold(size: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Khách ${hs.customer.name}',
                              style: HD.body(size: 11.5, color: HD.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: HD.inkMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
