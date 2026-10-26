import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/image_grid_uploader.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/shared/rental_journey_compact_widgets.dart';
import 'package:house_booking/providers/chat_provider.dart';

/// MÀN 6 của SALE — "Gửi hồ sơ chốt thuê" (mockup SALE, 20/09/2026).
///
/// Sale tải ảnh HỢP ĐỒNG ĐÃ KÝ + ảnh XÁC NHẬN CỌC, ghi số tiền cọc và ngày cọc
/// rồi gửi: `PUT /api/rental-journeys/{id}/contract`. Gửi xong hồ sơ nằm ở
/// trạng thái chờ KHÁCH xác nhận — sale không tự chốt được, đúng luật server.
///
/// Server chỉ có `urls` + `total_deposit` + `note`, không có ô riêng cho ngày
/// cọc, nên ngày cọc đi vào `note` (giữ nguyên chữ, không bịa cột mới).
class GuiHoSoChotThueScreen extends StatefulWidget {
  const GuiHoSoChotThueScreen({
    super.key,
    required this.journeyId,
    this.api = const RentalJourneyApi(),
    this.uploadFn,
    this.homNay,
  });

  final int journeyId;
  final RentalJourneyApi api;
  final ImageUploadFn? uploadFn;
  final DateTime? homNay;

  @override
  State<GuiHoSoChotThueScreen> createState() => _GuiHoSoChotThueScreenState();
}

class _GuiHoSoChotThueScreenState extends State<GuiHoSoChotThueScreen> {
  final _anhHopDong = <UploadImage>[];
  // Hai khoản cọc là HAI lần chuyển khoản (50% Vua Nhà, 50% chủ nhà) — mỗi
  // ô là minh chứng của một khoản. Trước đây chỉ có một ô "ảnh xác nhận cọc"
  // và ảnh bị GỘP vào tệp hợp đồng: sale tưởng đã nộp cọc, còn hồ sơ vẫn
  // thiếu hai minh chứng nên không ai chốt được (24/09/2026).
  final _anhCocApp = <UploadImage>[];
  final _anhCocChu = <UploadImage>[];
  final _tienCoc = TextEditingController();
  final _ghiChu = TextEditingController();
  late DateTime _ngayCoc;
  RentalJourney? _hs;
  bool _dangTai = true;
  bool _dangNap = false;
  bool _dangGui = false;
  String? _loi;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  bool _daNoiRealtime = false;

  @override
  void initState() {
    super.initState();
    _ngayCoc = widget.homNay ?? DateTime.now();
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
      // Widget tests may mount this screen without ChatProvider.
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _tienCoc.dispose();
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    if (_dangNap) return;
    _dangNap = true;
    try {
      final hs = await widget.api.detail(widget.journeyId);
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _dangTai = false;
        _loi = null;
        if (hs.totalDeposit > 0 && _tienCoc.text.isEmpty) {
          _tienCoc.text = '${hs.totalDeposit}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được hồ sơ. Kéo xuống để thử lại.';
      });
    } finally {
      _dangNap = false;
    }
  }

  /// URL tuyệt đối → đường dẫn tương đối server nhận (`/uploads/...`).
  static String _duongDan(String url) {
    final i = url.indexOf('/uploads/');
    return i >= 0 ? url.substring(i) : url;
  }

  Future<String> _tai(List<int> bytes, String ten) =>
      (widget.uploadFn ?? const ApiClient().uploadImage)(bytes, ten);

  static List<String> _duongDanCua(List<UploadImage> anh) => [
    for (final a in anh)
      if (a.url != null && a.url!.isNotEmpty) _duongDan(a.url!),
  ];

  bool get _guiDuoc =>
      _anhHopDong.isNotEmpty && (int.tryParse(_tienCoc.text.trim()) ?? 0) > 0;

  bool _daNop(String kind) =>
      _hs?.payments.any((p) => p.kind == kind && p.hasProof) ?? false;

  bool _duocNop(String kind) =>
      _hs?.availableActions.contains(
        kind == 'APP_DEPOSIT'
            ? RentalJourneyAction.submitAppDeposit
            : RentalJourneyAction.submitOwnerDeposit,
      ) ??
      false;

  /// Nộp minh chứng các khoản đã có ảnh. Trả lỗi đầu tiên (nếu có).
  Future<String?> _nopCoc() async {
    for (final (kind, anh) in [
      ('APP_DEPOSIT', _anhCocApp),
      ('OWNER_DEPOSIT', _anhCocChu),
    ]) {
      final urls = _duongDanCua(anh);
      if (urls.isEmpty || _daNop(kind) || !_duocNop(kind)) continue;
      try {
        final hs = await widget.api.submitPaymentProof(
          widget.journeyId,
          kind: kind,
          urls: urls,
        );
        if (!mounted) return null;
        setState(() {
          _hs = hs;
          anh.clear();
        });
      } catch (e) {
        return e is ApiException ? e.message : 'Chưa gửi được minh chứng cọc.';
      }
    }
    return null;
  }

  Future<void> _guiCoc() async {
    if (_dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    final loi = await _nopCoc();
    if (!mounted) return;
    setState(() {
      _dangGui = false;
      _loi = loi;
    });
  }

  Future<void> _gui() async {
    if (!_guiDuoc || _dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final hs = await widget.api.submitContract(
        widget.journeyId,
        urls: _duongDanCua(_anhHopDong),
        totalDeposit: int.parse(_tienCoc.text.trim()),
        note: [
          'Ngày cọc ${_ngayDep(_ngayCoc)}',
          if (_ghiChu.text.trim().isNotEmpty) _ghiChu.text.trim(),
        ].join(' · '),
      );
      if (!mounted) return;
      setState(() {
        _hs = hs;
        _anhHopDong.clear();
      });
      // Có ảnh chuyển cọc thì nộp luôn vào đúng khoản — không bắt sale quay
      // lại lần hai.
      final loi = await _nopCoc();
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = loi;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa gửi được hồ sơ.';
      });
    }
  }

  bool get _daGui => (_hs?.contractUrls.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final hs = _hs;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: HD.ink),
        title: Text('Hồ sơ thuê', style: HD.bodyBold(size: 16)),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  HD.s16,
                  HD.s12,
                  HD.s16,
                  HD.s24,
                ),
                children: [
                  if (hs != null) ...[
                    RentalJourneyCompactHeader(
                      journey: hs,
                      subtitle: '${hs.customer.name} · ${hs.owner.name}',
                    ),
                    const SizedBox(height: HD.s12),
                    RentalEvidenceCard(journey: hs, keyPrefix: 'sale'),
                    const SizedBox(height: HD.s16),
                  ],
                  if (_daGui) ...[
                    _khoiCocSauHopDong(),
                  ] else ...[
                    _oAnh(
                      khoa: 'hop-dong',
                      tieuDe: 'Hợp đồng đã ký',
                      anh: _anhHopDong,
                    ),
                    const SizedBox(height: HD.s12),
                    _oAnh(
                      khoa: 'coc-APP_DEPOSIT',
                      tieuDe: 'Cọc Vua Nhà · nếu có',
                      anh: _anhCocApp,
                    ),
                    const SizedBox(height: HD.s12),
                    _oAnh(
                      khoa: 'coc-OWNER_DEPOSIT',
                      tieuDe: 'Cọc chủ nhà · nếu có',
                      anh: _anhCocChu,
                    ),
                    const SizedBox(height: HD.s16),
                    TextField(
                      key: const Key('sale-tien-coc'),
                      controller: _tienCoc,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Tổng tiền cọc',
                        suffixText: 'đ',
                        isDense: true,
                        filled: true,
                        fillColor: HD.paperRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(HD.r12),
                        ),
                      ),
                    ),
                    const SizedBox(height: HD.s12),
                    InkWell(
                      key: const Key('sale-ngay-coc'),
                      onTap: _chonNgay,
                      borderRadius: BorderRadius.circular(HD.r12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: HD.s12,
                          vertical: HD.s12 + 2,
                        ),
                        decoration: BoxDecoration(
                          color: HD.paperRaised,
                          borderRadius: BorderRadius.circular(HD.r12),
                          border: Border.all(color: HD.hairline),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 17,
                              color: HD.inkMuted,
                            ),
                            const SizedBox(width: HD.s8),
                            Expanded(
                              child: Text(
                                'Ngày cọc: ${_ngayDep(_ngayCoc)}',
                                style: HD.body(size: 13, color: HD.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: HD.s12),
                    TextField(
                      key: const Key('sale-ghi-chu-ho-so'),
                      controller: _ghiChu,
                      maxLines: 2,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú · không bắt buộc',
                        counterText: '',
                        filled: true,
                        fillColor: HD.paperRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(HD.r12),
                        ),
                      ),
                    ),
                  ],
                  if (_loi != null) ...[
                    const SizedBox(height: HD.s12),
                    Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _dangTai || _daGui ? null : _thanhGui(),
    );
  }

  Future<void> _chonNgay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _ngayCoc,
      firstDate: DateTime(_ngayCoc.year - 1),
      lastDate: DateTime(_ngayCoc.year + 1),
    );
    if (d != null) setState(() => _ngayCoc = d);
  }

  Widget _oAnh({
    required String khoa,
    required String tieuDe,
    required List<UploadImage> anh,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tieuDe, style: HD.bodyBold(size: 13)),
      const SizedBox(height: HD.s8),
      ImageGridUploader(
        key: Key('sale-anh-$khoa'),
        images: anh,
        maxImages: 3,
        crossAxisCount: 3,
        uploadFn: _tai,
        onChanged: () => setState(() {}),
      ),
    ],
  );

  /// Sau khi đã gửi hợp đồng: từng khoản cọc đã có minh chứng chưa, và ô
  /// nộp hộ cho khoản còn thiếu.
  Widget _khoiCocSauHopDong() {
    Widget khoan(String kind, String ten, List<UploadImage> anh) {
      if (_daNop(kind)) return const SizedBox.shrink();
      if (!_duocNop(kind)) return const SizedBox.shrink();
      return _oAnh(khoa: 'coc-$kind', tieuDe: ten, anh: anh);
    }

    final conThieu =
        !_daNop('APP_DEPOSIT') && _duocNop('APP_DEPOSIT') ||
        !_daNop('OWNER_DEPOSIT') && _duocNop('OWNER_DEPOSIT');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (conThieu) ...[
          Text('Bổ sung ảnh còn thiếu', style: HD.bodyBold(size: 14)),
          const SizedBox(height: HD.s8),
          khoan('APP_DEPOSIT', 'Cọc Vua Nhà', _anhCocApp),
          if (!_daNop('APP_DEPOSIT') && _duocNop('APP_DEPOSIT'))
            const SizedBox(height: HD.s12),
          khoan('OWNER_DEPOSIT', 'Cọc chủ nhà', _anhCocChu),
          const SizedBox(height: HD.s12),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              key: const Key('sale-nop-coc'),
              onPressed: _dangGui || (_anhCocApp.isEmpty && _anhCocChu.isEmpty)
                  ? null
                  : _guiCoc,
              style: OutlinedButton.styleFrom(
                foregroundColor: HD.accent,
                side: const BorderSide(color: HD.accent),
              ),
              child: const Text('Gửi ảnh cọc'),
            ),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(HD.s12),
            decoration: BoxDecoration(
              color: HD.positiveTint,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: HD.positive, size: 19),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: Text(
                    'Đủ hồ sơ · chờ khách hoặc chủ nhà chốt',
                    style: HD.bodyBold(size: 12.5, color: HD.positive),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _thanhGui() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: SizedBox(
      height: 50,
      child: FilledButton(
        key: const Key('sale-gui-ho-so'),
        style: FilledButton.styleFrom(
          backgroundColor: HD.accent,
          disabledBackgroundColor: HD.accent.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HD.r12),
          ),
        ),
        onPressed: _daGui || !_guiDuoc || _dangGui ? null : _gui,
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
                _daGui ? 'Đã gửi hồ sơ' : 'Gửi hồ sơ',
                style: HD.bodyBold(size: 15, color: Colors.white),
              ),
      ),
    ),
  );

  static String _ngayDep(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
