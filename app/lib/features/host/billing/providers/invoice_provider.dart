import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/credit_note_model.dart';
import 'package:house_booking/data/models/invoice_model.dart';
import 'package:house_booking/data/repositories/api_invoice_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// InvoiceProvider — manages invoices list, detail, batch generation, payments,
/// debt-aging summary and "needs-reminder" widget for the host dashboard.
class InvoiceProvider extends ChangeNotifier implements UserScoped {
  final ApiInvoiceRepository _repo = ApiInvoiceRepository();

  List<InvoiceModel> _invoices = [];
  InvoiceModel? _selected;
  DebtAgingReport? _debtAging;
  List<NeedsReminderItem> _needsReminder = [];
  bool _isLoading = false;
  String? _error;

  List<InvoiceModel> get invoices => List.unmodifiable(_invoices);
  InvoiceModel? get selected => _selected;
  DebtAgingReport? get debtAging => _debtAging;
  List<NeedsReminderItem> get needsReminder =>
      List.unmodifiable(_needsReminder);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get reminderCount => _needsReminder.length;
  double get totalUnpaid => _debtAging?.totalUnpaid ?? 0;

  @override
  void resetUserScope() {
    _invoices = [];
    _selected = null;
    _debtAging = null;
    _needsReminder = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchInvoices({
    String? status,
    int? contractId,
    String? month,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _invoices = await _repo.fetchInvoices(
        status: status,
        contractId: contractId,
        month: month,
      );
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Không thể tải hoá đơn';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InvoiceModel?> fetchInvoice(int invoiceId) async {
    try {
      _selected = await _repo.getInvoice(invoiceId);
      notifyListeners();
      return _selected;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<List<InvoiceModel>?> generateBatch({
    required int buildingId,
    required String month,
    double? electricityUnitPrice,
    double? waterUnitPrice,
  }) async {
    try {
      final created = await _repo.generateBatch(
        buildingId: buildingId,
        month: month,
        electricityUnitPrice: electricityUnitPrice,
        waterUnitPrice: waterUnitPrice,
      );
      _invoices = [...created, ..._invoices];
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<InvoiceModel?> sendInvoice(int invoiceId) async {
    try {
      final updated = await _repo.sendInvoice(invoiceId);
      _replaceInList(updated);
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<InvoiceModel?> recordPayment(
    int invoiceId, {
    required double amount,
    String method = 'cash',
    String? paidAt,
    String? note,
  }) async {
    try {
      final updated = await _repo.recordPayment(
        invoiceId,
        amount: amount,
        method: method,
        paidAt: paidAt,
        note: note,
      );
      _replaceInList(updated);
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<CreditNoteModel?> issueCreditNote(
    int invoiceId, {
    required double amount,
    String reason = '',
    required String issuedDate,
  }) async {
    try {
      return await _repo.issueCreditNote(
        invoiceId,
        amount: amount,
        reason: reason,
        issuedDate: issuedDate,
      );
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Loads the debt aging report (cached on the provider for dashboard widget).
  Future<void> fetchDebtAging() async {
    try {
      _debtAging = await _repo.fetchDebtAging();
      notifyListeners();
    } catch (_) {
      // Silent fail — dashboard widget hides on error.
    }
  }

  Future<void> fetchNeedsReminder() async {
    try {
      _needsReminder = await _repo.fetchNeedsReminder();
      notifyListeners();
    } catch (_) {
      // Silent fail — dashboard widget hides on error.
    }
  }

  Future<String?> fetchZaloLink(int invoiceId) async {
    try {
      return await _repo.fetchZaloLink(invoiceId);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  void _replaceInList(InvoiceModel updated) {
    _invoices = _invoices
        .map((inv) => inv.id == updated.id ? updated : inv)
        .toList();
    if (_selected?.id == updated.id) _selected = updated;
    notifyListeners();
  }
}
