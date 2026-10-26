import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/fb_profile_header.dart';
import 'package:house_booking/core/widgets/full_image_viewer.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/auth/hoan_thien_ho_so_screen.dart';
import 'package:house_booking/features/guest/wishlist/wishlist_screen.dart';
import 'package:house_booking/features/guest/profile/ho_so_thieu.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/sale/link_sale_screen.dart';
import 'package:house_booking/features/guest/sale/sale_code_screen.dart';
import 'package:house_booking/features/guest/project/sale_projects_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_list_screen.dart';
import 'package:house_booking/features/host/profile/host_profile_screen.dart';
import 'package:house_booking/features/host/property/screens/building_list_screen.dart';
import 'package:house_booking/features/guest/home/widgets/home_map_preview.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/features/chat/conversations_screen.dart';
import 'package:house_booking/features/guest/service/my_service_requests_screen.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/features/guest/profile/settings_screen.dart';
import 'package:house_booking/features/guest/profile/sale_settings_screen.dart';
import 'package:house_booking/features/guest/booking/booking_history_screen.dart';
import 'package:house_booking/features/guest/profile/edit_profile_screen.dart';
import 'package:house_booking/features/host/host_home_screen.dart';
import 'package:house_booking/features/host/profile/my_listings_screen.dart';

/// Màn tài khoản dạng DANH SÁCH MỤC.
///
/// ⚠️ HIỆN CHỈ CÒN TỚI ĐƯỢC KHI CHƯA ĐĂNG NHẬP. Tab Cá nhân của người đã đăng
/// nhập nay là `BrokerProfileScreen(laChuTrang: true)` — trang công khai của
/// chính họ, sửa tại chỗ (xem `guest_shell.dart`). Nhánh dựng cho người đã đăng
/// nhập ở dưới vì thế KHÔNG chạy trong app; lối vào các mục của nó đã chuyển
/// sang `SaleSettingsScreen` (sau nút ⚙).
///
/// CỐ Ý GIỮ LẠI chứ không xoá: tab Cá nhân đã đổi qua đổi lại giữa hai màn này
/// trong cùng một ngày (07/09/2026), và đây là bản duy nhất còn giữ nguyên vẹn
/// menu tài khoản đầy đủ. Xoá đi thì lần đổi ý sau phải dựng lại từ đầu.
/// Nếu chốt hẳn không quay lại nữa thì xoá cả tệp này lẫn
/// `test/features/guest/profile/profile_screen_test.dart`.
class ProfileScreen extends StatelessWidget {
  final ValueChanged<int>? onJumpTab;

  /// Slot vật lý của tab "Yêu thích" trong shell — shell truyền xuống thay vì
  /// hardcode ở đây.
  /// Ô nào ở thanh dưới là Yêu thích. **`-1` = không còn ô nào** — từ khi ô đó
  /// nhường chỗ cho "Đã đặt", trang này phải TỰ MỞ `WishlistScreen` bằng push.
  /// Nhảy tới tab -1 thì không có gì xảy ra cả, và người dùng chỉ thấy một cú
  /// bấm chết.
  final int wishlistTab;

  const ProfileScreen({super.key, this.onJumpTab, this.wishlistTab = 2});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Browse-first: khách chưa đăng nhập → trạng thái mời đăng nhập (không crash).
    // listen:TRUE (không phải false) — màn hồ sơ PHẢI tự rebuild khi phiên đổi
    // (đăng xuất/đăng nhập). Trước đây listen:false khiến bấm "Đăng xuất" xong
    // hồ sơ vẫn hiện thông tin cũ nếu shell không bị thay — nay phản ứng trực tiếp.
    final maybeUser = Provider.of<AuthProvider>(context).currentUser;
    if (maybeUser == null) {
      return GuestTabPlaceholder(
        title: l.profPersonal,
        icon: Icons.person_outline,
        message: l.profLoginPrompt,
      );
    }
    final user = maybeUser;
    final hp = Provider.of<HouseProvider>(context);
    final ap = Provider.of<ViewingAppointmentProvider>(context);
    final wp = Provider.of<WishlistProvider>(context);

    final myListings = hp.myHouses.isNotEmpty
        ? hp.myHouses.length
        : hp.houses.where((h) => h.hostId == user.id).length;

    // KHÔNG lồng Scaffold: [GuestShell] bên ngoài đã sở hữu Scaffold rồi. Lồng
    // thêm sẽ nhân đôi padding của MediaQuery và khiến ScaffoldMessenger trỏ
    // vào scaffold trong (snackbar biến mất khi đổi tab) — cùng lý do đã ghi ở
    // _HostBuildingsTab.
    //
    // Thanh tiêu đề "TÀI KHOẢN / Cá nhân" đã BỎ: tab đáy đang sáng đã cho biết
    // người dùng ở đâu, nhắc lại tốn ~78px trong khi danh sách "Của tôi" chỉ
    // còn ~1,5 dòng trên màn 6.1". Cài đặt + Đăng xuất chuyển thành nút nổi
    // trên ảnh bìa nên KHÔNG mất lối vào.
    return ColoredBox(
      color: HD.paper,
      // MỘT mạch cuộn dọc. ĐÃ BỎ khối "Bài viết của bạn" ở đáy: toàn hệ thống
      // chưa có bài viết nào, nên nó chiếm trọn hơn một màn hình chỉ để nói
      // "chưa có gì" — đúng vết xe của khối Reel. Bỏ luôn NestedScrollView vì
      // nó chỉ tồn tại để nuôi khối đó; giờ chỉ còn một danh sách cuộn.
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _dauTrang(context, user)),
          // NHẮC ĐIỀN HỒ SƠ — ngay dưới đầu trang, trước danh sách mục.
          //
          // Mọi tài khoản mới là tài khoản bán, nhưng form đăng ký chỉ lấy
          // tên/email/mật khẩu (SĐT tuỳ chọn). Ai đăng ký từ trước bản có bước
          // nhập bắt buộc, hoặc bỏ dở giữa chừng, thì đây là lối vào duy nhất
          // để điền nốt. Thẻ tự ẩn khi đã đủ.
          SliverToBoxAdapter(
            child: TheHoanThienHoSo(
              thieu: HoSoThieu.tu(user),
              onNhan: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HoanThienHoSoScreen()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _myStuff(context, user, ap, wp, myListings),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: HD.s24)),
        ],
      ),
    );
  }

  Widget _dauTrang(BuildContext context, dynamic user) {
    final l = AppLocalizations.of(context);

    // Điểm uy tín chỉ tồn tại trên hồ sơ chủ nhà; gọi endpoint đó bằng tài
    // khoản khách sẽ 403 nên vẫn phải khoá theo vai. Nó chỉ thêm một cụm ★ vào
    // dòng phụ, không đổi bố cục trang.
    //
    // `cover_path` (ảnh bìa chủ nhà tự tải lên) KHÔNG còn đọc nữa: bìa luôn là
    // bản đồ tin đăng, mà `FbProfileHeader` cho `coverChild` thắng `coverUrl`
    // — nên ảnh đó đã không được vẽ từ trước, chỉ là không ai để ý.
    double? hostRating; // uy tín chủ = trung bình đánh giá trên MỌI tin của chủ
    if (context.watch<AuthProvider>().loginAccountType?.name == 'owner') {
      final hp = context.watch<HostProfileProvider>();
      hostRating = hp.profile?.rating;
      if (hp.profile == null && !hp.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => hp.fetchProfile());
      }
    }

    // BÌA = BẢN ĐỒ TIN ĐĂNG của chính tài khoản, dựng cho MỌI vai.
    //
    // Trước đây bìa bị khoá sau `role == 'host'`. Mà `role` được backend TỰ
    // NÂNG lên 'host' ngay khi đăng tin đầu tiên (`houses.py` — auto-upgrade
    // to host on first listing). Hệ quả: cùng là tài khoản bán, người chưa
    // đăng tin và người đã đăng tin mở tab Cá nhân ra thấy hai trang trông
    // không liên quan gì nhau, và không ai báo trước là nó sẽ đổi. Đó đúng là
    // thứ việc "gộp sale vào tài khoản guest" muốn xoá bỏ.
    //
    // Chưa có tin thì bản đồ hiện trạng thái rỗng của chính nó — thà vậy còn
    // hơn giấu cả mảng đầu trang đi rồi bày lại sau lưng người dùng.
    //
    // Nạp một lần từ HouseProvider (đã có sẵn `myHouses` cho màn Tin đã đăng)
    // — không thêm lời gọi API riêng cho ảnh bìa.
    final hpv = context.watch<HouseProvider>();
    if (hpv.myHouses.isEmpty && !hpv.myHousesLoading && user.id != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => hpv.fetchMyHouses(user.id! as int),
      );
    }
    final Widget biaChuNha = HomeMapPreview(
      houses: hpv.myHouses,
      kieuBia: true,
      // Tràn viền: bìa là mảng liền của đầu trang, bo góc sẽ hở bốn góc ra
      // nền trắng.
      boGoc: 0,
      height: 160,
    );
    return Column(
      children: [
        // Đầu trang kiểu Facebook: ảnh bìa + avatar tròn đè lên mép dưới.
        FbProfileHeader(
          name: user.name,
          avatarUrl: user.avatarPath.isNotEmpty ? user.avatarPath : null,
          coverChild: biaChuNha,
          // Bìa là bản đồ thì KHÔNG mở xem ảnh: mở ra sẽ là một ảnh trống.
          onTapCover: null,
          // Tap avatar → xem ảnh full (không còn "ảnh câm").
          onTapAvatar: user.avatarPath.isNotEmpty
              ? () => showFullImage(context, user.avatarPath)
              : null,
          // Email ĐÃ BỎ khỏi dòng phụ: đây là hồ sơ của chính người đang xem
          // (họ biết email mình), nhưng với tài khoản đơn vị thì nó là thông
          // tin liên hệ phơi ra ngay đầu màn mà không phục vụ việc gì.
          // Chủ nhà: hiện UY TÍN (★ rating tổng trên mọi tin) ngay dòng phụ.
          subtitle: _profileSubtitle(l, user, hostRating),
          bio: user.bio,
          badge: _roleBadge(context, user.role),
          // Cài đặt + Đăng xuất: trước ở app bar, nay nổi trên bìa (app bar
          // đã bỏ để lấy lại chiều cao).
          overlayActions: [
            FbCoverIconButton(
              icon: Icons.settings_outlined,
              tooltip: l.profSettings,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            FbCoverIconButton(
              icon: Icons.logout,
              tooltip: l.logout,
              mauIcon: HD.negative,
              onTap: () => logoutFlow(context),
            ),
          ],
          actions: [
            // CHỈ một nút chính. Nút "Tin đã lưu" cũ đã bỏ: cùng đích với tab
            // "Yêu thích" ở thanh đáy VÀ thẻ số "Yêu thích" ngay dưới — ba lối
            // vào cho một nơi.
            FbPrimaryButton(
              nhan: l.editProfile,
              icon: Icons.edit_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _myStuff(
    BuildContext context,
    dynamic user,
    ViewingAppointmentProvider ap,
    WishlistProvider wp,
    int myListings,
  ) {
    final l = AppLocalizations.of(context);
    return Column(
      // stretch: mặc định của Column là canh GIỮA, nên các nhãn mục ("Của tôi",
      // "Dịch vụ thi công") bị bó sát nội dung rồi trôi vào giữa màn — lệch hẳn
      // với danh sách bên dưới vốn canh trái.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        // CÔNG TẮC "Khách thuê / Chủ nhà" ĐÃ BỎ. Chủ nhà không còn là một chế
        // độ tách riêng có bộ tab riêng — nó là bộ công cụ quản lý nhà nằm
        // ngay trong màn này (xem `_khuChuNha`). Giữ công tắc thì lại đúng cái
        // cảnh mỗi tài khoản mở ra một app khác nhau.

        // Lịch hẹn GẦN NHẤT, hiện ngay chứ không nấp sau một dòng dẫn: ai đặt
        // lịch 9h sáng mai mà mở app không thấy nhắc thì cả hệ khung giờ đặt
        // xem coi như không tồn tại. Không có lịch nào thì khối này biến mất.
        ..._lichSapToi(context, ap, l),

        // Hàng thẻ số CHỈ hiện khi có ít nhất một con số khác 0.
        //
        // Người vừa tạo tài khoản mở tab Cá nhân ra mà thứ đầu tiên nhìn thấy
        // là một hàng số 0 thì đó không phải thông tin — đó là lời nhắc "bạn
        // chưa làm gì cả". Danh sách "Của tôi" ngay dưới đã dẫn tới đúng những
        // nơi đó rồi.
        if (ap.appointments.isNotEmpty || wp.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Thẻ "Tin đăng" ĐÃ BỎ khỏi phần chung: người dùng thường không
                // đăng tin, nên nó luôn là số 0 — và nó là số 0 ĐẦU TIÊN họ thấy
                // khi mở tài khoản. Chủ nhà xem số tin ở khu "Quản lý cho thuê".
                _statCard(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: l.profAppointmentsStat,
                  value: '${ap.appointments.length}',
                  // Đồng tông xanh với 2 thẻ còn lại: lục ở đây không mã hoá
                  // trạng thái tốt/xấu nào, chỉ gây nhiễu thị giác.
                  color: HD.accent,
                  // Slot 2 giờ là Bảng tin → mở thẳng lịch hẹn xem nhà.
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BookingHistoryScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _statCard(
                  context,
                  icon: Icons.favorite_outline,
                  label: l.profFavorites,
                  value: '${wp.items.length}',
                  color: HD.accent,
                  onTap: () => wishlistTab >= 0
                      ? onJumpTab?.call(wishlistTab)
                      : Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WishlistScreen(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        if (ap.appointments.isNotEmpty || wp.items.isNotEmpty)
          const SizedBox(height: 24),

        // Section: NỘI DUNG của tôi (cấu hình đã sang SettingsScreen).
        //
        // "Tin đã đăng" ĐÃ CHUYỂN sang khu "Quản lý cho thuê": phụ đề của nó
        // là "Quản lý phòng bạn cho thuê" — đọc vào, người dùng thường tưởng
        // mình vào nhầm tài khoản.
        _sectionTitle(l.profMine),
        _tile(
          // Lối vào tin nhắn TRƯỚC ĐÂY KHÔNG CÓ Ở ĐÂU: người nhắn cho chủ nhà
          // xong không biết vào đâu đọc trả lời — đứt đúng khâu chốt deal.
          icon: Icons.chat_bubble_outline,
          title: l.profMessages,
          subtitle: l.profMessagesSub,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConversationsScreen()),
          ),
        ),
        _tile(
          icon: Icons.event_available_outlined,
          title: l.profViewingAppointments,
          subtitle: l.profViewingAppointmentsSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
          ),
        ),
        // Sale là một lớp công cụ trên tài khoản guest, không phải một màn cá
        // nhân tách riêng. Vì vậy để lối vào quản lý sale ngay trong hub chung.
        _tile(
          icon: Icons.storefront_outlined,
          title: '営業設定・ツール',
          subtitle: '公開プロフィール・物件掲載・プロジェクト・内見スケジュール',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SaleSettingsScreen()),
          ),
        ),
        // Dự án (toà nhà) — sale dựng trước khi có chủ nhà. Hiện cho MỌI tài
        // khoản, kể cả chưa đăng tin nào: dự án là thứ dựng TRƯỚC rồi mới đăng
        // phòng vào, ẩn nó đi thì sale không có đường bắt đầu.
        _tile(
          icon: Icons.apartment_outlined,
          title: '自分のプロジェクト',
          subtitle: '建物単位で部屋を管理。部屋ごとにオーナー・担当者を設定可能',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SaleProjectsScreen()),
          ),
        ),
        _tile(
          icon: Icons.qr_code_2_outlined,
          title: '自分の紹介コード',
          subtitle: 'オーナーに送って管理権限を受け取る',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SaleCodeScreen()),
          ),
        ),
        _tile(
          icon: Icons.link,
          title: '担当者と連携する',
          subtitle: '担当者からコードを受け取ったらここで入力',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LinkSaleScreen()),
          ),
        ),
        _tile(
          icon: Icons.handyman_outlined,
          title: l.myReqTitle,
          subtitle: l.myReqSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyServiceRequestsScreen()),
          ),
        ),

        // Mục "Dịch vụ thi công" (yêu cầu của tôi + kênh đơn vị) đã gỡ cùng
        // mảng thi công — không còn sàn nhà thầu nào để dẫn tới.

        // ── Khu theo VAI ──────────────────────────────────────────────────
        // Phần trên giống hệt nhau cho mọi tài khoản; từ đây trở xuống mới
        // phụ thuộc vai. Thêm vai mới về sau = thêm một khối `if` như dưới,
        // không phải dựng lại bố cục hay sinh thêm một chế độ persona.
        if (context.watch<AuthProvider>().loginAccountType?.name == 'owner')
          ..._khuChuNha(context, l),

        const SizedBox(height: 8),
      ],
    );
  }

  /// Thẻ lịch hẹn xem nhà GẦN NHẤT còn hiệu lực.
  ///
  /// Chỉ lấy lịch ở tương lai và chưa bị huỷ/từ chối — nhắc một cuộc hẹn đã
  /// qua hoặc đã bị chủ nhà từ chối thì tệ hơn là không nhắc gì.
  List<Widget> _lichSapToi(
    BuildContext context,
    ViewingAppointmentProvider ap,
    AppLocalizations l,
  ) {
    final bayGio = DateTime.now();
    ViewingAppointmentModel? gan;
    DateTime? luc;
    for (final a in ap.appointments) {
      if (a.status == 'cancelled' || a.status == 'rejected') continue;
      final t = DateTime.tryParse('${a.bookingDate} ${a.bookingTime}');
      if (t == null || t.isBefore(bayGio)) continue;
      if (luc == null || t.isBefore(luc)) {
        luc = t;
        gan = a;
      }
    }
    if (gan == null || luc == null) return const [];

    two(int n) => n.toString().padLeft(2, '0');
    final khiNao = l.profNextViewingAt(
      '${two(luc.day)}/${two(luc.month)}',
      '${two(luc.hour)}:${two(luc.minute)}',
    );

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(HD.s20, 0, HD.s20, HD.s20),
        child: Material(
          color: HD.accentSoft,
          borderRadius: BorderRadius.circular(HD.r12),
          child: InkWell(
            borderRadius: BorderRadius.circular(HD.r12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(HD.s12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: HD.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: HD.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.profNextViewing,
                          style: HD.caption().copyWith(color: HD.accentDeep),
                        ),
                        const SizedBox(height: 2),
                        Text(khiNao, style: HD.bodyBold(size: 15)),
                        if ((gan.houseTitle ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            gan.houseTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HD.caption(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: HD.accentDeep),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Khu quản lý dành cho CHỦ NHÀ.
  ///
  /// Đây là lối đi NHANH, không thay thế chế độ "Chủ nhà": chủ nhà nhiều phòng
  /// vẫn cần cả thanh tab riêng. Nhưng đổi chế độ là một thao tác hai bước và
  /// làm reset về tab đầu — bắt người ta làm vậy chỉ để xem một hoá đơn là quá
  /// đắt.
  ///
  /// Mở bằng `Navigator.push` để màn con nằm TRONG tab Cá nhân (thanh dưới vẫn
  /// sáng đúng ô). Dùng `context.go` sẽ đẩy màn lên navigator gốc và nó nổi đè
  /// lên mọi tab — lỗi đã gặp với màn "Bạn muốn đăng gì?".
  List<Widget> _khuChuNha(BuildContext context, AppLocalizations l) {
    void mo(Widget man) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => man));

    return [
      const SizedBox(height: 24),
      _sectionTitle(l.profHostSection),
      // TỔNG QUAN chuyển vào đây. Trước nó là tab đầu của shell chủ nhà riêng;
      // bỏ shell đó đi mà không đặt lại lối vào thì màn này thành mồ côi.
      _tile(
        icon: Icons.dashboard_outlined,
        title: '管理ダッシュボード',
        subtitle: '収益・稼働率・対応事項の確認',
        onTap: () => mo(const HostHomeScreen()),
      ),
      _tile(
        // Chuyển từ mục "Của tôi" sang đây: phụ đề nói "phòng bạn cho thuê",
        // chỉ có nghĩa với chủ nhà.
        icon: Icons.campaign_outlined,
        title: l.profPostedListings,
        subtitle: l.profPostedListingsSubtitle,
        onTap: () => mo(const MyListingsScreen()),
      ),
      _tile(
        icon: Icons.apartment_outlined,
        title: l.profHostBuildings,
        subtitle: l.profHostBuildingsSub,
        onTap: () => mo(const BuildingListScreen()),
      ),
      _tile(
        icon: Icons.receipt_long_outlined,
        title: l.profHostInvoices,
        subtitle: l.profHostInvoicesSub,
        onTap: () => mo(const InvoiceListScreen()),
      ),
      _tile(
        icon: Icons.event_note_outlined,
        title: l.profHostAppointments,
        subtitle: l.profHostAppointmentsSub,
        onTap: () => mo(const HostAppointmentsScreen()),
      ),
      _tile(
        icon: Icons.verified_user_outlined,
        title: l.profHostKyc,
        subtitle: l.profHostKycSub,
        onTap: () => mo(const HostProfileScreen()),
      ),
      // KHÔNG có mục "Hợp đồng": app chưa có màn danh sách hợp đồng, hợp đồng
      // vào bằng đường phòng → chi tiết. Dựng một dòng dẫn tới hư không thì
      // thà chưa có.
    ];
  }

  /// Dòng phụ hồ sơ: chủ nhà có uy tín → "★ 4.7" (ghép với tuổi nếu có).
  String? _profileSubtitle(
    AppLocalizations l,
    dynamic user,
    double? hostRating,
  ) {
    final age = user.age != null ? l.profAgeYears(user.age) : null;
    if (hostRating != null && hostRating > 0) {
      final star = '★ ${hostRating.toStringAsFixed(1)}';
      return age == null ? star : '$star · $age';
    }
    return age;
  }

  Widget _roleBadge(BuildContext context, String role) {
    final l = AppLocalizations.of(context);
    final isAdmin = role == 'admin';
    final label = isAdmin ? l.profRoleAdmin : l.profRoleMember;
    final bg = isAdmin ? HD.warning : HD.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: bg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: HD.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nhãn mục — dùng [HD.eyebrow] cho khớp nhãn "Bài viết của bạn" ở cuối màn
  /// (trước đây tự dựng TextStyle riêng nên hai nhãn lệch nhau).
  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Text(text, style: HD.eyebrow()),
  );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    // Bọc Material: ListTile vẽ nền và gợn mực lên Material gần nhất, mà trang
    // này nằm trong một ColoredBox có nền riêng — Flutter bắt lỗi đúng trường
    // hợp đó ngay ở chế độ debug (assert nổ trên máy thật, không chỉ trong
    // test). Trong suốt để không đổi màu nền đang có.
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: HD.accentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: HD.accent, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing:
            trailing ?? const Icon(Icons.chevron_right, color: HD.inkMuted),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool initial;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends State<_SwitchTile> {
  late bool _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: HD.accentSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(widget.icon, color: HD.accent, size: 20),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: Switch(
        value: _value,
        onChanged: (v) {
          setState(() => _value = v);
          widget.onChanged(v);
        },
      ),
    );
  }
}

/// Giữ dải [TabBar] DÍNH lại dưới đầu trang khi cuộn — hành vi của trang cá
/// nhân Facebook. [SliverPersistentHeader] cần một delegate tự khai báo chiều
/// cao, nên phải có lớp nhỏ này.
