import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/image_grid_uploader.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/guest/booking/cho_xac_nhan_hoan_tat_screen.dart';
import 'package:house_booking/features/shared/rental_journey_compact_widgets.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';
import 'package:house_booking/providers/chat_provider.dart';

/// MÀN 6 — "Cọc & xác nhận thuê" (mockup KHÁCH THUÊ, 20/09/2026).
///
/// Cọc chia đôi: 50% chuyển vào tài khoản Vua Nhà (ký quỹ), 50% chuyển thẳng
/// cho chủ nhà. Khách tải MINH CHỨNG từng nửa; đủ hai nửa thì bấm xác nhận
/// (`/confirm`) — server mới chuyển hồ sơ sang hoàn tất.
///
/// API: `GET /api/rental-journeys/{id}`, `/payment-account`,
/// `PUT /{id}/payments/{APP_DEPOSIT|OWNER_DEPOSIT}/proof`, `POST /{id}/confirm`.
///
/// ĐƯỜNG DẪN MINH CHỨNG: server chỉ nhận đường dẫn TƯƠNG ĐỐI dạng
/// `/uploads/<tệp>` (`rental_journey_policy.validate_evidence_paths`), còn
/// `ApiClient.uploadImage` trả URL tuyệt đối để hiện ảnh — nên phải cắt phần
/// tên miền trước khi gửi, nếu không server trả 422.
///
/// Số tài khoản công ty lấy từ cấu hình server; chưa khai thì nói thẳng "chưa
/// có tài khoản nhận cọc" thay vì in một số tài khoản bịa.
class CocXacNhanThueScreen extends StatefulWidget {
  const CocXacNhanThueScreen({
    super.key,
    required this.journeyId,
    this.api = const RentalJourneyApi(),
    this.uploadFn,
  });

  final int journeyId;
  final RentalJourneyApi api;

  /// Chỉ để test thay chỗ tải ảnh thật.
  final ImageUploadFn? uploadFn;

  @override
  State<CocXacNhanThueScreen> createState() => _CocXacNhanThueScreenState();
}

class _CocXacNhanThueScreenState extends State<CocXacNhanThueScreen> {
  RentalJourney? _hs;
  PlatformPaymentAccount? _tk;
  final List<UploadImage> _anhApp = [];
  final List<UploadImage> _anhChu = [];
  bool _dangTai = true;
  bool _dangNap = false;
  bool _dangGui = false;
  String? _loi;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  bool _daNoiRealtime = false;

  /// Lỗi của MỘT khối minh chứng — hiện ngay dưới khối đó. Dùng chung một
  /// dòng lỗi cuối trang thì bấm nút khối dưới mà trông như khối trên hỏng.
  String? _loiKind;
  String? _loiKhoan;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_daNoiRealtime) return;
    _daNoiRealtime = true;
    try {
      _statusSub = context.read<ChatProvider>().statusEvents.listen((event) {
        final id = (event['entity_id'] as num?)?.toInt();
        if (event['entity'] == 'rental_journey' && id == widget.journeyId) {
          _nap();
        }
      });
    } catch (_) {
      // Widget tests may mount this screen without the app-level provider.
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _nap() async {
    if (_dangNap) return;
    _dangNap = true;
    try {
      final hs = await widget.api.detail(widget.journeyId);
      PlatformPaymentAccount? tk;
      try {
        tk = await widget.api.paymentAccount();
      } catch (_) {
        tk = null;
      }
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _tk = tk;
        _dangTai = false;
        _loi = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được hồ sơ thuê. Kéo xuống để thử lại.';
      });
    } finally {
      _dangNap = false;
    }
  }

  JourneyPayment? _khoan(String kind) {
    for (final p in _hs?.payments ?? const <JourneyPayment>[]) {
      if (p.kind == kind) return p;
    }
    return null;
  }

  /// URL tuyệt đối → đường dẫn tương đối server nhận.
  static String _duongDan(String url) {
    final i = url.indexOf('/uploads/');
    return i >= 0 ? url.substring(i) : url;
  }

  Future<String> _tai(List<int> bytes, String ten) =>
      (widget.uploadFn ?? const ApiClient().uploadImage)(bytes, ten);

  Future<void> _guiMinhChung(String kind, List<UploadImage> anh) async {
    final xong = [
      for (final a in anh)
        if (a.url != null && a.url!.isNotEmpty) _duongDan(a.url!),
    ];
    if (xong.isEmpty) {
      setState(() {
        _loiKind = kind;
        _loiKhoan = anh.isEmpty
            ? 'Chọn ảnh chuyển khoản trước đã.'
            : 'Ảnh đang tải lên, chờ vài giây rồi bấm lại.';
      });
      return;
    }
    setState(() {
      _dangGui = true;
      _loi = null;
      _loiKind = null;
    });
    try {
      final hs = await widget.api.submitPaymentProof(
        widget.journeyId,
        kind: kind,
        urls: xong,
      );
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _dangGui = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loiKind = kind;
        _loiKhoan = e is ApiException ? e.message : 'Chưa gửi được minh chứng.';
      });
    }
  }

  Future<void> _xacNhan() async {
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final hs = await widget.api.confirm(widget.journeyId);
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _dangGui = false;
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChoXacNhanHoanTatScreen(
            journeyId: widget.journeyId,
            api: widget.api,
            initial: hs,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa xác nhận được.';
      });
    }
  }

  void _chep(String chu, String ten) {
    Clipboard.setData(ClipboardData(text: chu));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã chép $ten')));
  }

  @override
  Widget build(BuildContext context) {
    final hs = _hs;
    final nuaCoc = ((hs?.totalDeposit ?? 0) / 2).round();
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Cọc & hợp đồng',
          style: HD.bodyBold(size: 17, color: Colors.white),
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  HD.s16,
                  HD.s8,
                  HD.s16,
                  HD.s24,
                ),
                children: [
                  if (hs != null)
                    RentalJourneyCompactHeader(
                      journey: hs,
                      subtitle: 'Khách thuê',
                    ),
                  const SizedBox(height: HD.s12),
                  if (!_denBuocCoc(hs))
                    _choHopDong()
                  else ...[
                    _chiaCoc(nuaCoc),
                    const SizedBox(height: HD.s12),
                    if (hs != null)
                      RentalEvidenceCard(journey: hs, keyPrefix: 'coc'),
                    const SizedBox(height: HD.s12),
                    Text('Chuyển cọc Vua Nhà', style: HD.bodyBold(size: 14)),
                    const SizedBox(height: HD.s8),
                    _theNganHang(hs),
                    if (!(_khoan('APP_DEPOSIT')?.hasProof ?? false) &&
                        _choPhepNop('APP_DEPOSIT')) ...[
                      const SizedBox(height: HD.s16),
                      _khoiMinhChung(
                        kind: 'APP_DEPOSIT',
                        tieuDe: 'Ảnh chuyển cọc Vua Nhà',
                        anh: _anhApp,
                      ),
                    ],
                    if (!(_khoan('OWNER_DEPOSIT')?.hasProof ?? false) &&
                        _choPhepNop('OWNER_DEPOSIT')) ...[
                      const SizedBox(height: HD.s16),
                      _khoiMinhChung(
                        kind: 'OWNER_DEPOSIT',
                        tieuDe: 'Ảnh chuyển cọc chủ nhà',
                        anh: _anhChu,
                      ),
                    ],
                  ],
                  if (_loi != null) ...[
                    const SizedBox(height: HD.s12),
                    Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _dangTai ? null : _thanhXacNhan(),
    );
  }

  Widget _chiaCoc(int tien) => Container(
    padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: 10),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        Expanded(
          child: _phanCoc(
            Icons.account_balance_wallet_outlined,
            'Vua Nhà',
            tien,
            HD.accent,
          ),
        ),
        Container(width: 1, height: 38, color: HD.hairline),
        Expanded(
          child: _phanCoc(Icons.home_outlined, 'Chủ nhà', tien, HD.positive),
        ),
      ],
    ),
  );

  Widget _phanCoc(IconData icon, String label, int tien, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 7),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('50% · $label', style: HD.bodyBold(size: 12, color: color)),
          if (tien > 0)
            Text(
              PriceFormat.full(tien.toDouble()),
              style: HD.body(size: 11.5, color: HD.inkSoft),
            ),
        ],
      ),
    ],
  );

  /// Bốn bước theo hành trình khách: đã xem → muốn thuê → cọc/hợp đồng → xong.
  Widget _banBuoc(String trangThai) {
    final b = switch (trangThai) {
      'COMPLETED' => 3,
      'CUSTOMER_CONFIRMATION_PENDING' => 2,
      _ => 2,
    };
    return ViewingJourneyProgress(
      labels: const ['Đã xem', 'Muốn thuê', 'Cọc & hợp đồng', 'Hoàn tất'],
      icons: const [Icons.check, Icons.favorite, Icons.description, Icons.home],
      current: b,
    );
  }

  Widget _theCan(RentalJourney hs) => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HD.r8),
          child: SizedBox(
            width: 60,
            height: 52,
            child: (hs.subject.image == null || hs.subject.image!.isEmpty)
                ? const ColoredBox(
                    color: HD.paperSunken,
                    child: Icon(Icons.apartment, color: HD.inkMuted),
                  )
                : CachedNetworkImage(
                    imageUrl: hs.subject.image!.startsWith('http')
                        ? hs.subject.image!
                        : '${ApiConfig.baseUrl}${hs.subject.image}',
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: HD.paperSunken),
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: HD.paperSunken),
                  ),
          ),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hs.subject.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 14),
              ),
              const SizedBox(height: 2),
              Text(
                'Tổng cọc ${PriceFormat.full(hs.totalDeposit.toDouble())}',
                style: HD.bodyBold(size: 13, color: HD.accent),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _oTyLe({
    required IconData icon,
    required Color mau,
    required String ten,
    required String chu,
    required int tien,
  }) => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: mau.withValues(alpha: 0.35)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 20, color: mau),
        const SizedBox(height: 4),
        Text(ten, style: HD.bodyBold(size: 12, color: mau)),
        const SizedBox(height: 2),
        Text('50%', style: HD.bodyBold(size: 20, color: mau)),
        if (tien > 0)
          Text(
            PriceFormat.full(tien.toDouble()),
            style: HD.bodyBold(size: 12, color: HD.ink),
          ),
        const SizedBox(height: 4),
        Text(
          chu,
          textAlign: TextAlign.center,
          style: HD.body(size: 11, color: HD.inkSoft),
        ),
      ],
    ),
  );

  Widget _theNganHang(RentalJourney? hs) {
    final tk = _tk;
    if (tk == null || !tk.isConfigured) {
      return Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: HD.warningTint,
          borderRadius: BorderRadius.circular(HD.r12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: HD.warning),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text(
                'Vua Nhà chưa công bố tài khoản nhận cọc. Liên hệ sale để được '
                'hướng dẫn chuyển khoản.',
                style: HD.body(size: 12.5, color: HD.inkSoft),
              ),
            ),
          ],
        ),
      );
    }
    final noiDung =
        '${tk.transferPrefix} - ${hs?.customer.name ?? ''} - ${hs?.subject.title ?? ''}';
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(HD.r8),
                ),
                child: const Icon(
                  Icons.account_balance,
                  size: 18,
                  color: HD.accent,
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: Text(tk.bankName ?? '', style: HD.bodyBold(size: 13)),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          _dongChep('Số tài khoản', tk.accountNumber ?? '', dam: true),
          _dongChep('Tên tài khoản', tk.accountHolder ?? ''),
          _dongChep('Nội dung chuyển khoản', noiDung),
        ],
      ),
    );
  }

  Widget _dongChep(String nhan, String chu, {bool dam = false}) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nhan, style: HD.body(size: 11.5, color: HD.inkMuted)),
              const SizedBox(height: 2),
              Text(
                chu,
                style: dam
                    ? HD.bodyBold(size: 14, color: HD.svcBlue)
                    : HD.bodyBold(size: 13, color: HD.ink),
              ),
            ],
          ),
        ),
        IconButton(
          key: Key('chep-$nhan'),
          onPressed: chu.isEmpty ? null : () => _chep(chu, nhan.toLowerCase()),
          icon: const Icon(Icons.copy_rounded, size: 16),
          color: HD.inkMuted,
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );

  /// Server quyết khách được nộp khoản nào (`available_actions`). Chưa có
  /// hợp đồng + số tiền cọc thì mọi lần nộp đều bị 409 — đừng mời khách tải
  /// ảnh chuyển khoản cho một khoản cọc 0đ.
  bool _choPhepNop(String kind) {
    final hs = _hs;
    if (hs == null) return false;
    return hs.availableActions.contains(
      kind == 'APP_DEPOSIT'
          ? RentalJourneyAction.submitAppDeposit
          : RentalJourneyAction.submitOwnerDeposit,
    );
  }

  bool _denBuocCoc(RentalJourney? hs) =>
      _choPhepNop('APP_DEPOSIT') ||
      _choPhepNop('OWNER_DEPOSIT') ||
      (_khoan('APP_DEPOSIT')?.hasProof ?? false) ||
      (_khoan('OWNER_DEPOSIT')?.hasProof ?? false);

  Widget _choHopDong() => Container(
    key: const Key('cho-hop-dong-coc'),
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.hourglass_top_rounded, color: HD.accent),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đang chờ hợp đồng và số tiền cọc',
                style: HD.bodyBold(size: 14, color: HD.accent),
              ),
              const SizedBox(height: 4),
              Text(
                'Sale hoặc chủ nhà sẽ gửi hợp đồng và báo số tiền cọc. Khi '
                'có, bạn chuyển cọc và tải ảnh minh chứng ngay tại đây — '
                'chưa cần chuyển khoản lúc này.',
                style: HD.body(size: 12.5, color: HD.ink),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _urlAnh(String url) =>
      url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

  Widget _anhMinhChung({
    required String keyPrefix,
    required List<String> urls,
    required int index,
  }) {
    final dayDu = [for (final url in urls) _urlAnh(url)];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('$keyPrefix-$index'),
        onTap: () => showImageGallery(context, dayDu, initialIndex: index),
        borderRadius: BorderRadius.circular(HD.r8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(HD.r8),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: dayDu[index],
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox(
                  width: 84,
                  height: 84,
                  child: ColoredBox(color: HD.paperSunken),
                ),
                errorWidget: (_, _, _) => const SizedBox(
                  width: 84,
                  height: 84,
                  child: ColoredBox(color: HD.paperSunken),
                ),
              ),
              const Positioned(
                right: 5,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _khoiHopDong(List<String> urls) => Column(
    key: const Key('coc-hop-dong-minh-chung'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text('Hợp đồng', style: HD.bodyBold(size: 14))),
          const Icon(Icons.check_circle, size: 15, color: HD.positive),
          const SizedBox(width: 4),
          Text('Đã nhận', style: HD.bodyBold(size: 12, color: HD.positive)),
        ],
      ),
      const SizedBox(height: HD.s8),
      Wrap(
        spacing: HD.s8,
        runSpacing: HD.s8,
        children: [
          for (var i = 0; i < urls.length; i++)
            _anhMinhChung(keyPrefix: 'coc-hop-dong-anh', urls: urls, index: i),
        ],
      ),
    ],
  );

  Widget _khoiMinhChung({
    required String kind,
    required String tieuDe,
    required List<UploadImage> anh,
  }) {
    final k = _khoan(kind);
    final daGui = k?.hasProof ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(tieuDe, style: HD.bodyBold(size: 14))),
            if (daGui)
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 15, color: HD.positive),
                  const SizedBox(width: 4),
                  Text(
                    k!.acknowledged ? 'Chủ nhà đã nhận' : 'Đã gửi',
                    style: HD.bodyBold(size: 12, color: HD.positive),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: HD.s8),
        if (daGui)
          Wrap(
            spacing: HD.s8,
            runSpacing: HD.s8,
            children: [
              for (var i = 0; i < k!.proofUrls.length; i++)
                _anhMinhChung(
                  keyPrefix: 'coc-$kind-anh',
                  urls: k.proofUrls,
                  index: i,
                ),
            ],
          )
        else if (!_choPhepNop(kind))
          Text(
            'Chưa đến bước nộp khoản này.',
            style: HD.body(size: 12.5, color: HD.inkMuted),
          )
        else ...[
          ImageGridUploader(
            key: Key('anh-$kind'),
            images: anh,
            maxImages: 3,
            crossAxisCount: 3,
            uploadFn: _tai,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: HD.s8),
          SizedBox(
            height: 42,
            child: OutlinedButton(
              key: Key('gui-minh-chung-$kind'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: HD.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
              ),
              onPressed: _dangGui ? null : () => _guiMinhChung(kind, anh),
              child: Text(
                'Gửi minh chứng',
                style: HD.bodyBold(size: 14, color: HD.accent),
              ),
            ),
          ),
          if (_loiKind == kind && _loiKhoan != null) ...[
            const SizedBox(height: HD.s8),
            Text(
              _loiKhoan!,
              key: Key('loi-minh-chung-$kind'),
              style: HD.body(size: 12.5, color: HD.negative),
            ),
          ],
        ],
      ],
    );
  }

  Widget _thanhXacNhan() {
    final hs = _hs;
    final duXac =
        hs?.availableActions.contains(RentalJourneyAction.confirmRental) ??
        false;
    final xong = hs?.status == 'COMPLETED';
    // Liệt kê đúng thứ còn thiếu. Từ 14/10/2026 thiếu vẫn CHỐT ĐƯỢC (thuê
    // trước, bổ sung sau ở mục Hợp đồng) — dòng này là cảnh báo, không chặn.
    final thieu = <String>[
      if (hs != null && hs.contractUrls.isEmpty) 'hợp đồng (sale gửi)',
      if (!(_khoan('APP_DEPOSIT')?.hasProof ?? false)) 'ảnh chuyển cọc Vua Nhà',
      if (!(_khoan('OWNER_DEPOSIT')?.hasProof ?? false))
        'ảnh chuyển cọc chủ nhà',
    ];
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!xong && hs != null && thieu.isNotEmpty) ...[
            Text(
              duXac
                  ? 'Chốt thuê được ngay — còn thiếu ${thieu.join(' · ')}, '
                        'bổ sung sau ở mục Hợp đồng của phòng.'
                  : 'Còn thiếu: ${thieu.join(' · ')}',
              key: const Key('coc-con-thieu'),
              textAlign: TextAlign.center,
              style: HD.body(size: 12.5, color: HD.inkSoft),
            ),
            const SizedBox(height: HD.s8),
          ],
          SizedBox(
            height: 50,
            child: FilledButton(
              key: const Key('coc-xac-nhan'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                disabledBackgroundColor: HD.accent.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
              ),
              onPressed: !duXac || _dangGui ? null : _xacNhan,
              child: _dangGui
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      xong ? 'Đã hoàn tất' : 'Xác nhận thuê & nhận phòng',
                      style: HD.bodyBold(size: 15, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
