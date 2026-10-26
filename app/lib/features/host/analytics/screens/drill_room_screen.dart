import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/drill_node_model.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/analytics/widgets/back_to_summary_button.dart';
import 'package:house_booking/features/host/analytics/widgets/breadcrumb.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/host/analytics/widgets/filter_bottom_sheet.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/providers/report_provider.dart';

/// Level 1 drill screen — list of rooms filterable by building.
///
/// Route: /host/analytics/drill/rooms
class DrillRoomScreen extends StatefulWidget {
  const DrillRoomScreen({super.key});

  @override
  State<DrillRoomScreen> createState() => _DrillRoomScreenState();
}

class _DrillRoomScreenState extends State<DrillRoomScreen> {
  static const int _kPageSize = 50;

  final ScrollController _scroll = ScrollController();
  final List<RoomListItem> _items = [];

  int _page = 1;
  int _totalCount = 0;
  bool _isLoading = false;
  bool _hasFetchedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPage(1, reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadPage(int page, {bool reset = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final filter = context.read<DrillProvider>().filter;
      final buildingId =
          filter.buildingIds.isNotEmpty ? filter.buildingIds.first : null;
      final resp = await context.read<ReportProvider>().fetchDrillRooms(
            buildingId: buildingId,
            page: page,
            pageSize: _kPageSize,
          );
      setState(() {
        if (reset) _items.clear();
        _items.addAll(resp.items);
        _totalCount = resp.totalCount;
        _page = resp.page;
        _hasFetchedOnce = true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadNextPage() {
    final maxPage = (_totalCount / _kPageSize).ceil();
    if (!_isLoading && _page < maxPage) {
      _loadPage(_page + 1);
    }
  }

  Future<void> _openFilter() async {
    await showFilterBottomSheet(context);
    // Refetch with new filter.
    _loadPage(1, reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: 'Phòng',
        actions: [
          Consumer<DrillProvider>(
            builder: (context, drill, _) => IconButton(
              icon: Badge(
                isLabelVisible: !drill.filter.isEmpty,
                backgroundColor: HD.accent,
                child: const Icon(Icons.filter_list_rounded),
              ),
              tooltip: 'Lọc',
              onPressed: _openFilter,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: HD.s8),
            child: BackToSummaryButton(),
          ),
        ],
      ),
      body: Column(
        children: [
          const Breadcrumb(),
          const Divider(height: 1, color: HD.hairline),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && !_hasFetchedOnce) {
      return const Center(child: DsRowSkeleton());
    }
    if (_error != null && _items.isEmpty) {
      return DsErrorState(
        message: _error!,
        onRetry: () => _loadPage(1, reset: true),
      );
    }
    if (_hasFetchedOnce && _items.isEmpty) {
      return const DsEmptyState(
        icon: Icons.meeting_room_outlined,
        title: 'Không có phòng nào',
      );
    }

    return ListView.builder(
      controller: _scroll,
      itemCount: _items.length + 1, // +1 for footer
      itemBuilder: (ctx, i) {
        if (i == _items.length) {
          return _PaginationFooter(
            isLoading: _isLoading,
            loaded: _items.length,
            total: _totalCount,
          );
        }
        final item = _items[i];
        return _RoomTile(
          item: item,
          onTap: () {
            context.read<DrillProvider>().pushLevel(
              level: 2,
              title: item.roomCode,
              params: {'roomId': item.roomId},
            );
            context.go(
              '/host/analytics/drill/room/${item.roomId}/contracts',
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _RoomTile
// ---------------------------------------------------------------------------

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.item, required this.onTap});

  final RoomListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
            horizontal: HD.s16, vertical: HD.s12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HD.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.roomCode, style: HD.bodyBold()),
                  const SizedBox(height: 2),
                  Text(
                    item.buildingName,
                    style: HD.caption(color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: HD.s8, vertical: HD.s4),
              decoration: BoxDecoration(
                color: _statusColor(item.roomStatus).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.roomStatus,
                style: HD.caption(color: _statusColor(item.roomStatus))
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: HD.s8),
            Icon(Icons.chevron_right_rounded,
                color: HD.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
      case 'rented':
        return HD.positive;
      case 'vacant':
      case 'empty':
        return HD.inkMuted;
      case 'maintenance':
        return HD.warning;
      default:
        return HD.inkSoft;
    }
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.isLoading,
    required this.loaded,
    required this.total,
  });

  final bool isLoading;
  final int loaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(HD.s16),
        child: Center(child: Text('Đang tải...', style: TextStyle(color: HD.inkMuted))),
      );
    }
    if (loaded >= total && total > 0) {
      return Padding(
        padding: const EdgeInsets.all(HD.s16),
        child: Center(
          child: Text(
            'Đã tải $loaded/$total phòng',
            style: HD.caption(color: HD.inkMuted),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

