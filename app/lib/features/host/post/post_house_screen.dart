// ⚠️ GOD-FILE ~1250 dòng — 1 màn đăng tin BĐS (form nhiều bước). Tách section
// widget là refactor sâu (AI-REFACTOR-PLAN §A3, chưa làm). MỤC LỤC method:
//   Ảnh:  _pickImages 226 · _uploadOne 285 · _buildImageGrid 727 · _buildThumbnail 840
//   Địa điểm: _loadProvinces 151 · _onProvinceChanged 174 · _onMapTap 196
//   Form: _buildTransactionTypePicker 923 · _buildListingTypeSelector 1001 ·
//         _buildLegalChips 1078 · _buildMultiUnitBlock 1099 · _submit 317
import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/permissions/permission_service.dart';
import 'package:house_booking/features/map/widgets/base_map_tile_layer.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/telemetry/analytics_service.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/features/permissions/helpers/priming_presenter.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/loai_phong_api.dart';
import 'package:house_booking/data/services/location_input_service.dart';
import 'package:house_booking/data/services/post_draft_service.dart';
import 'package:house_booking/features/host/ngan_han/loai_phong_screen.dart';
import 'package:house_booking/features/host/post/address_quality.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/features/planning/widgets/planning_check_button.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class _PickedImage {
  _PickedImage({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;

  /// Ba trường dưới CHỈ đổi sau khi tải lên xong, không ai truyền lúc khởi tạo
  /// (ảnh vừa chọn thì luôn là "đang tải, chưa có URL, chưa hỏng"). Trước đây
  /// chúng nằm trong constructor như tham số tuỳ chọn — analyzer báo
  /// `unused_element_parameter` vì không lời gọi nào dùng tới.
  String? uploadedUrl;
  bool isUploading = true;
  bool failed = false;
}

class PostHouseScreen extends StatefulWidget {
  final HouseModel? editing;
  const PostHouseScreen({super.key, this.editing});

  bool get isEdit => editing != null;

  @override
  State<PostHouseScreen> createState() => _PostHouseScreenState();
}

class _PostHouseScreenState extends State<PostHouseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _draft = const PostDraftService();
  Timer? _draftTimer;
  // Captured on initState. If the auth session changes mid-flight (logout
  // while form open), the build method pops the route so a subsequent login
  // doesn't inherit the previous user's draft (state audit F5).
  int? _ownerUserId;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bedroomsCtrl = TextEditingController(text: '1');
  final _bathroomsCtrl = TextEditingController(text: '1');
  final _totalUnitsCtrl = TextEditingController(text: '10');
  final _availableUnitsCtrl = TextEditingController(text: '10');

  final ImagePicker _picker = ImagePicker();
  final ApiClient _api = const ApiClient();

  // Địa giới hành chính 2 cấp (2025) — chọn từ master, không nhập tay.
  final _location = const LocationInputService();
  final _mapCtrl = MapController();
  List<AdminUnit> _provinces = [];
  List<AdminUnit> _wards = [];
  String? _provinceCode;
  String? _wardCode;
  String _provinceName = '';
  String _wardName = '';
  bool _loadingWards = false;
  /// Reverse geocode vừa trả về địa chỉ CHỈ tới cấp phường/xã (thiếu số nhà,
  /// tên đường). Dữ liệu OSM ở vùng ven/nông thôn VN thường không có mức đường
  /// → phải nhắc chủ nhà bổ sung, nếu không tin đăng sẽ không tìm thấy được.
  bool _addressNeedsDetail = false;

  int? _categoryId;

  /// Nhóm master đang chọn (bước 1): 'stay_long' | 'stay_short' | 'business'.
  /// Rỗng = chưa chọn → danh sách loại hình bên dưới còn khoá.
  String _groupKey = '';

  // ── Tin NGẮN HẠN neo vào HẠNG PHÒNG (backend 0130) ────────────────────────
  // Khách sạn/homestay bán HẠNG ("Deluxe hướng biển"), lễ tân mới gán số phòng
  // lúc nhận. Neo theo phòng lẻ như dài hạn thì mười phòng giống hệt nhau
  // thành mười tin trùng, và "hạng này còn mấy phòng" là câu không ai trả lời
  // được. Tồn kho của tin = số phòng của hạng → không hỏi lại người đăng.
  final LoaiPhongApi _hangApi = const LoaiPhongApi();
  List<ToaCoHang> _toaCoHang = const [];
  bool _dangTaiToa = false;
  String? _loiTaiToa;
  int? _toaId;
  int? _loaiPhongId;

  /// Bấm Đăng mà chưa chọn hạng → tô đỏ khối chọn (khối này không phải
  /// TextFormField nên không tự có trạng thái lỗi).
  bool _thieuHang = false;

  /// Tin ngắn hạn thì bán theo HẠNG, không theo căn/phòng lẻ.
  bool get _theoHang => !_isSale && _groupKey == 'stay_short';

  ToaCoHang? get _toaDangChon {
    for (final t in _toaCoHang) {
      if (t.id == _toaId) return t;
    }
    return null;
  }

  HangDeChon? get _hangDangChon {
    for (final h in _toaDangChon?.hang ?? const <HangDeChon>[]) {
      if (h.id == _loaiPhongId) return h;
    }
    return null;
  }
  bool _isSubmitting = false;
  String _listingType = 'single'; // single | multi_unit
  String _genderPref = 'any'; // any | male | female
  // Transaction type — 'rent' | 'sale'. Default 'rent' per D1.
  // Only sent to backend when kListingV2Enabled; otherwise omitted (backend defaults to 'rent').
  String _transactionType = 'rent';

  /// TỰ KHAI ai đang đăng: 'owner' (chủ nhà) | 'broker' (đăng hộ/môi giới) |
  /// '' (chưa chọn). Hỏi NGAY TẠI ĐÂY vì đăng tin đầu tiên là lúc tài khoản tự
  /// được nâng lên "host" — nếu không hỏi ở đây thì sau đó chẳng ai vào hồ sơ
  /// để tự khai, và app lại đoán bừa như trước.
  String _sellerType = '';

  /// Bấm Đăng mà chưa chọn vai trò → tô đỏ khối chọn (khối này không phải
  /// TextFormField nên không tự có trạng thái lỗi như các ô khác).
  bool _thieuVaiTro = false;
  String? _legalStatus; // sale-only: red_book|pink_book|sale_contract|pending
  bool get _isSale => _transactionType == 'sale';
  String? _direction; // hướng nhà (phong thuỷ), slug 8 hướng — null = không khai
  static const Map<String, String> _directionLabels = {
    'north': 'Bắc', 'northeast': 'Đông Bắc', 'east': 'Đông',
    'southeast': 'Đông Nam', 'south': 'Nam', 'southwest': 'Tây Nam',
    'west': 'Tây', 'northwest': 'Tây Bắc',
  };

  // Tọa độ BDS — null khi chưa có (geocoding chưa chạy hoặc địa chỉ chưa đủ).
  // Dùng bởi PlanningCheckButton để kiểm tra quy hoạch (D4: không block submit).
  // TODO(geocoding): set _lat/_lng khi tích hợp geocoding reverse address → LatLng.
  double? _lat;
  double? _lng;

  final List<_PickedImage> _images = [];
  // Ảnh đã upload từ trước (edit mode) — URL only, không có bytes.
  final List<String> _existingImages = [];
  static const int _maxImages = 8;

  @override
  void initState() {
    super.initState();
    _ownerUserId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    final e = widget.editing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description;
      _priceCtrl.text = e.price.toStringAsFixed(0);
      _areaCtrl.text = e.area.toStringAsFixed(0);
      _addressCtrl.text = e.address;
      _provinceName = e.city;
      _wardName = e.district;
      _lat = e.latitude;
      _lng = e.longitude;
      _bedroomsCtrl.text = e.bedrooms.toString();
      _bathroomsCtrl.text = e.bathrooms.toString();
      _categoryId = e.categoryId;
      _existingImages.addAll(e.images);
      _listingType = e.listingType;
      _totalUnitsCtrl.text = e.totalUnits.toString();
      _availableUnitsCtrl.text = e.availableUnits.toString();
      _genderPref = e.genderPref;
      _transactionType = e.transactionType;
      _sellerType = e.sellerType;
      _legalStatus = e.legalStatus;
      _direction = e.direction;
    }
    _loadProvinces();
    // Nháp CHỈ dành cho tin mới — sửa tin cũ mà khôi phục nháp sẽ ghi đè dữ
    // liệu thật của tin đang sửa.
    if (widget.editing == null) _khoiPhucNhap();
  }

  /// Đọc nháp lần trước (nếu có) và hỏi người dùng có khôi phục không.
  /// Hỏi chứ không tự điền: tự điền sẽ khó hiểu khi người dùng định đăng tin
  /// MỚI khác hẳn tin bỏ dở.
  Future<void> _khoiPhucNhap() async {
    final d = await _draft.load();
    if (d == null || d.isEmpty || !mounted) return;
    final l = AppLocalizations.of(context);
    final dong = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.postHouseDraftFoundTitle),
        content: Text(l.postHouseDraftFoundBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.postHouseDraftDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.postHouseDraftRestore),
          ),
        ],
      ),
    );
    if (dong != true) {
      await _draft.clear();
      return;
    }
    if (!mounted) return;
    setState(() {
      _titleCtrl.text = (d['title'] ?? '') as String;
      _descCtrl.text = (d['desc'] ?? '') as String;
      _priceCtrl.text = (d['price'] ?? '') as String;
      _areaCtrl.text = (d['area'] ?? '') as String;
      _addressCtrl.text = (d['address'] ?? '') as String;
      _bedroomsCtrl.text = (d['bedrooms'] ?? '') as String;
      _bathroomsCtrl.text = (d['bathrooms'] ?? '') as String;
      _categoryId = d['categoryId'] as int?;
      _transactionType = (d['tx'] ?? 'rent') as String;
      _sellerType = (d['seller'] ?? '') as String;
      _legalStatus = d['legal'] as String?;
      _listingType = (d['listingType'] ?? 'single') as String;
      _lat = (d['lat'] as num?)?.toDouble();
      _lng = (d['lng'] as num?)?.toDouble();
    });
    // Tỉnh/phường phải nạp theo thứ tự (chọn tỉnh mới có danh sách phường).
    final pCode = d['provinceCode'] as String?;
    if (pCode != null) {
      await _onProvinceChanged(pCode);
      final wCode = d['wardCode'] as String?;
      if (wCode != null && mounted) {
        final m = _wards.where((w) => w.code == wCode);
        if (m.isNotEmpty) {
          setState(() {
            _wardCode = wCode;
            _wardName = m.first.name;
          });
        }
      }
    }
  }

  /// Ghi nháp sau mỗi thay đổi, gộp lại 1 giây một lần để không ghi liên tục
  /// theo từng phím gõ.
  void _luuNhapSau() {
    if (widget.editing != null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 1), () {
      _draft.save({
        'title': _titleCtrl.text,
        'desc': _descCtrl.text,
        'price': _priceCtrl.text,
        'area': _areaCtrl.text,
        'address': _addressCtrl.text,
        'bedrooms': _bedroomsCtrl.text,
        'bathrooms': _bathroomsCtrl.text,
        'categoryId': _categoryId,
        'tx': _transactionType,
        'seller': _sellerType,
        'legal': _legalStatus,
        'listingType': _listingType,
        'provinceCode': _provinceCode,
        'wardCode': _wardCode,
        'lat': _lat,
        'lng': _lng,
      });
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _totalUnitsCtrl.dispose();
    _availableUnitsCtrl.dispose();
    super.dispose();
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'(thành phố|tỉnh|tp\.?|quận|huyện|phường|xã)'), '')
      .replaceAll(RegExp(r'[^a-z0-9à-ỹ]'), '')
      .trim();

  Future<void> _loadProvinces() async {
    try {
      final ps = await _location.provinces();
      if (!mounted) return;
      setState(() => _provinces = ps);
      // Edit mode: chọn sẵn tỉnh/xã theo tên đã lưu (best-effort).
      final e = widget.editing;
      if (e != null && e.city.isNotEmpty) {
        final m = ps.where((p) => _norm(p.name) == _norm(e.city));
        if (m.isNotEmpty) {
          await _onProvinceChanged(m.first.code);
          final wm = _wards.where((w) => _norm(w.name) == _norm(e.district));
          if (wm.isNotEmpty && mounted) {
            setState(() {
              _wardCode = wm.first.code;
              _wardName = wm.first.name;
            });
          }
        }
      }
    } catch (_) {/* im lặng — user vẫn chọn thủ công được */}
  }

  Future<void> _onProvinceChanged(String? code) async {
    if (code == null) return;
    final p = _provinces.firstWhere((x) => x.code == code);
    setState(() {
      _provinceCode = code;
      _provinceName = p.name;
      _wardCode = null;
      _wardName = '';
      _wards = [];
      _loadingWards = true;
    });
    try {
      final w = await _location.wards(code);
      if (mounted) setState(() {
        _wards = w;
        _loadingWards = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingWards = false);
    }
  }

  /// Chèn khung mô tả có sẵn để người dùng chỉ việc điền vào chỗ trống —
  /// thay cho việc BẮT BUỘC gõ mô tả từ con số không.
  void _chenKhungMoTa() {
    final l = AppLocalizations.of(context);
    setState(() {
      _descCtrl.text = l.postHouseDescTemplate;
      _descCtrl.selection =
          TextSelection.collapsed(offset: _descCtrl.text.length);
    });
  }

  /// Gợi ý tiêu đề dựng từ dữ liệu người dùng ĐÃ nhập — dùng làm hint (chữ mờ),
  /// KHÔNG tự ghi vào ô. Trả null khi chưa đủ dữ liệu để gợi ý có nghĩa.
  String? _titleSuggestion(HouseProvider p) {
    final cats = p.categories.where((c) => c['id'] == _categoryId);
    if (cats.isEmpty) return null;
    final loai = cats.first['name'] as String;
    final dienTich = _areaCtrl.text.trim();
    final phan = <String>[
      loai,
      if (dienTich.isNotEmpty) '${dienTich}m²',
      if (_wardName.isNotEmpty) _wardName,
    ];
    // Chỉ gợi ý khi có nhiều hơn mỗi tên loại, nếu không thì vô dụng.
    return phan.length > 1 ? phan.join(' · ') : null;
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
    });
    // Reverse geocode → tự điền địa chỉ + tỉnh/phường (chạm map là chủ ý đặt vị trí).
    // CHỈ chạy khi người dùng chạm map, không chạy lúc mở màn → mở tin cũ để sửa
    // không bao giờ bị ghi đè địa chỉ đã lưu.
    final res = await _location.reverseGeocode(point.latitude, point.longitude);
    if (res == null || !mounted) return;
    if (res.address.isNotEmpty) {
      setState(() {
        _addressCtrl.text = res.address;
        _addressNeedsDetail = laDiaChiTho(res.address);
      });
    }
    // Điền tỉnh/thành từ master đã match → load phường → điền phường nếu match.
    if (res.province != null) {
      await _onProvinceChanged(res.province!.code);
      if (!mounted) return;
      final wardCode = res.ward?.code;
      if (wardCode != null) {
        final m = _wards.where((w) => w.code == wardCode);
        if (m.isNotEmpty) {
          setState(() {
            _wardCode = wardCode;
            _wardName = m.first.name;
          });
        }
      }
    }
  }

  int get _totalImages => _images.length + _existingImages.length;

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalImages;
    if (remaining <= 0) return;

    // Camera priming for photo library access (iOS photo lib permission).
    // Uses gallery source so withCameraPermission is called inline (pickMultiImage).
    if (!kIsWeb) {
      final userId = Provider.of<AuthProvider>(context, listen: false)
              .currentUser
              ?.id
              ?.toString() ??
          '';
      PermissionService? service;
      try {
        service = Provider.of<PermissionService>(context, listen: false);
      } catch (_) {}

      if (service != null && userId.isNotEmpty) {
        final shouldPrime = await service.shouldShowCameraPriming(
            userId, CameraContext.postHousePhoto);
        if (shouldPrime) {
          if (!mounted) return;
          final outcome = await PrimingPresenter.presentCamera(
              context, CameraContext.postHousePhoto);
          if (outcome == PrimingOutcome.accept) {
            await service.grantCamera(
                userId: userId, context: CameraContext.postHousePhoto);
          } else {
            await service.deferCamera(userId, CameraContext.postHousePhoto);
            return; // User cancelled priming
          }
        }
      }
    }

    if (!mounted) return;

    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1600,
        imageQuality: 80,
        limit: remaining,
      );
      if (files.isEmpty) return;

      for (final f in files) {
        final bytes = await f.readAsBytes();
        final pic = _PickedImage(file: f, bytes: bytes);
        setState(() => _images.add(pic));
        _uploadOne(pic);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context).postHouseImagePickError('$e'))),
      );
    }
  }

  Future<void> _uploadOne(_PickedImage pic) async {
    try {
      final url = await _api.uploadImage(pic.bytes, pic.file.name);
      if (!mounted) return;
      setState(() {
        pic.uploadedUrl = url;
        pic.isUploading = false;
        pic.failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        pic.isUploading = false;
        pic.failed = true;
      });
    }
  }

  void _retry(_PickedImage pic) {
    setState(() {
      pic.isUploading = true;
      pic.failed = false;
    });
    _uploadOne(pic);
  }

  void _removeImage(_PickedImage pic) {
    setState(() => _images.remove(pic));
  }

  bool get _isAnyUploading => _images.any((p) => p.isUploading);

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    // "Chưa chọn loại nhà" nay báo đỏ ngay tại ô (validator) thay vì snackbar
    // ở đáy màn — nên validate() đã chặn, không cần kiểm _categoryId lần nữa.
    if (!_formKey.currentState!.validate()) return;
    // Vai trò không nằm trong Form (là 2 ô bấm, không phải TextFormField) nên
    // phải kiểm tay. Chỉ BẮT BUỘC với tin MỚI: tin cũ tạo trước 0075 chưa từng
    // được hỏi, ép khai lại lúc sửa là chặn oan việc sửa giá/ảnh.
    if (_sellerType.isEmpty && widget.editing == null) {
      setState(() => _thieuVaiTro = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.sellerRequired)),
      );
      return;
    }
    if (_theoHang && !widget.isEdit && _loaiPhongId == null) {
      setState(() => _thieuHang = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tin lưu trú ngắn hạn bán theo hạng phòng — chọn toà và hạng',
          ),
        ),
      );
      return;
    }
    if (_isAnyUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.postHouseWaitUpload)),
      );
      return;
    }
    final newUrls = _images
        .where((p) => p.uploadedUrl != null)
        .map((p) => p.uploadedUrl!)
        .toList();
    final allUrls = [..._existingImages, ...newUrls];
    if (allUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.postHouseNeedOneImage)),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final houseProvider = Provider.of<HouseProvider>(context, listen: false);
    final user = auth.currentUser!;
    final editing = widget.editing;

    setState(() => _isSubmitting = true);

    // Theo hạng: server ghi đè `listing_type`/tồn kho bằng số phòng của hạng
    // (`tin_ngan_han.gan_hang`), app gửi giá trị nào cũng không đổi kết quả —
    // gửi 'single' cho khỏi hiện "nhiều phòng" trước khi server trả lời.
    final effectiveListingType = (_isSale || _theoHang) ? 'single' : _listingType;
    final isMulti = effectiveListingType == 'multi_unit';
    final totalUnits =
        isMulti ? (int.tryParse(_totalUnitsCtrl.text.trim()) ?? 1) : 1;
    final availableUnits = isMulti
        ? (int.tryParse(_availableUnitsCtrl.text.trim()) ?? totalUnits)
            .clamp(0, totalUnits)
        : 1;

    final house = HouseModel(
      id: editing?.id,
      hostId: editing?.hostId ?? user.id!,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      categoryId: _categoryId!,
      price: double.tryParse(_priceCtrl.text.replaceAll('.', '').trim()) ?? 0,
      area: double.tryParse(_areaCtrl.text.trim()) ?? 0,
      address: _addressCtrl.text.trim(),
      city: _provinceName,
      district: _wardName,
      latitude: _lat,
      longitude: _lng,
      bedrooms: int.tryParse(_bedroomsCtrl.text.trim()) ?? 1,
      bathrooms: int.tryParse(_bathroomsCtrl.text.trim()) ?? 1,
      // Status override removed: backend defaults new listings to 'published'.
      // Edit mode preserves the existing status from the server.
      status: editing?.status ?? 'published',
      images: allUrls,
      createdAt: editing?.createdAt,
      listingType: effectiveListingType,
      totalUnits: totalUnits,
      availableUnits: availableUnits,
      genderPref: (!_isSale && isMulti) ? _genderPref : 'any',
      transactionType: _transactionType,
      sellerType: _sellerType,
      legalStatus: _isSale ? _legalStatus : null,
      direction: _direction,
      loaiPhongId: _theoHang ? _loaiPhongId : null,
    );

    bool ok;
    String? newToken;
    String? postedStatus;
    if (editing == null) {
      final result = await houseProvider.registerNewHouse(house);
      ok = result.ok;
      newToken = result.newToken;
      postedStatus = result.status;
    } else {
      ok = await houseProvider.updateHouse(house);
    }

    // Auto-host upgrade: if the backend returned a new JWT (guest → host on
    // first listing), persist it and refresh the auth session so host-only
    // features become available without forcing a re-login.
    if (ok && newToken != null) {
      await SessionService.instance.setToken(newToken);
      AnalyticsService.instance.logEvent('role_upgraded', props: const {
        'from': 'guest',
        'to': 'host',
        'trigger': 'first_listing',
      });
      if (mounted) {
        await Provider.of<AuthProvider>(context, listen: false).bootstrap();
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Tin BÁN giá trị lớn/tài khoản tái phạm → server đưa vào tiền kiểm
    // (`pending_review`). KHÔNG báo "đăng thành công" (snackbar xanh) vì tin
    // CHƯA lên feed công khai — dùng dialog nói rõ để chủ nhà không tưởng app lỗi.
    final pendingReview = ok && editing == null && postedStatus == 'pending_review';
    if (pendingReview) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.postHousePendingReviewTitle),
          content: Text(l.postHousePendingReviewBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.commonUnderstood),
            ),
          ],
        ),
      );
    } else {
      final msg = editing == null
          ? (ok ? l.postHousePostSuccess : l.postHousePostFailed)
          : (ok ? l.postHouseUpdateSuccess : l.postHouseUpdateFailed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }

    if (ok) {
      // Đăng xong thì nháp hết ý nghĩa — xoá để lần sau không bị hỏi khôi phục
      // dữ liệu của tin đã đăng rồi.
      _draftTimer?.cancel();
      await _draft.clear();
      // Refresh my listings nếu đang edit để badge status cập nhật
      if (editing != null) {
        await houseProvider.fetchMyHouses(user.id!);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final houseProvider = Provider.of<HouseProvider>(context);
    // Danh mục về sau initState (nạp async) nên phải suy nhóm ở đây, không phải
    // trong initState — lúc đó `categories` còn rỗng.
    _syncGroupFromCategory(houseProvider.categories);
    // Auth session dismiss: if the user logs out or a different user logs in
    // while this modal is open, pop the route rather than leak the draft.
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    if (_ownerUserId != null && currentUserId != _ownerUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: DsAppBar(
        title: widget.isEdit ? l.postHouseEditTitle : l.postHouseNewTitle,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          // Bắt MỌI thay đổi của field con trong form -> ghi nháp, không phải
          // rải lời gọi vào từng ô.
          onChanged: _luuNhapSau,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Transaction type picker — gated by LISTING_V2_ENABLED build flag.
              // Placed at very top so host picks rent/sale before entering details.
              if (kListingV2Enabled) ...[
                _buildTransactionTypePicker(),
                const SizedBox(height: 18),
              ],

              _label(l.postHousePhotosLabel(
                  _isSale
                      ? l.postHousePropertyPhotos
                      : l.postHouseRoomPhotos,
                  _totalImages,
                  _maxImages)),
              _buildImageGrid(),
              const SizedBox(height: 18),

              // Tin theo hạng KHÔNG hỏi 1 căn / nhiều phòng: tồn kho là số
              // phòng của hạng, hỏi lại chỉ tạo ra hai con số mâu thuẫn.
              if (!_isSale && !_theoHang) ...[
                _label(l.postHouseListingCategory),
                _buildListingTypeSelector(),
                if (_listingType == 'multi_unit') ...[
                  const SizedBox(height: 12),
                  _buildMultiUnitBlock(),
                ],
                const SizedBox(height: 18),
              ],

              _label(l.postHouseTitleLabel),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  // Gợi ý ĐỘNG dựng từ dữ liệu đã nhập (loại nhà · diện tích ·
                  // phường) để người dùng chỉ việc gõ theo. CỐ Ý không tự ghi
                  // vào ô: tiêu đề sinh máy sẽ trùng nhau hàng loạt khi tin
                  // nhiều lên → trang /tin dính trùng lặp nội dung, hại SEO.
                  hintText: _titleSuggestion(houseProvider) ??
                      l.postHouseTitleHint,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? l.postHouseRequired : null,
              ),
              const SizedBox(height: 14),

              // Mô tả KHÔNG bắt buộc: server chưa từng bắt buộc (dùng giá trị
              // mặc định), ràng buộc này là FE tự áp. Đây là ô tốn công nhất
              // (gõ tự do 3 dòng) nên bắt buộc nó chính là chỗ người dùng bỏ
              // cuộc. Đổi lại, nút chèn khung mẫu ở dưới giữ chất lượng tin.
              _label(l.postHouseDescLabelOptional),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                // Ẩn/hiện nút khung mẫu theo việc ô đã có chữ hay chưa.
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l.postHouseDescHint,
                ),
              ),
              if (_descCtrl.text.trim().isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _chenKhungMoTa,
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: Text(l.postHouseDescTemplateBtn),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // ── Vai trò người đăng (TỰ KHAI) ─────────────────────────────
              _label(l.sellerStep),
              _sellerPicker(l),
              const SizedBox(height: 14),

              // ── Bước 1: NHÓM ─────────────────────────────────────────────
              // Tách 2 bước vì 12 loại trong một dropdown vừa dài vừa không nói
              // được loại này thuộc mảng nào; nhóm còn quyết định MÀU PIN trên
              // bản đồ nên người đăng cần thấy mình đang chọn nhóm gì.
              _label(l.postGroupStep),
              _groupPicker(l),
              const SizedBox(height: 14),

              // ── Bước 2: LOẠI trong nhóm ──────────────────────────────────
              _label(_isSale ? l.postHousePropertyType : l.postHouseRoomType),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                items: _categoriesOfGroup(houseProvider.categories)
                    .map((cat) => DropdownMenuItem<int>(
                          value: cat['id'] as int,
                          child: Text(cat['name'] as String),
                        ))
                    .toList(),
                onChanged: _groupKey.isEmpty
                    ? null
                    : (v) => setState(() => _categoryId = v),
                decoration: InputDecoration(
                  hintText: _groupKey.isEmpty
                      ? l.postPickGroupFirst
                      : l.postHouseSelectType,
                ),
                // Trước đây thiếu validator: lỗi "chưa chọn loại" chỉ hiện bằng
                // snackbar ở ĐÁY màn lúc bấm đăng, trong khi form đã cuộn lên
                // các ô đỏ khác → người dùng không thấy mình thiếu gì.
                validator: (v) => v == null ? l.postHouseRequired : null,
              ),
              const SizedBox(height: 14),

              // ── Ngắn hạn: bán theo HẠNG PHÒNG của một toà ────────────────
              if (_theoHang) ...[
                _label('Toà & hạng phòng'),
                _khoiHangPhong(),
                const SizedBox(height: 14),
              ],

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tin theo hạng bán THEO ĐÊM/GIỜ/NGÀY (giá thật nằm ở
                        // hạng); ô này chỉ là giá HIỂN THỊ trên thẻ tin. Để
                        // nhãn "/tháng" ở đây là nói sai với chính tin mình.
                        _label(_isSale
                            ? l.postHouseSalePrice
                            : _theoHang
                                ? 'Giá hiện trên tin (₫/đêm)'
                                : l.postHouseRentPrice),
                        TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_ThousandsFormatter()],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: '₫ ',
                            suffixText: _isSale
                                ? null
                                : _theoHang
                                    ? '/đêm'
                                    : l.postHousePerMonth,
                            hintText: _isSale
                                ? l.postHouseSalePriceHint
                                : _theoHang
                                    ? 'Lấy theo giá qua đêm của hạng'
                                    : l.postHouseRentPriceHint,
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? l.postHouseRequired : null,
                        ),
                        if (_priceCtrl.text.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '≈ ${_moneyInWords(_priceCtrl.text)}'
                              '${_isSale ? '' : _theoHang ? '/đêm' : l.postHousePerMonth}',
                              style: const TextStyle(
                                  fontSize: 11, color: HD.inkMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(l.postHouseArea),
                        TextFormField(
                          controller: _areaCtrl,
                          keyboardType: TextInputType.number,
                          // Cập nhật gợi ý tiêu đề khi diện tích đổi.
                          onChanged: (_) => setState(() {}),
                          decoration:
                              InputDecoration(hintText: l.postHouseAreaHint),
                          validator: (v) =>
                              v == null || v.isEmpty ? l.postHouseRequired : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── ĐỊA ĐIỂM ─────────────────────────────────────────────────
              // Bản đồ đặt TRƯỚC 3 ô địa chỉ/tỉnh/phường một cách CỐ Ý: chạm map
              // gọi reverse geocode và tự điền cả 3 ô (_onMapTap). Trước đây map
              // nằm cuối khối nên người dùng gõ tay hết rồi mới thấy — công cụ
              // tiết kiệm nhất của form không ai gặp. 3 ô dưới vẫn sửa được vì
              // OSM vùng ven thường chỉ ra tới phường (xem _isCoarseAddress).
              _label(l.postHouseMapLocation),
              Text(
                l.postHouseMapHint,
                style: const TextStyle(fontSize: 12, color: HD.inkMuted),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 220,
                  child: FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: LatLng(_lat ?? 16.0, _lng ?? 107.9),
                      initialZoom: _lat != null ? 15 : 5.2,
                      onTap: (pos, latlng) => _onMapTap(latlng),
                    ),
                    children: [
                      lopTileNen(),
                      if (_lat != null && _lng != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: LatLng(_lat!, _lng!),
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.location_pin,
                                color: HD.accent, size: 44),
                          ),
                        ]),
                    ],
                  ),
                ),
              ),
              if (_lat != null && _lng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.postHousePinnedAt(_lat!.toStringAsFixed(5),
                        _lng!.toStringAsFixed(5)),
                    style: const TextStyle(fontSize: 11, color: HD.inkMuted),
                  ),
                ),
              // Nút kiểm tra quy hoạch — user-initiated (US-02 giảm scope: không real-time).
              // D4: nút này KHÔNG liên quan đến submit button — submit vẫn luôn enable.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PlanningCheckButton(lat: _lat, lng: _lng),
              ),
              const SizedBox(height: 14),

              _label(l.postHouseAddress),
              TextFormField(
                controller: _addressCtrl,
                decoration:
                    InputDecoration(hintText: l.postHouseAddressHint),
                validator: (v) =>
                    v == null || v.isEmpty ? l.postHouseRequired : null,
                onChanged: (_) {
                  // Người dùng đã tự sửa → gỡ nhắc bổ sung số nhà.
                  if (_addressNeedsDetail) {
                    setState(() => _addressNeedsDetail = false);
                  }
                },
              ),
              if (_addressNeedsDetail)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.postHouseAddressNeedsDetail,
                    style: const TextStyle(fontSize: 11, color: HD.warning),
                  ),
                ),
              const SizedBox(height: 14),

              _label(l.postHouseProvince),
              DropdownButtonFormField<String>(
                value: _provinceCode,
                isExpanded: true,
                decoration:
                    InputDecoration(hintText: l.postHouseSelectProvince),
                items: _provinces
                    .map((p) =>
                        DropdownMenuItem(value: p.code, child: Text(p.name)))
                    .toList(),
                validator: (v) => v == null ? l.postHouseRequired : null,
                onChanged: _onProvinceChanged,
              ),
              const SizedBox(height: 14),
              _label(l.postHouseWard),
              DropdownButtonFormField<String>(
                value: _wardCode,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: _loadingWards
                      ? l.postHouseLoading
                      : l.postHouseSelectWard,
                ),
                items: _wards
                    .map((w) =>
                        DropdownMenuItem(value: w.code, child: Text(w.name)))
                    .toList(),
                validator: (v) => v == null ? l.postHouseRequired : null,
                onChanged: _provinceCode == null
                    ? null
                    : (code) {
                        final w = _wards.firstWhere((x) => x.code == code);
                        setState(() {
                          _wardCode = code;
                          _wardName = w.name;
                        });
                      },
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(l.postHouseBedrooms),
                        TextFormField(
                          controller: _bedroomsCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(l.postHouseBathrooms),
                        TextFormField(
                          controller: _bathroomsCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isSale) ...[
                const SizedBox(height: 14),
                _label(l.postHouseLegal),
                _buildLegalChips(),
              ],
              const SizedBox(height: 14),
              _label('Hướng nhà (phong thuỷ)'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _directionLabels.entries.map((e) {
                  final sel = _direction == e.key;
                  return ChoiceChip(
                    selected: sel,
                    label: Text(e.value),
                    onSelected: (_) =>
                        setState(() => _direction = sel ? null : e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.isEdit
                            ? l.postHouseSaveChanges
                            : (_isSale ? l.postHouseSell : l.postHouseRent),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final canAddMore = _totalImages < _maxImages;
    final existingCount = _existingImages.length;
    final pickedCount = _images.length;
    final totalTiles = existingCount + pickedCount + (canAddMore ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalTiles,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        if (i < existingCount) {
          return _buildExistingThumbnail(_existingImages[i], isCover: i == 0);
        }
        final pickedIdx = i - existingCount;
        if (pickedIdx < pickedCount) {
          return _buildThumbnail(_images[pickedIdx],
              isCover: i == 0 && existingCount == 0);
        }
        // Add tile
        return InkWell(
          onTap: _pickImages,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: HD.paperSunken,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HD.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_a_photo_outlined,
                    color: HD.inkMuted, size: 28),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).postHouseAddPhoto,
                  style: const TextStyle(
                      color: HD.inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExistingThumbnail(String url, {required bool isCover}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: HD.paperSunken,
              child: const Icon(Icons.broken_image_outlined,
                  color: HD.inkMuted),
            ),
          ),
          if (isCover)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppLocalizations.of(context).postHouseCoverPhoto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _existingImages.remove(url)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(_PickedImage pic, {required bool isCover}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          kIsWeb
              ? Image.memory(pic.bytes, fit: BoxFit.cover)
              : Image.file(File(pic.file.path), fit: BoxFit.cover),
          if (pic.isUploading)
            Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
          if (pic.failed)
            GestureDetector(
              onTap: () => _retry(pic),
              child: Container(
                color: Colors.red.withOpacity(0.55),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh, color: Colors.white, size: 24),
                    const SizedBox(height: 4),
                    Text(AppLocalizations.of(context).postHouseRetry,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
            ),
          if (isCover && !pic.isUploading && !pic.failed)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppLocalizations.of(context).postHouseCoverPhoto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(pic),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Segmented picker: "Đăng cho thuê" (rent) vs "Đăng bán" (sale).
  /// Only rendered when [kListingV2Enabled] is true (build-time flag).
  /// Semantic labels follow the accessibility spec: "Loại tin: Cho thuê" / "Loại tin: Rao bán".
  Widget _buildTransactionTypePicker() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(l.postHouseListingForm),
        Row(
          children: [
            Expanded(
              child: _transactionOption(
                value: 'rent',
                label: l.postHouseRent,
                semanticLabel: l.postHouseSemanticRent,
                icon: Icons.key_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _transactionOption(
                value: 'sale',
                label: l.postHouseSell,
                semanticLabel: l.postHouseSemanticSale,
                icon: Icons.sell_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _transactionOption({
    required String value,
    required String label,
    required String semanticLabel,
    required IconData icon,
  }) {
    final selected = _transactionType == value;
    return Semantics(
      label: semanticLabel,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() => _transactionType = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? HD.accent.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? HD.accent : HD.hairline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? HD.accent : HD.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? HD.accent : HD.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingTypeSelector() {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: _typeOption(
          value: 'single',
          icon: Icons.home_outlined,
          title: l.postHouseSingleTitle,
          subtitle: l.postHouseSingleSubtitle,
        )),
        const SizedBox(width: 8),
        Expanded(child: _typeOption(
          value: 'multi_unit',
          icon: Icons.apartment,
          title: l.postHouseMultiTitle,
          subtitle: l.postHouseMultiSubtitle,
        )),
      ],
    );
  }

  Widget _typeOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _listingType == value;
    return InkWell(
      onTap: () => setState(() => _listingType = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? HD.accent.withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? HD.accent
                : HD.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: selected
                    ? HD.accent
                    : HD.inkMuted,
                size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected
                    ? HD.accent
                    : HD.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: HD.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalChips() {
    final l = AppLocalizations.of(context);
    final opts = [
      ('red_book', l.postHouseLegalRedBook),
      ('pink_book', l.postHouseLegalPinkBook),
      ('sale_contract', l.postHouseLegalSaleContract),
      ('pending', l.postHouseLegalPending),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: opts
          .map((o) => ChoiceChip(
                label: Text(o.$2),
                selected: _legalStatus == o.$1,
                onSelected: (s) =>
                    setState(() => _legalStatus = s ? o.$1 : null),
              ))
          .toList(),
    );
  }

  Widget _buildMultiUnitBlock() {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.accentSoft,
        borderRadius: BorderRadius.circular(10),
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
                    _label(l.postHouseTotalUnits),
                    TextFormField(
                      controller: _totalUnitsCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(hintText: l.postHouseTotalUnitsHint),
                      onChanged: (v) {
                        final total = int.tryParse(v) ?? 0;
                        final cur =
                            int.tryParse(_availableUnitsCtrl.text) ?? 0;
                        if (cur > total) {
                          _availableUnitsCtrl.text = total.toString();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(l.postHouseAvailableUnits),
                    TextFormField(
                      controller: _availableUnitsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          hintText: l.postHouseAvailableUnitsHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _label(l.postHousePriorityTenant),
          Row(
            children: [
              _genderOption('any', l.postHouseGenderAny, Icons.people_outline),
              const SizedBox(width: 6),
              _genderOption('male', l.postHouseGenderMale, Icons.male),
              const SizedBox(width: 6),
              _genderOption('female', l.postHouseGenderFemale, Icons.female),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderOption(String value, String label, IconData icon) {
    final selected = _genderPref == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _genderPref = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? HD.accent : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? HD.accent
                  : HD.hairline,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : HD.inkSoft),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : HD.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chọn nhóm → loại (2 bước) ─────────────────────────────────────────────

  /// 3 nhóm master. Nhãn để ở đây (l10n) chứ không lấy từ API để form vẽ được
  /// ngay cả khi mạng chậm — API chỉ cần cho biết loại nào thuộc nhóm nào.
  List<({String key, String label, IconData icon})> _groups(AppLocalizations l) => [
        (key: 'stay_long', label: l.postGroupStayLong, icon: Icons.home_work_outlined),
        (key: 'stay_short', label: l.postGroupStayShort, icon: Icons.vpn_key_outlined),
        (key: 'business', label: l.postGroupBusiness, icon: Icons.storefront_outlined),
      ];

  /// Loại hình thuộc nhóm đang chọn. Danh mục cũ chưa có `group_key` (API cũ
  /// hoặc backend chưa migrate) → coi như thuộc nhóm dài hạn, KHÔNG để trống
  /// danh sách khiến không đăng tin được.
  /// Suy ngược nhóm từ `categoryId` — dùng khi SỬA tin cũ hoặc khôi phục bản
  /// nháp: hai luồng đó chỉ lưu id loại, không lưu nhóm.
  void _syncGroupFromCategory(List<Map<String, dynamic>> all) {
    if (_categoryId == null || _groupKey.isNotEmpty) return;
    final cat = all.firstWhere(
      (c) => c['id'] == _categoryId,
      orElse: () => const {},
    );
    if (cat.isEmpty) return;
    final g = (cat['group_key'] as String?) ?? '';
    _groupKey = g.isEmpty ? 'stay_long' : g;
    // Khôi phục bản nháp của một tin ngắn hạn: nhóm về muộn (sau khi danh mục
    // nạp xong) nên phải tải toà+hạng ở đây, không thì khối chọn hạng đứng im.
    if (_groupKey == 'stay_short' && !widget.isEdit && _toaCoHang.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _taiToaVaHang());
    }
  }

  List<Map<String, dynamic>> _categoriesOfGroup(
      List<Map<String, dynamic>> all) {
    if (_groupKey.isEmpty) return const [];
    return all.where((c) {
      final g = (c['group_key'] as String?) ?? '';
      return g.isEmpty ? _groupKey == 'stay_long' : g == _groupKey;
    }).toList();
  }

  /// Hai lựa chọn TO, rõ nghĩa — không dùng dropdown vì đây là câu hỏi người
  /// dùng phải đọc và hiểu, không phải một trường khai báo cho xong.
  Widget _sellerPicker(AppLocalizations l) {
    final opts = <({String key, String title, String desc, IconData icon})>[
      (
        key: 'owner',
        title: l.sellerOwner,
        desc: l.sellerOwnerDesc,
        icon: Icons.person_outline
      ),
      (
        key: 'broker',
        title: l.sellerBroker,
        desc: l.sellerBrokerDesc,
        icon: Icons.handshake_outlined
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final o in opts) ...[
              if (o.key != 'owner') const SizedBox(width: HD.s8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(HD.r12),
                  onTap: () => setState(() {
                    _sellerType = o.key;
                    _thieuVaiTro = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _sellerType == o.key
                          ? HD.accentTint
                          : HD.paperRaised,
                      borderRadius: BorderRadius.circular(HD.r12),
                      border: Border.all(
                        color: _sellerType == o.key
                            ? HD.accent
                            : (_thieuVaiTro ? HD.negative : HD.hairline),
                        width: _sellerType == o.key ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(o.icon,
                            size: 20,
                            color: _sellerType == o.key
                                ? HD.accent
                                : HD.inkMuted),
                        const SizedBox(height: HD.s4),
                        Text(
                          o.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _sellerType == o.key
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: _sellerType == o.key
                                ? HD.accent
                                : HD.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(o.desc,
                            style: const TextStyle(
                                fontSize: 11, color: HD.inkMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: HD.s4),
        // Nói thẳng đây là TỰ KHAI — app không xác minh giấy tờ, và nhãn hiện
        // ra cho khách cũng ghi đúng như vậy.
        Text(
          _thieuVaiTro ? l.sellerRequired : l.sellerStepHelper,
          style: HD.caption(color: _thieuVaiTro ? HD.negative : null),
        ),
      ],
    );
  }

  // ── Toà + hạng phòng cho tin ngắn hạn ────────────────────────────────────

  /// Tải danh sách toà kèm hạng. Gọi LƯỜI (chỉ khi người đăng chọn nhóm lưu
  /// trú ngắn hạn) — đại đa số tin là dài hạn, không việc gì bắt mọi người
  /// chờ một lượt gọi mạng họ không dùng tới.
  Future<void> _taiToaVaHang() async {
    if (_dangTaiToa) return;
    setState(() {
      _dangTaiToa = true;
      _loiTaiToa = null;
    });
    try {
      final ds = await _hangApi.toaVaHang();
      if (!mounted) return;
      setState(() {
        _toaCoHang = ds;
        // Đúng một toà thì chọn sẵn — bắt bấm một ô chỉ có một lựa chọn là
        // thêm bước cho vui.
        if (_toaId == null && ds.length == 1) _toaId = ds.first.id;
        final t = _toaDangChon;
        if (_loaiPhongId == null && t != null && t.hang.length == 1) {
          _loaiPhongId = t.hang.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loiTaiToa = e is ApiException
          ? e.message
          : 'Không tải được danh sách toà');
    } finally {
      if (mounted) setState(() => _dangTaiToa = false);
    }
  }

  Widget _khoiHangPhong() {
    // Sửa tin: server KHÔNG nhận đổi hạng qua PUT (allowlist), nên đừng bày ô
    // chọn giả vờ đổi được — nói thẳng phải đăng tin mới.
    final dangSua = widget.editing?.hangPhong;
    if (widget.isEdit) {
      return _hopHang(
        child: dangSua == null
            ? const Text('Tin này không bán theo hạng phòng.',
                style: TextStyle(fontSize: 13, color: HD.inkSoft))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dangSua['ten']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: HD.ink),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Muốn bán hạng khác thì đăng tin mới — đổi hạng ngay trên '
                    'tin cũ sẽ làm sai lịch của những đơn đã đặt.',
                    style: TextStyle(fontSize: 12, color: HD.inkMuted),
                  ),
                ],
              ),
      );
    }
    if (_dangTaiToa && _toaCoHang.isEmpty) {
      return _hopHang(
        child: const Row(
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Đang tải toà của bạn…',
                style: TextStyle(fontSize: 13, color: HD.inkSoft)),
          ],
        ),
      );
    }
    if (_loiTaiToa != null) {
      return _hopHang(
        vien: HD.negative,
        child: Row(
          children: [
            Expanded(
              child: Text(_loiTaiToa!,
                  style: const TextStyle(fontSize: 13, color: HD.negative)),
            ),
            TextButton(onPressed: _taiToaVaHang, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_toaCoHang.isEmpty) {
      return _hopHang(
        child: const Text(
          'Bạn chưa quản lý toà nào. Tin lưu trú ngắn hạn bán theo HẠNG PHÒNG '
          'của một toà — hãy tạo toà và khai hạng ở tab Cá nhân → Quản lý toà, '
          'rồi quay lại đăng tin.',
          style: TextStyle(fontSize: 13, color: HD.inkSoft, height: 1.4),
        ),
      );
    }
    final toa = _toaDangChon;
    final hang = _hangDangChon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: const Key('post-toa'),
          initialValue: _toaId,
          items: [
            for (final t in _toaCoHang)
              DropdownMenuItem<int>(
                value: t.id,
                child: Text(t.ten, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            _toaId = v;
            // Đổi toà thì hạng cũ thuộc toà khác — bỏ chọn, đừng để lại một id
            // sẽ bị server trả 404 lúc bấm Đăng.
            _loaiPhongId = null;
            final t = _toaDangChon;
            if (t != null && t.hang.length == 1) _loaiPhongId = t.hang.first.id;
          }),
          decoration: const InputDecoration(hintText: 'Chọn toà'),
        ),
        const SizedBox(height: 10),
        if (toa != null && toa.hang.isEmpty)
          _hopHang(
            vien: _thieuHang ? HD.negative : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${toa.ten}" chưa có hạng phòng nào. Khai hạng (tên, sức '
                  'chứa, giá) rồi quay lại — tin sẽ tự bán đúng số phòng của '
                  'hạng.',
                  style: const TextStyle(
                      fontSize: 13, color: HD.inkSoft, height: 1.4),
                ),
                // Mở thẳng màn hạng của toà này; quay về là tải lại ô chọn,
                // khỏi bắt người đăng tự tìm đường qua Quản lý toà.
                TextButton.icon(
                  key: const Key('post-khai-hang'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LoaiPhongScreen(
                          buildingId: toa.id,
                          tenToa: toa.ten,
                        ),
                      ),
                    );
                    if (mounted) await _taiToaVaHang();
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Khai hạng phòng cho toà này'),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<int>(
            key: const Key('post-hang'),
            initialValue: _loaiPhongId,
            items: [
              for (final h in toa?.hang ?? const <HangDeChon>[])
                DropdownMenuItem<int>(
                  value: h.id,
                  child: Text(
                    '${h.ten} · ${h.soPhong} phòng',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: toa == null
                ? null
                : (v) => setState(() {
                      _loaiPhongId = v;
                      _thieuHang = false;
                      // Giá thật đã khai ở hạng — điền sẵn giá qua đêm để
                      // người đăng khỏi gõ lại (và khỏi gõ lệch). Chỉ điền khi
                      // ô còn trống: không đè lên con số họ vừa tự nhập.
                      final g = _hangDangChon?.giaQuaDem;
                      if (g != null && g > 0 && _priceCtrl.text.trim().isEmpty) {
                        _priceCtrl.text = _groupThousands(g.toStringAsFixed(0));
                      }
                    }),
            decoration: InputDecoration(
              hintText: toa == null ? 'Chọn toà trước' : 'Chọn hạng phòng',
              errorText: _thieuHang ? 'Chọn hạng phòng để bán' : null,
            ),
          ),
        if (hang != null) ...[
          const SizedBox(height: 8),
          _hopHang(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tin sẽ bán ${hang.soPhong} phòng của hạng này',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: HD.ink, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (hang.sucChua > 0) '${hang.sucChua} khách',
                    if (hang.giuong != null) hang.giuong!,
                    if (hang.dienTich != null)
                      '${hang.dienTich!.round()} m²',
                    if (hang.giaTheoGio != null)
                      '${PriceFormat.full(hang.giaTheoGio!)}/giờ',
                    if (hang.giaQuaDem != null)
                      '${PriceFormat.full(hang.giaQuaDem!)}/đêm',
                    if (hang.giaTheoNgay != null)
                      '${PriceFormat.full(hang.giaTheoNgay!)}/ngày',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: HD.inkMuted),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Khách đặt HẠNG, lễ tân gán số phòng lúc nhận — nên không '
                  'phải khai số căn hay số phòng trống.',
                  style: TextStyle(fontSize: 12, color: HD.inkMuted),
                ),
                if (hang.soPhong == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Hạng này chưa xếp phòng nào vào — xếp phòng trong Quản '
                      'lý toà, nếu không tin sẽ không nhận được đơn.',
                      style: TextStyle(fontSize: 12, color: HD.negative),
                    ),
                  ),
                if (!hang.dangBan)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Hạng đang TẠM NGỪNG nhận khách — bật lại trong Quản lý '
                      'toà thì tin mới nhận đơn.',
                      style: TextStyle(fontSize: 12, color: HD.negative),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _hopHang({required Widget child, Color? vien}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: vien ?? HD.hairline),
        ),
        child: child,
      );

  Widget _groupPicker(AppLocalizations l) {
    return Row(
      children: [
        for (final g in _groups(l)) ...[
          if (g.key != 'stay_long') const SizedBox(width: HD.s8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(HD.r12),
              onTap: () => setState(() {
                if (_groupKey == g.key) return;
                _groupKey = g.key;
                // Đổi nhóm thì loại cũ không còn hợp lệ — bỏ chọn thay vì để
                // lại một id thuộc nhóm khác (sẽ lưu sai âm thầm).
                _categoryId = null;
                _thieuHang = false;
                // Ngắn hạn mới cần danh sách toà+hạng; tải lười ngay lúc
                // người đăng rẽ vào nhánh đó.
                if (g.key == 'stay_short' && !widget.isEdit) _taiToaVaHang();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: _groupKey == g.key ? HD.accentTint : HD.paperRaised,
                  borderRadius: BorderRadius.circular(HD.r12),
                  border: Border.all(
                    color: _groupKey == g.key ? HD.accent : HD.hairline,
                    width: _groupKey == g.key ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(g.icon,
                        size: 20,
                        color: _groupKey == g.key ? HD.accent : HD.inkMuted),
                    const SizedBox(height: HD.s4),
                    Text(
                      g.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _groupKey == g.key
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _groupKey == g.key ? HD.accent : HD.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: HD.inkSoft,
            fontSize: 13,
          ),
        ),
      );
}


/// Chèn dấu chấm phân tách hàng nghìn kiểu VN cho ô nhập số tiền.
String _groupThousands(String input) {
  final d = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return '';
  final buf = StringBuffer();
  for (int i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) buf.write('.');
    buf.write(d[i]);
  }
  return buf.toString();
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = _groupThousands(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Diễn giải số tiền bằng chữ: "2,5 tỷ" / "8 triệu" / "500.000 ₫".
String _moneyInWords(String raw) {
  final n = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  if (n >= 1000000000) {
    final ty = n / 1000000000;
    return '${ty.toStringAsFixed(ty % 1 == 0 ? 0 : 1).replaceAll('.', ',')} tỷ';
  }
  if (n >= 1000000) {
    final tr = n / 1000000;
    return '${tr.toStringAsFixed(tr % 1 == 0 ? 0 : 1).replaceAll('.', ',')} triệu';
  }
  return '${_groupThousands(raw)} ₫';
}
