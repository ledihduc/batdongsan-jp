/// Mock implementation of [IJpViewingRepository].
///
/// In-memory store; resets on app restart. Useful for UI dev without BE.
library;

import 'package:house_booking/data/models/jp/jp_viewing.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_viewing_repository.dart';

class MockJpViewingRepository implements IJpViewingRepository {
  MockJpViewingRepository();

  final List<JpViewing> _store = [];
  int _nextId = 1001;

  @override
  Future<JpViewing> create({
    required int listingId,
    required List<JpViewingSlot> proposedSlots,
    String? message,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final v = JpViewing(
      id: _nextId++,
      listingId: listingId,
      tenantId: 1,
      proposedSlots: proposedSlots,
      status: JpViewingStatus.pending,
      message: message,
      createdAt: DateTime.now().toIso8601String(),
    );
    _store.add(v);
    return v;
  }

  @override
  Future<JpViewing> getById(int viewingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _store.firstWhere(
      (v) => v.id == viewingId,
      orElse: () => throw Exception('Viewing $viewingId not found'),
    );
  }

  @override
  Future<List<JpViewing>> listForTenant(int tenantId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _store.where((v) => v.tenantId == tenantId).toList();
  }

  @override
  Future<List<JpViewing>> listForAgent(int agentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<JpViewing>.from(_store);
  }

  @override
  Future<JpViewing> confirmSlot({
    required int viewingId,
    required JpViewingSlot slot,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final idx = _store.indexWhere((v) => v.id == viewingId);
    if (idx == -1) throw Exception('Viewing $viewingId not found');
    final updated = JpViewing(
      id: _store[idx].id,
      listingId: _store[idx].listingId,
      tenantId: _store[idx].tenantId,
      proposedSlots: _store[idx].proposedSlots,
      status: JpViewingStatus.confirmed,
      confirmedSlot: slot,
      agentId: _store[idx].agentId,
      agentName: _store[idx].agentName,
      tenantName: _store[idx].tenantName,
      listingTitle: _store[idx].listingTitle,
      message: _store[idx].message,
      createdAt: _store[idx].createdAt,
    );
    _store[idx] = updated;
    return updated;
  }

  @override
  Future<JpViewing> cancel(int viewingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final idx = _store.indexWhere((v) => v.id == viewingId);
    if (idx == -1) throw Exception('Viewing $viewingId not found');
    final updated = JpViewing(
      id: _store[idx].id,
      listingId: _store[idx].listingId,
      tenantId: _store[idx].tenantId,
      proposedSlots: _store[idx].proposedSlots,
      status: JpViewingStatus.cancelled,
      message: _store[idx].message,
      createdAt: _store[idx].createdAt,
    );
    _store[idx] = updated;
    return updated;
  }
}
