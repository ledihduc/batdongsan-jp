import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/khai_bao_model.dart';
import 'package:house_booking/data/repositories/api_khai_bao_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Provider for Phase 05 khai báo tạm trú state.
class KhaiBaoProvider extends ChangeNotifier implements UserScoped {
  KhaiBaoProvider({ApiKhaiBaoRepository? repo})
      : _repo = repo ?? ApiKhaiBaoRepository();

  final ApiKhaiBaoRepository _repo;

  List<KhaiBaoModel> _records = [];
  KhaiBaoDashboardSummary _summary = KhaiBaoDashboardSummary.empty;
  KhaiBaoModel? _selected;
  bool _isLoading = false;
  String? _error;

  List<KhaiBaoModel> get records => List.unmodifiable(_records);
  KhaiBaoDashboardSummary get summary => _summary;
  KhaiBaoModel? get selected => _selected;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get overdueCount => _summary.overdue;
  int get pendingCount => _summary.pending;
  bool get hasUrgent => overdueCount > 0;

  @override
  void resetUserScope() {
    _records = [];
    _summary = KhaiBaoDashboardSummary.empty;
    _selected = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchSummary() async {
    try {
      _summary = await _repo.fetchDashboardSummary();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  Future<void> fetchList({String? status, int? buildingId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await _repo.fetchList(status: status, buildingId: buildingId);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDetail(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      _selected = await _repo.getDetail(id);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markDeclared(int id) async {
    try {
      final updated = await _repo.markDeclared(id);
      _replace(updated);
      await fetchSummary();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> markSkipped(int id, String reason) async {
    try {
      final updated = await _repo.markSkipped(id, reason: reason);
      _replace(updated);
      await fetchSummary();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  void _replace(KhaiBaoModel updated) {
    final idx = _records.indexWhere((r) => r.id == updated.id);
    if (idx >= 0) _records[idx] = updated;
    if (_selected?.id == updated.id) _selected = updated;
    notifyListeners();
  }
}
