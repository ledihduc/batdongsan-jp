import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';

// ---------------------------------------------------------------------------
// FilterState — immutable, copy-with semantics.
// ---------------------------------------------------------------------------

/// Immutable filter state for drill-down navigation.
///
/// Session-only: in-memory; cleared on app restart per AC-09 KISS.
class FilterState {
  final List<int> buildingIds;
  final List<int> sourceIds;
  final DateTimeRange? dateRange;
  final String? roomType;

  const FilterState({
    this.buildingIds = const [],
    this.sourceIds = const [],
    this.dateRange,
    this.roomType,
  });

  /// Returns an empty (default) FilterState.
  const FilterState.empty()
      : buildingIds = const [],
        sourceIds = const [],
        dateRange = null,
        roomType = null;

  /// True when no filters are active.
  bool get isEmpty =>
      buildingIds.isEmpty &&
      sourceIds.isEmpty &&
      dateRange == null &&
      (roomType == null || roomType!.isEmpty);

  FilterState copyWith({
    List<int>? buildingIds,
    List<int>? sourceIds,
    DateTimeRange? dateRange,
    String? roomType,
    // Pass explicit null sentinels to clear nullable fields.
    bool clearDateRange = false,
    bool clearRoomType = false,
  }) {
    return FilterState(
      buildingIds: buildingIds ?? this.buildingIds,
      sourceIds: sourceIds ?? this.sourceIds,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      roomType: clearRoomType ? null : (roomType ?? this.roomType),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilterState &&
          _listEq(buildingIds, other.buildingIds) &&
          _listEq(sourceIds, other.sourceIds) &&
          dateRange == other.dateRange &&
          roomType == other.roomType);

  @override
  int get hashCode =>
      Object.hash(buildingIds, sourceIds, dateRange, roomType);

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// BreadcrumbItem — one segment in the breadcrumb trail.
// ---------------------------------------------------------------------------

/// A single breadcrumb segment.
///
/// [level] 0 = summary home, 1 = rooms, 2 = contracts, 3 = tenants, 4 = invoices.
/// [params] are the query/path params needed to rebuild the route for this level.
class BreadcrumbItem {
  final int level;
  final String title;
  final Map<String, dynamic> params;

  const BreadcrumbItem({
    required this.level,
    required this.title,
    this.params = const {},
  });
}

// ---------------------------------------------------------------------------
// DrillProvider
// ---------------------------------------------------------------------------

/// Manages drill-down navigation state: breadcrumb stack + filter.
///
/// Separate from [ReportProvider] to avoid polluting analytics cache state.
class DrillProvider extends ChangeNotifier implements UserScoped {
  final List<BreadcrumbItem> _breadcrumb = [
    // Level 0 is always "Tổng quan" (summary home).
    const BreadcrumbItem(level: 0, title: 'Tổng quan'),
  ];

  FilterState _filter = const FilterState.empty();

  // Level 0 is the starting point (analytics home), not a drill level.
  int _currentLevel = 0;

  /// Ordered breadcrumb trail including the summary root.
  List<BreadcrumbItem> get breadcrumb => List.unmodifiable(_breadcrumb);

  /// Currently active filter.
  FilterState get filter => _filter;

  /// Active drill level (0 = home, 1–4 = drill screens).
  int get currentLevel => _currentLevel;

  /// Push a new level onto the breadcrumb.
  ///
  /// If the user navigates forward from an intermediate level (breadcrumb was
  /// already longer), we truncate to [level - 1] first to maintain linearity.
  void pushLevel({
    required int level,
    required String title,
    Map<String, dynamic> params = const {},
  }) {
    // Truncate any stale forward history beyond this point.
    while (_breadcrumb.length > level) {
      _breadcrumb.removeLast();
    }
    _breadcrumb.add(BreadcrumbItem(level: level, title: title, params: params));
    _currentLevel = level;
    notifyListeners();
  }

  /// Pop back to a specific level (tap breadcrumb item).
  ///
  /// Truncates everything after [level].
  void popToLevel(int level) {
    if (level >= _breadcrumb.length) return;
    // Remove items beyond [level].
    _breadcrumb.removeRange(level + 1, _breadcrumb.length);
    _currentLevel = level;
    notifyListeners();
  }

  /// Update the active filter. Triggers listeners (screens refetch).
  void updateFilter(FilterState newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  /// Clear filter, keep breadcrumb.
  void clearFilter() {
    _filter = const FilterState.empty();
    notifyListeners();
  }

  @override
  void resetUserScope() => reset();

  /// Reset breadcrumb to root + clear filter. Called when returning to summary.
  void reset() {
    _breadcrumb
      ..clear()
      ..add(const BreadcrumbItem(level: 0, title: 'Tổng quan'));
    _filter = const FilterState.empty();
    _currentLevel = 0;
    notifyListeners();
  }
}
