import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/host_profile_model.dart';
import 'package:house_booking/data/repositories/api_host_profile_repository.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:house_booking/domain/repositories/i_host_profile_repository.dart';

/// State management for HostProfile onboarding and profile operations.
///
/// Usage:
///   final provider = context.read[HostProfileProvider]();
///   await provider.fetchProfile();
///   if (provider.profile == null) navigate to onboarding
class HostProfileProvider extends ChangeNotifier implements UserScoped {
  final IHostProfileRepository _repo = ApiHostProfileRepository();

  HostProfileModel? _profile;
  bool _isLoading = false;
  String? _error;

  HostProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True only when all onboarding steps are complete.
  bool get isOnboardingComplete => _profile?.isOnboardingComplete ?? false;

  Future<void> fetchProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repo.fetchProfile();
    } catch (e) {
      _error = _toMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    String? taxId,
    String? payoutSchedule,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repo.updateProfile(
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
        bankAccountHolder: bankAccountHolder,
        taxId: taxId,
        payoutSchedule: payoutSchedule,
      );
      return true;
    } catch (e) {
      _error = _toMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadCccd({
    XFile? front,
    XFile? back,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repo.uploadCccd(front: front, back: back);
      // Refresh profile to get updated upload flags
      _profile = await _repo.fetchProfile();
      return true;
    } catch (e) {
      _error = _toMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upgrade guest account to host.
  /// Saves the new JWT to session and refreshes provider state.
  /// Returns true on success.
  Future<bool> upgradeToHost() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newToken = await _repo.upgradeToHost();
      await SessionService.instance.setToken(newToken);
      // After token saved, fetch profile (created by backend during upgrade)
      _profile = await _repo.fetchProfile();
      return true;
    } catch (e) {
      _error = _toMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update the host's monthly revenue goal (AC-18).
  ///
  /// Pass null to clear the goal. Updates local model and notifies listeners.
  Future<bool> updateMonthlyGoal(double? goal) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repo.updateMonthlyGoal(goal);
      return true;
    } catch (e) {
      _error = _toMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateCover(String url) async {
    try {
      _profile = await _repo.updateCover(url);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _toMessage(e);
      notifyListeners();
      return false;
    }
  }

  @override
  void resetUserScope() {
    _profile = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  String _toMessage(Object e) {
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return 'Đã xảy ra lỗi';
  }
}
