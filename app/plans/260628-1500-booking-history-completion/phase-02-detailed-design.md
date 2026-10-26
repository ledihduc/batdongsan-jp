# Phase 02 — Detailed Design (Code-level Spec)

## 1. Backend Changes

### 1.1 `helpers.viewing_appointment_to_dict`

Thêm 2 field vào dict response:

```python
def viewing_appointment_to_dict(db: Session, b: ViewingAppointment) -> dict:
    house = db.get(House, b.house_id)
    guest = db.get(User, b.guest_id)
    host = db.get(User, house.host_id) if house else None

    # has_reviewed: chỉ check khi guest đã hoàn thành viewing (completed)
    # tránh N+1 cho list pending/approved.
    has_reviewed = False
    if b.status == "completed" and house:
        has_reviewed = db.query(Review).filter(
            Review.user_id == b.guest_id,
            Review.house_id == b.house_id,
        ).first() is not None

    return {
        "id": b.id,
        "house_id": b.house_id,
        "host_id": house.host_id if house else None,   # ← MỚI
        "guest_id": b.guest_id,
        # ... (giữ nguyên các field cũ)
        "has_reviewed": has_reviewed,                   # ← MỚI
    }
```

### 1.2 Import `Review` model

Thêm `from app.models import Review` ở đầu `helpers.py` nếu chưa có (verify).

### 1.3 Không cần migration

Cả 2 field tính toán runtime; schema DB không đổi.

---

## 2. Flutter Model Changes

### 2.1 `ViewingAppointmentModel`

```dart
class ViewingAppointmentModel {
  // ... fields cũ
  final int? hostId;          // ← MỚI
  final bool hasReviewed;     // ← MỚI

  ViewingAppointmentModel({
    // ... params cũ
    this.hostId,
    this.hasReviewed = false,
  });

  factory ViewingAppointmentModel.fromMap(Map<String, dynamic> map) {
    return ViewingAppointmentModel(
      // ... fields cũ
      hostId: map['host_id'],
      hasReviewed: map['has_reviewed'] ?? false,
    );
  }
}
```

---

## 3. New `BookingDetailScreen`

Path: `lib/features/guest/booking/booking_detail_screen.dart` (mới)

```dart
class BookingDetailScreen extends StatelessWidget {
  final ViewingAppointmentModel appointment;
  const BookingDetailScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết lịch hẹn')),
      body: ListView(
        children: [
          _HeaderCard(appointment: appointment),
          const _SectionDivider(),
          _ScheduleSection(appointment: appointment),
          const _SectionDivider(),
          _MessageSection(message: appointment.message),
          if (_canShowHost) ...[
            const _SectionDivider(),
            _HostSection(appointment: appointment),
          ],
          const _SectionDivider(),
          _TimelineSection(status: appointment.status,
                           createdAt: appointment.createdAt),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: _StickyActionBar(appointment: appointment),
      ),
    );
  }

  bool get _canShowHost =>
      const ['approved', 'completed', 'locked'].contains(appointment.status);
}
```

### 3.1 Sub-widgets

| Widget | Responsibility |
|--------|----------------|
| `_HeaderCard` | Thumbnail 160h + title + address + status chip lớn |
| `_ScheduleSection` | Date (Vietnamese format) + time + createdAt |
| `_MessageSection` | Italic quote box hiển thị `appointment.message`; nếu empty → "Không có lời nhắn" |
| `_HostSection` | Avatar placeholder + name + phone (tap → tel:) + button "Nhắn tin" |
| `_TimelineSection` | Vertical step indicator dùng `Step` widget hoặc custom |
| `_StickyActionBar` | Status-dependent buttons (xem section 4) |

### 3.2 Action bar logic

```dart
Widget _buildBar(BuildContext ctx, ViewingAppointmentModel a) {
  switch (a.status) {
    case 'pending':
      return _DangerButton(label: 'Huỷ lịch hẹn', onPressed: _confirmCancel);
    case 'approved':
    case 'locked':
      return Row(children: [
        _OutlineButton(label: 'Gọi', icon: Icons.phone, onPressed: _callHost),
        _PrimaryButton(label: 'Nhắn tin', icon: Icons.chat, onPressed: _openChat),
      ]);
    case 'completed':
      return a.hasReviewed
          ? _DisabledChip(label: 'Đã đánh giá')
          : _PrimaryButton(label: 'Viết đánh giá', onPressed: _openReview);
    case 'rejected':
    case 'cancelled':
    case 'lost':
      return _OutlineButton(label: 'Xem nhà khác', onPressed: _openHouse);
    default:
      return const SizedBox.shrink();
  }
}
```

---

## 4. `BookingHistoryScreen` cải tổ

### 4.1 State additions

```dart
class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  String _activeTab = 'pending';
  String _completedSubFilter = 'all'; // all|completed|rejected|cancelled|lost
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refetchIfStale());
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  Future<void> _refetchIfStale() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    // Chỉ refetch nếu list rỗng HOẶC oldestStaleAt > 60s.
    // Tránh double-fetch khi AuthWrapper đã hydrate ban đầu.
    final p = context.read<ViewingAppointmentProvider>();
    if (p.appointments.isEmpty || p.isStale(maxAgeSeconds: 60)) {
      await p.fetchAppointments(user.id!, 'guest');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }
}
```

### 4.2 Filtering pipeline

```dart
List<ViewingAppointmentModel> get _filtered {
  final all = context.read<ViewingAppointmentProvider>().appointments;

  // 1. Status tab filter
  Iterable<ViewingAppointmentModel> result = all.where((a) {
    if (_activeTab == 'pending')  return a.status == 'pending';
    if (_activeTab == 'approved') return a.status == 'approved';
    return const ['completed','cancelled','rejected','locked','lost']
        .contains(a.status);
  });

  // 2. Sub-filter (chỉ ở tab completed)
  if (_activeTab == 'completed' && _completedSubFilter != 'all') {
    result = result.where((a) => a.status == _completedSubFilter);
  }

  // 3. Search filter
  if (_searchQuery.isNotEmpty) {
    result = result.where((a) {
      final t = (a.houseTitle ?? '').toLowerCase();
      final addr = (a.houseAddress ?? '').toLowerCase();
      return t.contains(_searchQuery) || addr.contains(_searchQuery);
    });
  }

  return result.toList();
}
```

### 4.3 Tab counts (no double-iterate)

```dart
({int pending, int approved, int completed}) _counts(List<ViewingAppointmentModel> all) {
  int p=0,a=0,c=0;
  for (final x in all) {
    if (x.status == 'pending') p++;
    else if (x.status == 'approved') a++;
    else c++; // completed/cancelled/rejected/locked/lost
  }
  return (pending: p, approved: a, completed: c);
}
```

### 4.4 Action button changes

Phần `_buildActionButtons` — đổi để:
- **pending:** giữ Huỷ + thêm tap-detail thay vì button "Chi tiết" (card whole-area tap).
- **approved:** thay nút "Liên hệ host" thành 2 nút icon-only: `Icons.phone` + `Icons.chat`.
- **completed:** check `appointment.hasReviewed` → ẩn nút hoặc đổi thành "Đã đánh giá".
- **rejected/cancelled/lost:** thêm button outline "Xem nhà khác".

### 4.5 Card tap detection

Bọc Card trong `InkWell`:

```dart
InkWell(
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => BookingDetailScreen(appointment: appointment))),
  child: Card(...),
)
```

Các nút action bên trong vẫn nhận tap riêng vì `ElevatedButton`/`IconButton` consume gesture trước InkWell parent.

---

## 5. `ViewingAppointmentProvider` additions

```dart
DateTime? _lastFetchAt;
bool isStale({int maxAgeSeconds = 60}) {
  if (_lastFetchAt == null) return true;
  return DateTime.now().difference(_lastFetchAt!).inSeconds > maxAgeSeconds;
}

Future<void> fetchAppointments(int userId, String role) async {
  // ... existing logic
  _lastFetchAt = DateTime.now();
  // ...
}
```

---

## 6. Date Formatting Helper

Tạo file mới `lib/core/utils/vn_date.dart`:

```dart
/// Format ISO "YYYY-MM-DD" → "Thứ X, DD/MM/YYYY"
String formatVnDate(String isoDate, {bool withWeekday = true}) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year;
  if (!withWeekday) return '$dd/$mm/$yyyy';
  const weekdays = ['', 'Thứ 2','Thứ 3','Thứ 4','Thứ 5','Thứ 6','Thứ 7','Chủ nhật'];
  return '${weekdays[d.weekday]}, $dd/$mm/$yyyy';
}

/// Format DateTime → "DD/MM/YYYY HH:mm"
String formatVnDateTime(DateTime dt) {
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${dt.year} $hh:$mi';
}
```

---

## 7. Tel-link Helper (no extra package)

Tránh thêm `url_launcher` cho 1 use case. Dùng `js_interop` trên web hoặc copy phone tới clipboard.

**Quyết định:** Phase 1 — copy-to-clipboard + SnackBar:

```dart
void _callHost(BuildContext ctx, String phone) async {
  await Clipboard.setData(ClipboardData(text: phone));
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text('Đã copy số $phone vào clipboard. Mở app gọi điện để gọi.'),
    behavior: SnackBarBehavior.floating,
  ));
}
```

Phase 2 (nếu cần native dialer): thêm `url_launcher` và switch.

---

## 8. Files modified / created

| File | Action | LOC delta (est.) |
|------|--------|------------------|
| `ancu365-backend/app/helpers.py` | Modify — add 2 fields | +6 |
| `lib/data/models/viewing_appointment_model.dart` | Modify — add hostId, hasReviewed | +6 |
| `lib/providers/viewing_appointment_provider.dart` | Modify — isStale + _lastFetchAt | +8 |
| `lib/features/guest/booking/booking_history_screen.dart` | Major rewrite | ~+120 net |
| `lib/features/guest/booking/booking_detail_screen.dart` | New | ~+350 |
| `lib/core/utils/vn_date.dart` | New | ~+25 |

Total est. ~515 LOC added.

---

## 9. Test Strategy

### 9.1 Unit tests
- `formatVnDate` — 5 cases (valid ISO, invalid, edge dates 01/01, 31/12, weekday rollover).
- `_filtered` getter — 8 cases (mỗi status × 2 search cases).
- `_counts` — empty / 1-of-each / all same.

### 9.2 Widget tests
- `BookingHistoryScreen`:
  - tab tap → re-render with filtered list
  - search debounce → 300ms applied
  - empty state when no appointments
  - empty state when search no match
  - card tap → push BookingDetailScreen
- `BookingDetailScreen`:
  - render pending → bottom CTA "Huỷ lịch hẹn"
  - render approved → 2 CTAs Gọi + Chat
  - render completed + reviewed → "Đã đánh giá" chip
  - render rejected → "Xem nhà khác"

### 9.3 Integration test
- Manual smoke test: login as guest → create appointment → view history → cancel → verify status moves to "Hoàn thành" tab → search by house title → verify filtered.

### 9.4 Backend
- Pytest cho `viewing_appointment_to_dict` mới: status='completed' + đã review → `has_reviewed=True`.
