/// Hai "thế giới" của super-app. Dùng làm giá trị `defaultWorld` và làm khoá
/// sắp xếp 2 slot đầu của bottom nav (xem `guest_shell.dart`).
const String kWorldRealEstate = 'realestate';
const String kWorldConstruction = 'construction';

/// Sở thích/mục đích người dùng (khảo sát phân loại — redesign v2 P1).
/// interests: các mục đích lướt (KHÔNG gồm "là đơn vị" — đó là danh tính riêng).
class UserPreferences {
  const UserPreferences({
    this.interests = const [],
    this.provinces = const [],
    this.serviceSlugs = const [],
    this.defaultWorld = 'realestate',
  });

  final List<String>
  interests; // rent, buy, sell_or_list, find_service, follow_construction
  final List<String> provinces; // province_code[]
  final List<String> serviceSlugs; // design, build, interior, industrial
  final String defaultWorld; // realestate | construction

  bool get isEmpty =>
      interests.isEmpty && provinces.isEmpty && serviceSlugs.isEmpty;

  factory UserPreferences.fromMap(Map<String, dynamic> m) => UserPreferences(
    interests: List<String>.from((m['interests'] as List?) ?? const []),
    provinces: List<String>.from((m['provinces'] as List?) ?? const []),
    serviceSlugs: List<String>.from((m['service_slugs'] as List?) ?? const []),
    defaultWorld: (m['default_world'] as String?) ?? 'realestate',
  );

  Map<String, dynamic> toMap() => {
    'interests': interests,
    'provinces': provinces,
    'service_slugs': serviceSlugs,
    'default_world': defaultWorld,
  };

  UserPreferences copyWith({
    List<String>? interests,
    List<String>? provinces,
    List<String>? serviceSlugs,
    String? defaultWorld,
  }) => UserPreferences(
    interests: interests ?? this.interests,
    provinces: provinces ?? this.provinces,
    serviceSlugs: serviceSlugs ?? this.serviceSlugs,
    defaultWorld: defaultWorld ?? this.defaultWorld,
  );

  /// Quyết định "thế giới" đứng slot 0 của bottom nav (và là màn mở đầu app).
  ///
  /// Thứ tự ưu tiên — CỐ Ý theo đúng thứ tự này:
  ///   1. [nguoiDungTuChon] (đổi trong Profile) → luôn thắng. Cá nhân hoá tự
  ///      động không được phép ghi đè lựa chọn tường minh, nếu không người
  ///      dùng sẽ thấy cài đặt của mình "tự nhảy về" và không sửa được.
  ///   2. [laDonVi] → Thi công. Đơn vị đăng nhập là để tìm việc/gửi báo giá;
  ///      danh tính này KHÔNG nằm trong khảo sát nên trước đây bị bỏ qua.
  ///   3. [theGioiDaLuu] do khảo sát suy ra (mặc định BĐS).
  static String resolveWorld({
    required String theGioiDaLuu,
    required bool nguoiDungTuChon,
    required bool laDonVi,
  }) {
    if (nguoiDungTuChon) return theGioiDaLuu;
    if (laDonVi) return kWorldConstruction;
    return theGioiDaLuu;
  }

  /// Tie-break: có bất kỳ mục đích BĐS → 'realestate'; chỉ có mục đích thi công →
  /// 'construction'; rỗng → 'realestate'.
  static String computeWorld(List<String> interests) {
    const realestate = {'rent', 'buy', 'sell_or_list'};
    const construction = {'find_service', 'follow_construction'};
    if (interests.any(realestate.contains)) return 'realestate';
    if (interests.any(construction.contains)) return 'construction';
    return 'realestate';
  }
}
