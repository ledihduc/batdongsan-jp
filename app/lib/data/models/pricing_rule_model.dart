/// Phase 07 — Homestay nightly pricing rule.
///
/// Mirror backend `app/schemas/pricing_rule.py`.
/// rule_type ∈ {base, weekend, holiday, manual}.
library;

class PricingRuleModel {
  final int id;
  final int hostId;
  final int? roomId;
  final int? houseId;
  final String ruleType; // base | weekend | holiday | manual
  final String startDate; // ISO YYYY-MM-DD
  final String endDate;
  final double pricePerNight;
  final int priority;
  final int? weekdayMask;
  final String? holidayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PricingRuleModel({
    required this.id,
    required this.hostId,
    required this.roomId,
    required this.houseId,
    required this.ruleType,
    required this.startDate,
    required this.endDate,
    required this.pricePerNight,
    required this.priority,
    required this.weekdayMask,
    required this.holidayName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isBase => ruleType == 'base';
  bool get isWeekend => ruleType == 'weekend';
  bool get isHoliday => ruleType == 'holiday';
  bool get isManual => ruleType == 'manual';

  factory PricingRuleModel.fromJson(Map<String, dynamic> json) =>
      PricingRuleModel(
        id: json['id'] as int,
        hostId: json['host_id'] as int,
        roomId: json['room_id'] as int?,
        houseId: json['house_id'] as int?,
        ruleType: json['rule_type'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String,
        pricePerNight: (json['price_per_night'] as num).toDouble(),
        priority: json['priority'] as int,
        weekdayMask: json['weekday_mask'] as int?,
        holidayName: json['holiday_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Decoded weekday bits — Mon=0..Sun=6. Empty for non-weekend rules.
  List<int> get activeWeekdays {
    final mask = weekdayMask;
    if (mask == null) return const [];
    return List<int>.generate(
      7,
      (i) => i,
    ).where((i) => (mask >> i) & 1 == 1).toList();
  }
}
