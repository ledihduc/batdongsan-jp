/// The workspace requested at login. This never changes the user's auth role.
enum LoginAccountType {
  customer,
  sale,
  owner,
  admin;

  static LoginAccountType? fromValue(String? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }

  String get homeLocation => switch (this) {
    customer => '/',
    sale || owner => '/?tab=activity',
    admin => '/admin',
  };
}

class LoginAccountTypeMismatch implements Exception {
  const LoginAccountTypeMismatch();

  @override
  String toString() =>
      'Tài khoản chưa có quyền đăng nhập với loại tài khoản đã chọn. '
      'Vui lòng chọn lại loại tài khoản hoặc liên hệ quản trị viên.';
}
