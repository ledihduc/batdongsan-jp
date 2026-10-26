import 'dart:convert';

import 'package:house_booking/data/services/_session_storage_io.dart'
    if (dart.library.html) 'package:house_booking/data/services/_session_storage_web.dart'
    as storage;

enum CustomerDecision { notSuitable, considering, wantToRent }

extension CustomerDecisionLabel on CustomerDecision {
  String get label => switch (this) {
    CustomerDecision.notSuitable => 'Không phù hợp',
    CustomerDecision.considering => 'Đang cân nhắc',
    CustomerDecision.wantToRent => 'Muốn thuê',
  };

  String get value => switch (this) {
    CustomerDecision.notSuitable => 'not_suitable',
    CustomerDecision.considering => 'considering',
    CustomerDecision.wantToRent => 'want_to_rent',
  };

  static CustomerDecision? parse(String? value) => switch (value) {
    'not_suitable' => CustomerDecision.notSuitable,
    'considering' => CustomerDecision.considering,
    'want_to_rent' => CustomerDecision.wantToRent,
    _ => null,
  };
}

class CustomerJourneyEntry {
  const CustomerJourneyEntry({
    required this.decision,
    this.issues = const [],
    this.feedback = '',
    required this.updatedAt,
  });

  final CustomerDecision decision;
  final List<String> issues;
  final String feedback;
  final DateTime updatedAt;

  factory CustomerJourneyEntry.fromMap(Map<String, dynamic> map) =>
      CustomerJourneyEntry(
        decision:
            CustomerDecisionLabel.parse(map['decision'] as String?) ??
            CustomerDecision.considering,
        issues: List<String>.from(map['issues'] as List? ?? const []),
        feedback: map['feedback'] as String? ?? '',
        updatedAt:
            DateTime.tryParse(map['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'decision': decision.value,
    'issues': issues,
    'feedback': feedback,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Customer-only journey decisions; appointment data remains server-owned.
class CustomerJourneyStore {
  const CustomerJourneyStore();

  String _key(int userId) => 'customer_journey_v1_$userId';

  Future<Map<int, CustomerJourneyEntry>> read(int userId) async {
    try {
      final raw = await storage.readToken(_key(userId));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <int, CustomerJourneyEntry>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key);
        if (id == null) continue;
        result[id] = CustomerJourneyEntry.fromMap(
          (entry.value as Map).cast<String, dynamic>(),
        );
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> save(
    int userId,
    int appointmentId,
    CustomerJourneyEntry entry,
  ) async {
    final current = await read(userId);
    current[appointmentId] = entry;
    await storage.writeToken(
      _key(userId),
      jsonEncode({
        for (final item in current.entries)
          item.key.toString(): item.value.toMap(),
      }),
    );
  }

  /// Remove only a decision that has been accepted by the canonical server.
  /// Unsent drafts stay local so an interrupted migration never loses input.
  Future<void> remove(int userId, int appointmentId) async {
    final current = await read(userId);
    if (current.remove(appointmentId) == null) return;
    if (current.isEmpty) {
      await storage.deleteToken(_key(userId));
      return;
    }
    await storage.writeToken(
      _key(userId),
      jsonEncode({
        for (final item in current.entries)
          item.key.toString(): item.value.toMap(),
      }),
    );
  }
}
