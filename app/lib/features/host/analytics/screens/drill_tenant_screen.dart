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

/// Level 3 drill screen — tenants on a contract.
///
/// Route: /host/analytics/drill/contract/:contractId/tenants
class DrillTenantScreen extends StatefulWidget {
  const DrillTenantScreen({
    super.key,
    required this.contractId,
  });

  final int contractId;

  @override
  State<DrillTenantScreen> createState() => _DrillTenantScreenState();
}

class _DrillTenantScreenState extends State<DrillTenantScreen> {
  static const int _kPageSize = 50;

  final ScrollController _scroll = ScrollController();
  final List<TenantByContractItem> _items = [];

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
      final drill = context.read<DrillProvider>();
      if (drill.currentLevel < 3) {
        drill.pushLevel(
          level: 3,
          title: 'HĐ #${widget.contractId}',
          params: {'contractId': widget.contractId},
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
      final resp = await context.read<ReportProvider>().fetchDrillTenants(
            contractId: widget.contractId,
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
        title: 'Người thuê',
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
        icon: Icons.person_off_rounded,
        title: 'Hợp đồng chưa có người thuê',
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
            unit: 'người thuê',
          );
        }
        final item = _items[i];
        return _TenantTile(
          item: item,
          onTap: () {
            context.read<DrillProvider>().pushLevel(
              level: 4,
              title: item.fullName,
              params: {
                'tenantId': item.tenantId,
                'contractId': widget.contractId,
              },
            );
            context.go(
              '/host/analytics/drill/tenant/${item.tenantId}/invoices'
              '?contract_id=${widget.contractId}',
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _TenantTile
// ---------------------------------------------------------------------------

class _TenantTile extends StatelessWidget {
  const _TenantTile({required this.item, required this.onTap});

  final TenantByContractItem item;
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
            CircleAvatar(
              radius: 20,
              backgroundColor: HD.ink.withValues(alpha: 0.08),
              child: Text(
                item.fullName.isNotEmpty
                    ? item.fullName[0].toUpperCase()
                    : '?',
                style: HD.bodyBold(color: HD.ink),
              ),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.fullName, style: HD.bodyBold()),
                      if (item.isPrimary) ...[
                        const SizedBox(width: HD.s4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: HD.positive.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'Ký HĐ',
                            style: HD.caption(color: HD.positive)
                                .copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.phone.isNotEmpty)
                    Text(item.phone,
                        style: HD.caption(color: HD.inkMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: HD.inkMuted, size: 20),
          ],
        ),
      ),
    );
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

