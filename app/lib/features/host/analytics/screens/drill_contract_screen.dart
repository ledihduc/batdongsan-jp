import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/drill_node_model.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/analytics/widgets/back_to_summary_button.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/host/analytics/widgets/breadcrumb.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/providers/report_provider.dart';

/// Level 2 drill screen — contracts for a room.
///
/// Route: /host/analytics/drill/room/:roomId/contracts
class DrillContractScreen extends StatefulWidget {
  const DrillContractScreen({super.key, required this.roomId});

  final int roomId;

  @override
  State<DrillContractScreen> createState() => _DrillContractScreenState();
}

class _DrillContractScreenState extends State<DrillContractScreen> {
  static const int _kPageSize = 50;

  final ScrollController _scroll = ScrollController();
  final List<ContractByRoomItem> _items = [];

  int _page = 1;
  int _totalCount = 0;
  bool _isLoading = false;
  bool _hasFetchedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Ensure breadcrumb is at level 2.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final drill = context.read<DrillProvider>();
      if (drill.currentLevel < 2) {
        drill.pushLevel(
          level: 2,
          title: 'Hợp đồng',
          params: {'roomId': widget.roomId},
        );
      }
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
      final resp = await context.read<ReportProvider>().fetchDrillContracts(
            roomId: widget.roomId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        title: 'Hợp đồng',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: HD.s8),
            child: BackToSummaryButton(),
          ),
        ],
      ),
      body: Column(
        children: [
          const Breadcrumb(),
          const Divider(height: 1, color: HD.hairline),
          Expanded(child: _buildBody()),
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
        icon: Icons.description_outlined,
        title: 'Phòng này chưa có hợp đồng',
      );
    }

    return ListView.builder(
      controller: _scroll,
      itemCount: _items.length + 1,
      itemBuilder: (ctx, i) {
        if (i == _items.length) {
          return _PaginationFooter(
            isLoading: _isLoading,
            loaded: _items.length,
            total: _totalCount,
            unit: 'hợp đồng',
          );
        }
        final item = _items[i];
        return _ContractTile(
          item: item,
          onTap: () {
            context.read<DrillProvider>().pushLevel(
              level: 3,
              title: 'HĐ #${item.contractId}',
              params: {
                'contractId': item.contractId,
                'roomId': widget.roomId,
              },
            );
            context.go(
              '/host/analytics/drill/contract/${item.contractId}/tenants',
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _ContractTile
// ---------------------------------------------------------------------------

class _ContractTile extends StatelessWidget {
  const _ContractTile({required this.item, required this.onTap});

  final ContractByRoomItem item;
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
                  Text('HĐ #${item.contractId}', style: HD.bodyBold()),
                  const SizedBox(height: 2),
                  Text(
                    '${item.startDate} → ${item.endDate}',
                    style: HD.caption(color: HD.inkMuted),
                  ),
                  Text(
                    '${_formatCurrency(item.monthlyRent)} / tháng',
                    style: HD.caption(color: HD.inkSoft)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: HD.s8, vertical: HD.s4),
              decoration: BoxDecoration(
                color: _statusColor(item.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.status,
                style: HD.caption(color: _statusColor(item.status))
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: HD.s8),
            const Icon(Icons.chevron_right_rounded,
                color: HD.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
        return HD.positive;
      case 'expired':
      case 'terminated':
        return HD.negative;
      default:
        return HD.inkSoft;
    }
  }

  String _formatCurrency(double v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    return v.toStringAsFixed(0);
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.isLoading,
    required this.loaded,
    required this.total,
    required this.unit,
  });

  final bool isLoading;
  final int loaded;
  final int total;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(HD.s16),
        child: Center(
            child: Text('Đang tải...',
                style: TextStyle(color: HD.inkMuted))),
      );
    }
    if (loaded >= total && total > 0) {
      return Padding(
        padding: const EdgeInsets.all(HD.s16),
        child: Center(
          child: Text(
            'Đã tải $loaded/$total $unit',
            style: HD.caption(color: HD.inkMuted),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

