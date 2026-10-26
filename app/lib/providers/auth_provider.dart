import 'package:flutter/material.dart';
import 'package:house_booking/core/permissions/permission_service.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/data/repositories/api_auth_repository.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:house_booking/data/services/preferences_service.dart';
import 'package:house_booking/data/services/user_prefs_service.dart';
import 'package:house_booking/domain/repositories/i_auth_repository.dart';

class AuthProvider with ChangeNotifier {
  /// [repository] chỉ để TEST tiêm bản giả. Mặc định vẫn là bản gọi API thật
  /// nên mọi nơi đang dùng `AuthProvider()` không phải sửa gì.
  /// Trước đây repository bị khởi tạo cứng ở đây, nên không cách nào kiểm tra
  /// luồng đăng nhập/đăng xuất mà không gọi mạng thật — đó là lý do vùng auth
  /// có 0 test dù là cổng vào cả ứng dụng.
  AuthProvider({IAuthRepository? repository})
    : _authRepository = repository ?? ApiAuthRepository();

  final IAuthRepository _authRepository;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isBootstrapping = true;
  String? _errorMessage;
  LoginAccountType? _loginAccountType;
  bool _accountTypeMismatch = false;

  /// Tracks the role from the previous authenticated state.
  /// Used to detect role upgrades (guest→host→admin) per AC-N8.
  String? _previousRoleSnapshot;

  /// Injected after construction (avoids changing constructor signature).
  /// Set once from main.dart after both AuthProvider and PermissionService are built.
  PermissionService? _permissionService;

  /// Hook invoked at the start of [logout] and after auto-upgrade role changes.
  /// Set from main.dart so it can call [UserScopeCleanup.resetAll] with a
  /// live BuildContext — AuthProvider itself has no context access.
  VoidCallback? _userScopeCleanup;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  LoginAccountType? get loginAccountType => _loginAccountType;
  bool get accountTypeMismatch => _accountTypeMismatch;
  String get loginLocation =>
      _loginAccountType?.homeLocation ??
      (_currentUser?.role == 'admin' ? '/admin' : '/');

  /// Injects [PermissionService] post-construction.
  /// Called once from MyApp._MyAppState.initState via the locator.
  void setPermissionService(PermissionService service) {
    _permissionService = service;
  }

  /// Injects the user-scope cleanup callback. Called from a widget that has
  /// access to the provider tree (see main.dart _CleanupHookWiring).
  void setUserScopeCleanup(VoidCallback? fn) {
    _userScopeCleanup = fn;
  }

  /// Gọi 1 lần lúc app khởi động. Nếu có token còn hiệu lực → restore user.
  Future<void> bootstrap() async {
    try {
      final token = await SessionService.instance.getToken();
      if (token == null || token.isEmpty) return;
      final user = await _authRepository.me();
      if (user != null) {
        final saved = LoginAccountType.fromValue(
          await UserPrefsService.instance.getLastMode(),
        );
        _loginAccountType = saved != null && user.canLoginAs(saved)
            ? saved
            : null;
        if (saved != null && _loginAccountType == null) {
          await UserPrefsService.instance.clearLastMode();
        }
        _detectAndHandleRoleChange(user);
        _currentUser = user;
      }
    } catch (_) {
      // Token hỏng → silent fail, user về login.
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  /// Refreshes the in-memory user after a role-changing action such as claim.
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    try {
      final user = await _authRepository.me();
      if (user != null) {
        final selected = _loginAccountType;
        if (selected != null && !user.canLoginAs(selected)) {
          _loginAccountType = LoginAccountType.customer;
          await UserPrefsService.instance.setLastMode('customer');
        }
        _detectAndHandleRoleChange(user);
        _currentUser = user;
        notifyListeners();
      }
    } catch (_) {
      // The current session remains usable if the refresh is temporarily offline.
    }
  }

  /// Keep Activity switching and the next authenticated redirect in sync.
  Future<bool> selectLoginAccountType(LoginAccountType type) async {
    if (!(currentUser?.canLoginAs(type) ?? false)) return false;
    await UserPrefsService.instance.setLastMode(type.name);
    _loginAccountType = type;
    notifyListeners();
    return true;
  }

  Future<bool> login(
    String email,
    String password, {
    LoginAccountType? accountType,
  }) async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    _accountTypeMismatch = false;
    notifyListeners();

    try {
      final result = await _authRepository.login(
        email,
        password,
        accountType: accountType,
      );
      if (result != null) {
        if (accountType != null && !result.user.canLoginAs(accountType)) {
          await _authRepository.logout();
          throw const LoginAccountTypeMismatch();
        }
        // Store the context BEFORE auth listeners can redirect to the shell.
        if (accountType != null) {
          await UserPrefsService.instance.setLastMode(accountType.name);
        } else {
          await UserPrefsService.instance.clearLastMode();
        }
        _loginAccountType = accountType;
        // Tài khoản mới → hỏi lại xem có phải đơn vị không (quyết định tab nào
        // đứng đầu). Không reset thì giữ nguyên kết quả của tài khoản trước.
        _detectAndHandleRoleChange(result.user);
        _currentUser = result.user;
        return true;
      }
      _errorMessage = 'Email/SĐT hoặc mật khẩu không chính xác';
      return false;
    } catch (e) {
      _accountTypeMismatch = e is LoginAccountTypeMismatch;
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String role = 'guest',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authRepository.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        role: role,
      );
      if (result != null) {
        await UserPrefsService.instance.setLastMode('customer');
        _loginAccountType = LoginAccountType.customer;
        _currentUser = result.user;
        return true;
      }
      _errorMessage = 'Đăng ký thất bại';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // Danh tính "là đơn vị thi công" được nhớ theo phiên — không xoá thì tài
    // khoản đăng nhập sau sẽ thừa hưởng và bị mở nhầm vào tab Thi công.
    // Notify PermissionService BEFORE clearing currentUser (AC-T1: delete FCM token).
    final userId = _currentUser?.id?.toString();
    if (userId != null && _permissionService != null) {
      try {
        await _permissionService!.onLogout(userId);
      } catch (_) {
        // Non-fatal — FCM token deletion is best-effort.
      }
    }

    // Phase 02 v3: clear all user-scoped provider caches BEFORE nulling the
    // user, so listeners that read currentUser during reset see the correct
    // outgoing identity if they need it.
    try {
      _userScopeCleanup?.call();
    } catch (_) {
      // Non-fatal — session end still proceeds even if cleanup throws.
    }

    await _authRepository.logout();
    // Clear persona mode so user B on shared device doesn't inherit user A's
    // last_active_mode (host) and accidentally land in Host shell.
    await UserPrefsService.instance.clearLastMode();
    // Xoá prefs local (sở thích/thế giới) để tài khoản/khách kế tiếp trên trình
    // duyệt DÙNG CHUNG không thừa hưởng và không bị mergeOnLogin trộn nhầm.
    await PreferencesService.instance.clearLocal();
    _previousRoleSnapshot = null;
    _loginAccountType = null;
    _accountTypeMismatch = false;
    _currentUser = null;
    notifyListeners();
  }

  /// Người dùng tự XOÁ tài khoản. Backend ẩn danh hoá PII + vô hiệu hoá tài
  /// khoản (yêu cầu xác nhận mật khẩu). Thành công thì dọn sạch phiên như logout.
  Future<bool> deleteAccount(String password) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.deleteAccount(password);
      await logout();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Role-upgrade detection ──────────────────────────────────────────────────

  /// Compares the incoming user's role with [_previousRoleSnapshot].
  /// If changed, notifies [PermissionService.onRoleUpgrade] (AC-N8).
  ///
  /// Called synchronously inside [login] and [bootstrap] success blocks BEFORE
  /// assigning [_currentUser], so the comparison is always previous vs new.
  void _detectAndHandleRoleChange(UserModel newUser) {
    final newRole = newUser.role; // String: 'guest' | 'host' | 'admin'
    final userId = newUser.id?.toString();

    if (userId == null) return;

    if (_previousRoleSnapshot != null &&
        _previousRoleSnapshot != newRole &&
        _permissionService != null) {
      final roleEnum = _parseUserRole(newRole);
      if (roleEnum != null) {
        // Fire-and-forget: role upgrade recording is non-blocking.
        _permissionService!.onRoleUpgrade(userId, roleEnum).catchError((_) {});
      }
    }

    _previousRoleSnapshot = newRole;
  }

  /// Maps a role string from the API to [UserRole] enum.
  static UserRole? _parseUserRole(String? role) {
    switch (role) {
      case 'guest':
        return UserRole.guest;
      case 'host':
        return UserRole.host;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? avatarPath,
    String? email,
    String? birthday,
    String? bio,
    String? idNumber,
  }) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await _authRepository.updateProfile(
        _currentUser!.id!,
        name: name,
        phone: phone,
        avatarPath: avatarPath,
        email: email,
        birthday: birthday,
        bio: bio,
        idNumber: idNumber,
      );
      if (updated != null) {
        _currentUser = updated.loginAccountTypes == null
            ? updated.copyWith(
                loginAccountTypes: _currentUser!.loginAccountTypes,
              )
            : updated;
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _authRepository.changePassword(
        _currentUser!.id!,
        oldPassword,
        newPassword,
      );
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
