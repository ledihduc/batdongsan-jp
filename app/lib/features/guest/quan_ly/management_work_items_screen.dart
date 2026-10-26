import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/features/guest/quan_ly/widgets/management_v2_components.dart';

/// Danh sách công việc read-only của Activity V2.
///
/// Đây là màn bổ sung sau feature flag, không thay màn lịch xem/CRM/hợp đồng
/// cũ. `detail_route` và `allowed_actions` là contract server-authoritative đã
/// được giữ lại trong adapter nhưng chưa được biến thành command ở P03.
class ManagementWorkItemsScreen extends StatefulWidget {
  const ManagementWorkItemsScreen({
    super.key,
    required this.mode,
    this.initialBucket = ManagementBucket.actionRequired,
    this.api = const ManagementReadModelApi(),
    this.onOpenItem,
  });

  final ManagementMode mode;
  final ManagementBucket initialBucket;
  final ManagementReadModelApi api;

  /// Route server-authoritative được shell gọi lại để mở đúng màn legacy.
  /// Màn danh sách không tự suy diễn quyền hoặc biến `allowed_actions` thành
  /// command trong P03.
  final Future<void> Function(ManagementWorkItem item)? onOpenItem;

  @override
  State<ManagementWorkItemsScreen> createState() =>
      _ManagementWorkItemsScreenState();
}

class _ManagementWorkItemsScreenState extends State<ManagementWorkItemsScreen> {
  late ManagementBucket _bucket = widget.initialBucket;
  ManagementWorkItems? _data;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    final loadingMore = page > 1;
    setState(() {
      if (loadingMore) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final data = await widget.api.workItems(
        mode: widget.mode,
        bucket: _bucket,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _data = loadingMore && _data != null
            ? ManagementWorkItems(
                items: [..._data!.items, ...data.items],
                totalItems: data.totalItems,
                page: data.page,
                totalPages: data.totalPages,
              )
            : data;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (loadingMore) {
        setState(() => _loadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa tải được trang tiếp theo.')),
        );
      } else {
        setState(() {
          _error = 'Chưa tải được công việc. Kiểm tra kết nối rồi thử lại.';
          _loading = false;
        });
      }
    }
  }

  void _select(ManagementBucket bucket) {
    if (_bucket == bucket) return;
    setState(() => _bucket = bucket);
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfffbfcfe),
    appBar: AppBar(
      backgroundColor: const Color(0xfffbfcfe),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: HD.ink),
      ),
      title: Text(
        'Công việc hoạt động',
        style: HD.bodyBold(size: 19, color: HD.ink),
      ),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, color: HD.accent),
        ),
      ],
    ),
    body: Column(
      children: [
        ManagementBucketSelector(selected: _bucket, onSelected: _select),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (_loading) {
      return Semantics(
        liveRegion: true,
        label: 'Đang tải công việc hoạt động',
        child: const Center(child: CircularProgressIndicator(color: HD.accent)),
      );
    }
    if (_error != null) {
      return _errorView();
    }
    final items = _data?.items ?? const <ManagementWorkItem>[];
    if (items.isEmpty) {
      return _emptyView();
    }
    return RefreshIndicator(
      color: HD.accent,
      onRefresh: _load,
      child: ListView.separated(
        key: const Key('management-v2-work-item-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          if (index == items.length) return _loadMoreButton();
          return ManagementWorkItemCard(
            item: items[index],
            onOpen:
                widget.onOpenItem == null || items[index].detailRoute.isEmpty
                ? null
                : () => widget.onOpenItem!(items[index]),
          );
        },
      ),
    );
  }

  bool get _hasMore =>
      _data != null && _data!.page > 0 && _data!.page < _data!.totalPages;

  Widget _loadMoreButton() => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: OutlinedButton.icon(
      key: const Key('management-v2-load-more'),
      onPressed: _loadingMore ? null : () => _load(page: _data!.page + 1),
      icon: _loadingMore
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more_rounded),
      label: Text(_loadingMore ? 'Đang tải...' : 'Xem thêm'),
    ),
  );

  Widget _errorView() => Semantics(
    liveRegion: true,
    label: _error,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 46, color: HD.inkMuted),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: HD.body(size: 14, color: HD.inkMuted),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      ),
    ),
  );

  Widget _emptyView() => Semantics(
    liveRegion: true,
    label: _emptyMessage(_bucket),
    child: RefreshIndicator(
      color: HD.accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),
          const Icon(Icons.inbox_outlined, size: 52, color: HD.inkMuted),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Chưa có công việc',
              style: HD.bodyBold(size: 17, color: HD.ink),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              _emptyMessage(_bucket),
              textAlign: TextAlign.center,
              style: HD.body(size: 13.5, color: HD.inkMuted),
            ),
          ),
        ],
      ),
    ),
  );

  static String _emptyMessage(ManagementBucket value) => switch (value) {
    ManagementBucket.actionRequired => 'Bạn chưa có việc nào cần phản hồi.',
    ManagementBucket.waitingExternal =>
      'Không có lịch hoặc hồ sơ đang chờ bên khác.',
    ManagementBucket.upcoming => 'Chưa có lịch xem nào sắp tới.',
    ManagementBucket.afterViewing => 'Kết quả sau xem sẽ xuất hiện tại đây.',
    ManagementBucket.history =>
      'Lịch sử đã hoàn tất hoặc đã hủy sẽ xuất hiện tại đây.',
  };
}
