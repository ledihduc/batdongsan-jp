/// Một khung giờ xem nhà cho 1 ngày cụ thể.
class AvailableSlot {
  const AvailableSlot({required this.time, required this.isTaken});

  /// 'HH:MM-HH:MM' (không khoảng trắng), ví dụ '09:00-10:00'.
  final String time;

  /// True khi khung đã có người đặt (pending/approved/locked) → không chọn được.
  final bool isTaken;

  factory AvailableSlot.fromMap(Map<String, dynamic> m) => AvailableSlot(
    time: (m['time'] ?? '').toString(),
    isTaken: (m['status'] ?? 'open').toString() == 'taken',
  );

  /// Hiển thị đẹp: '09:00-10:00' → '09:00 - 10:00'.
  String get label => time.replaceAll('-', ' - ');
}

/// Cấu hình khung giờ chủ nhà mở nhận đặt xem (host availability).
class HostAvailability {
  const HostAvailability({
    required this.weekdays,
    required this.slots,
    required this.allSlots,
    required this.isDefault,
  });

  /// Các thứ trong tuần nhận khách. 0 = Thứ Hai ... 6 = Chủ Nhật.
  final List<int> weekdays;

  /// Các khung giờ nhận khách ('HH:MM-HH:MM').
  final List<String> slots;

  /// Toàn bộ khung giờ chuẩn khả dụng để bật/tắt (do backend cung cấp).
  final List<String> allSlots;

  /// True khi chủ nhà chưa cấu hình (đang dùng mặc định mở tất cả).
  final bool isDefault;

  factory HostAvailability.fromMap(Map<String, dynamic> m) {
    final config = (m['config'] as Map?) ?? const {};
    return HostAvailability(
      weekdays: List<int>.from(
        (config['weekdays'] as List? ?? const []).map(
          (e) => (e as num).toInt(),
        ),
      ),
      slots: List<String>.from(
        (config['slots'] as List? ?? const []).map((e) => e.toString()),
      ),
      allSlots: List<String>.from(
        (m['all_slots'] as List? ?? const []).map((e) => e.toString()),
      ),
      isDefault: (m['is_default'] as bool?) ?? false,
    );
  }

  HostAvailability copyWith({List<int>? weekdays, List<String>? slots}) =>
      HostAvailability(
        weekdays: weekdays ?? this.weekdays,
        slots: slots ?? this.slots,
        allSlots: allSlots,
        isDefault: isDefault,
      );
}
