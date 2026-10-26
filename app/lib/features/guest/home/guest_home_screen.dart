import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/content_actions_sheet.dart';
import 'package:house_booking/core/widgets/fb_post_card.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';
import 'package:house_booking/core/widgets/skeleton.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/user_preferences.dart'
    show kWorldConstruction;
// MapScreen / PlanningMapScreen / HouseDetailScreen — KHÔNG import eager:
// dùng context.push('/map' | '/planning' | '/house/:id') để tách chunk JS
// (flutter_map + vector_map_tiles ~600KB không vào initial bundle).
import 'package:house_booking/providers/chat_provider.dart';
import 'package:house_booking/features/guest/home/advanced_filter_screen.dart';
import 'package:house_booking/features/guest/home/widgets/explore_trade_card.dart';
import 'package:house_booking/features/guest/search/search_screen.dart';
import 'package:house_booking/data/services/preferences_service.dart';
import 'package:house_booking/features/guest/home/app_system_drawer.dart';
import 'package:house_booking/features/guest/reels/reel_bar.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/l10n/app_localizations.dart';
// JP market (Phase 01) — facets drawer for chintai listing filter.
// Gated behind FeatureFlags.isJapan at runtime; tree-shaken in VN release builds
// because the `if (FeatureFlags.isJapan)` blocks are compile-time false.
import 'package:house_booking/features/guest/search/jp_search_facets_drawer.dart';
import 'package:house_booking/core/widgets/ds_legal_footer.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({
    super.key,
    this.world = 'realestate',
    this.onOpenProfile,
    this.onOpenMode,
    this.onPostHouse,
  });

  /// Thế giới của tab này: 'realestate' hoặc 'construction'. Điều hướng lõi giờ
  /// dùng bottom-nav (mỗi thế giới 1 tab), KHÔNG còn segmented switcher ở trên.
  final String world;

  /// Mở tab Cá nhân (avatar bên phải AppBar). Cài đặt người dùng nằm ở đó.
  final VoidCallback? onOpenProfile;

  final VoidCallback? onOpenMode;

  /// Mở luồng đăng tin cho thuê (shell giữ logic guest-gate + become-host).
  final VoidCallback? onPostHouse;

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final ScrollController _scrollController = ScrollController();

  // Guard: đặt default 'rent' đúng 1 lần sau frame đầu tiên.
  // Tránh gọi Provider.of trước khi widget tree sẵn sàng trong initState.
  bool _transactionDefaultSet = false;

  @override
  void initState() {
    super.initState();
    // KHÔNG addListener(setState) — sẽ rebuild toàn screen + 6 provider
    // mỗi keystroke. Clear-button dùng ValueListenableBuilder trên controller.
    _scrollController.addListener(_onScroll);
    if (_laThiCong) {
      PreferencesService.instance.getLocal().then((p) {
        if (mounted && p.serviceSlugs.isNotEmpty) {}
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // D6: tab mặc định = "Cho thuê" (rent). Chỉ chạy 1 lần duy nhất.
    if (!_transactionDefaultSet) {
      _transactionDefaultSet = true;
      Provider.of<HouseProvider>(
        context,
        listen: false,
      ).setTransactionType('rent');
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.position.pixels;
    if (cur >= max - 300) {
      Provider.of<HouseProvider>(context, listen: false).loadMoreHouses();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Đang ở nửa Thi công? Quyết định màu nhấn + nhãn + các nút phù hợp.
  bool get _laThiCong => widget.world == kWorldConstruction;

  /// JP: current search filter state; updated by JpSearchFacetsDrawer.onApply.
  JpSearchFilter _jpFilter = const JpSearchFilter();

  /// Opens the appropriate filter UI depending on build region.
  ///
  /// JP build: slides in [JpSearchFacetsDrawer] from an endDrawer (caller must
  /// pass its own [ctx] — an AppBar action context that is a descendant of
  /// the Scaffold, so [Scaffold.of] resolves correctly).
  /// VN build: pushes [AdvancedFilterScreen] full-screen.
  void _moBoLocBds([BuildContext? ctx]) {
    if (FeatureFlags.isJapan) {
      Scaffold.of(ctx ?? context).openEndDrawer();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdvancedFilterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AuthProvider không dùng listen → currentUser rất ít đổi giữa session;
    // tránh rebuild Scaffold theo từng notifyListeners của auth.
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final l = AppLocalizations.of(context);
    // Không Provider.of<HouseProvider>(context) ở build() — sẽ rebuild toàn
    // Scaffold (kể cả AppBar) mỗi notify. Việc listen được nhường cho
    // Consumer<HouseProvider> bên trong body, giới hạn vùng rebuild.

    return HDGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: AppSystemDrawer(
          world: widget.world,
          onOpenProfile: widget.onOpenProfile,
          onPostHouse: widget.onPostHouse,
        ),
        // JP market (Phase 01): chintai listing filter drawer.
        // Only mounted in JP region builds; VN builds use AdvancedFilterScreen push.
        endDrawer: FeatureFlags.isJapan
            ? JpSearchFacetsDrawer(
                initialFilter: _jpFilter,
                onApply: (f) => setState(() => _jpFilter = f),
              )
            : null,
        appBar: AppBar(
          // Tiêu đề nay 2 dòng (logo + nhãn thế giới) nên phải nới chiều cao:
          // mặc định 56px không đủ, chữ sẽ sát/cắt viền trên màn hẹp.
          toolbarHeight: 64,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(bottom: BorderSide(color: HD.hairline)),
          leadingWidth: user == null ? 56 : 178,
          // TRÁI: hamburger mở menu HỆ THỐNG (kèm chấm đỏ nếu có tin nhắn/thông
          // báo chưa đọc — 2 mục này đã chuyển vào menu theo yêu cầu).
          leading: Builder(
            builder: (ctx) => Consumer2<ChatProvider, NotificationProvider>(
              builder: (context, cp, np, _) {
                final unread = cp.totalUnread + np.unread;
                final menu = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: l.homeMenuTooltip,
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 10,
                        right: 8,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: HD.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: HD.paperRaised,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
                if (user == null) return menu;
                final mode = user.laSale
                    ? 'Sale'
                    : (user.role == 'host' || user.accountType == 'owner')
                    ? 'オーナー'
                    : '入居希望者';
                final avatar = user.avatarPath.isNotEmpty
                    ? CachedNetworkImageProvider(
                        user.avatarPath.startsWith('http')
                            ? user.avatarPath
                            : '${ApiConfig.baseUrl}${user.avatarPath}',
                      )
                    : null;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    menu,
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: widget.onOpenMode,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: HD.accentSoft,
                              backgroundImage: avatar,
                              child: avatar == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: HD.accentDeep,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HD.bodyBold(size: 12),
                                  ),
                                  Text(
                                    mode,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HD.caption().copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.onOpenMode != null)
                              const Icon(Icons.expand_more, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          centerTitle: true,
          // Thanh tiêu đề TRƯỚC ĐÂY giống hệt nhau ở cả hai thế giới nên mở app
          // lên không biết mình đang ở nửa Bất động sản hay nửa Thi công — nội
          // dung khác nhau nhưng "vỏ" thì không. Thêm nhãn thế giới + màu nhấn
          // riêng để luôn định vị được.
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo.mark(size: 22),
                  const SizedBox(width: 6),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: Brand.logoPart1,
                          style: HD.masthead(size: 22),
                        ),
                        // Logo GIỮ NGUYÊN màu thương hiệu ở cả hai thế giới. Bản
                        // đầu tôi đổi màu chữ "365" theo tab — sai: wordmark phải
                        // bất biến, nếu không người dùng chụp màn hình chia sẻ lên
                        // Zalo (kênh vào duy nhất hiện nay) sẽ thấy hai "logo" khác
                        // nhau và không chắc là cùng một app. Phân biệt thế giới
                        // bằng NHÃN bên dưới.
                        TextSpan(
                          text: Brand.logoPart2,
                          style: HD.mastheadItalic(color: HD.accent, size: 22),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                _laThiCong ? l.worldConstructionLabel : l.worldRealEstateLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3,
                  color: HD.worldAccent(_laThiCong),
                ),
              ),
            ],
          ),
          actions: [
            // 1 icon SEARCH ở header → mở màn tìm kiếm toàn hệ thống (thay ô search
            // cũ nằm trong feed). Bộ lọc nâng cao giữ riêng 1 icon.
            IconButton(
              tooltip: l.homeSearchTooltip,
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            // Cùng vị trí, HAI bộ lọc khác nhau theo thế giới đang đứng:
            //  · BĐS      → AdvancedFilterScreen (giá theo triệu, số phòng ngủ).
            //  · Thi công → ContractorFilterScreen (ngành · khu vực · sắp xếp).
            // Trước đây tab Thi công dùng chung bộ lọc BĐS nên người tìm nhà thầu
            // bấm vào thì bị hỏi "mấy phòng ngủ" — sai nghiệp vụ, không chỉ sai
            // thẩm mỹ; rồi bị ẨN hẳn, thành mất luôn khả năng lọc khu vực.
            Builder(
              builder: (bCtx) => IconButton(
                tooltip: _laThiCong
                    ? l.homeConstructionFilterTooltip
                    : l.homeAdvancedFilterTooltip,
                icon: const Icon(Icons.tune),
                // Pass bCtx so Scaffold.of() resolves when isJapan opens endDrawer.
                onPressed: () => _moBoLocBds(bCtx),
              ),
            ),
            // PHẢI: khách chưa đăng nhập → nút "Đăng nhập"; đã đăng nhập → không
            // còn avatar (vào Hồ sơ qua tab "Cá nhân").
            if (user == null)
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: Center(
                  child: OutlinedButton(
                    onPressed: () => GuestGate.promptLogin(
                      context,
                      message: l.homeLoginPromptSaveContactPost,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HD.accent,
                      side: const BorderSide(color: HD.accent),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      l.loginButton,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Consumer<HouseProvider> giới hạn vùng rebuild khi HouseProvider
        // notifyListeners — AppBar (Chat/Notification consumers) không bị rebuild
        // theo. Trước đây dùng Provider.of(context) ở build(), khiến toàn bộ
        // Scaffold rebuild mỗi lần list houses thay đổi.
        body: Consumer<HouseProvider>(
          builder: (context, houseProvider, _) => RefreshIndicator(
            onRefresh: () => houseProvider.fetchHouses(),
            child: CustomScrollView(
              controller: _scrollController,
              // cacheExtent vừa phải: prefetch ~300px ngoài viewport cho mượt,
              // nhưng không dựng/decode quá nhiều card ảnh cùng lúc (giảm jank).
              cacheExtent: 300,
              slivers: [
                // ĐÃ BỎ hai hàng chip lọc (nhóm nhu cầu + loại hình) khỏi
                // đầu feed. Chúng chiếm gần 100px ngay dưới thanh tiêu đề,
                // đẩy tin đầu tiên xuống quá nửa màn hình — mở tab ra là thấy
                // hai hàng nút chứ chưa thấy tin nào. Lối lọc vẫn còn đủ: icon
                // phễu trên thanh tiêu đề (Bộ lọc nâng cao) và bộ lọc đầy đủ
                // trong màn "Xem tổng hợp" ở thẻ Khám phá ngay bên dưới.
                //
                // Chọn mua/thuê chỉ dựng khi bật SALE_ENABLED (mặc định tắt),
                // giữ lại để bật cờ là có ngay, không phải dựng lại.
                if (FeatureFlags.saleEnabled)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _TransactionTypeSelector(
                        value: houseProvider.transactionType ?? 'rent',
                        onChanged: (v) => houseProvider.setTransactionType(v),
                      ),
                    ),
                  ),
                // Đã bỏ ô compose "Bạn đang nghĩ gì?" (FbComposerBar): nút "Đăng tin"
                // cố định ở FAB giữa thanh dưới màn hình đã là lối đăng tin, nên khối
                // này dư thừa. Bộ lọc/Reel vẫn vào được từ AppBar và thanh dưới.
                // Khối REEL kiểu Facebook (full-bleed) — đặt giữa header và feed.
                if (FeatureFlags.reelsEnabled)
                  SliverToBoxAdapter(
                    child: ReelBar(
                      category: 'lease',
                      title: l.homeRealEstateReels,
                    ),
                  ),
                // Lối vào màn tổng hợp có bộ lọc. Đặt giữa dải Reel và feed chứ
                // không nhét lên AppBar: người mở tab này đang CUỘN, thứ nằm trên
                // đường cuộn mới được nhìn thấy.
                const SliverToBoxAdapter(child: ExploreTradeCard()),
                // Feed BĐS 1 cột — SliverList xây LƯỜI: chỉ dựng card trong/gần
                // viewport (tránh decode toàn bộ ảnh cùng lúc như ListView
                // shrinkWrap cũ) → cuộn mượt hơn nhiều.
                if (houseProvider.isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.list(
                      children: List.generate(
                        3,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: HouseCardSkeleton(),
                        ),
                      ),
                    ),
                  )
                else if (houseProvider.houses.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _listingPlaceholder(context, houseProvider),
                    ),
                  )
                else
                  // KHÔNG lề ngang: card chạm hai mép như feed Facebook trên điện
                  // thoại. [FbPostCard] tự bo góc khi màn ≥600px.
                  SliverList.builder(
                    itemCount: houseProvider.houses.length,
                    itemBuilder: (context, index) =>
                        _buildFeedCard(context, houseProvider.houses[index]),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (houseProvider.isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        if (!houseProvider.hasMore &&
                            houseProvider.houses.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                l.homeNoMoreRooms,
                                style: const TextStyle(
                                  color: HD.inkMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        // Chừa chỗ cho FAB "Đăng tin" (centerDocked) khỏi đè banner.
                        const SizedBox(height: 96),
                      ],
                    ),
                  ),
                ),
                // JP legal footer — required for Japan market compliance.
                // Shown only in JP builds; VN builds tree-shake this at compile time.
                if (FeatureFlags.isJapan)
                  const SliverToBoxAdapter(child: DsLegalFooter()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Trạng thái danh sách rỗng — phân biệt LỖI tải (có nút thử lại) và RỖNG
  /// thật (gợi ý xoá bộ lọc). Không bao giờ hiện chuỗi "không tìm thấy" trơ.
  Widget _listingPlaceholder(BuildContext context, HouseProvider hp) {
    final l = AppLocalizations.of(context);
    final isError = hp.loadError;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: HD.paperSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.cloud_off_outlined : Icons.search_off_outlined,
                color: HD.inkMuted,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isError ? l.homeLoadListFailed : l.homeNoMatchingListings,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HD.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isError ? l.homeCheckNetworkRetry : l.homeTryRemoveFilters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: HD.inkMuted),
            ),
            const SizedBox(height: 16),
            isError
                ? ElevatedButton.icon(
                    onPressed: () => hp.fetchHouses(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l.homeRetry),
                  )
                : OutlinedButton(
                    onPressed: () => hp.clearFilters(),
                    child: Text(l.homeClearFilters),
                  ),
          ],
        ),
      ),
    );
  }

  /// Thẻ tin BĐS kiểu bài đăng Facebook — 1 cột, full-width: header người
  /// đăng → ảnh lớn → thông tin → hàng hành động (Lưu / Liên hệ / Chi tiết).
  Widget _buildFeedCard(BuildContext context, HouseModel house) {
    final l = AppLocalizations.of(context);
    final myId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    final laChuTin = myId != null && myId == house.hostId;

    return RepaintBoundary(
      child: Consumer<WishlistProvider>(
        builder: (context, wishlist, _) {
          final daLuu = house.id != null && wishlist.isFavorited(house.id!);

          Future<void> luu() async {
            final user = Provider.of<AuthProvider>(
              context,
              listen: false,
            ).currentUser;
            if (user == null) {
              GuestGate.requireAuth(
                context,
                message: l.homeLoginToSaveFavorite,
              );
              return;
            }
            try {
              await wishlist.toggle(user.id!, house);
            } catch (_) {}
          }

          return FbPostCard(
            authorName: (house.hostName?.trim().isNotEmpty ?? false)
                ? house.hostName!.trim()
                : l.homeHost,
            subtitle: [
              if (house.district.isNotEmpty) house.district,
              if (house.city.isNotEmpty) house.city,
            ].join(' · '),
            badge: house.isTrusted
                ? const Icon(Icons.verified, size: 15, color: HD.accent)
                : null,
            body: house.title,
            media: _anhVaGia(house),
            onTap: () => context.push('/house/${house.id}'),
            // Bấm avatar/tên → trang cá nhân người đăng. hostId là int không
            // null nhưng dữ liệu cũ có thể về 0; 0 thì trang sẽ rỗng nên tắt.
            onTapAuthor: house.hostId > 0
                ? () => context.push('/sale/${house.hostId}')
                : null,
            onMore: () => ContentActionsSheet.show(
              context,
              targetType: ContentTargetType.house,
              targetId: house.id ?? 0,
              isSaved: daLuu,
              onToggleSave: luu,
            ),
            // Tin BĐS KHÔNG có like/bình luận trong model — dùng đúng các hành
            // động có thật, không vẽ nút bấm vào chẳng xảy ra gì.
            //
            // "Liên hệ" (nhắn tin với chủ nhà) và "Chi tiết" (mở trang tin) là
            // HAI chức năng khác nhau — trước đây cùng dẫn về /house/:id, nay
            // tách: Liên hệ mở thẳng khung chat, Chi tiết mở trang tin.
            actions: [
              if (!laChuTin)
                FbAction(
                  icon: daLuu ? Icons.favorite : Icons.favorite_border,
                  nhan: l.homeSave,
                  dangBat: daLuu,
                  onTap: luu,
                ),
              // Không hiện "Liên hệ" cho tin của chính mình — tự nhắn mình vô nghĩa.
              if (!laChuTin)
                FbAction(
                  icon: Icons.chat_bubble_outline,
                  nhan: l.homeContact,
                  onTap: () => _nhanTinChuNha(context, house),
                ),
              FbAction(
                icon: Icons.arrow_forward,
                nhan: l.homeDetails,
                onTap: () => context.push('/house/${house.id}'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Mở khung nhắn tin với chủ tin. Khác "Chi tiết" (mở trang tin): đây là
  /// chức năng liên hệ riêng. Khách chưa đăng nhập → mời đăng nhập.
  void _nhanTinChuNha(BuildContext context, HouseModel house) {
    final l = AppLocalizations.of(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      GuestGate.requireAuth(context, message: l.homeLoginToMessageHost);
      return;
    }
    // Phòng thủ: không tự nhắn mình (nút đã ẩn cho tin của mình, nhưng chắc chắn).
    if (user.id == house.hostId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: house.hostId,
          peerName: (house.hostName?.trim().isNotEmpty ?? false)
              ? house.hostName!.trim()
              : l.homeHost,
          peerAvatar: house.hostAvatar ?? '',
          houseId: house.id,
        ),
      ),
    );
  }

  /// Ảnh tràn viền + hàng giá/diện tích/khoảng cách ngay dưới — giữ nguyên
  /// thông tin cũ, chỉ đổi khung sang nhịp của [FbPostCard].
  Widget _anhVaGia(HouseModel house) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: house.images.isNotEmpty
                    ? house.images.first
                    : 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=700',
                fit: BoxFit.cover,
                memCacheWidth: 560,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, _) => Container(color: HD.paperSunken),
                errorWidget: (_, _, _) => Container(
                  color: HD.paperSunken,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.home_outlined,
                    size: 40,
                    color: HD.inkMuted,
                  ),
                ),
              ),
              if (house.isMultiUnit)
                Positioned(top: 10, left: 10, child: _multiUnitBadge(house)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: Row(
            children: [
              Text(
                house.priceCompactLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: HD.accent,
                ),
              ),
              const Text(
                '  ·  ',
                style: TextStyle(color: HD.inkMuted, fontSize: 13),
              ),
              Text(
                l.homeAreaM2(house.area.toStringAsFixed(0)),
                style: const TextStyle(
                  fontSize: 13,
                  color: HD.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (house.distanceLabel != null) ...[
                const Icon(Icons.near_me, size: 13, color: HD.accent),
                const SizedBox(width: 3),
                Text(
                  l.homeDistanceAway(house.distanceLabel!),
                  style: const TextStyle(
                    color: HD.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _multiUnitBadge(HouseModel house) {
    final l = AppLocalizations.of(context);
    final full = house.isFull;
    final color = full ? Colors.grey : HD.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            full ? Icons.do_not_disturb_on_outlined : Icons.meeting_room,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            full
                ? l.homeFull
                : l.homeAvailableUnits(house.availableUnits, house.totalUnits),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented control — "Cho thuê" / "Mua bán" — dùng [DsSegmented] Editorial style.
///
/// Selected state phản chiếu [value] từ [HouseProvider.transactionType].
/// Semantic label thay đổi theo tab đang chọn để screen reader (TalkBack /
/// VoiceOver) đọc "Bộ lọc: Cho thuê" hoặc "Bộ lọc: Mua bán".
class _TransactionTypeSelector extends StatelessWidget {
  const _TransactionTypeSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final options = [
      (value: 'rent', label: l.homeTabRent, icon: null as IconData?),
      (value: 'sale', label: l.homeTabSale, icon: null as IconData?),
    ];
    return Semantics(
      label: value == 'rent' ? l.homeFilterRent : l.homeFilterSale,
      child: Center(
        child: DsSegmented<String>(
          options: options,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
