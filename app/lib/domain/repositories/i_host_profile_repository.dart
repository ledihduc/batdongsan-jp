import 'package:image_picker/image_picker.dart' show XFile;
import 'package:house_booking/data/models/host_profile_model.dart';

/// Domain interface for HostProfile API operations.
abstract class IHostProfileRepository {
  /// Fetch the authenticated host's profile. Returns null if not created yet.
  Future<HostProfileModel?> fetchProfile();

  /// Update bank/tax fields. Returns updated profile.
  Future<HostProfileModel> updateProfile({
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    String? taxId,
    String? payoutSchedule,
  });

  /// Upload CCCD front and/or back images.
  /// Uses XFile so the implementation can read bytes uniformly on web and native.
  Future<void> uploadCccd({
    XFile? front,
    XFile? back,
  });

  /// Upgrade guest account to host. Returns new JWT token.
  Future<String> upgradeToHost();

  /// Update the monthly revenue goal (AC-18).
  ///
  /// Pass null to clear the goal. Uses PATCH /api/host/profile with
  /// `{"monthly_revenue_goal": double|null}`.
  Future<HostProfileModel> updateMonthlyGoal(double? goal);

  /// Cập nhật ảnh bìa storefront chủ nhà (PATCH cover_path).
  Future<HostProfileModel> updateCover(String? coverPath);
}
