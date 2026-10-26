import 'login_account_type.dart';

class UserModel {
  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final String phone;
  final String avatarPath;
  final String role; // 'admin', 'host', 'guest'

  /// Nhãn hồ sơ cũ: 'customer' | 'sale' | 'owner' | 'admin'.
  ///
  /// Khác [role] (quyền hệ thống). Sale hiện vẫn mang `role='guest'` nên đây
  /// không giới hạn ba chế độ làm việc. Quyền do [loginAccountTypes] cung cấp.
  final String accountType;

  /// Self-only capabilities from /auth/login and /auth/me. Not a DB column.
  final List<String>? loginAccountTypes;
  final bool isActive;
  final DateTime createdAt;

  // Optional profile fields
  final String? birthday; // ISO yyyy-MM-dd
  final String? bio;
  final String? idNumber;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.phone,
    required this.avatarPath,
    required this.role,
    this.accountType = 'customer',
    this.loginAccountTypes,
    this.isActive = true,
    DateTime? createdAt,
    this.birthday,
    this.bio,
    this.idNumber,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final isActiveValue = map['is_active'];

    return UserModel(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      passwordHash: map['password_hash'] ?? '',
      phone: map['phone'] ?? '',
      avatarPath: map['avatar_path'] ?? '',
      role: map['role'],
      accountType: (map['account_type'] as String?) ?? 'customer',
      loginAccountTypes: (map['login_account_types'] as List?)
          ?.whereType<String>()
          .toList(growable: false),
      isActive: isActiveValue == true || isActiveValue == 1,
      createdAt: DateTime.parse(map['created_at']),
      birthday: map['birthday'] as String?,
      bio: map['bio'] as String?,
      idNumber: map['id_number'] as String?,
    );
  }

  UserModel copyWith({
    List<String>? loginAccountTypes,
    String? name,
    String? email,
    String? phone,
    String? avatarPath,
    String? birthday,
    String? bio,
    String? idNumber,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash,
      phone: phone ?? this.phone,
      avatarPath: avatarPath ?? this.avatarPath,
      role: role,
      accountType: accountType,
      loginAccountTypes: loginAccountTypes ?? this.loginAccountTypes,
      isActive: isActive,
      createdAt: createdAt,
      birthday: birthday ?? this.birthday,
      bio: bio ?? this.bio,
      idNumber: idNumber ?? this.idNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      'password_hash': passwordHash,
      'phone': phone,
      'avatar_path': avatarPath,
      'role': role,
      'account_type': accountType,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      if (birthday != null) 'birthday': birthday,
      if (bio != null) 'bio': bio,
      if (idNumber != null) 'id_number': idNumber,
    };
  }

  /// Tài khoản người bán (sale) — quyết định trang "Cá nhân" dựng bản nào.
  bool get laSale => accountType == 'sale';

  /// UI check only; the server authorizes the selected context before issuing
  /// a token. The fallback supports older servers and the local repository.
  bool canLoginAs(LoginAccountType type) {
    if (!isActive) return false;
    // Never infer administrator privileges from a business account label.
    if (type == LoginAccountType.admin) return role == 'admin';
    if (loginAccountTypes != null) {
      return loginAccountTypes!.contains(type.name);
    }
    // Older/local sessions lack capabilities. Every active account can use
    // the three business contexts; resource access is enforced by the API.
    return true;
  }

  /// Tuổi tính từ birthday (ISO yyyy-MM-dd). null nếu chưa có hoặc parse lỗi.
  int? get age {
    if (birthday == null || birthday!.isEmpty) return null;
    try {
      final dob = DateTime.parse(birthday!);
      final now = DateTime.now();
      var years = now.year - dob.year;
      final hadBirthdayThisYear =
          now.month > dob.month ||
          (now.month == dob.month && now.day >= dob.day);
      if (!hadBirthdayThisYear) years -= 1;
      return years < 0 ? null : years;
    } catch (_) {
      return null;
    }
  }
}
