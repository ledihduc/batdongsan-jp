import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Onboarding người dùng mới: giới thiệu "một app — hai thế giới" (Bất động sản
/// + Xây dựng) và các chức năng chính mỗi bên. 3 slide (hero 2 thế giới → lưới
/// BĐS → lưới Xây dựng); nút/dots/hero đổi màu theo thế giới của slide.
/// Route: gate trong app_router `_RootGate` (trước IntroSurvey). Provider: không.
/// Chỉ giới thiệu chức năng CÓ THẬT (không mua/bán — đang tắt cờ; homestay gộp
/// vào "Quản lý nhà trọ" cho chủ, chưa có luồng khách đặt).
const _onboardingKey = 'onboarding_done';

Future<bool> shouldShowOnboarding() async {
  try {
    const storage = FlutterSecureStorage();
    final v = await storage.read(key: _onboardingKey);
    return v != '1';
  } catch (_) {
    return false; // nếu plugin lỗi, bỏ qua onboarding
  }
}

Future<void> _markDone() async {
  try {
    const storage = FlutterSecureStorage();
    await storage.write(key: _onboardingKey, value: '1');
  } catch (_) {}
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;
  static const _slideCount = 3;

  /// Chỉ slide Xây dựng (index 2) là "thi công" → màu nâu. Slide hero (0) và BĐS
  /// (1) dùng màu xanh BĐS. worldAccent(false)=accent, worldAccent(true)=construction.
  bool get _laThiCong => _page == 2;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _markDone();
    widget.onFinish();
  }

  void _onNext() {
    if (_page == _slideCount - 1) {
      _finish();
    } else {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = HD.worldAccent(_laThiCong);
    return HDGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: HD.s12),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HD.s12),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(foregroundColor: HD.inkSoft),
                    child: Text(l.onboardingSkip,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _ctrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _HeroSlide(l: l),
                    _WorldSlide.realEstate(l),
                    _WorldSlide.construction(l),
                  ],
                ),
              ),
              // Chấm chỉ báo trang — màu active theo thế giới của slide.
              // Dùng `smooth_page_indicator` thay hai bản tự vẽ trước đây: nó
              // bám THẲNG vào PageController nên chấm trượt mượt theo ngón tay
              // khi vuốt dở chừng, chứ không nhảy nấc sau khi trang đã đổi.
              SmoothPageIndicator(
                controller: _ctrl,
                count: _slideCount,
                effect: ExpandingDotsEffect(
                  dotWidth: 8,
                  dotHeight: 8,
                  expansionFactor: 3,
                  spacing: 8,
                  activeDotColor: accent,
                  dotColor: HD.hairline,
                ),
              ),
              const SizedBox(height: HD.s24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: HD.s24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SizedBox(
                    width: double.infinity,
                    // Màu nút trượt xanh→nâu khi sang slide Xây dựng.
                    child: TweenAnimationBuilder<Color?>(
                      duration: const Duration(milliseconds: 300),
                      tween: ColorTween(end: accent),
                      builder: (context, color, _) => ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _onNext,
                        child: Text(
                          _page == _slideCount - 1
                              ? l.onboardingStart
                              : l.onboardingNext,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: HD.s24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slide 1 — "Một app, hai thế giới": 2 card khối lớn định vị ngay 2 mảng.
class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return _SlideFrame(
      children: [
        const SizedBox(height: HD.s24),
        // Màn ĐẦU TIÊN người lạ nhìn thấy sau lúc tải. Trước đây chỉ có chữ,
        // nên ấn tượng đầu không có nhận diện nào.
        const BrandLogo.full(size: 104),
        const SizedBox(height: HD.s20),
        Text(l.onboardingHeroTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: HD.ink)),
        const SizedBox(height: HD.s12),
        Text(l.onboardingHeroSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: HD.inkSoft, fontSize: 14, height: 1.5)),
        const SizedBox(height: HD.s32),
        Row(children: [
          Expanded(
            child: _WorldCard(
              icon: Icons.apartment_rounded,
              title: l.onboardingHeroCardReTitle,
              desc: l.onboardingHeroCardReDesc,
              accent: HD.accent,
              tint: HD.accentTint,
            ),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: _WorldCard(
              icon: Icons.architecture_rounded,
              title: l.onboardingHeroCardBuildTitle,
              desc: l.onboardingHeroCardBuildDesc,
              accent: HD.construction,
              tint: HD.constructionTint,
            ),
          ),
        ]),
      ],
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard(
      {required this.icon,
      required this.title,
      required this.desc,
      required this.accent,
      required this.tint});
  final IconData icon;
  final String title;
  final String desc;
  final Color accent;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HD.s16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: accent),
          const SizedBox(height: HD.s12),
          Text(title,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: accent)),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(
                  fontSize: 12.5, color: HD.inkSoft, height: 1.35)),
        ],
      ),
    );
  }
}

/// Slide 2/3 — hero gradient theo thế giới + lưới 3×2 icon-tile chức năng.
class _WorldSlide extends StatelessWidget {
  const _WorldSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.tint,
    required this.gradient,
    required this.features,
    this.caption,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color tint;
  final Gradient gradient;
  final List<(IconData, String)> features;
  final String? caption;

  factory _WorldSlide.realEstate(AppLocalizations l) => _WorldSlide(
        icon: Icons.apartment_rounded,
        title: l.onboardingReTitle,
        subtitle: l.onboardingReSubtitle,
        accent: HD.accent,
        tint: HD.accentTint,
        gradient: HD.accentGradient,
        features: [
          (Icons.search_rounded, l.onboardingReSearch),
          (Icons.home_work_rounded, l.onboardingReListings),
          (Icons.add_business_rounded, l.onboardingRePost),
          (Icons.event_available_rounded, l.onboardingReBooking),
          (Icons.meeting_room_rounded, l.onboardingReRooms),
          (Icons.dashboard_customize_rounded, l.onboardingReManage),
        ],
      );

  factory _WorldSlide.construction(AppLocalizations l) => _WorldSlide(
        icon: Icons.architecture_rounded,
        title: l.onboardingBuildTitle,
        subtitle: l.onboardingBuildSubtitle,
        accent: HD.construction,
        tint: HD.constructionTint,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HD.construction, HD.constructionDeep],
        ),
        features: [
          (Icons.draw_rounded, l.onboardingBuildDesign),
          (Icons.chair_rounded, l.onboardingBuildInterior),
          (Icons.engineering_rounded, l.onboardingBuildConstruct),
          (Icons.photo_library_rounded, l.onboardingBuildGallery),
          (Icons.menu_book_rounded, l.onboardingBuildKnowledge),
          (Icons.request_quote_rounded, l.onboardingBuildRfq),
        ],
        caption: l.onboardingBuildCaption,
      );

  @override
  Widget build(BuildContext context) {
    return _SlideFrame(
      children: [
        // Hero gradient bo đáy — icon + tiêu đề trắng.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(HD.s24),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Column(children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: HD.s12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ]),
        ),
        const SizedBox(height: HD.s16),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: HD.inkSoft, fontSize: 14, height: 1.5)),
        const SizedBox(height: HD.s24),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: HD.s12,
          crossAxisSpacing: HD.s12,
          childAspectRatio: 0.9,
          children: [
            for (final (ic, label) in features)
              _FeatureTile(
                  icon: ic, label: label, tileColor: tint, iconColor: accent),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: HD.s16),
          Text(caption!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HD.inkMuted, fontSize: 12)),
        ],
      ],
    );
  }
}

/// Ô icon-tile trình bày (không điều hướng) — mẫu tham số hoá màu từ
/// home_services_section._tile để dùng chung cho cả 2 thế giới.
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.tileColor,
    required this.iconColor,
  });
  final IconData icon;
  final String label;
  final Color tileColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(height: HD.s8),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12, height: 1.15, color: HD.ink)),
      ],
    );
  }
}

/// Khung chung mỗi slide: giới hạn bề rộng desktop + cuộn được trên màn thấp.
class _SlideFrame extends StatelessWidget {
  const _SlideFrame({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: HD.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}
