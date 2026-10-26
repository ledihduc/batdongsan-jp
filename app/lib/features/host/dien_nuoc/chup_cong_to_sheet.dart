import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/image_grid_uploader.dart' show ImageUploadFn;
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';

/// CHỤP CÔNG TƠ — chủ nhà tự chụp ảnh đồng hồ bằng camera TRỰC TIẾP rồi ghi
/// luôn chỉ số. Mở từ nút "Chụp lại" trên thẻ đồng hồ của màn Điện nước.
/// API: `POST /api/host/dien-nuoc/phong/{id}/chup`. Pop `true` khi đã lưu.
///
/// KHÔNG có đường chọn ảnh từ thư viện — cố ý. Ảnh có sẵn trong máy thì không
/// ai biết chụp lúc nào, ở đâu: nó có thể là ảnh công tơ tháng trước, hoặc công
/// tơ phòng bên. Tấm ảnh mất sạch giá trị đối chứng đúng lúc cần nhất, là lúc
/// hai bên cãi nhau về số điện.
///
/// Ảnh được đóng dấu GIỜ + TOẠ ĐỘ ngay trên ảnh (nhìn là thấy) và gửi kèm dạng
/// số cho server (lọc, đối chiếu được). Từ chối quyền vị trí vẫn chụp được: cấm
/// họ thì họ quay về ghi tay và mất luôn cả tấm ảnh — ảnh khi đó đóng dấu
/// "KHONG CO VI TRI", nói thẳng là thiếu chứ không giả vờ có.
///
/// Ô CHỈ SỐ luôn nằm ngay dưới khung hình, kể cả trước khi chụp. Trước 18/09
/// ô chỉ hiện SAU khi chụp xong — chủ nhà mở "Chụp lại" không thấy chỗ ghi số
/// đâu, và máy không mở được camera (máy tính, từ chối quyền) thì ô không bao
/// giờ hiện. Lưu vẫn cần đủ CẢ ảnh lẫn số: ảnh là bằng chứng của con số.
class ChupCongToSheet extends StatefulWidget {
  const ChupCongToSheet({
    super.key,
    required this.roomId,
    required this.maPhong,
    required this.loai,
    this.chiSoCu,
    this.chiSoDangGhi,
    this.nguonDangGhi = 'Đang ghi',
    this.api = const DienNuocApi(),
    this.uploadFn,
    this.chupThu,
    this.viTriThu,
    this.dsCameraThu,
  });

  final int roomId;
  final String maPhong;

  /// 'dien' | 'nuoc'.
  final String loai;

  /// Chỉ số đã duyệt tháng trước — để nhắc tại chỗ khi gõ nhỏ hơn.
  final double? chiSoCu;

  /// Số tháng này đang ghi (thường là số người thuê gửi) — hiện dưới ô để chủ
  /// nhà đối chiếu với đồng hồ. KHÔNG điền sẵn vào ô: điền sẵn là mời bấm Lưu
  /// mà không nhìn đồng hồ, đúng cái việc "chụp lại" sinh ra để chặn.
  final double? chiSoDangGhi;

  /// Nhãn cho [chiSoDangGhi]: 'Người thuê gửi' / 'Đang ghi'.
  final String nguonDangGhi;
  final DienNuocApi api;

  /// Chỉ để test thay chỗ tải ảnh thật.
  final ImageUploadFn? uploadFn;

  /// Chỉ để test: thay khung hình camera (test không có camera thật).
  final Future<Uint8List> Function()? chupThu;

  /// Chỉ để test: thay GPS.
  final Future<({double lat, double lng})?> Function()? viTriThu;

  /// Chỉ để test: thay danh sách camera (trong test `availableCameras()` treo
  /// mãi không trả, nên không dựng được nhánh "máy không có camera").
  final Future<List<CameraDescription>> Function()? dsCameraThu;

  @override
  State<ChupCongToSheet> createState() => _ChupCongToSheetState();
}

class _ChupCongToSheetState extends State<ChupCongToSheet> {
  final _chiSo = TextEditingController();
  final _oSo = FocusNode();
  CameraController? _ctl;
  bool _sanSang = false;
  bool _dangChup = false;
  bool _dangLuu = false;
  Uint8List? _anh;
  DateTime? _chupLuc;
  ({double lat, double lng})? _viTri;
  String? _loi;
  String? _loiCamera;

  bool get _laDien => widget.loai == 'dien';
  String get _tenDo => _laDien ? 'công tơ điện' : 'đồng hồ nước';
  Color get _mau => _laDien ? HD.accent : HD.svcBlue;

  @override
  void initState() {
    super.initState();
    _moCamera();
    _layViTri();
  }

  @override
  void dispose() {
    _chiSo.dispose();
    _oSo.dispose();
    _ctl?.dispose();
    super.dispose();
  }

  Future<void> _moCamera() async {
    if (widget.chupThu != null) {
      setState(() => _sanSang = true);
      return;
    }
    try {
      final ds = await (widget.dsCameraThu ?? availableCameras)();
      if (ds.isEmpty) {
        if (mounted) setState(() => _loiCamera = 'Thiết bị này không có camera.');
        return;
      }
      final cam = ds.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => ds.first,
      );
      final ctl = CameraController(cam, ResolutionPreset.high, enableAudio: false);
      await ctl.initialize();
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() {
        _ctl = ctl;
        _sanSang = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loiCamera =
            'Không mở được camera. Hãy cho phép quyền camera cho trang này rồi thử lại.');
      }
    }
  }

  Future<void> _layViTri() async {
    try {
      final thu = widget.viTriThu;
      if (thu != null) {
        final v = await thu();
        if (mounted) setState(() => _viTri = v);
        return;
      }
      var quyen = await Geolocator.checkPermission();
      if (quyen == LocationPermission.denied) {
        quyen = await Geolocator.requestPermission();
      }
      if (quyen == LocationPermission.denied ||
          quyen == LocationPermission.deniedForever) {
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) setState(() => _viTri = (lat: p.latitude, lng: p.longitude));
    } catch (_) {
      // Không có vị trí thì ảnh vẫn chụp được, chỉ đóng dấu "KHONG CO VI TRI".
    }
  }

  Future<void> _chup() async {
    setState(() {
      _dangChup = true;
      _loi = null;
    });
    try {
      final Uint8List goc = widget.chupThu != null
          ? await widget.chupThu!()
          : await (await _ctl!.takePicture()).readAsBytes();
      final luc = DateTime.now();
      final anh = dongDauCongTo(
        goc,
        maPhong: widget.maPhong,
        loai: widget.loai,
        luc: luc,
        viTri: _viTri,
      );
      if (!mounted) return;
      setState(() {
        _anh = anh;
        _chupLuc = luc;
      });
      // Chụp xong là tới lượt ghi số — đưa con trỏ vào ô nếu chưa gõ gì.
      if (_chiSo.text.trim().isEmpty) _oSo.requestFocus();
    } catch (e) {
      if (mounted) setState(() => _loi = 'Chụp không được. Thử lại giúp em.');
    } finally {
      if (mounted) setState(() => _dangChup = false);
    }
  }

  Future<void> _luu() async {
    final anh = _anh;
    final luc = _chupLuc;
    if (anh == null || luc == null) {
      setState(() => _loi = 'Chụp ảnh $_tenDo trước đã');
      return;
    }
    final so = double.tryParse(_chiSo.text.trim().replaceAll(',', '.'));
    if (so == null) {
      setState(() => _loi = 'Nhập chỉ số đang hiện trên đồng hồ');
      return;
    }
    final cu = widget.chiSoCu;
    if (cu != null && so < cu) {
      // Công tơ không chạy lùi — chặn ngay tại chỗ, đỡ một vòng gọi server.
      setState(() => _loi = 'Chỉ số nhỏ hơn tháng trước (${_so(cu)}). Xem lại giúp em.');
      return;
    }
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      final tai = widget.uploadFn ?? const ApiClient().uploadImage;
      final url = await tai(anh, 'cong-to-${widget.loai}-${widget.maPhong}.jpg');
      await widget.api.chuNhaChup(
        widget.roomId,
        loai: widget.loai,
        chiSo: so,
        anh: url,
        chupLuc: luc.toIso8601String(),
        lat: _viTri?.lat,
        lng: _viTri?.lng,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangLuu = false;
        _loi = e is ApiException ? e.message : 'Không lưu được. Thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cao = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: cao * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s8, HD.s8),
              child: Row(
                children: [
                  Icon(_laDien ? Icons.bolt : Icons.water_drop, size: 18, color: _mau),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Chụp $_tenDo · ${widget.maPhong}',
                      style: HD.bodyBold(size: 16),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Khung hình chừa chỗ cho ô số + nút: để khung 3:4 chiếm hết
                    // chiều rộng thì trên điện thoại ô số bị đẩy khỏi màn.
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: cao * 0.42),
                      // heightFactor 1: ôm đúng chiều cao nội dung. `Center` giãn
                      // kín trần → hộp báo lỗi camera nổi giữa một khoảng trống.
                      child: Align(heightFactor: 1, child: _khungAnh()),
                    ),
                    const SizedBox(height: HD.s8),
                    _dongViTri(),
                    const SizedBox(height: HD.s12),
                    TextField(
                      key: const ValueKey('chi-so-moi'),
                      controller: _chiSo,
                      focusNode: _oSo,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Chỉ số mới — đọc trên $_tenDo',
                        helperText: _goiY(),
                        helperMaxLines: 2,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(HD.r12),
                        ),
                      ),
                    ),
                    const SizedBox(height: HD.s12),
                    if (_loi != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: HD.s8),
                        child: Text(_loi!, style: HD.body(size: 12, color: HD.negative)),
                      ),
                    _nut(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Tháng trước: 1379 · Người thuê gửi: 1428" — hai số để đối chiếu.
  String? _goiY() {
    final cu = widget.chiSoCu;
    final dang = widget.chiSoDangGhi;
    final phan = [
      if (cu != null) 'Tháng trước: ${_so(cu)}',
      if (dang != null) '${widget.nguonDangGhi}: ${_so(dang)}',
    ];
    return phan.isEmpty ? null : phan.join(' · ');
  }

  Widget _khungAnh() {
    final anh = _anh;
    if (anh != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(HD.r12),
        child: Image.memory(anh, key: const ValueKey('anh-vua-chup'), fit: BoxFit.contain),
      );
    }
    if (_loiCamera != null) {
      return Container(
        padding: const EdgeInsets.all(HD.s16),
        decoration: BoxDecoration(
          color: HD.negativeTint,
          borderRadius: BorderRadius.circular(HD.r12),
        ),
        child: Column(
          // Khung ảnh nay có trần chiều cao — để Column giãn mặc định thì hộp
          // báo lỗi phình kín cả khung (ảnh chụp thật 18/09).
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: HD.negative),
            const SizedBox(height: HD.s8),
            Text(
              _loiCamera!,
              textAlign: TextAlign.center,
              style: HD.body(size: 13, color: HD.negative),
            ),
          ],
        ),
      );
    }
    final ctl = _ctl;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HD.r12),
        child: ctl != null && ctl.value.isInitialized
            ? CameraPreview(ctl)
            : ColoredBox(
                color: HD.ink,
                child: Center(
                  child: _sanSang
                      ? Text(
                          'Khung hình sẵn sàng',
                          style: HD.body(size: 12, color: HD.paperRaised),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
                ),
              ),
      ),
    );
  }

  Widget _dongViTri() {
    final v = _viTri;
    return Row(
      children: [
        Icon(
          v == null ? Icons.location_off_outlined : Icons.my_location,
          size: 14,
          color: v == null ? HD.inkMuted : HD.positive,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            v == null
                ? 'Chưa lấy được vị trí — ảnh vẫn đóng dấu giờ chụp'
                : 'Vị trí: ${v.lat.toStringAsFixed(6)}, ${v.lng.toStringAsFixed(6)}',
            style: HD.body(size: 11, color: v == null ? HD.inkMuted : HD.inkSoft),
          ),
        ),
      ],
    );
  }

  Widget _nut() {
    if (_anh == null && _loiCamera != null) {
      // Trước đây nút "Chụp ảnh" vẫn bấm được ở đây và chỉ ra "Chụp không
      // được". Trên web, người dùng thường vừa bấm "Cho phép" ở hộp hỏi quyền
      // — mở lại camera là đủ, không cần đóng sheet.
      return OutlinedButton.icon(
        key: const ValueKey('mo-lai-camera'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        onPressed: () {
          setState(() {
            _loiCamera = null;
            _sanSang = false;
          });
          _moCamera();
        },
        icon: const Icon(Icons.videocam_outlined),
        label: const Text('Mở lại camera'),
      );
    }
    if (_anh == null) {
      return FilledButton.icon(
        key: const ValueKey('chup-anh'),
        style: FilledButton.styleFrom(
          backgroundColor: _mau,
          minimumSize: const Size.fromHeight(46),
        ),
        onPressed: _dangChup || !_sanSang ? null : _chup,
        icon: _dangChup
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.photo_camera),
        label: const Text('Chụp ảnh'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('chup-lai-anh'),
            onPressed: _dangLuu
                ? null
                : () => setState(() {
                      _anh = null;
                      _chupLuc = null;
                    }),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Chụp lại'),
          ),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('luu-chi-so'),
            style: FilledButton.styleFrom(backgroundColor: _mau),
            onPressed: _dangLuu ? null : _luu,
            icon: _dangLuu
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Lưu chỉ số'),
          ),
        ),
      ],
    );
  }
}

String _so(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _hai(int n) => n.toString().padLeft(2, '0');

/// Đóng dấu MÃ PHÒNG · GIỜ CHỤP · TOẠ ĐỘ lên ảnh rồi nén JPEG.
///
/// Chữ KHÔNG DẤU: bộ chữ dựng sẵn của gói `image` chỉ có Latin-1, chữ Việt có
/// dấu ra ô vuông. Dấu này để ĐỌC ĐƯỢC lúc in ra đối chứng, không phải để đẹp.
///
/// Nén JPEG thay vì PNG: ảnh chụp dạng PNG nặng gấp mấy lần mức `/api/upload`
/// chịu được (8MB), mà mỗi tháng mỗi phòng hai tấm.
Uint8List dongDauCongTo(
  Uint8List goc, {
  required String maPhong,
  required String loai,
  required DateTime luc,
  ({double lat, double lng})? viTri,
}) {
  final anh = img.decodeImage(goc);
  if (anh == null) return goc;
  final nho = anh.width > 1280 ? img.copyResize(anh, width: 1280) : anh;
  final dong = <String>[
    '${khongDau(maPhong)} - ${loai == 'dien' ? 'CONG TO DIEN' : 'DONG HO NUOC'}',
    '${_hai(luc.day)}/${_hai(luc.month)}/${luc.year} ${_hai(luc.hour)}:'
        '${_hai(luc.minute)}:${_hai(luc.second)}',
    viTri == null
        ? 'KHONG CO VI TRI'
        : '${viTri.lat.toStringAsFixed(6)}, ${viTri.lng.toStringAsFixed(6)}',
  ];
  const caoDong = 18;
  final caoDai = caoDong * dong.length + 10;
  img.fillRect(
    nho,
    x1: 0,
    y1: nho.height - caoDai,
    x2: nho.width,
    y2: nho.height,
    color: img.ColorRgba8(0, 0, 0, 170),
  );
  var y = nho.height - caoDai + 5;
  for (final d in dong) {
    img.drawString(nho, d, font: img.arial14, x: 8, y: y, color: img.ColorRgb8(255, 255, 255));
    y += caoDong;
  }
  return Uint8List.fromList(img.encodeJpg(nho, quality: 82));
}

/// 'Phòng P101' → 'PHONG P101'. Bỏ dấu để bộ chữ bitmap vẽ được.
///
/// Gom theo NHÓM thay vì hai chuỗi song song: hai chuỗi lệch nhau một ký tự là
/// 'đ' ra 'y' mà mắt không thấy (đã dính đúng lỗi đó).
const _boDau = <String, String>{
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

String khongDau(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    var ra = c;
    for (final e in _boDau.entries) {
      if (e.value.contains(c)) {
        ra = e.key;
        break;
      }
    }
    b.write(ra);
  }
  return b.toString().toUpperCase();
}
