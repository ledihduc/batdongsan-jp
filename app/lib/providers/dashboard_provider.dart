import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/dashboard_action_items_model.dart';
import 'package:house_booking/data/repositories/api_dashboard_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Provider for Phase 06 dashboard action items.
class DashboardProvider extends ChangeNotifier implements UserScoped {
  DashboardProvider({ApiDashboardRepository? repo})
      : _repo = repo ?? ApiDashboardRepository();

  final ApiDashboardRepository _repo;

  DashboardActionItemsModel _actionItems = DashboardActionItemsModel.empty;
  bool _isLoading = false;
  String? _error;

  DashboardActionItemsModel get actionItems => _actionItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalActionCount => _actionItems.summary.total;

  @override
  void resetUserScope() {
    _actionItems = DashboardActionItemsModel.empty;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchActionItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _actionItems = await _repo.fetchActionItems();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ZaloReminderModel?> buildInvoiceZaloReminder({
    required int invoiceId,
    String? phoneOverride,
  }) async {
    try {
      _error = null;
      return await _repo.buildInvoiceZaloReminder(
        invoiceId: invoiceId,
        phoneOverride: phoneOverride,
      );
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }
}
