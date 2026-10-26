import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/pricing_rule_model.dart';
import 'package:house_booking/data/repositories/api_homestay_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Phase 07 — pricing rules state for a host's homestay rooms.
class PricingRuleProvider extends ChangeNotifier implements UserScoped {
  PricingRuleProvider({ApiHomestayRepository? repo})
      : _repo = repo ?? ApiHomestayRepository();

  final ApiHomestayRepository _repo;

  List<PricingRuleModel> _rules = [];
  bool _isLoading = false;
  String? _error;

  List<PricingRuleModel> get rules => List.unmodifiable(_rules);
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void resetUserScope() {
    _rules = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetch({int? roomId, int? houseId, String? ruleType}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _rules = await _repo.fetchPricingRules(
        roomId: roomId,
        houseId: houseId,
        ruleType: ruleType,
      );
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create({
    int? roomId,
    int? houseId,
    required String ruleType,
    required String startDate,
    required String endDate,
    required double pricePerNight,
    int? priority,
    int? weekdayMask,
    String? holidayName,
  }) async {
    try {
      final created = await _repo.createPricingRule(
        roomId: roomId,
        houseId: houseId,
        ruleType: ruleType,
        startDate: startDate,
        endDate: endDate,
        pricePerNight: pricePerNight,
        priority: priority,
        weekdayMask: weekdayMask,
        holidayName: holidayName,
      );
      _rules = [..._rules, created];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update({
    required int ruleId,
    String? startDate,
    String? endDate,
    double? pricePerNight,
    int? priority,
    int? weekdayMask,
    String? holidayName,
  }) async {
    try {
      final updated = await _repo.updatePricingRule(
        ruleId: ruleId,
        startDate: startDate,
        endDate: endDate,
        pricePerNight: pricePerNight,
        priority: priority,
        weekdayMask: weekdayMask,
        holidayName: holidayName,
      );
      final i = _rules.indexWhere((r) => r.id == ruleId);
      if (i >= 0) _rules[i] = updated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int ruleId) async {
    try {
      await _repo.deletePricingRule(ruleId);
      _rules.removeWhere((r) => r.id == ruleId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}
