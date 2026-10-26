import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:house_booking/domain/repositories/i_auth_repository.dart';

class ApiAuthRepository implements IAuthRepository {
  ApiAuthRepository({ApiClient? client})
    : _client = client ?? const ApiClient();

  final ApiClient _client;

  /// [email] nay là ĐỊNH DANH: email hoặc số điện thoại.
  ///
  /// Tên tham số giữ nguyên để không phải sửa cả `IAuthRepository` và mọi nơi
  /// gọi; khoá gửi lên thì đổi thành `dinh_danh`. Backend vẫn nhận khoá `email`
  /// cũ, nên hai bên deploy lệch nhau vài phút cũng không ai đăng nhập hỏng.
  @override
  Future<AuthResult?> login(
    String email,
    String password, {
    LoginAccountType? accountType,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await _client.post(
        '/api/auth/login',
        body: {
          'dinh_danh': email,
          'password': password,
          if (accountType != null) 'login_account_type': accountType.name,
        },
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403 && accountType != null) {
        throw const LoginAccountTypeMismatch();
      }
      rethrow;
    }

    final token = response['token'] as String;
    final userData = Map<String, dynamic>.from(response['user'] as Map);
    final user = UserModel.fromMap(userData);
    // Older servers may ignore the new request field. Do not store a session
    // with a context the returned account cannot use.
    if (accountType != null && !user.canLoginAs(accountType)) {
      throw const LoginAccountTypeMismatch();
    }
    await SessionService.instance.setToken(token);
    return AuthResult(user: user, token: token);
  }

  @override
  Future<AuthResult?> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String role = 'guest',
  }) async {
    final response = await _client.post(
      '/api/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
      },
    );
    final token = response['token'] as String;
    final user = UserModel.fromMap(
      Map<String, dynamic>.from(response['user'] as Map),
    );
    await SessionService.instance.setToken(token);
    return AuthResult(user: user, token: token);
  }

  @override
  Future<UserModel?> me() async {
    try {
      final response = await _client.get('/api/auth/me');
      return UserModel.fromMap(
        Map<String, dynamic>.from(response['user'] as Map),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await SessionService.instance.clear();
      }
      return null;
    }
  }

  @override
  Future<void> logout() async {
    await SessionService.instance.clear();
  }

  @override
  Future<UserModel?> updateProfile(
    int userId, {
    String? name,
    String? phone,
    String? avatarPath,
    String? email,
    String? birthday,
    String? bio,
    String? idNumber,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (avatarPath != null) body['avatar_path'] = avatarPath;
    if (email != null) body['email'] = email;
    if (birthday != null) body['birthday'] = birthday;
    if (bio != null) body['bio'] = bio;
    if (idNumber != null) body['id_number'] = idNumber;
    final res = await _client.patch('/api/users/$userId', body: body);
    final map = Map<String, dynamic>.from(res['user'] as Map);
    return UserModel.fromMap(map);
  }

  @override
  Future<bool> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    await _client.post(
      '/api/auth/change-password',
      body: {
        'user_id': userId,
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
    return true;
  }

  @override
  Future<bool> deleteAccount(String password) async {
    await _client.post(
      '/api/auth/delete-account',
      body: {'password': password},
    );
    return true;
  }
}
