import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/models/login_account_type.dart';

class AuthResult {
  final UserModel user;
  final String token;
  AuthResult({required this.user, required this.token});
}

abstract class IAuthRepository {
  Future<AuthResult?> login(
    String email,
    String password, {
    LoginAccountType? accountType,
  });
  Future<AuthResult?> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String role = 'guest',
  });
  Future<UserModel?> me();
  Future<void> logout();
  Future<UserModel?> updateProfile(
    int userId, {
    String? name,
    String? phone,
    String? avatarPath,
    String? email,
    String? birthday,
    String? bio,
    String? idNumber,
  });
  Future<bool> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  );

  /// Người dùng tự xoá tài khoản (Apple 5.1.1(v) + Google Play bắt buộc).
  /// Backend ẩn danh hoá PII + vô hiệu hoá; yêu cầu xác nhận mật khẩu.
  Future<bool> deleteAccount(String password);
}
