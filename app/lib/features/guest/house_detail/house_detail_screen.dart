import 'package:house_booking/features/guest/booking/room_booking_screen.dart';
// ⚠️ GOD-FILE ~1240 dòng — 1 màn chi tiết nhà (1 State đơn khối). Tách section
// widget là refactor sâu (AI-REFACTOR-PLAN §A3, chưa làm). MỤC LỤC method:
//   _buildBookingBanner 562 · _buildPropertySpecs 683 · _buildIndustrialSpecs 806 ·
//   _availabilityBadge 868 · _buildHostCard 943 · _buildReviewsBlock 1122 ·
//   _buildActionButton 739 · _loadReviews 61
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/utils/privacy_mask.dart';
import 'package:house_booking/core/widgets/empty_state.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/models/review_model.dart';
import 'package:house_booking/data/services/review_service.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/guest/booking/booking_history_screen.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/features/guest/tools/loan_calculator_screen.dart';
import 'package:house_booking/features/guest/house_detail/widgets/quality_card.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/features/guest/booking/yeu_cau_xem_phong_screen.dart';
import 'package:house_booking/features/planning/widgets/planning_badge.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/ds_trusted_badge.dart';
import 'package:house_booking/core/config/env.dart';
// JP market (Phase 01) — gated behind FeatureFlags.isJapan at runtime.
import 'package:house_booking/features/guest/listing/jp_terms_section.dart';
import 'package:house_booking/features/guest/listing/jp_property_info_section.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_listing_repository.dart';
import 'package:house_booking/data/models/jp/jp_listing.dart';

class HouseDetailScreen extends StatefulWidget {
  final int houseId;
  const HouseDetailScreen({super.key, required this.houseId});

  @override
  State<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends State<HouseDetailScreen> {
  int _carouselIndex = 0;

  /// Cần controller để chấm chỉ báo bám theo ngón tay khi vuốt dở chừng —
  /// `SmoothPageIndicator` đọc thẳng từ đây thay vì chờ trang đổi xong.
  final PageController _anhCtrl = PageController();
  final _reviewService = ReviewService();
  ReviewSummary? _reviewSummary;
  bool _apptFetched = false;

  // ── JP market (Phase 01) ──────────────────────────────────────────────────
  JpListing? _jpListing;
  final _jpRepo = const MockJpListingRepository();

  @override
  void dispose() {
    _anhCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HouseProvider>(
        context,
        listen: false,
      ).selectHouse(widget.houseId);
      _loadReviews();
      final user = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser;
      if (user != null) {
        Provider.of<ViewingAppointmentProvider>(
          context,
          listen: false,
        ).fetchAppointments(user.id!, 'guest').whenComplete(() {
          if (mounted) setState(() => _apptFetched = true);
        });
      }
      // JP market: load JP listing data when region=jp.
      if (FeatureFlags.isJapan) {
        _jpRepo.getById(widget.houseId).then((jp) {
          if (mounted) setState(() => _jpListing = jp);
        }).catchError((_) {/* JP listing not found — show VN-only content */});
      }
    });
  }

  Future<void> _loadReviews() async {
    try {
      final s = await _reviewService.fetchByHouse(widget.houseId);
      if (mounted) setState(() => _reviewSummary = s);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final houseProvider = Provider.of<HouseProvider>(context);
    final house = houseProvider.selectedHouse;
    final apptProvider = Provider.of<ViewingAppointmentProvider>(context);
    final ViewingAppointmentModel? myAppt = (house != null && _apptFetched)
        ? _activeAppointment(apptProvider.appointments, widget.houseId)
        : null;

    return Scaffold(
      // Nền xám để các khối trắng nổi lên — nhịp của feed Facebook.
      backgroundColor: HD.paper,
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.hdBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          Brand.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: l.hdShare,
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final h = Provider.of<HouseProvider>(
                context,
                listen: false,
              ).selectedHouse;
              if (h == null) return;
              // Trước đây link trỏ 'urbannest.app' — tên miền KHÔNG tồn tại,
              // khách bấm vào là lỗi. Nay trỏ site công khai SSR (có preview
              // Zalo/Facebook + Google đọc được).
              final link = Env.housePublicUrl(h.id!, h.title);
              Clipboard.setData(ClipboardData(text: link));
              AppFeedback.info(context, l.hdLinkCopied);
            },
          ),
        ],
      ),
      body: houseProvider.isLoading || house == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (house.shortStay != null || house.hangPhong != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DsButton(
                        label: '短期宿泊を予約 · 料金・ポリシーを確認',
                        icon: Icons.bed_outlined,
                        expand: true,
                        onPressed: () => _datNganHan(house),
                      ),
                    ),
                  // Image Carousel
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      SizedBox(
                        height: 260,
                        child: house.images.isEmpty
                            ? Container(
                                color: HD.paperSunken,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.home_outlined,
                                  size: 64,
                                  color: HD.inkMuted,
                                ),
                              )
                            : PageView.builder(
                                controller: _anhCtrl,
                                onPageChanged: (i) =>
                                    setState(() => _carouselIndex = i),
                                itemCount: house.images.length,
                                itemBuilder: (context, index) {
                                  return Semantics(
                                    label: l.hdImageLabel(
                                      house.title,
                                      index + 1,
                                    ),
                                    // Chạm để xem to: trước đây ảnh trong tin
                                    // KHÔNG mở to được, trong khi xem kỹ ảnh
                                    // chính là việc người mua làm nhiều nhất.
                                    child: GestureDetector(
                                      onTap: () => showImageGallery(
                                        context,
                                        house.images,
                                        initialIndex: index,
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: house.images[index],
                                        fit: BoxFit.cover,
                                        // Full-screen carousel — cache ở 1080px
                                        // đủ cho hầu hết device, giảm RAM ~3x.
                                        memCacheWidth: 1080,
                                        fadeInDuration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        placeholder: (_, __) =>
                                            Container(color: HD.paperSunken),
                                        errorWidget: (_, __, ___) => Container(
                                          color: HD.paperSunken,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: HD.inkMuted,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      if (house.images.length > 1)
                        Positioned(
                          bottom: 12,
                          child: SmoothPageIndicator(
                            controller: _anhCtrl,
                            count: house.images.length,
                            effect: WormEffect(
                              dotWidth: 8,
                              dotHeight: 8,
                              spacing: 6,
                              activeDotColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              // Ảnh nền có sáng có tối → chấm mờ phải đủ đục
                              // để không biến mất trên ảnh sáng.
                              dotColor: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      if (house.images.length > 1)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_carouselIndex + 1}/${house.images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      // Trusted badge — top-left, away from image counter (top-right)
                      if (house.isTrusted)
                        const Positioned(
                          top: 12,
                          left: 12,
                          child: DsTrustedBadge(),
                        ),
                    ],
                  ),

                  // Content — khối TRẮNG trên nền xám [HD.paper], tách khỏi ảnh
                  // bằng 8px giống cách Facebook xếp các khối nội dung.
                  Container(
                    color: HD.paperRaised,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    house.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: HD.ink,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${house.address}, ${house.district}, ${house.city}',
                                          style: const TextStyle(
                                            color: HD.inkSoft,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  PriceFormat.full(house.price),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                // Chỉ tin cho thuê mới có kỳ giá "/tháng"; tin bán
                                // là giá trọn gói nên không hiển thị hậu tố.
                                if (house.isForRent)
                                  Text(
                                    // 短期物件の価格表示は1泊単位。
                                    (house.shortStay != null ||
                                            house.hangPhong != null)
                                        ? '/泊'
                                        : l.hdPerMonth,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: HD.inkSoft,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                _availabilityBadge(house),
                              ],
                            ),
                          ],
                        ),
                        // Badge quy hoạch async (AC-04) — chỉ render khi có tọa độ hợp lệ.
                        // Fail-silent: nếu API fail badge sẽ tự ẩn (PlanningBadge xử lý nội bộ).
                        if (house.latitude != null &&
                            house.longitude != null &&
                            house.latitude != 0.0 &&
                            house.longitude != 0.0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: PlanningBadge(
                              lat: house.latitude!,
                              lng: house.longitude!,
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Máy tính vay — chỉ cho tin BÁN (mua nhà thường cần vay).
                        // Pivot 2026-07: ẩn khi bỏ mảng mua/bán (SALE_ENABLED off).
                        if (house.isForSale && FeatureFlags.saleEnabled) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              foregroundColor: HD.accent,
                              side: const BorderSide(color: HD.accent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.calculate_outlined,
                              size: 18,
                            ),
                            label: Text(l.hdLoanCalc),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoanCalculatorScreen(
                                  initialPrice: house.price.round(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (myAppt != null) ...[
                          _buildBookingBanner(myAppt),
                          const SizedBox(height: 16),
                        ],

                        // Specs Row (hàng tóm tắt)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: HD.hairline,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSpecItem(
                                Icons.bed,
                                l.hdBedroomsShort(house.bedrooms),
                              ),
                              _buildSpecItem(
                                Icons.bathtub,
                                l.hdBathroomsShort(house.bathrooms),
                              ),
                              _buildSpecItem(
                                Icons.square_foot,
                                l.hdAreaSqm(house.area.toStringAsFixed(0)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sao chất lượng cơ sở (mảng thuê) — tách bạch với review.
                        if (house.isForRent)
                          QualityCard(
                            houseId: house.id!,
                            isOwner:
                                Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                ).currentUser?.id ==
                                house.hostId,
                          ),

                        _buildPropertySpecs(house),
                        const SizedBox(height: 24),

                        // BĐS công nghiệp (P3) — thông số KCN.
                        if (house.isIndustrial &&
                            (house.industrialAttrs?.isNotEmpty ?? false)) ...[
                          _buildIndustrialSpecs(house.industrialAttrs!),
                          const SizedBox(height: 24),
                        ],

                        // JP market (Phase 01) — 物件情報 + 賃貸条件 sections.
                        if (FeatureFlags.isJapan && _jpListing != null) ...[
                          JpPropertyInfoSection(
                            propertyInfo: _jpListing!.propertyInfo,
                            transitAccesses: _jpListing!.transitAccesses,
                          ),
                          JpTermsSection(terms: _jpListing!.rentalTerms),
                          const SizedBox(height: 8),
                        ],

                        if (house.description.trim().isNotEmpty) ...[
                          Text(
                            l.hdDescriptionTitle,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: HD.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            house.description,
                            style: const TextStyle(
                              color: HD.inkSoft,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),

                  // Khối TRẮNG riêng: đánh giá. Facebook tách mỗi nhóm nội dung
                  // thành một khối cách nhau 8px thay vì đổ hết vào một tấm dài
                  // — mắt bắt được ranh giới mà không cần đọc tiêu đề.
                  Container(
                    color: HD.paperRaised,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    child: _buildReviewsBlock(),
                  ),

                  // Khối TRẮNG riêng: chủ nhà.
                  Container(
                    color: HD.paperRaised,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.hdHostInfoTitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: HD.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHostCard(
                          context,
                          house.hostName,
                          house.hostAvatar,
                          house.hostPhone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomSheet: house == null
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Consumer<WishlistProvider>(
                    builder: (context, wishlist, _) {
                      // Chủ tin không thả tim tin của chính mình → ẩn nút.
                      final myId = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).currentUser?.id;
                      if (myId != null && myId == house.hostId) {
                        return const SizedBox.shrink();
                      }
                      final isFav = wishlist.isFavorited(house.id!);
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          side: BorderSide(
                            color: isFav ? HD.accent : HD.hairline,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          // Browse-first: khách chưa đăng nhập → mời đăng nhập.
                          if (!GuestGate.requireAuth(
                            context,
                            message: l.hdLoginToSave,
                          )) {
                            return;
                          }
                          final user = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).currentUser;
                          if (user == null) return;
                          try {
                            await wishlist.toggle(user.id!, house);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l.hdFavUpdateFailed)),
                              );
                            }
                          }
                        },
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? HD.accent : HD.ink,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildActionButton(house, myAppt)),
                ],
              ),
            ),
    );
  }

  ViewingAppointmentModel? _activeAppointment(
    List<ViewingAppointmentModel> list,
    int houseId,
  ) {
    final mine = list.where((a) => a.houseId == houseId).toList();
    if (mine.isEmpty) return null;
    mine.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final a in mine) {
      if (a.status == 'pending' ||
          a.status == 'approved' ||
          a.status == 'locked') {
        return a;
      }
    }
    return mine.first; // lịch cũ đã kết thúc (rejected/completed/cancelled)
  }

  String _formatDate(String ymd) {
    final p = ymd.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : ymd;
  }

  String? _legalLabel(String? s) {
    final l = AppLocalizations.of(context);
    switch (s) {
      case 'red_book':
        return l.hdLegalRedBook;
      case 'pink_book':
        return l.hdLegalPinkBook;
      case 'sale_contract':
        return l.hdLegalSaleContract;
      case 'pending':
        return l.hdLegalPending;
    }
    return null;
  }

  String _specPriceValue(HouseModel h) {
    if (h.isForSale) return PriceFormat.compact(h.price);
    final gia = _giaNganHan(h);
    if (gia != null) return gia;
    final tr = h.price / 1000000;
    final s = tr == tr.roundToDouble()
        ? tr.toStringAsFixed(0)
        : tr.toStringAsFixed(1).replaceAll('.', ',');
    return AppLocalizations.of(context).hdPricePerMonth(s);
  }

  Widget _buildBookingBanner(ViewingAppointmentModel a) {
    final l = AppLocalizations.of(context);
    Color bg, fg;
    IconData icon;
    String title, subtitle;
    final sched = '${_formatDate(a.bookingDate)} · ${a.bookingTime}';
    switch (a.status) {
      case 'approved':
        bg = HD.positiveTint;
        fg = HD.positive;
        icon = Icons.check_circle;
        title = l.hdApptApprovedTitle;
        subtitle = l.hdApptApprovedSub(sched);
        break;
      case 'rejected':
        bg = HD.negativeTint;
        fg = HD.negative;
        icon = Icons.cancel;
        title = l.hdApptRejectedTitle;
        subtitle = l.hdApptRejectedSub;
        break;
      case 'cancelled':
        bg = HD.paperSunken;
        fg = HD.inkMuted;
        icon = Icons.event_busy;
        title = l.hdApptCancelledTitle;
        subtitle = l.hdApptCancelledSub;
        break;
      case 'completed':
        bg = HD.accentTint;
        fg = HD.accent;
        icon = Icons.event_available;
        title = l.hdApptCompletedTitle;
        subtitle = sched;
        break;
      case 'locked':
        bg = HD.paperSunken;
        fg = HD.inkMuted;
        icon = Icons.lock_clock;
        title = l.hdApptLockedTitle;
        subtitle = sched;
        break;
      default: // pending
        bg = HD.warningTint;
        fg = HD.warning;
        icon = Icons.hourglass_top;
        title = l.hdApptPendingTitle;
        subtitle = l.hdApptPendingSub(sched);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: HD.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HD.paper,
              border: Border.all(color: HD.hairline),
            ),
            child: Icon(icon, size: 18, color: HD.accent),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: const TextStyle(color: HD.inkMuted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: HD.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertySpecs(HouseModel house) {
    final l = AppLocalizations.of(context);
    final rows = <Widget>[];
    void add(IconData icon, String label, String? value) {
      if (value == null || value.trim().isEmpty) return;
      rows.add(_buildSpecRow(icon: icon, label: label, value: value));
    }

    add(Icons.attach_money, l.hdSpecPrice, _specPriceValue(house));
    add(
      Icons.crop_free,
      l.hdSpecArea,
      house.area > 0 ? l.hdAreaSqm(house.area.toStringAsFixed(0)) : null,
    );
    add(
      Icons.bed,
      l.hdSpecBedrooms,
      house.bedrooms > 0 ? l.hdRoomsCount(house.bedrooms) : null,
    );
    add(
      Icons.bathtub_outlined,
      l.hdSpecBathrooms,
      house.bathrooms > 0 ? l.hdRoomsCount(house.bathrooms) : null,
    );
    add(Icons.home_work_outlined, l.hdSpecType, house.categoryName);
    final hang = house.hangPhong;
    if (hang != null) {
      add(Icons.meeting_room_outlined, '部屋タイプ', hang['ten'] as String?);
      final so = (hang['so_phong'] as num?)?.toInt() ?? 0;
      // 同タイプの空室数を表示 — 部屋番号はチェックイン時にフロントが割り当てる。
      add(
        Icons.door_front_door_outlined,
        '同タイプ室数',
        so > 0 ? '$so室' : null,
      );
      final suc = (hang['suc_chua'] as num?)?.toInt() ?? 0;
      add(Icons.people_outline, '定員', suc > 0 ? '$suc名' : null);
      add(Icons.king_bed_outlined, 'ベッドタイプ', hang['giuong'] as String?);
    }
    if (house.isForSale) {
      add(
        Icons.verified_outlined,
        l.hdSpecLegal,
        _legalLabel(house.legalStatus),
      );
    }
    add(
      Icons.weekend_outlined,
      l.hdSpecFurniture,
      house.amenities.isNotEmpty ? house.amenities.join(', ') : null,
    );

    if (rows.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(
          const Divider(height: 1, thickness: 0.5, color: HD.hairline),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.hdPropertySpecsTitle,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: HD.ink,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HD.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(children: children),
        ),
      ],
    );
  }

  /// "70.000đ/giờ · 380.000đ/đêm · 480.000đ/ngày" — ba giá của phòng ngắn hạn.
  /// Tin neo HẠNG lấy giá của hạng (`hang_phong`), tin neo phòng lấy giá kênh
  /// của phòng (`short_stay.products`) — một hàm cho cả hai để màn chi tiết
  /// không bao giờ hiện giá ở chỗ này mà thiếu ở chỗ kia.
  String? _giaNganHan(HouseModel h) {
    final hang = h.hangPhong;
    if (hang != null) {
      final ds = <String>[
        for (final k in const [
          ('gia_theo_gio', 'giờ'),
          ('gia_qua_dem', 'đêm'),
          ('gia_theo_ngay', 'ngày'),
        ])
          if (hang[k.$1] is num)
            '${PriceFormat.full((hang[k.$1] as num).toDouble())}/${k.$2}',
      ];
      if (ds.isNotEmpty) return ds.join(' · ');
    }
    final ds = (h.shortStay?['products'] as List?) ?? const [];
    if (ds.isEmpty) return null;
    return [
      for (final p in ds)
        if (p is Map && p['unit_price'] is num)
          '${PriceFormat.full((p['unit_price'] as num).toDouble())}/${p['unit']}',
    ].join(' · ');
  }

  void _datNganHan(HouseModel house) {
    if (!GuestGate.requireAuth(context, message: 'ログインして予約してください')) {
      return;
    }
    // Tin neo HẠNG: app KHÔNG chọn phòng — server bốc phòng trống lúc chốt
    // đơn (`/api/short-stays/tin/{id}/dat`). Gửi roomId ở đây là tự chọn hộ
    // khách một phòng có thể vừa có người giữ.
    final hang = house.hangPhong;
    final args = hang != null
        ? RoomBookingArgs(
            roomId: 0,
            roomCode: '',
            buildingName:
                (hang['toa'] as Map?)?['ten'] as String? ?? house.address,
            price: 0,
            saleName: '',
            houseId: house.id,
            theoHang: true,
          )
        : RoomBookingArgs(
            roomId: house.sourceRoomId!,
            roomCode: house.shortStay!['room_code'] as String,
            buildingName: house.shortStay!['building_name'] as String,
            price: 0,
            saleName: '',
            // Ghi lại tin nào dẫn khách về — để công của đơn thuộc đúng
            // người rao tin.
            houseId: house.id,
          );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomBookingScreen(args: args)),
    );
  }

  Widget _buildActionButton(HouseModel house, ViewingAppointmentModel? appt) {
    final l = AppLocalizations.of(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null && user.id == house.hostId) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.home_outlined),
        label: Text(l.hdYourListing),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
      );
    }
    // Phòng ngắn hạn thì khách ĐẶT Ở, không hẹn đi xem.
    if (house.hangPhong != null ||
        (house.shortStay != null && house.sourceRoomId != null)) {
      return ElevatedButton.icon(
        key: const Key('hd-dat-ngan-han'),
        icon: const Icon(Icons.bed_outlined),
        label: const Text('予約する'),
        onPressed: () => _datNganHan(house),
      );
    }
    final active =
        appt != null &&
        (appt.status == 'pending' ||
            appt.status == 'approved' ||
            appt.status == 'locked');
    if (active) {
      final color = appt.status == 'approved' ? HD.positive : HD.warning;
      return OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
        ),
        icon: Icon(Icons.event_note, color: color),
        label: Text(l.hdViewBooking, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    final again = appt != null; // đã từng đặt nhưng lịch cũ đã kết thúc
    return ElevatedButton.icon(
      icon: const Icon(Icons.calendar_today),
      label: Text(again ? l.hdRebookViewing : l.hdBookViewing),
      onPressed: () {
        // Browse-first: khách chưa đăng nhập → mời đăng nhập trước khi đặt lịch.
        if (!GuestGate.requireAuth(context, message: l.hdLoginToBook)) {
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YeuCauXemPhongScreen(houseId: house.id!),
          ),
        );
      },
    );
  }

  Widget _buildSpecItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, color: HD.ink),
        ),
      ],
    );
  }

  /// Thẻ thông số BĐS công nghiệp (P3): diện tích ha, tải điện, PCCC, pháp lý KCN.
  /// Chỉ render các trường có mặt trong industrial_attrs.
  Widget _buildIndustrialSpecs(Map<String, dynamic> attrs) {
    final l = AppLocalizations.of(context);
    final rows = <Widget>[];
    void add(IconData icon, String label, String value) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: HD.accent),
              const SizedBox(width: 8),
              Text('$label: ', style: const TextStyle(color: HD.inkSoft)),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: HD.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final areaHa = attrs['area_ha'];
    if (areaHa is num)
      add(Icons.crop_square, l.hdSpecArea, l.hdAreaHa('$areaHa'));
    final power = attrs['power_mva'];
    if (power is num) add(Icons.bolt, l.hdIndPower, l.hdPowerMva('$power'));
    if (attrs['fire_safety'] is bool) {
      add(
        Icons.local_fire_department,
        l.hdIndFireSafety,
        attrs['fire_safety'] == true ? l.hdHas : l.hdHasNot,
      );
    }
    final legal = attrs['kcn_legal'];
    if (legal is String && legal.trim().isNotEmpty) {
      add(Icons.gavel, l.hdIndLegal, legal);
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.hdIndustrialSpecsTitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: HD.ink,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _availabilityBadge(dynamic house) {
    final l = AppLocalizations.of(context);
    // Tin bán: không có khái niệm "phòng"/units → badge "Đang bán".
    if (house.isForSale as bool) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: HD.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sell_outlined, color: HD.accent, size: 12),
            const SizedBox(width: 4),
            Text(
              l.hdForSale,
              style: const TextStyle(
                color: HD.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    if (house.isMultiUnit as bool) {
      final full = house.isFull as bool;
      final color = full ? Colors.grey : HD.accent;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              full ? Icons.do_not_disturb_on_outlined : Icons.meeting_room,
              color: color,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              full
                  ? l.hdFull
                  : l.hdUnitsAvailable(house.availableUnits, house.totalUnits),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HD.positiveTint.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        l.hdAvailable,
        style: const TextStyle(
          color: HD.positive,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHostCard(
    BuildContext context,
    String? name,
    String? avatar,
    String? phone,
  ) {
    final l = AppLocalizations.of(context);
    final maskedName = PrivacyMask.name(name);
    final maskedPhone = PrivacyMask.phone(phone);
    // Nút "Nhắn tin với chủ nhà" chỉ dành cho NGƯỜI XEM (không phải chủ của
    // chính tin này). Ẩn khi user hiện tại là chủ sở hữu bài đăng — khớp
    // pattern đã dùng ở nút thả tim (:388) và nút đặt lịch (_buildActionButton).
    // Lưu ý: /house/:id đã yêu cầu đăng nhập (app_router redirect), nên
    // currentUser gần như luôn != null trên màn này.
    final me = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final house = Provider.of<HouseProvider>(
      context,
      listen: false,
    ).selectedHouse;
    final isOwnListing = me != null && house != null && me.id == house.hostId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.hairline.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: HD.accentTint,
                backgroundImage: (avatar != null && avatar.isNotEmpty)
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: (avatar == null || avatar.isEmpty)
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            maskedName ?? l.hdHost,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: HD.ink,
                            ),
                          ),
                        ),
                        // Badge "đã xác minh CCCD" — tín hiệu uy tín chủ nhà.
                        if (house?.hostVerified ?? false) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: l.hdHostVerifiedTooltip,
                            child: const Icon(
                              Icons.verified,
                              size: 16,
                              color: HD.accent,
                            ),
                          ),
                        ],
                        // Badge "Chủ nhà tin cậy" (Superhost-style, Đợt 3).
                        if (house?.hostTrusted ?? false) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: l.hdHostTrustedTooltip,
                            child: const Icon(
                              Icons.workspace_premium,
                              size: 16,
                              color: HD.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Sao trung bình + tốc độ phản hồi (Đợt 1 uy tín).
                    if (house != null &&
                        (house.hostRating != null ||
                            house.hostAvgResponseHours != null)) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (house.hostRating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              house.hostRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HD.inkSoft,
                              ),
                            ),
                          ],
                          if (house.hostRating != null &&
                              house.hostAvgResponseHours != null)
                            const Text(
                              '  ·  ',
                              style: TextStyle(
                                color: HD.inkMuted,
                                fontSize: 12,
                              ),
                            ),
                          if (house.hostAvgResponseHours != null)
                            Text(
                              l.hdResponseTime(
                                house.hostAvgResponseHours!.toStringAsFixed(0),
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: HD.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (maskedPhone != null && maskedPhone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: HD.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            maskedPhone,
                            style: const TextStyle(
                              color: HD.inkSoft,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.hdHidden,
                            style: const TextStyle(
                              fontSize: 10,
                              color: HD.inkMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Chỉ hiển thị cho người xem (không phải chủ tin này).
          if (!isOwnListing) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.chat_outlined),
              label: Text(l.hdMessageHost),
              onPressed: () {
                // Chưa đăng nhập (phòng thủ) → điều hướng đăng nhập.
                if (me == null) {
                  context.push('/login');
                  return;
                }
                if (house == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      peerId: house.hostId,
                      peerName: maskedName ?? l.hdHost,
                      peerAvatar: avatar ?? '',
                      houseId: house.id,
                      // Đính kèm tin dạng THẺ (ảnh nhỏ + tiêu đề + giá) — không
                      // dán link thô — ghim đầu cuộc trò chuyện.
                      houseTitle: house.title,
                      houseImage: house.images.isNotEmpty
                          ? house.images.first
                          : null,
                      housePrice: house.price,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsBlock() {
    final l = AppLocalizations.of(context);
    final s = _reviewSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.hdReviewsTitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: HD.ink,
              ),
            ),
            const Spacer(),
            if (s != null && s.count > 0) ...[
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                '${s.average} (${s.count})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (s == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (s.reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l.hdNoReviews,
              style: const TextStyle(color: HD.inkMuted, fontSize: 13),
            ),
          )
        else
          ...s.reviews.take(3).map(_buildReviewItem),
        if (s != null && s.reviews.length > 3)
          TextButton(
            onPressed: () {},
            child: Text(l.hdViewAllReviews(s.reviews.length)),
          ),
      ],
    );
  }

  Widget _buildReviewItem(ReviewModel r) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: HD.accentTint,
                backgroundImage:
                    (r.userAvatar != null && r.userAvatar!.isNotEmpty)
                    ? CachedNetworkImageProvider(r.userAvatar!)
                    : null,
                child: (r.userAvatar == null || r.userAvatar!.isEmpty)
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.userName ?? l.hdUser,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < r.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.comment,
              style: const TextStyle(
                color: HD.inkSoft,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
