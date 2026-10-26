import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/demand_post.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/data/services/demand_api.dart';
import 'package:house_booking/features/guest/browse/widgets/property_list_card.dart';
import 'package:house_booking/features/guest/browse/widgets/trade_filter_sheet.dart';
import 'package:house_booking/features/guest/demand/demand_form_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_search_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/house_provider.dart';

/// Bên nào của thị trường người dùng đang đứng.
enum TradeSide { mua, ban }

/// Nhu cầu ghim sẵn thành chip — cùng bộ phân loại với chú giải bản đồ, để một
/// người dùng chỉ phải học nghĩa của bốn màu này MỘT lần cho cả app.
enum TradeNeed { tatCa, ban, nganHan, daiHan, kinhDoanh, canMua, canThue }

/// Màn "Mua bán · Cho thuê". Route: không có URL (push từ hub).
/// API: GET /api/houses (nguồn cung) · GET /api/demands (nhu cầu).
///
/// Vì sao chia hai tab theo VAI của người dùng chứ không theo loại tin: cùng
/// một danh sách trộn lẫn nhà bán, nhà cho thuê và tin cần mua thì không ai
/// dùng được. Người đi mua cần thấy NGUỒN CUNG; người đi bán cần thấy AI ĐANG
/// TÌM. Hai việc ngược chiều nhau, ép chung một danh sách là bắt cả hai bên tự
/// lọc bằng mắt.
class TradeHubScreen extends StatefulWidget {
  const TradeHubScreen({
    super.key,
    this.title,
    this.repo,
    this.demandApi,
    this.initialSide = TradeSide.mua,
  });

  final String? title;

  /// Chỉ để test bơm dữ liệu giả.
  final ApiHouseRepository? repo;
  final DemandApi? demandApi;
  final TradeSide initialSide;

  @override
  State<TradeHubScreen> createState() => _TradeHubScreenState();
}

class _TradeHubScreenState extends State<TradeHubScreen> {
  ApiHouseRepository get _repo => widget.repo ?? ApiHouseRepository();
  DemandApi get _demandApi => widget.demandApi ?? const DemandApi();

  final _timCtl = TextEditingController();

  /// Hoãn gọi API sau khi người dùng NGỪNG gõ. Trước đây phải bấm Enter mới
  /// tìm — trên điện thoại nhiều người gõ xong rồi chờ, không thấy gì đổi nên
  /// tưởng ô tìm hỏng.
  Timer? _hoanTim;

  late TradeSide _ben = widget.initialSide;
  TradeNeed _nhuCau = TradeNeed.tatCa;
  TradeFilter _loc = const TradeFilter();

  List<HouseModel> _tinRao = const [];
  List<DemandPost> _tinNhuCau = const [];
  bool _dangTai = true;

  /// Chip hợp lệ theo từng bên — "Cần mua" chỉ có nghĩa ở tab Tôi bán.
  List<TradeNeed> get _chips => _ben == TradeSide.mua
      ? const [
          TradeNeed.tatCa,
          TradeNeed.ban,
          TradeNeed.nganHan,
          TradeNeed.daiHan,
          TradeNeed.kinhDoanh,
        ]
      : const [TradeNeed.tatCa, TradeNeed.canMua, TradeNeed.canThue];

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _hoanTim?.cancel();
    _timCtl.dispose();
    super.dispose();
  }

  void _goTim(String _) {
    // setState để nút xoá hiện/ẩn ngay, còn việc gọi API thì hoãn lại.
    setState(() {});
    _hoanTim?.cancel();
    _hoanTim = Timer(const Duration(milliseconds: 350), _nap);
  }

  void _doiBen(TradeSide s) {
    if (s == _ben) return;
    setState(() {
      _ben = s;
      // Chip của bên kia vô nghĩa ở đây → về "Tất cả" thay vì giữ lựa chọn cũ
      // rồi trả về danh sách rỗng khó hiểu.
      _nhuCau = TradeNeed.tatCa;
    });
    _nap();
  }

  /// Tham số lọc dịch từ chip + bảng lọc. Tách ra để việc ĐẾM và việc NẠP
  /// dùng đúng một bộ điều kiện — hai chỗ tự dịch riêng là lúc con số trên nút
  /// "Xem N tin" bắt đầu nói dối.
  ({String? tt, String? group}) get _dieuKienChip => (
    tt: switch (_nhuCau) {
      TradeNeed.ban => 'sale',
      TradeNeed.nganHan || TradeNeed.daiHan || TradeNeed.kinhDoanh => 'rent',
      _ => null,
    },
    group: switch (_nhuCau) {
      TradeNeed.nganHan => 'stay_short',
      TradeNeed.daiHan => 'stay_long',
      TradeNeed.kinhDoanh => 'business',
      _ => null,
    },
  );

  Future<int> _dem(TradeFilter f) {
    final dk = _dieuKienChip;
    final q = _timCtl.text.trim();
    return _repo.countHouses(
      query: q.isEmpty ? null : q,
      transactionType: dk.tt,
      group: dk.group,
      minPrice: f.giaTu,
      maxPrice: f.giaDen,
      minArea: f.dienTichTu,
      maxArea: f.dienTichDen,
      minBedrooms: f.phongNgu,
      categoryId: f.loaiHinh,
      directions: f.huongNha.toList(),
      isTrusted: f.chiUyTin ? true : null,
      minRating: f.diemDanhGia,
      minQualityStar: f.saoChatLuong,
      nearLat: f.coToaDo ? f.lat : null,
      nearLng: f.coToaDo ? f.lng : null,
      radiusKm: f.banKinhKm,
    );
  }

  Future<void> _nap() async {
    setState(() => _dangTai = true);
    final q = _timCtl.text.trim();
    try {
      if (_ben == TradeSide.mua) {
        _tinRao = await _repo.getHouses(
          query: q.isEmpty ? null : q,
          transactionType: _dieuKienChip.tt,
          group: _dieuKienChip.group,
          minPrice: _loc.giaTu,
          maxPrice: _loc.giaDen,
          minArea: _loc.dienTichTu,
          maxArea: _loc.dienTichDen,
          minBedrooms: _loc.phongNgu,
          sort: _loc.sort,
          categoryId: _loc.loaiHinh,
          directions: _loc.huongNha.toList(),
          // `false` nghĩa là "chỉ hiện nhà KHÔNG uy tín" ở backend — tắt công
          // tắc phải gửi null, không phải false.
          isTrusted: _loc.chiUyTin ? true : null,
          minRating: _loc.diemDanhGia,
          minQualityStar: _loc.saoChatLuong,
          // Chỉ gửi toạ độ khi ĐÃ lấy được. Gửi bán kính một mình thì backend
          // bỏ qua nó, còn người dùng thì tưởng đang lọc trong 3km.
          nearLat: _loc.coToaDo ? _loc.lat : null,
          nearLng: _loc.coToaDo ? _loc.lng : null,
          radiusKm: _loc.banKinhKm,
          limit: 50,
        );
      } else {
        _tinNhuCau = await _demandApi.list(
          kind: switch (_nhuCau) {
            TradeNeed.canMua => 'buy',
            TradeNeed.canThue => 'rent',
            _ => null,
          },
          // Ô tìm ở tab này trước đây KHÔNG được gửi đi — gõ gì cũng ra cùng
          // một danh sách.
          query: q.isEmpty ? null : q,
          limit: 50,
        );
      }
    } catch (_) {
      _tinRao = const [];
      _tinNhuCau = const [];
    }
    if (mounted) setState(() => _dangTai = false);
  }

  Future<void> _moBoLoc() async {
    final r = await showModalBottomSheet<TradeFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TradeFilterSheet(
        initial: _loc,
        dem: _dem,
        // Đang lọc tin BÁN thì tiền tính bằng TỶ — dùng chung thang triệu như
        // tin thuê sẽ khiến cả thanh trượt vô dụng.
        thangTy: _nhuCau == TradeNeed.ban,
        danhMuc: _danhMuc(),
        repo: _repo,
      ),
    );
    if (r == null || !mounted) return;
    setState(() => _loc = r);
    _nap();
  }

  /// Danh mục loại hình. Đã được `HouseProvider` nạp sẵn cho trang chủ — dùng
  /// lại thay vì gọi thêm một lượt API cho cùng một danh sách.
  ///
  /// Bọc try/catch vì màn này còn được dựng ở nơi KHÔNG có `HouseProvider`
  /// (test widget, và các luồng push lẻ): thiếu provider thì chỉ nên mất một
  /// mục lọc, không nên làm nổ cả bảng lọc.
  List<dynamic> _danhMuc() {
    try {
      return context.read<HouseProvider>().categories;
    } catch (_) {
      return const [];
    }
  }

  void _dangTin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Tab Tôi bán → mặc định đăng tin BÁN; tab Tôi mua → tin CẦN MUA.
        builder: (_) =>
            DemandFormScreen(kind: _ben == TradeSide.mua ? 'buy' : 'rent'),
      ),
    );
  }

  String _nhanChip(TradeNeed n, AppLocalizations l) => switch (n) {
    TradeNeed.tatCa => l.tradeChipAll,
    TradeNeed.ban => l.tradeChipSale,
    TradeNeed.nganHan => l.tradeChipShort,
    TradeNeed.daiHan => l.tradeChipLong,
    TradeNeed.kinhDoanh => l.tradeChipBusiness,
    TradeNeed.canMua => l.tradeChipNeedBuy,
    TradeNeed.canThue => l.tradeChipNeedRent,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final soKetQua = _ben == TradeSide.mua ? _tinRao.length : _tinNhuCau.length;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: widget.title ?? l.hubActionTrade,
        actions: [
          TextButton.icon(
            onPressed: _dangTin,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l.hubActionPost),
            style: TextButton.styleFrom(foregroundColor: HD.accent),
          ),
        ],
      ),
      // KHÔNG có FAB ở màn này. Shell đã có sẵn một FAB "Đăng tin" nổi trên
      // mọi màn con push trong tab, nên FAB thứ hai ở đây đè chồng lên nó —
      // hai nút đỏ giống hệt nhau nằm cạnh nhau giữa màn hình.
      //
      // Chúng cũng KHÔNG làm cùng một việc: FAB của shell đăng TIN BÁN/CHO
      // THUÊ, còn nút này đăng TIN NHU CẦU. Bản trước cố cho hai nút trông y
      // hệt nhau — sai ngay từ tiền đề. Nay chuyển lên thanh tiêu đề với đúng
      // nhãn "Đăng tin nhu cầu" để phân biệt được.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s8),
            child: Row(
              children: [
                Expanded(
                  child: DsSegmented<TradeSide>(
                    options: [
                      (
                        value: TradeSide.mua,
                        label: l.tradeTabBuy,
                        icon: Icons.search,
                      ),
                      (
                        value: TradeSide.ban,
                        label: l.tradeTabSell,
                        icon: Icons.sell_outlined,
                      ),
                    ],
                    value: _ben,
                    onChanged: _doiBen,
                  ),
                ),
                const SizedBox(width: HD.s8),
                // Lối tắt sang bản đồ, đặt ngay cạnh hai tab: xem theo DANH
                // SÁCH hay xem theo VỊ TRÍ là cùng một câu hỏi "tìm ở đâu",
                // nên hai lối đó phải đứng cạnh nhau.
                Material(
                  color: HD.paperRaised,
                  borderRadius: BorderRadius.circular(HD.r8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(HD.r8),
                    onTap: () => context.push('/map'),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(HD.r8),
                        border: Border.all(color: HD.hairline),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            size: 16,
                            color: HD.accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            l.tradeOpenMap,
                            style: HD
                                .bodyBold(size: 13)
                                .copyWith(color: HD.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Một câu nói rõ tab này cho ai xem cái gì — hai tab ngược chiều
          // nhau, không giải thích thì người dùng đoán sai rồi bỏ đi.
          Padding(
            padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _ben == TradeSide.mua ? l.tradeBuyHint : l.tradeSellHint,
                style: HD.caption(),
              ),
            ),
          ),
          _hangTim(l),
          _hangChip(l),
          // Ngắn hạn tìm theo KHUNG GIỜ còn trống, không theo tin: lối vào
          // màn tìm phòng trống trước đây chỉ là một dòng chữ dưới đáy màn
          // Tìm kiếm, gần như không ai thấy.
          if (_nhuCau == TradeNeed.nganHan && _ben == TradeSide.mua)
            _theTimPhongTrong(l),
          if (!_dangTai)
            Padding(
              padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l.tradeResultCount(soKetQua), style: HD.caption()),
              ),
            ),
          Expanded(child: _danhSach(l)),
        ],
      ),
    );
  }

  Widget _hangTim(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _timCtl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _nap(),
              onChanged: _goTim,
              decoration: InputDecoration(
                isDense: true,
                hintText: l.tradeSearchHint,
                prefixIcon: const Icon(Icons.search, color: HD.inkMuted),
                suffixIcon: _timCtl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _timCtl.clear();
                          _goTim('');
                        },
                      ),
                filled: true,
                fillColor: HD.paperRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: HD.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: HD.hairline),
                ),
              ),
            ),
          ),
          const SizedBox(width: HD.s8),
          // Bộ lọc chỉ áp cho NGUỒN CUNG; tin nhu cầu không có giá/diện tích
          // theo cùng nghĩa nên ẩn đi thay vì để nút bấm không ăn gì.
          if (_ben == TradeSide.mua)
            Material(
              color: _loc.dangLoc ? HD.accentTint : HD.paperRaised,
              shape: CircleBorder(
                side: BorderSide(color: _loc.dangLoc ? HD.accent : HD.hairline),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _moBoLoc,
                child: Tooltip(
                  message: l.tradeFilter,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 20,
                          color: _loc.dangLoc ? HD.accent : HD.inkSoft,
                        ),
                        // Số tiêu chí đang bật, ngay trên nút — biết danh sách
                        // bị cắt bớt bao nhiêu mà không phải mở bảng ra xem.
                        if (_loc.dangLoc)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 14,
                              height: 14,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: HD.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_loc.soTieuChi}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _theTimPhongTrong(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s8),
    child: Material(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(HD.r12),
      child: InkWell(
        key: const Key('trade-tim-phong-trong'),
        borderRadius: BorderRadius.circular(HD.r12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ShortStaySearchScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.bed_outlined, color: HD.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.tradeShortStaySearchTitle,
                      style: HD.bodyBold(size: 14.5, color: HD.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.tradeShortStaySearchSub,
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: HD.accent),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _hangChip(AppLocalizations l) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HD.s16),
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: HD.s8),
        itemBuilder: (_, i) {
          final n = _chips[i];
          final chon = n == _nhuCau;
          return ChoiceChip(
            selected: chon,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            label: Text(_nhanChip(n, l)),
            onSelected: (_) {
              setState(() => _nhuCau = n);
              _nap();
            },
          );
        },
      ),
    );
  }

  Widget _danhSach(AppLocalizations l) {
    if (_dangTai) {
      return const Center(child: CircularProgressIndicator());
    }
    final rong = _ben == TradeSide.mua ? _tinRao.isEmpty : _tinNhuCau.isEmpty;
    if (rong) {
      return DsEmptyState(
        icon: Icons.search_off,
        title: _ben == TradeSide.mua ? l.tradeEmptyBuy : l.tradeEmptySell,
        subtitle: l.tradeEmptyHint,
      );
    }
    return RefreshIndicator(
      onRefresh: _nap,
      child: ListView.separated(
        // Chừa chỗ cho FAB — thẻ cuối bị nút che là lỗi kinh điển.
        padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, 88),
        itemCount: _ben == TradeSide.mua ? _tinRao.length : _tinNhuCau.length,
        separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
        itemBuilder: (_, i) => _ben == TradeSide.mua
            ? PropertyListCard(house: _tinRao[i])
            : _theNhuCau(_tinNhuCau[i], l),
      ),
    );
  }

  Widget _theNhuCau(DemandPost d, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsStatusPill(
                label: d.laThue ? l.tradeChipNeedRent : l.tradeChipNeedBuy,
                tone: d.laThue ? DsStatusTone.info : DsStatusTone.warning,
                dense: true,
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Text(
                  d.provinceName ?? d.areaLabel ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 13),
                ),
              ),
            ],
          ),
          if (d.note != null && d.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              d.note!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HD.caption(),
            ),
          ],
        ],
      ),
    );
  }
}
