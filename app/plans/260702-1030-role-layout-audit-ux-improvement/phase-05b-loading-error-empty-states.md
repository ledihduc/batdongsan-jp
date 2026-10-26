# Phase 05b — Loading / Error / Empty State Pattern Sweep

**Priority:** P1 | **Status:** pending | **Estimate:** 1.5 ngày | **Depends on:** Phase 05a

## Context

Split từ Phase 05 v1. Phase 05a xong design tokens + AppBar + DsSnackBar. Phase 05b audit 40+ file thiếu loading/error/empty state pattern và unify.

Từ researcher-05: 77 CircularProgressIndicator vs 50 Skeleton (không nhất quán), 40+ file thiếu error state.

**Correction from reference verification #27:** File tồn tại là `lib/core/widgets/empty_state.dart` (không phải `ds_empty_state.dart` như v1 note). Phase 05b sẽ rename hoặc alias.

## Requirements

**Functional:**
- Loading state: dùng `Skeleton` cho content, `CircularProgressIndicator` chỉ cho inline spinner
- Error state: dùng `DsErrorState` (mới) với retry action
- Empty state: dùng `DsEmptyState` (rename từ `empty_state.dart` → wrap trong `Ds*` naming để consistent)
- Standard 3-state pattern trong screens có data fetch

**Non-functional:**
- Không break visual — trước/sau phải giống nhau
- Không rewrite theme core

## Related files

**Đọc / rename / mở rộng:**
- `lib/core/widgets/empty_state.dart` → rename sang `ds_empty_state.dart` (hoặc keep tên cũ + add typedef `DsEmptyState = EmptyState`)
- `lib/core/widgets/skeleton.dart` — thêm `DsLoadingOverlay` cho blocking loads

**Tạo mới:**
- `lib/core/widgets/ds_error_state.dart` — error UI với retry

**Modify:**
- 40+ file thiếu error state — audit + add

## Implementation steps

1. **Rename / typedef empty_state** (30 phút):
   - Option A (safer): giữ `empty_state.dart`, add `typedef DsEmptyState = EmptyState;` để có tên consistent
   - Option B: rename file + update tất cả import
   - Recommend: A (ít risk)
2. **DsLoadingOverlay** (30 phút):
   - Thêm vào `skeleton.dart` (hoặc file mới) — full-screen semi-transparent overlay với CircularProgressIndicator
   - Dùng cho form submit, upload (blocking action)
3. **DsErrorState** (1 giờ):
   - `lib/core/widgets/ds_error_state.dart`:
     ```dart
     class DsErrorState extends StatelessWidget {
       final String message;
       final VoidCallback? onRetry;
       // icon + message + retry button
     }
     ```
4. **Loading state cleanup** (0.5 ngày):
   - Grep tất cả `CircularProgressIndicator` trong features
   - Cho content loads: replace bằng `Skeleton` hoặc `DsRowSkeleton`
   - Cho inline spinners (button loading, form submit): giữ nguyên
   - Add `DsLoadingOverlay` cho full-screen blocking (form submit, upload)
5. **Empty/error state pattern sweep** (0.5 ngày):
   - Standard 3-state trong screens có data fetch:
     ```dart
     if (loading && items.isEmpty) return const Skeleton();
     if (error != null && items.isEmpty) return DsErrorState(onRetry: refresh);
     if (items.isEmpty) return const DsEmptyState(icon:, title:, cta:);
     return content;
     ```
   - Audit 40+ file thiếu error state — add
6. **Verification:**
   - `flutter analyze` clean
   - Visual regression test: screenshot before/after 10 màn key
   - Run app, verify pull-to-refresh + error → retry flow

## Testing

**Manual:**
- Simulate offline network → verify all list screens show DsErrorState với retry
- Simulate empty API response → verify DsEmptyState
- Blocking form submit → DsLoadingOverlay visible

## TODO checklist

- [ ] `DsEmptyState` typedef hoặc rename
- [ ] `DsLoadingOverlay` cho blocking loads
- [ ] `DsErrorState` widget
- [ ] Migrate CircularProgressIndicator → Skeleton cho content loads (~40+ instances)
- [ ] Add error state cho 40+ file thiếu
- [ ] `flutter analyze` clean
- [ ] Visual spot check 10 màn (offline test, empty test)

## Success criteria

- Tất cả data-fetch screens có 3 state (loading/error/empty/content)
- Homestay module đạt ≥ 90% design compliance (từ 60%)
- Grep `CircularProgressIndicator` in `lib/features/` chỉ còn button/inline (< 20 instances)

## Risk

- **State transition edge cases** (loading + error đồng thời, empty + loading race) → định nghĩa rõ trong pattern doc
- **Existing custom empty state có UX riêng** → keep tùy chỉnh nếu justified, wrap thành variant của DsEmptyState

## Out of scope

- Không rebuild design tokens (đã xong Phase 05a)
- Không đổi navigation
- Không animation/transition mới
