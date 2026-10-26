import 'package:house_booking/data/database/database_helper.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/domain/repositories/i_auth_repository.dart';

class LocalAuthRepository implements IAuthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  UserModel? _currentUser;

  @override
  Future<AuthResult?> login(
    String email,
    String password, {
    LoginAccountType? accountType,
  }) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ? AND password_hash = ? AND is_active = 1',
      whereArgs: [email, password],
    );

    if (maps.isNotEmpty) {
      final user = UserModel.fromMap(maps.first);
      if (accountType != null && !user.canLoginAs(accountType)) {
        throw const LoginAccountTypeMismatch();
      }
      _currentUser = user;
      return AuthResult(user: user, token: 'local-${user.id}');
    }
    return null;
  }

  @override
  Future<AuthResult?> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String role = 'guest',
  }) async {
    try {
      final db = await _dbHelper.database;
      final id = await db.insert('users', {
        'name': name,
        'email': email,
        'password_hash': password,
        'phone': phone,
        'avatar_path': '',
        'role': role,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return null;
      final user = UserModel.fromMap(rows.first);
      _currentUser = user;
      return AuthResult(user: user, token: 'local-${user.id}');
    } catch (e) {
      return null;
    }
  }

  @override
  Future<UserModel?> me() async => _currentUser;

  @override
  Future<void> logout() async {
    _currentUser = null;
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
    final db = await _dbHelper.database;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (avatarPath != null) updates['avatar_path'] = avatarPath;
    if (email != null) updates['email'] = email;
    if (birthday != null) updates['birthday'] = birthday;
    if (bio != null) updates['bio'] = bio;
    if (idNumber != null) updates['id_number'] = idNumber;
    if (updates.isNotEmpty) {
      await db.update('users', updates, where: 'id = ?', whereArgs: [userId]);
    }
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isNotEmpty) {
      _currentUser = UserModel.fromMap(rows.first);
    }
    return _currentUser;
  }

  @override
  Future<bool> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'users',
      where: 'id = ? AND password_hash = ?',
      whereArgs: [userId, oldPassword],
    );
    if (rows.isEmpty) return false;
    await db.update(
      'users',
      {'password_hash': newPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return true;
  }

  @override
  Future<bool> deleteAccount(String password) async {
    final db = await _dbHelper.database;
    await db.delete('users', where: 'password_hash = ?', whereArgs: [password]);
    return true;
  }
}
