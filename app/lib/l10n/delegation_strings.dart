/// Delegation feature string dictionary — Vietnamese (primary) + English fallbacks.
///
/// Follows existing codebase pattern of hardcoded Vietnamese strings in UI.
/// All strings in this file are centralized for future .arb extraction.
/// See researcher-03 §H for i18n setup context.
library;

/// Vietnamese strings used across the delegation feature.
///
/// Usage: DelegationStrings.actingAsBanner(ownerName: 'Anh A')
abstract class DelegationStrings {
  // ── Acting-as banner ──────────────────────────────────────────────────────
  static String actingAsBanner(String ownerName) =>
      'Bạn đang thao tác thay cho $ownerName';
  static const exitActingAs = 'Thoát';

  // ── Operator portfolio ────────────────────────────────────────────────────
  static const portfolioTitle = 'Danh mục của tôi';
  static const portfolioEyebrow = 'OPERATOR · PORTFOLIO';
  static const portfolioEmptyTitle = 'Chưa có bất động sản nào';
  static const portfolioEmptySubtitle =
      'Khi chủ nhà ủy thác cho bạn, tài sản sẽ xuất hiện ở đây.';
  static const pendingApprovalBadge = 'chờ duyệt';

  // ── Invitation inbox ──────────────────────────────────────────────────────
  static const invitationInboxTitle = 'Lời mời ủy thác';
  static const invitationEmptyTitle = 'Không có lời mời nào';
  static const invitationEmptySubtitle =
      'Khi chủ nhà mời bạn, lời mời sẽ xuất hiện ở đây.';
  static const acceptInvitation = 'Chấp nhận';
  static const rejectInvitation = 'Từ chối';

  // ── Delegation invite (owner side) ────────────────────────────────────────
  static const inviteOperatorTitle = 'Mời Operator';
  static const inviteOperatorEyebrow = 'CHỦ NHÀ · ỦY THÁC';
  static const inviteOperatorEmailLabel = 'Email Operator';
  static const inviteOperatorEmailHint = 'operator@email.com';
  static const inviteOperatorPermissionTitle = 'Quyền hạn';
  static const inviteOperatorThresholdTitle = 'Ngưỡng phê duyệt (VND)';
  static const inviteOperatorSendButton = 'Gửi lời mời';
  static const inviteOperatorSuccessMessage = 'Đã gửi lời mời thành công';

  // ── Role presets ──────────────────────────────────────────────────────────
  static const roleOperatorFull = 'Vận hành đầy đủ';
  static const roleAccountant = 'Kế toán';
  static const roleViewer = 'Chỉ xem';
  static const roleOwnerView = 'Chủ nhà (xem)';

  // ── Delegation detail ─────────────────────────────────────────────────────
  static const delegationDetailEyebrow = 'CHỦ NHÀ · QUẢN LÝ ỦY THÁC';
  static const statusActive = 'Đang hoạt động';
  static const statusPaused = 'Tạm dừng';
  static const statusTerminated = 'Đã chấm dứt';
  static const pauseDelegation = 'Tạm dừng';
  static const resumeDelegation = 'Tiếp tục';
  static const terminateDelegation = 'Chấm dứt';
  static const terminateConfirmTitle = 'Chấm dứt ủy thác?';
  static const terminateConfirmBody =
      'Operator sẽ mất quyền truy cập sau 30 ngày. Hành động này không thể hoàn tác.';
  static const thresholdSectionTitle = 'Ngưỡng phê duyệt';
  static const thresholdEditButton = 'Chỉnh sửa';
  static const thresholdSaveButton = 'Lưu ngưỡng';
  static const thresholdCancelButton = 'Hủy';

  // ── Approval inbox ────────────────────────────────────────────────────────
  static const approvalInboxTitle = 'Hộp phê duyệt';
  static const approvalInboxEyebrow = 'CHỦ NHÀ · PHÊ DUYỆT';
  static const approvalEmptyTitle = 'Không có yêu cầu nào';
  static const approvalEmptySubtitle =
      'Khi Operator cần phê duyệt, yêu cầu sẽ xuất hiện ở đây.';
  static const approveButton = 'Phê duyệt';
  static const rejectButton = 'Từ chối';
  static const biometricReason = 'Xác thực sinh trắc học để phê duyệt';
  static const rejectionReasonHint = 'Lý do (không bắt buộc)';

  // ── Activity feed ─────────────────────────────────────────────────────────
  static const activityFeedTitle = 'Nhật ký hoạt động';
  static const filterToday = 'Hôm nay';
  static const filterWeek = 'Tuần này';
  static const filterMonth = 'Tháng này';
  static const feedEmptyTitle = 'Chưa có hoạt động nào';
  static const feedEmptySubtitle =
      'Các hành động của Operator sẽ xuất hiện ở đây.';

  // ── Tenant authority badge ────────────────────────────────────────────────
  static String authorityBadgeLabel(String operator, String owner) =>
      'Đại diện: $operator | Chủ: $owner';
  static const authorityDetailTitle = 'Thông tin đại diện';
  static const operatorLabel = 'Đại lý vận hành';
  static const ownerLabel = 'Chủ sở hữu';
  static const reportUnauthorized =
      'Báo cáo không phải đại diện của tôi';
  static const kycVerified = 'Đã xác minh';
  static const kycPending = 'Chờ xác minh';

  // ── Report unauthorized ───────────────────────────────────────────────────
  static const reportTitle = 'Báo cáo đại diện';
  static const reportSubmitSuccess = 'Báo cáo đã được ghi nhận';
  static const reportSubmitSuccessSubtitle =
      'Chúng tôi sẽ xem xét và liên hệ với bạn trong vòng 24 giờ.';

  // ── Sole ownership attestation (AC-64) ────────────────────────────────────
  static const attestationTitle = 'Xác nhận chủ sở hữu';
  static const attestationQuestion =
      'Tài sản này có đăng ký dưới tên duy nhất của bạn (sổ đỏ chính chủ)?';
  static const attestationV1Limit =
      'Phiên bản v1 chỉ hỗ trợ tài sản chính chủ (một chủ sở hữu). '
      'Tính năng đồng sở hữu sẽ ra mắt trong v2 Q4 2026.';
  static const attestationTosCheckbox =
      'Tôi xác nhận tài sản thuộc quyền sở hữu duy nhất của tôi '
      'và đồng ý với điều khoản miễn trừ trách nhiệm.';
  static const attestationConfirm = 'Có — xác nhận';
  static const attestationCancel = 'Không — hủy';

  // ── Shared login disclosure (AC-66) ───────────────────────────────────────
  static const sharedLoginTitle = 'Thông báo tài khoản chung';
  static const sharedLoginIntro =
      'Bạn đang sử dụng tài khoản doanh nghiệp chung. Vui lòng lưu ý:';
  static const sharedLoginPoint1 =
      'Mọi hành động được ghi lại trong nhật ký kiểm toán dưới danh tính tài khoản chung.';
  static const sharedLoginPoint2 =
      'Việc thay đổi mật khẩu là trách nhiệm của công ty bạn. '
      'Hệ thống sẽ không cảnh báo khi có đăng nhập bất thường.';
  static const sharedLoginPoint3 =
      'Phân quyền cá nhân trong doanh nghiệp (RBAC v2) sẽ ra mắt trong phiên bản tới.';
  static const sharedLoginAck = 'Tôi hiểu';

  // ── Error messages ────────────────────────────────────────────────────────
  static const delegationRevoked =
      'Ủy thác đã bị thu hồi. Bạn đã được chuyển về danh mục.';
  static const biometricRequired =
      'Cần xác thực sinh trắc học để tiếp tục';
  static const loadError = 'Không tải được dữ liệu';
  static const retryButton = 'Thử lại';
}
