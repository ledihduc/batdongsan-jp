import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/domain/repositories/i_auth_repository.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Vì sao có tệp này: `auth_provider.dart` là cổng vào TOÀN BỘ ứng dụng nhưng
/// trước đây không có một test nào — 665 test hiện có vẫn xanh kể cả khi luồng
/// đăng nhập vỡ. Bộ này khoá lại các hành vi quan trọng nhất.
///
/// Không chạm mạng: repository được tiêm bản giả.

class _FakeAuthRepo implements IAuthRepository {
  _FakeAuthRepo({this.ketQuaDangNhap, this.nem = false});

  /// null = sai thông tin đăng nhập.
  final AuthResult? ketQuaDangNhap;

  /// true = ném lỗi (mất mạng / server 500).
  final bool nem;

  /// Kết quả của `me()` khi khôi phục phiên.
  int soLanDangXuat = 0;

  @override
  Future<AuthResult?> login(
    String email,
    String password, {
    LoginAccountType? accountType,
  }) async {
    if (nem) throw Exception('mat ket noi');
    return ketQuaDangNhap;
  }

  @override
  Future<AuthResult?> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String role = 'guest',
  }) async {
    if (nem) throw Exception('mat ket noi');
    return ketQuaDangNhap;
  }

  @override
  Future<UserModel?> me() async {
    if (nem) throw Exception('token hong');
    return null;
  }

  @override
  Future<void> logout() async {
    soLanDangXuat++;
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
  }) async => null;

  @override
  Future<bool> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async => true;

  @override
  Future<bool> deleteAccount(String password) async => true;
}

UserModel _user({int id = 1, String role = 'guest'}) => UserModel(
  id: id,
  name: 'Nguoi Dung',
  email: 'a@example.com',
  passwordHash: '',
  phone: '',
  avatarPath: '',
  role: role,
  isActive: true,
);

void main() {
  group('đăng nhập', () {
    test('thành công → đã xác thực, giữ đúng user', () async {
      final p = AuthProvider(
        repository: _FakeAuthRepo(
          ketQuaDangNhap: AuthResult(user: _user(), token: 'tok'),
        ),
      );
      final ok = await p.login('a@example.com', 'MatKhau123');
      expect(ok, isTrue);
      expect(p.isAuthenticated, isTrue);
      expect(p.currentUser?.email, 'a@example.com');
      expect(p.isLoading, isFalse, reason: 'phải tắt loading dù thành công');
    });

    test('sai thông tin → KHÔNG xác thực và có thông báo lỗi', () async {
      final p = AuthProvider(repository: _FakeAuthRepo(ketQuaDangNhap: null));
      final ok = await p.login('a@example.com', 'sai');
      expect(ok, isFalse);
      expect(p.isAuthenticated, isFalse);
      expect(p.errorMessage, isNotNull);
      expect(p.isLoading, isFalse, reason: 'phải tắt loading dù thất bại');
    });

    test('lỗi mạng → không xác thực, không văng ngoại lệ ra UI', () async {
      final p = AuthProvider(repository: _FakeAuthRepo(nem: true));
      final ok = await p.login('a@example.com', 'MatKhau123');
      expect(ok, isFalse);
      expect(p.isAuthenticated, isFalse);
      expect(p.errorMessage, isNotNull);
    });

    test('đăng nhập lại sau khi lỗi thì xoá thông báo lỗi cũ', () async {
      final p = AuthProvider(
        repository: _FakeAuthRepo(
          ketQuaDangNhap: AuthResult(user: _user(), token: 'tok'),
        ),
      );
      await p.login('a@example.com', 'MatKhau123');
      expect(p.errorMessage, isNull);
    });
  });

  group('đăng xuất', () {
    test('xoá sạch người dùng hiện tại và gọi repository', () async {
      final repo = _FakeAuthRepo(
        ketQuaDangNhap: AuthResult(user: _user(), token: 'tok'),
      );
      final p = AuthProvider(repository: repo);
      await p.login('a@example.com', 'MatKhau123');
      expect(p.isAuthenticated, isTrue);

      await p.logout();
      expect(p.isAuthenticated, isFalse);
      expect(p.currentUser, isNull);
      expect(repo.soLanDangXuat, 1);
    });

    test(
      'đăng xuất rồi đăng nhập tài khoản KHÁC không giữ lại người cũ',
      () async {
        final p = AuthProvider(
          repository: _FakeAuthRepo(
            ketQuaDangNhap: AuthResult(user: _user(id: 1), token: 't1'),
          ),
        );
        await p.login('a@example.com', 'x');
        await p.logout();

        final p2 = AuthProvider(
          repository: _FakeAuthRepo(
            ketQuaDangNhap: AuthResult(
              user: _user(id: 2, role: 'host'),
              token: 't2',
            ),
          ),
        );
        await p2.login('b@example.com', 'y');
        expect(p2.currentUser?.id, 2);
        expect(p2.currentUser?.role, 'host');
      },
    );
  });

  group('khôi phục phiên (bootstrap)', () {
    test(
      'không có token → không xác thực, và PHẢI tắt cờ đang khởi động',
      () async {
        final p = AuthProvider(repository: _FakeAuthRepo());
        await p.bootstrap();
        expect(p.isAuthenticated, isFalse);
        expect(
          p.isBootstrapping,
          isFalse,
          reason: 'kẹt cờ này thì app đứng mãi ở màn chờ',
        );
      },
    );

    test('token hỏng/hết hạn → không xác thực và không văng lỗi', () async {
      final p = AuthProvider(repository: _FakeAuthRepo(nem: true));
      await p.bootstrap();
      expect(p.isAuthenticated, isFalse);
      expect(p.isBootstrapping, isFalse);
    });
  });

  group('đăng ký', () {
    test('thành công → đã xác thực', () async {
      final p = AuthProvider(
        repository: _FakeAuthRepo(
          ketQuaDangNhap: AuthResult(user: _user(), token: 'tok'),
        ),
      );
      final ok = await p.register(
        name: 'N',
        email: 'a@example.com',
        password: 'MatKhau123',
      );
      expect(ok, isTrue);
      expect(p.isAuthenticated, isTrue);
    });

    test('thất bại → không xác thực, có thông báo lỗi', () async {
      final p = AuthProvider(repository: _FakeAuthRepo(ketQuaDangNhap: null));
      final ok = await p.register(
        name: 'N',
        email: 'a@example.com',
        password: 'MatKhau123',
      );
      expect(ok, isFalse);
      expect(p.isAuthenticated, isFalse);
      expect(p.errorMessage, isNotNull);
    });
  });
}
