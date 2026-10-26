import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/permissions/with_camera_permission.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/fb_post_card.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/core/widgets/binh_luan_sheet.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/house_social_api.dart';
import 'package:house_booking/data/services/host_public_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/config/env.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/auth/hoan_thien_ho_so_screen.dart';
import 'package:house_booking/features/guest/profile/ho_so_thieu.dart';
import 'package:house_booking/features/guest/broker/khay_lien_he_sheet.dart';
import 'package:house_booking/features/guest/project/sale_projects_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/features/host/post/post_house_screen.dart';
import 'package:house_booking/features/guest/project/project_strip.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/features/guest/broker/broker_deal_map.dart';
import 'package:house_booking/features/guest/home/widgets/home_map_preview.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hồ sơ CÔNG KHAI của một môi giới / chủ nhà.
/// Route: không có URL (push trong tab). Provider: không.
/// API: GET /api/hosts/{id} · /api/hosts/{id}/reviews · /api/houses?hostId=
///
/// Bố cục theo bản thiết kế của chủ dự án: bìa gradient đỏ → avatar tròn đè lên
/// bìa → tên + tick → ô điểm → 4 thẻ số liệu → bản đồ điểm chốt → tin đang đăng
/// (cuộn ngang) → nhận xét khách hàng.
///
/// SỐ LIỆU LÀ THẬT: 4 thẻ lấy từ backend (số tin published, số quận/huyện có
/// tin, số đánh giá, số năm tham gia). Bản thiết kế có "giao dịch thành công" và
/// "khách hàng tư vấn" — hệ thống KHÔNG có dữ liệu nào đo được hai chỉ số đó,
/// nên không dựng thẻ bịa số.
///
/// [name]/[avatarPath] nhận từ thẻ ở trang chủ để vẽ ngay đầu trang trong lúc
/// chờ mạng — tránh nháy khung rỗng rồi mới có tên.
class BrokerProfileScreen extends StatefulWidget {
  const BrokerProfileScreen({
    super.key,
    required this.userId,
    this.name,
    this.avatarPath,
    this.api = const HostPublicApi(),
    this.profileLoader,
    this.listingsLoader,
    this.reviewsLoader,
    this.laChuTrang = false,
    this.choDangBai = true,
    this.xemNhuKhach = false,
    this.onMoCaiDat,
    this.xoaTinLoader,
    this.xaHoiApi,
  });

  /// CHÍNH CHỦ đang xem trang của mình.
  ///
  /// Cùng một trang, cùng một dữ liệu — chỉ mọc thêm nút sửa cạnh từng khối.
  /// Không dựng màn "sửa hồ sơ" riêng: người bán cần thấy ĐÚNG thứ khách thấy
  /// lúc họ sửa, chứ không phải một danh sách ô nhập rồi tự hình dung.
  final bool laChuTrang;

  /// Cho phép đăng tin mới không.
  ///
  /// CHỦ NHÀ dùng chung trang này với sale nhưng KHÔNG đăng tin: họ vận hành
  /// toà, còn rao bán/cho thuê là việc của sale. Đường của chủ nhà là gán
  /// phòng vào tin có sẵn, làm ở bảng điều khiển "Quản lí nhà".
  final bool choDangBai;

  /// BẢN XEM THỬ: chính chủ đang soi trang mình DƯỚI CON MẮT NGƯỜI LẠ.
  ///
  /// Đi kèm [laChuTrang] = false — không phải một chế độ hiển thị thứ ba, mà
  /// đúng bản khách thấy, chỉ thêm một dải nhắc để người xem biết mình đang ở
  /// đâu. Vì sao cần cờ riêng thay vì cứ push bản khách: mất hết nút ✏️ Sửa mà
  /// không giải thích thì người dùng tưởng trang hỏng, và không có đường rõ
  /// ràng để thoát ra.
  ///
  /// Nó soi ra được thứ mà chính chủ KHÔNG BAO GIỜ thấy ở bản của mình: tin
  /// đang chờ duyệt/nháp biến mất (khách chỉ thấy `published`), giới thiệu để
  /// trống thì cả khối biến mất chứ không phải hiện lời mời điền, và thanh
  /// Gọi/Nhắn nổi lên chiếm chỗ.
  final bool xemNhuKhach;

  /// Mở màn tài khoản (cài đặt, đăng xuất, đơn của tôi…). Chỉ dùng khi
  /// [laChuTrang] — shell truyền xuống vì màn đó là thân tab, không tự đứng.
  final VoidCallback? onMoCaiDat;

  final int userId;
  final String? name;
  final String? avatarPath;
  final HostPublicApi api;

  // ── Nguồn dữ liệu, tách ra để test bơm được ────────────────────────────────
  //
  // KHÔNG mock nổi bằng cách bơm http client: `ApiClient` luôn đọc JWT qua
  // `SessionService` → flutter_secure_storage, và trong widget test kênh
  // platform đó KHÔNG BAO GIỜ trả lời (future treo vĩnh viễn, màn kẹt ở vòng
  // quay chờ). Nên tầng chèn phải ở đây, trên cả ApiClient.
  final Future<Map<String, dynamic>> Function(int userId)? profileLoader;
  final Future<List<HouseModel>> Function(int userId)? listingsLoader;
  final Future<List<Map<String, dynamic>>> Function(int userId)? reviewsLoader;

  /// Xoá một tin. Cùng lý do tách như ba loader trên — `ApiHouseRepository`
  /// nằm dưới `ApiClient`, mà cái đó đọc JWT qua secure storage nên treo trong
  /// widget test.
  final Future<bool> Function(int houseId)? xoaTinLoader;

  /// Tim/bình luận/ghim/ẩn/thống kê. Bơm được để test không cần mạng.
  final HouseSocialApi? xaHoiApi;

  @override
  State<BrokerProfileScreen> createState() => _BrokerProfileScreenState();
}

class _BrokerProfileScreenState extends State<BrokerProfileScreen> {
  final _houseRepo = ApiHouseRepository();
  final _api = const ApiClient();
  HouseSocialApi get _xaHoi => widget.xaHoiApi ?? const HouseSocialApi();

  /// Trạng thái tim ĐÈ LÊN dữ liệu tải về, theo house id.
  ///
  /// `HouseModel` không có `copyWith`, mà nạp lại cả trang chỉ vì một trái tim
  /// là bắt người ta chờ mạng cho một thao tác đáng ra tức thì.
  final _tim = <int, ({bool daTim, int soTim})>{};

  /// Neo để mở menu ⋯ ngay dưới nút, không phải khay trượt từ đáy màn.
  final _khoaBai = <int, GlobalKey>{};

  /// Neo để nút "Xem nhà" cuộn tới mục tin đăng.
  final _khoaTinDang = GlobalKey();

  Map<String, dynamic>? _profile;
  List<HouseModel> _houses = const [];
  List<Map<String, dynamic>> _nhanXet = const [];
  bool _loading = true;
  bool _notFound = false;

  // ── Sửa TẠI CHỖ (chỉ khi laChuTrang) ─────────────────────────────────────
  //
  // Ô đang hiển thị biến thẳng thành ô nhập, không đẩy sang màn khác. Người
  // bán sửa trong đúng khung khách sẽ đọc, nên thấy ngay chỗ nào dài quá.
  final _tenCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _suaTen = false;
  bool _suaBio = false;
  bool _dangLuu = false;
  bool _dangTaiAnh = false;

  /// Bộ lọc feed: '' = tất cả · 'rent' · 'sale'.
  String _loc = '';

  /// Dạng xem feed: danh sách bài viết hay lưới 2 cột.
  bool _dangLuoi = false;

  /// Số tin hiện lúc đầu.
  ///
  /// Sale có 20 tin thì feed dài mấy màn hình và khối đánh giá bị đẩy ra khỏi
  /// tầm với — người xem bỏ cuộc trước khi thấy nó. Cắt ngắn rồi cho bấm mở
  /// thêm giữ được cả hai: ai muốn xem hết vẫn xem được, ai muốn xem đánh giá
  /// không phải cuộn qua 20 bài.
  static const _soTinBanDau = 3;
  bool _moHetTin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tenCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  /// Lưu một trường của hồ sơ rồi nạp lại trang.
  ///
  /// Đi qua `AuthProvider` chứ không gọi thẳng API: nó còn cập nhật
  /// `currentUser` trong bộ nhớ, thiếu bước đó thì tên trên thanh điều hướng
  /// và trong menu tài khoản vẫn là tên cũ cho tới lần đăng nhập sau.
  Future<void> _luuHoSo({String? ten, String? bio}) async {
    setState(() => _dangLuu = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.updateProfile(name: ten, bio: bio);
    if (!mounted) return;
    setState(() {
      _dangLuu = false;
      if (ok) {
        _suaTen = false;
        _suaBio = false;
      }
    });
    if (ok) {
      await _load();
    } else if (mounted) {
      AppFeedback.error(context, auth.errorMessage ?? 'Lưu không được');
    }
  }

  Future<void> _load() async {
    // Hồ sơ là BẮT BUỘC (không có thì báo không tìm thấy); tin đăng và nhận xét
    // hỏng thì chỉ ẩn mục đó — vẫn xem được hồ sơ.
    Map<String, dynamic>? prof;
    try {
      prof = widget.profileLoader != null
          ? await widget.profileLoader!(widget.userId)
          : await widget.api.profile(widget.userId);
    } catch (_) {
      prof = null;
    }
    List<HouseModel> houses = const [];
    try {
      houses = widget.listingsLoader != null
          ? await widget.listingsLoader!(widget.userId)
          // Chủ trang thấy CẢ tin đang ẩn / chờ duyệt / bị từ chối. Backend
          // chỉ mở nhánh này khi token đúng chủ (`_own_scope` trong
          // `houses.py`), nên không rò tin nháp của người khác.
          : await _houseRepo.getHouses(
              hostId: widget.userId,
              limit: 50,
              status: widget.laChuTrang ? 'all' : null,
            );
      // Tin GHIM nổi lên đầu (0090). Sắp ở client chứ không nhờ backend:
      // `GET /api/houses` phục vụ cả trang chủ và tìm kiếm, thêm một nhánh
      // sắp xếp chỉ dành cho trang cá nhân là làm nặng đường đi chung.
      houses = [
        ...houses.where((h) => h.pinned),
        ...houses.where((h) => !h.pinned),
      ];
    } catch (_) {}
    List<Map<String, dynamic>> nx = const [];
    try {
      nx = widget.reviewsLoader != null
          ? await widget.reviewsLoader!(widget.userId)
          : await widget.api.reviews(widget.userId, limit: 5);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _profile = prof;
      _notFound = prof == null;
      _houses = houses;
      _nhanXet = nx;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: widget.xemNhuKhach
            ? 'Xem như khách'
            : widget.laChuTrang
            ? 'Trang của tôi'
            : l.brokerProfileTitle,
        actions: [
          // Tài khoản/cài đặt/đăng xuất KHÔNG mất đi khi tab Cá nhân đổi thành
          // trang công khai — chỉ lùi vào sau một nút.
          if (widget.laChuTrang && widget.onMoCaiDat != null)
            IconButton(
              tooltip: 'Tài khoản & cài đặt',
              icon: const Icon(Icons.settings_outlined),
              onPressed: widget.onMoCaiDat,
            ),
          // XEM NHƯ KHÁCH. Sửa tại chỗ có một điểm mù: chính chủ luôn nhìn bản
          // CÓ nút sửa, có tin nháp, có lời mời điền chỗ trống — nên không bao
          // giờ thấy trang mình thực sự trống đến mức nào với người lạ. Nút này
          // là đường duy nhất để tự soi.
          if (widget.laChuTrang)
            IconButton(
              tooltip: 'Xem trang dưới mắt khách',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: _moXemNhuKhach,
            ),
          // Lý do mục này tồn tại: môi giới cần MỘT ĐƯỜNG LINK gửi cho khách.
          // Link trỏ sang site SSR công khai (có preview Zalo/Facebook, Google
          // đọc được), KHÔNG phải app.
          if (!_notFound && !_loading)
            IconButton(
              tooltip: l.saleQrTitle,
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => _moQr(l),
            ),
          if (!_notFound && !_loading)
            IconButton(
              tooltip: l.brokerShare,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _chiaSe(l),
            ),
        ],
      ),
      body: _thanBoc(
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _notFound
            ? Center(child: Text(l.brokerNotFound, style: HD.body()))
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _hero(l),
                  // NHẮC ĐIỀN HỒ SƠ — chỉ trên bản của chính mình, đặt ngay dưới
                  // thẻ danh tính để nhìn thấy đúng lúc đang nhìn chỗ còn trống.
                  // Khách xem trang người khác thì không liên quan gì.
                  if (widget.laChuTrang)
                    TheHoanThienHoSo(
                      thieu: HoSoThieu.tu(
                        context.watch<AuthProvider>().currentUser,
                      ),
                      onNhan: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HoanThienHoSoScreen(),
                          ),
                        );
                        if (mounted) await _load();
                      },
                    ),
                  _stats(l),
                  _theGioiThieu(),
                  // ĐÃ BỎ hàng huy hiệu riêng: thẻ danh tính nay đã có cả
                  // "Đã xác minh danh tính" lẫn chip phản hồi. Hai chỗ nói cùng
                  // một điều trên một màn là thừa.
                  // "BĐS đang phân phối" = dự án BĐS (buildings, có bảng giá
                  // từng phòng) + album tin đăng. Đứng TRÊN feed: sale ôm nguyên
                  // toà thì thứ khách cần thấy đầu tiên là "có nguyên toà", không
                  // phải cuộn qua 20 bài rời rạc rồi tự suy ra.
                  ProjectStrip(
                    ownerId: widget.userId,
                    onSua: widget.laChuTrang
                        ? () => _mo(const SaleProjectsScreen())
                        : null,
                  ),
                  // ĐÃ BỎ khối "Bản đồ điểm chốt" nhúng giữa trang: bìa nay
                  // CHÍNH LÀ bản đồ đó. Hai bản đồ cùng một dữ liệu trên một
                  // trang chỉ làm người xem phải hỏi "cái này khác cái kia chỗ
                  // nào".
                  // Chủ trang chưa có tin nào VẪN vẽ mục: không thì nút
                  // "Thêm tin" nằm trong đó cũng biến mất theo.
                  if (_houses.isNotEmpty || widget.laChuTrang)
                    _listingsSection(l),
                  if (_nhanXet.isNotEmpty) _khoiDanhGia(),
                  // 96 là chỗ cho thanh nổi Gọi/Nhắn; chủ trang không có thanh
                  // đó nên chừa 96px là chừa một khoảng trắng vô cớ.
                  SizedBox(height: widget.laChuTrang ? HD.s24 : 96),
                ],
              ),
      ),
      // Chủ trang KHÔNG có thanh nổi: Gọi/Nhắn là để khách bấm, mà ba nút sửa
      // thì đã nằm ngay cạnh từng khối rồi. Một thanh đỏ chiếm 76px chỉ để
      // lặp lại việc đó là ăn mất hai dòng nội dung ở mọi lần cuộn.
      bottomNavigationBar: (_loading || _notFound || widget.laChuTrang)
          ? null
          : _thanhLienHe(l),
    );
  }

  String get _ten => (_profile?['name'] as String?) ?? widget.name ?? '';

  String get _duongDan => Env.brokerPublicUrl(widget.userId, _ten);

  /// Mở khay chia sẻ của hệ thống; hỏng thì rơi về copy clipboard.
  ///
  /// Trước đây CHỈ copy — người dùng phải tự mở Zalo, tự dán. Mỗi bước thừa là
  /// một chỗ họ bỏ cuộc, mà đây đúng là hành động cả trang này sinh ra để phục
  /// vụ.
  Future<void> _chiaSe(AppLocalizations l) async {
    final url = _duongDan;
    try {
      await Share.share('$_ten\n$url');
      return;
    } catch (_) {
      // Nền tảng không có khay chia sẻ (web trên trình duyệt cũ) → copy.
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppFeedback.info(context, l.brokerShareCopied);
  }

  /// Mã QR để khách quét tại chỗ — nhanh hơn đọc link qua điện thoại.
  void _moQr(AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HD.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.saleQrTitle, style: HD.bodyBold(size: 16)),
              const SizedBox(height: HD.s4),
              Text(l.saleQrHint, style: HD.caption()),
              const SizedBox(height: HD.s20),
              // Nền trắng bắt buộc: máy quét đọc bằng tương phản, đặt QR lên
              // nền màu là tỉ lệ đọc trượt tăng vọt.
              Container(
                padding: const EdgeInsets.all(HD.s12),
                color: Colors.white,
                child: QrImageView(data: _duongDan, size: 200),
              ),
              const SizedBox(height: HD.s16),
              Text(_duongDan, textAlign: TextAlign.center, style: HD.caption()),
            ],
          ),
        ),
      ),
    );
  }

  /// Thanh liên hệ DÍNH ĐÁY — thứ biến trang xem thành trang bán.
  ///
  /// Bản trước cuộn hết trang không có một nút hành động nào: khách xem xong
  /// thấy ưng thì hết đường. Nay cuộn tới đâu cũng liên hệ được.
  ///
  /// Chưa hiện SĐT vì API hồ sơ công khai cố ý không trả số (giữ bất biến "SĐT
  /// masked"). Nút "Gọi" sẽ thêm khi có công tắc cho sale tự bật.
  /// SĐT chỉ có khi người bán TỰ BẬT (`show_phone`, migration 0088). Backend
  /// bỏ hẳn khoá khi tắt, nên vắng khoá = không được gọi.
  String? get _sdt {
    final v = (_profile?['phone'] as String?)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get _zalo {
    final v = (_profile?['zalo'] as String?)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get _facebook {
    final v = (_profile?['facebook'] as String?)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> _goiDien() async {
    final so = _sdt;
    if (so == null) return;
    await launchUrl(Uri(scheme: 'tel', path: so));
  }

  Future<void> _moZalo() async {
    final z = _zalo;
    if (z == null) return;
    // zalo.me nhận cả số điện thoại lẫn id — không tự đoán, đưa nguyên thứ
    // người bán nhập.
    await launchUrl(
      Uri.parse('https://zalo.me/$z'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _moFacebook() async {
    final fb = _facebook;
    if (fb == null) return;
    await launchUrl(Uri.parse(fb), mode: LaunchMode.externalApplication);
  }

  /// Thanh liên hệ — card NỔI, không phải dải dính mép.
  ///
  /// Card nổi tách khỏi nội dung nên không bị nhầm là một phần của bài đăng
  /// cuối cùng, và bo góc + đổ bóng làm nó đọc như một thanh công cụ luôn sẵn.
  // ── Chế độ chủ trang ───────────────────────────────────────────────────────

  /// Mở một màn con rồi NẠP LẠI khi quay về — sửa xong mà trang vẫn hiện dữ
  /// liệu cũ thì người ta tưởng lưu hụt và bấm sửa lại lần nữa.
  Future<void> _mo(Widget man) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => man));
    if (mounted) _load();
  }

  /// Khay bật/tắt liên hệ công khai. Đặt ở đây chứ không nhét vào "Sửa hồ sơ":
  /// hai công tắc này đổi thứ KHÁCH THẤY, nên phải sửa ngay trên trang khách
  /// thấy.
  Future<void> _moCaiDatLienHe() async {
    final doi = await showDsBottomSheet<bool>(
      context: context,
      builder: (_) => const KhayLienHeSheet(),
    );
    if (doi == true && mounted) _load();
  }

  /// Dòng chức danh ngay dưới tên.
  ///
  /// KHÔNG đăng tin nào, KHÔNG dự án nào thì không phải người bán — dù
  /// `account_type` trong CSDL vẫn là `sale` (mặc định của mọi tài khoản đăng
  /// ký, xem mô hình vai). Gọi họ là "Chuyên viên tư vấn BĐS" là để app tự
  /// khoác cho một người chưa làm gì cái danh họ chưa có, và khách đọc dòng đó
  /// ngay cạnh tick xanh sẽ hiểu thành đã được xác nhận.
  ///
  /// Dùng `listings` (đếm tin CÔNG KHAI) chứ không phải số tin trong máy: tin
  /// nháp chỉ mình chủ thấy, nên nó không làm ai thành người bán trong mắt
  /// khách.
  String _chucDanh(
    Map<String, dynamic> p, {
    required int listings,
    required int soDuAn,
  }) {
    if (listings == 0 && soDuAn == 0) return 'Thành viên';
    return p['seller_kind'] == 'broker' ? 'Chuyên viên tư vấn BĐS' : 'Chủ nhà';
  }

  /// Mở bản xem thử: CHÍNH màn này, chỉ khác `laChuTrang: false`.
  ///
  /// Cố ý không dựng màn mô phỏng riêng. Một bản "giả lập" sẽ trôi khỏi bản
  /// thật sau vài lần sửa, và khi đó nó nói dối đúng vào lúc người dùng tin nó
  /// nhất. Dùng lại nguyên màn thì bản xem thử không thể sai.
  void _moXemNhuKhach() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrokerProfileScreen(
          userId: widget.userId,
          name: widget.name,
          avatarPath: widget.avatarPath,
          api: widget.api,
          profileLoader: widget.profileLoader,
          listingsLoader: widget.listingsLoader,
          reviewsLoader: widget.reviewsLoader,
          xaHoiApi: widget.xaHoiApi,
          xemNhuKhach: true,
        ),
      ),
    );
  }

  /// Dải nhắc CỐ ĐỊNH ở đầu bản xem thử — không cuộn mất.
  ///
  /// Nếu để nó cuộn theo nội dung thì đúng lúc người dùng cuộn xuống xem tin
  /// đăng — lúc dễ quên mình đang ở chế độ nào nhất — nó đã biến mất.
  Widget _thanBoc(Widget con) {
    if (!widget.xemNhuKhach) return con;
    return Column(
      children: [
        Material(
          color: HD.inkSoft,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s8, HD.s8),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: HD.s8),
                  const Expanded(
                    child: Text(
                      'Đây là những gì người khác nhìn thấy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: HD.s12),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Thoát'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: con),
      ],
    );
  }

  /// Trong bản xem thử, nút liên hệ CÒN NGUYÊN nhưng không chạy: ẩn đi thì mất
  /// đúng thứ cần xem (thanh này che 76px cuối trang), mà để chạy thật thì
  /// người dùng tự gọi chính mình.
  bool _chanNeuXemThu() {
    if (!widget.xemNhuKhach) return false;
    AppFeedback.info(context, 'Bản xem thử — nút này chỉ khách bấm được');
    return true;
  }

  Widget _thanhLienHe(AppLocalizations l) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(HD.s12, 0, HD.s12, HD.s12),
      child: Container(
        padding: const EdgeInsets.all(HD.s8),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
          boxShadow: HD.floatShadow,
        ),
        // Nút nào thiếu dữ liệu thì KHÔNG vẽ. Vẽ nút xám bấm không ăn còn tệ
        // hơn không có nút: khách bấm rồi mới biết là hụt.
        child: Row(
          children: [
            if (_sdt != null) ...[
              _nutDoc(Icons.call, 'Gọi', () {
                if (!_chanNeuXemThu()) _goiDien();
              }),
              const SizedBox(width: HD.s8),
            ],
            Expanded(
              child: SizedBox(
                height: 48,
                child: DsButton(
                  label: _ten.isEmpty ? l.saleCall : l.saleCallNamed(_ten),
                  icon: Icons.chat_bubble_outline,
                  expand: true,
                  onPressed: () {
                    if (!_chanNeuXemThu()) _nhanTin(l);
                  },
                ),
              ),
            ),
            const SizedBox(width: HD.s8),
            if (_zalo != null)
              _nutDoc(Icons.forum_outlined, 'Zalo', () {
                if (!_chanNeuXemThu()) _moZalo();
              })
            else if (_facebook == null)
              _nutDoc(
                Icons.event_available_outlined,
                'Xem nhà',
                _cuonToiTinDang,
              ),
            if (_facebook != null) ...[
              const SizedBox(width: HD.s8),
              _nutDoc(Icons.facebook_rounded, 'Facebook', () {
                if (!_chanNeuXemThu()) _moFacebook();
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// Nút phụ dạng dọc: icon trên, nhãn chữ dưới — như mẫu tham chiếu.
  Widget _nutDoc(IconData icon, String nhan, VoidCallback cham) {
    return InkWell(
      onTap: cham,
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        width: 54,
        // 52 thì icon 18 + nhãn caption tràn đúng 1px. Không bóp icon cho vừa
        // — nới ô, vì nút chính cạnh nó cũng cao 48 và hai bên phải bằng nhau.
        height: 48,
        decoration: BoxDecoration(
          color: HD.paper,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: HD.accent),
            Text(nhan, style: HD.caption(), maxLines: 1),
          ],
        ),
      ),
    );
  }

  /// "Xem nhà" cuộn tới mục tin đăng thay vì mở luồng đặt lịch.
  ///
  /// Đặt lịch xem nhà trong hệ thống BẮT BUỘC có `house_id`; từ trang hồ sơ
  /// chưa biết khách muốn xem căn nào. Mở một form trống rồi bắt họ chọn lại
  /// là thêm một bước; đưa thẳng tới danh sách để họ chọn căn mới đúng thứ tự.
  void _cuonToiTinDang() {
    final ctx = _khoaTinDang.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: HD.motionMedium,
      curve: HD.curveStandard,
    );
  }

  void _nhanTin(AppLocalizations l) {
    if (!GuestGate.requireAuth(context, message: l.saleCall)) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: widget.userId,
          peerName: _ten,
          peerAvatar: (_profile?['avatar_path'] as String?) ?? '',
        ),
      ),
    );
  }

  // ── Bìa + danh tính ───────────────────────────────────────────────────────
  /// Đầu trang: bản đồ **để trống**, thẻ danh tính là một card trắng NỔI LÊN
  /// đè mép dưới bản đồ.
  ///
  /// Bản trước đặt tên chữ trắng đè thẳng lên bản đồ. Đọc được, nhưng thông tin
  /// bị giới hạn ở hai dòng — không nhét nổi chức danh, sàn hợp tác, huy hiệu
  /// phản hồi. Card nổi cho đủ chỗ mà vẫn giữ được cảm giác chồng lớp.
  Widget _hero(AppLocalizations l) {
    // Column + `Transform.translate` chứ KHÔNG phải Stack với chỗ trống cố
    // định: chiều cao thẻ danh tính thay đổi theo việc có sàn hợp tác / có chip
    // phản hồi hay không. Chừa cứng 58px thì hồ sơ đầy đủ sẽ tràn ra và đè lên
    // hàng thẻ số liệu bên dưới — đúng lỗi gặp ở lượt dựng đầu.
    return Column(
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _nenBia(),
              // Scrim nhẹ hơn bản trước: không còn chữ nào nằm trên bản đồ nữa,
              // lớp này chỉ để các pill nổi và mép dưới không chói.
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x40000000),
                        Colors.transparent,
                        Color(0x73000000),
                      ],
                      stops: [0.0, 0.35, 1.0],
                    ),
                  ),
                ),
              ),
              if (_pins.isNotEmpty)
                Positioned(
                  right: HD.s8,
                  top: HD.s8,
                  child: _NhanBanDo(
                    soTin: _pins.length,
                    soKhu: (_profile!['area_count'] as num?)?.toInt() ?? 0,
                  ),
                ),
              Positioned(
                left: HD.s12,
                right: HD.s12,
                // 42 chứ không phải 12: thẻ danh tính đè lên 30px cuối của
                // bìa, để 12 thì dải chip nằm đúng dưới gầm thẻ.
                bottom: 42,
                child: _ChipKhuVuc(
                  khu: _dsChu('main_areas'),
                  mon: _dsChu('specialties'),
                ),
              ),
            ],
          ),
        ),
        // Kéo thẻ lên đè 30px cuối của bìa. `Transform.translate` không thu
        // nhỏ ô chiếm chỗ, nên 30px trắng nó để lại chính là lề dưới của khối
        // đầu trang — vì thế `_stats` không cần lề trên nữa.
        Transform.translate(
          offset: const Offset(0, -30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HD.s16),
            child: _theDanhTinh(l),
          ),
        ),
      ],
    );
  }

  List<String> _dsChu(String key) =>
      (_profile?[key] as List? ?? const []).whereType<String>().toList();

  /// Nền bìa: bản đồ ghim tin > ảnh bìa tự tải > gradient đỏ.
  /// Bìa LUÔN là bản đồ — kể cả khi chưa có tin nào.
  ///
  /// Trước đây không có ghim thì bìa đổ về một mảng gradient đỏ trơn: hồ sơ mới
  /// lập mở ra là một khối màu không nói lên điều gì, rồi tự biến thành bản đồ
  /// sau khi đăng tin đầu tiên — hai trang trông khác hẳn nhau cho cùng một
  /// người. Bản đồ ngay từ đầu cũng nói đúng bản chất trang này: địa bàn.
  ///
  /// Nhánh `cover_path` (ảnh bìa tự tải lên) bỏ luôn: `FbProfileHeader` cho
  /// `coverChild` thắng `coverUrl`, nên ảnh đó chưa từng được vẽ ở đâu.
  ///
  /// `HomeMapPreview` lo phần canh khung theo thứ tự: ghim tin đăng → vị trí
  /// hiện tại → toàn cảnh Việt Nam.
  Widget _nenBia() {
    return HomeMapPreview(
      houses: _pins,
      kieuBia: true,
      boGoc: 0,
      height: 190,
      // Chưa có ghim thì không có gì để mở ra xem.
      onTap: _pins.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    BrokerDealMapScreen(houses: _pins, hostName: _ten),
              ),
            ),
    );
  }

  /// Thẻ danh tính — avatar vuông bo góc + tên + chức danh + sàn hợp tác, rồi
  /// hai dải ngăn bằng đường kẻ: điểm đánh giá, và huy hiệu xác minh.
  Widget _theDanhTinh(AppLocalizations l) {
    final p = _profile!;
    final name = (p['name'] as String?) ?? widget.name ?? '';
    final avatar = (p['avatar_path'] as String?) ?? widget.avatarPath;
    final rating = (p['rating'] as num?)?.toDouble();
    final reviews = (p['review_count'] as num?)?.toInt() ?? 0;
    final listings = (p['listing_count'] as num?)?.toInt() ?? _houses.length;
    final trusted = p['trusted'] == true;
    final verified = p['verified'] == true;
    // "Đang phân phối" — backend SUY TỪ dự án sale đang quản lý, không phải ô
    // chữ họ tự gõ. Cột `agency` cũ để trống vì không kiểm được: ai cũng gõ
    // được "CBRE", mà dòng này nằm ngay cạnh tick xanh nên khách đọc thành
    // "đã xác minh".
    final duAn = (p['distributing'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final gio = _gioPhanHoiDangTin(p);

    return Container(
      padding: const EdgeInsets.all(HD.s16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
        boxShadow: HD.floatShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(name, avatar),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_suaTen)
                      _oSuaTen()
                    else
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.bodyBold(size: 18),
                            ),
                          ),
                          // Nhãn hạng CHỈ khi `trusted` — cờ đó do backend
                          // tính từ đánh giá đã kiểm, không phải chữ tự gán.
                          if (trusted) ...[
                            const SizedBox(width: 5),
                            const _NhanHang(),
                          ],
                          if (widget.laChuTrang) ...[
                            const SizedBox(width: 6),
                            DsEditChip(
                              tooltip: 'Sửa tên',
                              onTap: () => setState(() {
                                _tenCtrl.text = name;
                                _suaTen = true;
                              }),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _chucDanh(p, listings: listings, soDuAn: duAn.length),
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    ),
                    if (duAn.isNotEmpty) ...[
                      const SizedBox(height: HD.s4),
                      Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            size: 13,
                            color: HD.accent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Đang phân phối: ${duAn.join(' · ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.body(size: 12, color: HD.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          const Divider(height: 1, color: HD.hairline),
          const SizedBox(height: HD.s8),
          Row(
            children: [
              if (rating != null && reviews > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HD.s8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: HD.warningTint,
                    borderRadius: BorderRadius.circular(HD.r4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: HD.warning,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: HD.bodyBold(size: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: HD.s8),
                Text(
                  '$reviews nhận xét',
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
                const SizedBox(width: HD.s8),
                Text('·', style: HD.body(size: 12, color: HD.hairlineStrong)),
                const SizedBox(width: HD.s8),
              ],
              Flexible(
                child: Text(
                  '$listings tin đang đăng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
              ),
            ],
          ),
          if (gio != null || verified) ...[
            const SizedBox(height: HD.s8),
            const Divider(height: 1, color: HD.hairline),
            const SizedBox(height: HD.s8),
            Row(
              children: [
                if (gio != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HD.s8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: HD.positiveTint,
                      borderRadius: BorderRadius.circular(HD.rPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: HD.positive,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _chuPhanHoi(gio),
                          style: HD.bodyBold(size: 11.5, color: HD.positive),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                // Chỉ nói ĐÚNG thứ đã xác minh. Mockup ghi "CCCD & CCHN" nhưng
                // hệ thống không có khái niệm chứng chỉ hành nghề — ghi vào là
                // khẳng định một thứ chưa ai kiểm.
                if (verified)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 13,
                        color: HD.positive,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Đã xác minh danh tính',
                        style: HD.body(size: 11.5, color: HD.inkMuted),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          // Chủ trang: nói thẳng khách đang thấy được liên hệ nào. Đây là
          // thông tin CHỈ chủ trang cần — khách đã có nút Gọi/Zalo ở thanh
          // dưới rồi, không cần đọc lại bằng chữ.
          if (widget.laChuTrang) ...[
            const SizedBox(height: HD.s8),
            const Divider(height: 1, color: HD.hairline),
            const SizedBox(height: HD.s8),
            Row(
              children: [
                Icon(
                  _sdt == null && _zalo == null && _facebook == null
                      ? Icons.phone_disabled_outlined
                      : Icons.phone_in_talk_outlined,
                  size: 13,
                  color: _sdt == null && _zalo == null && _facebook == null
                      ? HD.inkMuted
                      : HD.positive,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _chuLienHe(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                ),
                const SizedBox(width: HD.s8),
                DsEditChip(
                  tooltip: 'Liên hệ công khai',
                  onTap: _moCaiDatLienHe,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Một dòng tóm tắt khách đang liên hệ được bằng đường nào.
  String _chuLienHe() {
    final co = <String>[
      if (_sdt != null) 'gọi trực tiếp',
      if (_zalo != null) 'Zalo',
      if (_facebook != null) 'Facebook',
    ];
    if (co.isEmpty) return 'Khách chỉ nhắn được trong app';
    return 'Khách ${co.join(' · ')}';
  }

  /// Giờ phản hồi trung bình, CHỈ khi nó dựa trên đủ số lần đo.
  ///
  /// Trên staging từng có `avg_response_hours = 0.6` ở 1.053 hồ sơ trong khi
  /// bảng lịch hẹn RỖNG — con số do seed ghi thẳng. Một trung bình trên 0 lần
  /// đo không phải là số đo, và "Phản hồi trong 36 phút" là loại khẳng định
  /// khách tin ngay mà không kiểm được.
  ///
  /// Ngưỡng 5: dưới đó một lần trả lời nhanh may mắn cũng kéo trung bình xuống.
  static const _mauToiThieu = 5;

  double? _gioPhanHoiDangTin(Map<String, dynamic> p) {
    final mau = (p['response_sample'] as num?)?.toInt() ?? 0;
    if (mau < _mauToiThieu) return null;
    return (p['avg_response_hours'] as num?)?.toDouble();
  }

  String _chuPhanHoi(double gio) => gio < 1
      ? 'Phản hồi trong ${(gio * 60).round()} phút'
      : 'Phản hồi trong ${gio.round()} giờ';

  /// Avatar VUÔNG BO GÓC + huy hiệu tick ở góc dưới phải.
  ///
  /// Vuông thay vì tròn: ảnh chân dung nghề nghiệp cắt tròn hay mất vai và cằm;
  /// khung vuông giữ được bố cục người chụp đã canh.
  Widget _avatar(String name, String? avatar) {
    final url = _absOrNull(avatar);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final xacMinh = _profile?['verified'] == true;
    final tinCay = _profile?['trusted'] == true;

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: HD.accentTint,
              borderRadius: BorderRadius.circular(HD.r12),
              border: Border.all(color: HD.paperRaised, width: 3),
              boxShadow: HD.sunkenShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: url == null
                ? Center(
                    child: Text(
                      initial,
                      style: HD.masthead(size: 32, color: HD.accent),
                    ),
                  )
                : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          ),
          // Chủ trang: huy hiệu nhường chỗ cho nút đổi ảnh. Ảnh cần trình
          // chọn tệp nên không sửa tại chỗ được như tên và giới thiệu.
          if (widget.laChuTrang)
            Positioned(
              right: -4,
              bottom: -4,
              child: Material(
                color: HD.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _dangTaiAnh ? null : _doiAnh,
                  child: Tooltip(
                    message: 'Đổi ảnh đại diện',
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: _dangTaiAnh
                          ? const Padding(
                              padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.photo_camera_outlined,
                              size: 15,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            )
          else if (xacMinh || tinCay)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: HD.paperRaised,
                ),
                child: Icon(
                  tinCay ? Icons.verified : Icons.verified_user,
                  size: 18,
                  color: HD.positive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Thẻ số liệu ───────────────────────────────────────────────────────────
  //
  // Chỉ hiện thẻ CÓ SỐ. Người mới tham gia mà trưng "0 khu vực · 0 năm" thì thà
  // đừng trưng — nó nói "người này chưa làm gì" to hơn mọi thứ khác trên trang.
  // Không còn thẻ nào → bỏ luôn cả hàng.
  Widget _stats(AppLocalizations l) {
    final p = _profile!;
    int n(String key, [int fallback = 0]) =>
        (p[key] as num?)?.toInt() ?? fallback;

    final listings = n('listing_count', _houses.length);
    final deals = n('deal_count');
    final reviews = n('review_count');
    final years = n('years_active');

    // Mỗi thẻ một icon riêng: bốn ô chữ số giống hệt nhau thì mắt phải ĐỌC
    // nhãn mới phân biệt được, icon cho phép nhận ra bằng hình dáng.
    // Mỗi thẻ một icon TRONG VÒNG TRÒN MÀU riêng: bốn ô chữ số giống hệt nhau
    // thì mắt phải đọc nhãn mới phân biệt, còn bốn màu thì nhận ra bằng hình.
    final items = <(IconData, Color, String, String)>[
      if (listings > 0)
        (
          Icons.home_work_outlined,
          HD.accent,
          '$listings',
          l.brokerStatListings,
        ),
      // Giao dịch ĐÃ ĐƯỢC CHỦ NHÀ XÁC NHẬN. Sale không tạo được bản ghi này
      // (khách tạo, chủ duyệt) nên con số không tự thổi lên được. 0 thì ẩn —
      // "0 giao dịch" nói to hơn mọi thứ khác trên trang.
      if (deals > 0)
        (Icons.handshake_outlined, HD.warning, '$deals', 'Giao dịch'),
      // KHÔNG có thẻ "Khu vực": nhãn nổi trên bìa đã ghi "5 tin · 3 khu vực".
      // Nói hai lần trên cùng một màn là phí mất một ô.
      if (reviews > 0)
        (
          Icons.star_border_rounded,
          HD.positive,
          '$reviews',
          l.brokerStatReviews,
        ),
      if (years > 0)
        (
          Icons.schedule_outlined,
          const Color(0xFF6366F1),
          '$years+',
          l.brokerStatYears,
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      // Lề trên 0: 30px trắng do `Transform.translate` ở `_hero` để lại đã
      // đóng vai lề rồi.
      padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, 0),
      // `IntrinsicHeight` để 4 thẻ cao BẰNG NHAU dù nhãn 1 hay 2 dòng. Không
      // dùng `stretch` trần: Row nằm trong ListView nên chiều cao không giới
      // hạn, stretch sẽ ép con cao vô hạn và cả trang không dựng được.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: HD.s8),
              // Chỉ dàn đều khi có từ 3 thẻ trở lên. Tài khoản mới chỉ có một
              // thẻ mà kéo dài hết chiều ngang thì con số bé xíu nằm giữa một
              // mảng trống — nhìn như trang bị hỏng chứ không phải "mới".
              if (items.length >= 3)
                Expanded(
                  child: _statCard(
                    items[i].$1,
                    items[i].$2,
                    items[i].$3,
                    items[i].$4,
                  ),
                )
              else
                SizedBox(
                  width: 104,
                  child: _statCard(
                    items[i].$1,
                    items[i].$2,
                    items[i].$3,
                    items[i].$4,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Card "Giới thiệu" — phần người bán tự viết về mình.
  Widget _theGioiThieu() {
    final bio = (_profile?['bio'] as String?)?.trim() ?? '';
    // Khách: không có giới thiệu thì không vẽ khối rỗng.
    // Chủ trang: VẪN vẽ — thiếu chỗ này thì không có nút nào để thêm bio.
    if (bio.isEmpty && !widget.laChuTrang) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, 0),
      child: Container(
        padding: const EdgeInsets.all(HD.s16),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _TieuDeMuc(
                    icon: Icons.info_outline,
                    chu: 'Giới thiệu',
                  ),
                ),
                if (widget.laChuTrang && !_suaBio) ...[
                  const SizedBox(width: HD.s8),
                  DsEditChip(
                    tooltip: 'Sửa giới thiệu',
                    onTap: () => setState(() {
                      _bioCtrl.text = bio;
                      _suaBio = true;
                    }),
                  ),
                ],
              ],
            ),
            const SizedBox(height: HD.s8),
            if (_suaBio)
              _oSuaBio()
            else if (bio.isEmpty)
              Text(
                'Chưa có giới thiệu. Khách xem trang sẽ không biết bạn mạnh ở '
                'khu nào, loại nhà nào.',
                style: HD.body(size: 13, color: HD.inkMuted),
              )
            else
              _BioRutGon(chu: bio),
          ],
        ),
      ),
    );
  }

  // ── Quản lý tin đăng ngay trên bài ─────────────────────────────────────────

  /// Menu ⋯ của một bài — thả xuống NGAY DƯỚI nút, không phải khay trượt từ
  /// đáy màn.
  ///
  /// Khay đáy màn che mất chính bài đang thao tác, và với sáu mục thì nó chiếm
  /// nửa màn hình cho một menu ngữ cảnh. Menu neo vào nút thì bài vẫn nằm đó,
  /// mắt không phải tìm lại.
  Future<void> _khayTin(HouseModel h) async {
    if (h.id == null) return;
    final o = _khoaBai[h.id!]?.currentContext?.findRenderObject();
    if (o is! RenderBox) return;
    final man = Overlay.of(context).context.findRenderObject() as RenderBox;
    final goc = o.localToGlobal(Offset.zero, ancestor: man);
    // Neo vào mép phải, ngay dưới hàng đầu của card (nơi nút ⋯ đứng).
    final viTri = RelativeRect.fromLTRB(
      goc.dx + o.size.width - 260,
      goc.dy + 46,
      man.size.width - goc.dx - o.size.width + 8,
      0,
    );

    final chon = await showMenu<String>(
      context: context,
      position: viTri,
      color: HD.paperRaised,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HD.r12),
      ),
      items: [
        _mucMenu('sua', Icons.edit_outlined, 'Chỉnh sửa bài đăng'),
        _mucMenu(
          'ghim',
          h.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          h.pinned ? 'Bỏ ghim bài đăng' : 'Ghim bài đăng',
          noiBat: h.pinned,
        ),
        _mucMenu('thongke', Icons.bar_chart_rounded, 'Xem thống kê'),
        _mucMenu('chiase', Icons.share_outlined, 'Chia sẻ bài đăng'),
        _mucMenu(
          'an',
          h.status == 'hidden'
              ? Icons.unarchive_outlined
              : Icons.archive_outlined,
          h.status == 'hidden' ? 'Hiện lại bài đăng' : 'Ẩn bài đăng',
        ),
        const PopupMenuDivider(),
        _mucMenu('xoa', Icons.delete_outline, 'Xoá bài đăng', nguyHiem: true),
      ],
    );
    if (chon == null || !mounted) return;
    switch (chon) {
      case 'sua':
        await _mo(PostHouseScreen(editing: h));
      case 'ghim':
        await _ghim(h);
      case 'thongke':
        await _moThongKe(h);
      case 'chiase':
        await _chiaSeTin(h);
      case 'an':
        await _anTin(h);
      case 'xoa':
        await _xoaTin(h);
    }
  }

  PopupMenuItem<String> _mucMenu(
    String gia,
    IconData icon,
    String chu, {
    bool nguyHiem = false,
    bool noiBat = false,
  }) {
    final mau = nguyHiem ? HD.negative : HD.ink;
    return PopupMenuItem<String>(
      value: gia,
      height: 46,
      // Nền nhạt cho mục đang BẬT (đã ghim) — cùng cách trang khác đánh dấu
      // trạng thái, không phải chỉ đổi chữ rồi để người ta tự nhớ.
      child: Container(
        color: noiBat ? HD.accentTint : null,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 19, color: nguyHiem ? HD.negative : HD.inkSoft),
            const SizedBox(width: HD.s12),
            Flexible(
              child: Text(
                chu,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 14.5, color: mau),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ghim(HouseModel h) async {
    try {
      await _xaHoi.ghim(h.id!, ghim: !h.pinned);
      if (!mounted) return;
      AppFeedback.success(context, h.pinned ? 'Đã bỏ ghim' : 'Đã ghim lên đầu');
      await _load();
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Không ghim được: $e');
    }
  }

  Future<void> _anTin(HouseModel h) async {
    final dangAn = h.status == 'hidden';
    try {
      await _xaHoi.doiHienThi(h.id!, an: !dangAn);
      if (!mounted) return;
      AppFeedback.success(
        context,
        dangAn ? 'Tin đã hiện lại' : 'Đã ẩn — khách không còn thấy tin này',
      );
      await _load();
    } catch (e) {
      if (mounted) {
        // 409 = tin đang chờ duyệt / bị từ chối. Nói đúng lý do thay vì
        // "có lỗi xảy ra".
        AppFeedback.error(
          context,
          '$e'.contains('409')
              ? 'Tin đang chờ duyệt hoặc bị từ chối — không tự ẩn/hiện được'
              : 'Không đổi được: $e',
        );
      }
    }
  }

  Future<void> _chiaSeTin(HouseModel h) async {
    final url = Env.housePublicUrl(h.id!, h.title);
    try {
      await Share.share('${h.title}\n$url');
      return;
    } catch (_) {
      // Nền tảng không có khay chia sẻ → copy.
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) AppFeedback.info(context, 'Đã sao chép link tin');
  }

  Future<void> _moThongKe(HouseModel h) async {
    await showDsBottomSheet<void>(
      context: context,
      builder: (_) => DsBottomSheet(
        title: 'Thống kê tin',
        child: FutureBuilder<ThongKeTin>(
          future: _xaHoi.thongKe(h.id!),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Không tải được số liệu',
                    style: HD.body(color: HD.inkMuted),
                  ),
                ),
              );
            }
            final t = snap.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  h.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 13, color: HD.inkMuted),
                ),
                const SizedBox(height: HD.s16),
                _dongSo(Icons.visibility_outlined, 'Lượt xem', t.luotXem),
                _dongSo(Icons.favorite_border, 'Lượt tim', t.luotTim),
                _dongSo(Icons.mode_comment_outlined, 'Bình luận', t.binhLuan),
                _dongSo(Icons.bookmark_border, 'Khách lưu tin', t.luotLuu),
                _dongSo(
                  Icons.event_available_outlined,
                  'Lịch hẹn xem',
                  t.lichHen,
                ),
                const SizedBox(height: HD.s12),
                // Nói thẳng mốc bắt đầu: lượt xem chỉ tính từ khi bật đo
                // (06/09/2026), không suy ngược cho tin cũ.
                Text(
                  'Lượt xem đếm từ 06/09/2026, không tính lượt bạn tự mở.',
                  textAlign: TextAlign.center,
                  style: HD.caption(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dongSo(IconData icon, String nhan, int so) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 18, color: HD.accent),
        const SizedBox(width: HD.s12),
        Expanded(child: Text(nhan, style: HD.body(size: 14))),
        Text('$so', style: HD.bodyBold(size: 16)),
      ],
    ),
  );

  // ── Tim & bình luận (ai cũng dùng, không riêng chủ trang) ──────────────────

  Future<void> _doiTim(HouseModel h) async {
    if (h.id == null) return;
    if (!GuestGate.requireAuth(
      context,
      message: 'Đăng nhập để thích tin này',
    )) {
      return;
    }
    try {
      final r = await _xaHoi.doiTim(h.id!);
      if (mounted) {
        setState(() => _tim[h.id!] = (daTim: r.daTim, soTim: r.soTim));
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Không thích được: $e');
    }
  }

  Future<void> _moBinhLuan(HouseModel h) async {
    if (h.id == null) return;
    await showDsBottomSheet<void>(
      context: context,
      builder: (_) => BinhLuanSheet(
        nap: () => _xaHoi.binhLuan(h.id!),
        gui: (noiDung, {int? parentId}) =>
            _xaHoi.vietBinhLuan(h.id!, noiDung, parentId: parentId),
        xoa: (cid) => _xaHoi.xoaBinhLuan(h.id!, cid),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _xoaTin(HouseModel h) async {
    // Nói ĐÚNG thứ backend làm: `delete_house` xoá kèm lịch hẹn xem và lượt
    // lưu của khách. Chỉ ghi "xoá tin" là giấu mất phần đó.
    final dongY = await showDsConfirm(
      context: context,
      title: 'Xoá tin này?',
      message:
          '"${h.title}" sẽ biến mất khỏi trang của bạn và khỏi kết quả tìm '
          'kiếm. Lịch hẹn xem và lượt lưu của khách cũng mất theo.',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!dongY || !mounted) return;
    try {
      final xoa = widget.xoaTinLoader ?? _houseRepo.deleteHouse;
      await xoa(h.id!);
      if (!mounted) return;
      AppFeedback.success(context, 'Đã xoá tin');
      await _load();
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Xoá không được: $e');
    }
  }

  /// Nhãn trạng thái — CHỈ vẽ cho tin chưa hiển thị với khách.
  ///
  /// Chủ trang nhìn thấy cả tin ẩn/chờ duyệt/bị từ chối (xem `_load`), nên phải
  /// phân biệt được ngay cái nào khách đang thấy và cái nào không.
  Widget? _nhanTrangThai(HouseModel h) {
    final (chu, mau) = switch (h.status) {
      'hidden' => ('Đang ẩn', HD.inkMuted),
      'pending' => ('Chờ duyệt', HD.warning),
      'rejected' => ('Bị từ chối', HD.negative),
      _ => (null, HD.inkMuted),
    };
    if (chu == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(HD.r4),
      ),
      child: Text(chu, style: HD.bodyBold(size: 10.5, color: mau)),
    );
  }

  /// Đổi ảnh đại diện NGAY TẠI CHỖ: chọn ảnh → tải lên → lưu → nạp lại.
  ///
  /// Trước đây nút này đẩy sang `EditProfileScreen` — cả một biểu mẫu tên,
  /// email, ngày sinh, CCCD chỉ để thay một tấm ảnh, rồi quay về mới biết
  /// kết quả.
  Future<void> _doiAnh() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tep = await withCameraPermission(
      context,
      source: ImageSource.gallery,
      primingContext: CameraContext.profileAvatar,
      userId: '${auth.currentUser?.id ?? ''}',
    );
    if (tep == null || !mounted) return; // bấm huỷ ở trình chọn ảnh
    setState(() => _dangTaiAnh = true);
    try {
      final url = await _api.uploadImage(await tep.readAsBytes(), tep.name);
      final ok = await auth.updateProfile(avatarPath: url);
      if (!mounted) return;
      setState(() => _dangTaiAnh = false);
      if (ok) {
        await _load();
      } else {
        AppFeedback.error(context, auth.errorMessage ?? 'Không lưu được ảnh');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangTaiAnh = false);
      AppFeedback.error(context, 'Tải ảnh không được: $e');
    }
  }

  /// Ô nhập TÊN nằm đúng chỗ dòng tên. Một dòng nên nút nằm ngang bên phải.
  Widget _oSuaTen() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _tenCtrl,
            autofocus: true,
            enabled: !_dangLuu,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _luuTen(),
            style: HD.bodyBold(size: 18),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
        _nutNho(Icons.check, 'Lưu', HD.positive, _dangLuu ? null : _luuTen),
        _nutNho(
          Icons.close,
          'Huỷ',
          HD.inkMuted,
          _dangLuu ? null : () => setState(() => _suaTen = false),
        ),
      ],
    );
  }

  void _luuTen() {
    final t = _tenCtrl.text.trim();
    // Tên rỗng thì trang cá nhân thành một thẻ không có ai — chặn ngay tại đây
    // thay vì để backend trả lỗi mơ hồ.
    if (t.isEmpty) {
      AppFeedback.error(context, 'Tên không được để trống');
      return;
    }
    _luuHoSo(ten: t);
  }

  /// Ô nhập GIỚI THIỆU — nhiều dòng nên nút xuống hàng dưới.
  Widget _oSuaBio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _bioCtrl,
          autofocus: true,
          enabled: !_dangLuu,
          maxLines: 6,
          minLines: 3,
          maxLength: 500,
          style: HD.body(size: 13.5),
          decoration: const InputDecoration(
            hintText: 'Bạn mạnh ở khu nào, loại nhà nào, làm nghề bao lâu?',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DsButton(
              label: 'Huỷ',
              variant: DsButtonVariant.ghost,
              size: DsButtonSize.compact,
              onPressed: _dangLuu
                  ? null
                  : () => setState(() => _suaBio = false),
            ),
            const SizedBox(width: HD.s8),
            DsButton(
              label: 'Lưu',
              size: DsButtonSize.compact,
              isLoading: _dangLuu,
              onPressed: _dangLuu
                  ? null
                  : () => _luuHoSo(bio: _bioCtrl.text.trim()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _nutNho(IconData icon, String tooltip, Color mau, VoidCallback? cham) {
    return IconButton(
      tooltip: tooltip,
      onPressed: cham,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 20, color: cham == null ? HD.inkMuted : mau),
    );
  }

  Widget _statCard(IconData icon, Color mau, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: HD.s12, horizontal: 4),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mau.withValues(alpha: .12),
            ),
            child: Icon(icon, size: 15, color: mau),
          ),
          const SizedBox(height: 5),
          Text(value, style: HD.masthead(size: 19, color: HD.ink)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 10.5, color: HD.inkMuted),
          ),
        ],
      ),
    );
  }

  // ── Bản đồ điểm chốt ──────────────────────────────────────────────────────
  List<HouseModel> get _pins => _houses
      .where((h) => h.latitude != null && h.longitude != null)
      .toList(growable: false);

  // ── Bài đăng của sale ─────────────────────────────────────────────────────
  //
  // Kiểu TƯỜNG FACEBOOK: mỗi tin là một bài, trải dọc xuống dưới — giống hệt
  // feed ở tab Tin tức. Bản trước là dải ngang 240px cuộn sang phải: nhét được
  // nhiều tin vào ít chỗ, nhưng ảnh bé, giá bé, và ai không kéo ngang thì chỉ
  // thấy đúng hai tin đầu. Trang này sinh ra để KHOE hàng, nên hàng phải to.
  //
  // Dùng lại `FbPostCard` của feed chứ không vẽ thẻ riêng: cùng một thứ (tin
  // đăng) mà mỗi màn một kiểu thì người dùng phải học lại cách đọc ở mỗi chỗ.
  List<HouseModel> get _feed => _loc.isEmpty
      ? _houses
      : _houses.where((h) => h.transactionType == _loc).toList();

  int _dem(String loai) =>
      _houses.where((h) => h.transactionType == loai).length;

  Widget _listingsSection(AppLocalizations l) {
    final ds = _feed;
    final soThue = _dem('rent');
    final soBan = _dem('sale');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: _khoaTinDang,
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s24, HD.s16, HD.s8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: _TieuDeMuc(
                        icon: Icons.article_outlined,
                        chu: l.brokerListings,
                      ),
                    ),
                    const SizedBox(width: HD.s8),
                    Text('${_houses.length}', style: HD.caption()),
                  ],
                ),
              ),
              // Đăng tin mới đứng ngay đầu mục — chỗ mắt dừng lại trước khi
              // cuộn qua danh sách. Chip "Quản lý tin đăng" cũ đã bỏ: sửa và
              // xoá nay nằm trong menu ⋯ của từng bài.
              if (widget.laChuTrang && widget.choDangBai) ...[
                const SizedBox(width: HD.s8),
                DsButton(
                  label: 'Thêm tin',
                  icon: Icons.add,
                  variant: DsButtonVariant.secondary,
                  size: DsButtonSize.compact,
                  onPressed: () => _mo(const PostHouseScreen()),
                ),
              ],
            ],
          ),
        ),
        if (_houses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chipLoc('Tất cả', '', _houses.length),
                        // Chip nào ĐẾM RA 0 thì không vẽ: một bộ lọc bấm vào ra
                        // danh sách rỗng chỉ tổ làm người ta tưởng trang hỏng.
                        if (soThue > 0) _chipLoc('Cho thuê', 'rent', soThue),
                        if (soBan > 0) _chipLoc('Bán', 'sale', soBan),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: HD.s8),
                _nutDangXem(),
              ],
            ),
          ),
        if (ds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HD.s16,
              vertical: HD.s24,
            ),
            child: Center(
              child: Text(
                widget.laChuTrang && _houses.isEmpty
                    ? (widget.choDangBai
                          ? 'Chưa có tin nào. Bấm "Thêm tin" để đăng bài đầu tiên.'
                          : 'Chưa có tin nào. Tin rao do sale phụ trách đăng; '
                                'bạn gán phòng vào tin ở mục Quản lí nhà.')
                    : 'Không có tin nào',
                textAlign: TextAlign.center,
                style: HD.body(color: HD.inkMuted),
              ),
            ),
          )
        else if (_dangLuoi)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HD.s16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: HD.s12,
                crossAxisSpacing: HD.s12,
                // Ảnh vuông + 3 dòng chữ. 0.72 (bản trước) bóp ảnh bẹp và
                // chèn chữ; 0.62 cho ảnh vuông thật và chữ có chỗ thở.
                childAspectRatio: 0.62,
              ),
              itemCount: _soHien(ds.length),
              itemBuilder: (_, i) => _oLuoi(ds[i]),
            ),
          )
        else
          for (final h in ds.take(_soHien(ds.length))) ...[
            KeyedSubtree(
              key: _khoaBai.putIfAbsent(h.id ?? 0, GlobalKey.new),
              child: _baiDang(h, l),
            ),
            const SizedBox(height: HD.s8),
          ],
        if (ds.length > _soHien(ds.length)) _nutXemThem(ds.length),
      ],
    );
  }

  int _soHien(int tong) => _moHetTin ? tong : _soTinBanDau;

  Widget _nutXemThem(int tong) {
    final conLai = tong - _soHien(tong);
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s4, HD.s16, 0),
      child: DsButton(
        label: 'Xem thêm $conLai tin',
        variant: DsButtonVariant.secondary,
        trailingIcon: Icons.expand_more,
        expand: true,
        onPressed: () => setState(() => _moHetTin = true),
      ),
    );
  }

  Widget _chipLoc(String nhan, String gia_tri, int n) {
    final chon = _loc == gia_tri;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() {
          _loc = gia_tri;
          // Thu gọn lại khi đổi bộ lọc: giữ trạng thái "đã mở hết" của lần lọc
          // trước sẽ làm danh sách mới bung ra bất ngờ.
          _moHetTin = false;
        }),
        borderRadius: BorderRadius.circular(HD.rPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: HD.s12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: chon ? HD.ink : HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.rPill),
            border: Border.all(color: chon ? HD.ink : HD.hairline),
          ),
          child: Text(
            '$nhan ($n)',
            style: HD.bodyBold(
              size: 12.5,
              color: chon ? HD.paperRaised : HD.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _nutDangXem() {
    Widget o(IconData icon, bool luoi, String tip) => Tooltip(
      message: tip,
      child: InkWell(
        onTap: () => setState(() => _dangLuoi = luoi),
        borderRadius: BorderRadius.circular(HD.r8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _dangLuoi == luoi ? HD.paperRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          child: Icon(
            icon,
            size: 17,
            color: _dangLuoi == luoi ? HD.accent : HD.inkMuted,
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: HD.paperSunken,
        borderRadius: BorderRadius.circular(HD.r8),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          o(Icons.view_agenda_outlined, false, 'Dạng bài viết'),
          o(Icons.grid_view_rounded, true, 'Dạng lưới'),
        ],
      ),
    );
  }

  /// Ô trong dạng lưới 2 cột.
  ///
  /// Bản trước nhét giá + tiêu đề 2 dòng + địa chỉ vào một ô cao 0.72 tỷ lệ:
  /// chữ chen nhau, ảnh bẹp, và ba dòng chữ cùng cỡ nên không có gì dẫn mắt.
  /// Nay: ảnh VUÔNG có nhãn loại đè lên, rồi giá là dòng to nhất, tiêu đề nhỏ
  /// hơn, cuối cùng là hàng thông số có icon.
  Widget _oLuoi(HouseModel h) {
    final anh = h.images.isEmpty ? null : _abs(h.images.first);
    final thongSo = [
      if (h.area > 0) '${h.area.toStringAsFixed(0)}m²',
      if (h.bedrooms > 0) '${h.bedrooms} PN',
    ].join(' · ');

    return InkWell(
      onTap: () => context.push('/house/${h.id}'),
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (anh == null)
                    Container(
                      color: HD.paperSunken,
                      child: const Icon(
                        Icons.home_outlined,
                        color: HD.inkMuted,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: anh,
                      fit: BoxFit.cover,
                      memCacheWidth: 420,
                      placeholder: (_, _) =>
                          const ColoredBox(color: HD.paperSunken),
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: HD.paperSunken),
                    ),
                  if (widget.laChuTrang) ...[
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: const Color(0xB3000000),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _khayTin(h),
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_nhanTrangThai(h) != null)
                      Positioned(
                        left: 6,
                        top: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: HD.paperRaised,
                            borderRadius: BorderRadius.circular(HD.r4),
                          ),
                          child: _nhanTrangThai(h),
                        ),
                      ),
                  ],
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: h.isForSale ? HD.ink : HD.accent,
                        borderRadius: BorderRadius.circular(HD.r4),
                      ),
                      child: Text(
                        h.isForSale ? 'Bán' : 'Cho thuê',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Số ảnh — cho biết bấm vào còn gì để xem.
                  if (h.images.length > 1)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(HD.r4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${h.images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(HD.s8, HD.s8, HD.s8, HD.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _giaGon(h),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 15, color: HD.accent),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    h.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12.5, color: HD.ink),
                  ),
                  const SizedBox(height: HD.s4),
                  Row(
                    children: [
                      if (thongSo.isNotEmpty) ...[
                        Text(thongSo, style: HD.caption()),
                        const SizedBox(width: 5),
                        Text('·', style: HD.caption()),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          h.district.isNotEmpty ? h.district : h.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.caption(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _giaGon(HouseModel h) => h.price <= 0
      ? 'Thoả thuận'
      : '${PriceFormat.compact(h.price)}${h.isForRent ? '/tháng' : ''}';

  // ── Đánh giá khách hàng ───────────────────────────────────────────────────
  //
  // Chỉ vẽ khi CÓ nhận xét. Điểm trung bình lấy từ hồ sơ (backend tính), không
  // tự cộng lại từ mấy dòng đang hiển thị — chúng chỉ là 5 cái gần nhất.
  Widget _khoiDanhGia() {
    final p = _profile!;
    final diem = (p['rating'] as num?)?.toDouble();
    final tong = (p['review_count'] as num?)?.toInt() ?? _nhanXet.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s24, HD.s16, 0),
      child: Container(
        padding: const EdgeInsets.all(HD.s16),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TieuDeMuc(
                        icon: Icons.reviews_outlined,
                        chu: 'Đánh giá từ khách hàng',
                      ),
                      const SizedBox(height: HD.s4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            diem == null ? '—' : diem.toStringAsFixed(1),
                            style: HD.masthead(size: 22),
                          ),
                          const SizedBox(width: HD.s4),
                          Text('/ 5.0 · $tong nhận xét', style: HD.caption()),
                        ],
                      ),
                    ],
                  ),
                ),
                if (diem != null) _HangSao(diem: diem),
              ],
            ),
            const SizedBox(height: HD.s12),
            for (final r in _nhanXet.take(3)) ...[
              _theNhanXet(r),
              const SizedBox(height: HD.s8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _theNhanXet(Map<String, dynamic> r) {
    final ten = (r['user_name'] as String?)?.trim();
    final tenHT = (ten == null || ten.isEmpty) ? 'Khách' : ten;
    final diem = (r['rating'] as num?)?.toDouble() ?? 0;
    final chu = (r['comment'] as String?)?.trim() ?? '';
    final tin = (r['house_title'] as String?)?.trim();

    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paper,
        borderRadius: BorderRadius.circular(HD.r8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: HD.paperSunken,
                child: Text(
                  tenHT[0].toUpperCase(),
                  style: HD.bodyBold(size: 12),
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenHT, style: HD.bodyBold(size: 12.5)),
                    if (tin != null && tin.isNotEmpty)
                      Text(
                        tin,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.caption(),
                      ),
                  ],
                ),
              ),
              Text(
                '${diem.toStringAsFixed(1)} ★',
                style: HD.bodyBold(size: 12, color: HD.warning),
              ),
            ],
          ),
          if (chu.isNotEmpty) ...[
            const SizedBox(height: HD.s8),
            Text(
              chu,
              style: HD.body(size: 12.5).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _baiDang(HouseModel h, AppLocalizations l) {
    // Trạng thái tim: bản đè cục bộ (vừa bấm) thắng dữ liệu tải về.
    final de = _tim[h.id];
    final daTim = de?.daTim ?? h.liked;
    final soTim = de?.soTim ?? h.likeCount;
    return FbPostCard(
      authorName: _ten,
      avatarUrl: _absOrNull(_profile?['avatar_path'] as String?),
      subtitle: [
        if (h.district.isNotEmpty) h.district,
        if (h.city.isNotEmpty) h.city,
      ].join(' · '),
      badge: widget.laChuTrang ? _nhanTrangThai(h) : null,
      body: h.title,
      media: _anhVaGia(h, l),
      likeCount: soTim,
      commentCount: h.commentCount,
      liked: daTim,
      onMore: widget.laChuTrang ? () => _khayTin(h) : null,
      onTap: () => context.push('/house/${h.id}'),
      // Hàng nút mặc định của FbPostCard: Thích · Bình luận · Chia sẻ. Tin
      // đăng nay có tim và bình luận thật (migration 0090) nên không còn lý
      // do bắt nó cư xử khác một bài viết. "Chi tiết" chuyển lên nằm ngay
      // dưới dòng giá — đó là nơi mắt đang ở sau khi xem ảnh.
      onLike: () => _doiTim(h),
      onComment: () => _moBinhLuan(h),
      onShare: () => _chiaSeTin(h),
    );
  }

  /// Ảnh lớn + dòng giá bên dưới — cùng bố cục với thẻ ở feed Tin tức.
  Widget _anhVaGia(HouseModel h, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: h.images.isEmpty
              ? Container(
                  color: HD.paperSunken,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.home_outlined,
                    size: 40,
                    color: HD.inkMuted,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: _abs(h.images.first),
                  fit: BoxFit.cover,
                  memCacheWidth: 900,
                  placeholder: (_, _) => Container(color: HD.paperSunken),
                  errorWidget: (_, _, _) => Container(color: HD.paperSunken),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: Row(
            children: [
              Text(
                h.priceCompactLabel,
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
                l.homeAreaM2(h.area.toStringAsFixed(0)),
                style: const TextStyle(
                  fontSize: 13,
                  color: HD.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // "Chi tiết" nằm NGAY DƯỚI dòng giá, trên hàng Thích/Bình luận/Chia
        // sẻ — đây là chỗ mắt dừng lại sau khi xem ảnh và giá. Trước đây nó
        // chiếm luôn hàng nút, đẩy tim và bình luận ra khỏi card.
        InkWell(
          onTap: () => context.push('/house/${h.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_forward, size: 16, color: HD.inkSoft),
                const SizedBox(width: 6),
                Text(l.homeDetails, style: HD.bodyBold(size: 13.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

String? _absOrNull(String? url) =>
    (url == null || url.isEmpty) ? null : _abs(url);

/// Tiêu đề một mục trên trang cá nhân — icon + chữ, cùng một kiểu ở mọi mục.
///
/// Vì sao tách widget: trang này có 5 mục, trước đây mỗi chỗ tự viết `Text(...)`
/// với cỡ chữ hơi khác nhau. Mắt đọc được sự lệch đó kể cả khi không chỉ ra
/// được lệch chỗ nào — nó làm trang trông "chưa xong".
class _TieuDeMuc extends StatelessWidget {
  const _TieuDeMuc({required this.icon, required this.chu});

  final IconData icon;
  final String chu;

  @override
  Widget build(BuildContext context) {
    // `mainAxisSize.min` + `Flexible`: tiêu đề này được đặt bên trong một Row
    // khác (mục "Tin đang đăng" có thêm con số bên phải). Row lồng Row mà
    // không giới hạn thì Flutter không dựng được và cả trang trắng.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: HD.accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            chu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.bodyBold(size: 15),
          ),
        ),
      ],
    );
  }
}

/// Nhãn nổi góc bìa: "19 tin · 11 khu vực".
///
/// Ở mức phóng cả nước, ghim nhỏ như hạt bụi và người xem không đếm được.
/// Con số làm thay việc đó, còn bản đồ giữ vai trò cho biết vùng nào.
class _NhanBanDo extends StatelessWidget {
  const _NhanBanDo({required this.soTin, required this.soKhu});

  final int soTin;
  final int soKhu;

  @override
  Widget build(BuildContext context) {
    if (soTin == 0) return const SizedBox.shrink();
    final chu = soKhu > 0 ? '$soTin tin · $soKhu khu vực' : '$soTin tin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(HD.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            chu,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Đoạn giới thiệu rút gọn 2 dòng, có "Xem thêm".
///
/// Nút chỉ hiện khi chữ THỰC SỰ bị cắt — đo bằng [TextPainter] chứ không đoán
/// theo số ký tự: cùng một độ dài, tiếng Việt có dấu và màn hình rộng cho ra
/// số dòng khác nhau, đoán kiểu đó sẽ có bài hiện "Xem thêm" mà bấm vào không
/// thấy gì thêm.
class _BioRutGon extends StatefulWidget {
  const _BioRutGon({required this.chu});

  final String chu;

  @override
  State<_BioRutGon> createState() => _BioRutGonState();
}

class _BioRutGonState extends State<_BioRutGon> {
  static const _soDong = 2;
  bool _moRong = false;

  @override
  Widget build(BuildContext context) {
    final kieu = HD.body(size: 15, color: HD.inkSoft);
    return LayoutBuilder(
      builder: (context, rang) {
        final do_ = TextPainter(
          text: TextSpan(text: widget.chu, style: kieu),
          maxLines: _soDong,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: rang.maxWidth);
        final biCat = do_.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chu,
              style: kieu,
              maxLines: _moRong ? null : _soDong,
              overflow: _moRong ? null : TextOverflow.ellipsis,
            ),
            if (biCat)
              InkWell(
                onTap: () => setState(() => _moRong = !_moRong),
                child: Padding(
                  padding: const EdgeInsets.only(top: HD.s4),
                  child: Text(
                    _moRong ? 'Thu gọn' : 'Xem thêm',
                    style: HD.bodyBold(size: 13, color: HD.accent),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Nhãn hạng cạnh tên. Chỉ vẽ khi backend nói `trusted` — cờ đó tính từ đánh
/// giá ĐÃ KIỂM (migration 0087), không phải chữ ai cũng tự gán được.
class _NhanHang extends StatelessWidget {
  const _NhanHang();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: HD.warningTint,
        borderRadius: BorderRadius.circular(HD.r4),
        border: Border.all(color: HD.warning.withValues(alpha: .4)),
      ),
      child: Text(
        'UY TÍN',
        style: HD.eyebrow(color: HD.warning).copyWith(fontSize: 9.5),
      ),
    );
  }
}

/// Dải chip trượt ngang ở đáy bìa: khu vực hoạt động + loại BĐS chuyên.
///
/// Cả hai SUY TỪ TIN ĐANG ĐĂNG, không tự khai. Đặt trên bìa thay vì thành hai
/// hàng riêng bên dưới: chúng trả lời cùng một câu hỏi với bản đồ ("bán ở đâu,
/// bán loại gì"), tách ra là bắt mắt nhảy hai lần cho một ý.
///
/// KHÔNG có chấm màu đầu chip. Trước đây mỗi chip có một chấm lấy theo VỊ TRÍ
/// trong dải, còn ghim trên bản đồ tô theo LOẠI TIN (`PinKind`) — hai hệ màu
/// không liên quan gì nhau. Đặt ngay trên bản đồ thì người xem đọc thành chú
/// giải màu và tưởng chấm vàng ứng với ghim vàng.
class _ChipKhuVuc extends StatelessWidget {
  const _ChipKhuVuc({required this.khu, required this.mon});

  final List<String> khu;
  final List<String> mon;

  @override
  Widget build(BuildContext context) {
    final muc = [...khu.take(3), ...mon.take(2)];
    if (muc.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: muc.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0x40000000),
            borderRadius: BorderRadius.circular(HD.r8),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Text(
            muc[i],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Năm ngôi sao vàng theo điểm. Repo chưa có widget dùng chung cho việc này —
/// `DsQualityStars` là thang vạch đỏ cho chất lượng cơ sở, cố ý khác.
class _HangSao extends StatelessWidget {
  const _HangSao({required this.diem});

  final double diem;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= diem.round() ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 15,
            color: HD.warning,
          ),
      ],
    );
  }
}
