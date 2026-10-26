import 'package:house_booking/data/models/dashboard_action_items_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/dashboard endpoints (Phase 06).
class ApiDashboardRepository {
  final ApiClient _client = const ApiClient();

  Future<DashboardActionItemsModel> fetchActionItems() async {
    final resp = await _client.get('/api/host/dashboard/action-items');
    return DashboardActionItemsModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Build a Zalo deep-link + templated reminder message for an unpaid invoice.
  /// Host then taps the returned `zalo_link` to open the Zalo chat.
  Future<ZaloReminderModel> buildInvoiceZaloReminder({
    required int invoiceId,
    String? phoneOverride,
  }) async {
    final resp = await _client.post(
      '/api/host/dashboard/invoices/$invoiceId/zalo-reminder',
      body: {if (phoneOverride != null) 'phone_override': phoneOverride},
    );
    return ZaloReminderModel.fromJson(Map<String, dynamic>.from(resp));
  }
}
