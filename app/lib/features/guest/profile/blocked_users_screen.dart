import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/moderation_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Danh sách người đã chặn + bỏ chặn (Apple 1.2 — quản lý người bị chặn).
/// Route: push từ Cài đặt. API: GET/DELETE /api/social/blocks.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _api = const ModerationApi();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.blocked();
  }

  void _reload() => setState(() => _future = _api.blocked());

  Future<void> _unblock(int userId) async {
    final l = AppLocalizations.of(context);
    try {
      await _api.unblock(userId);
      if (!mounted) return;
      AppFeedback.success(context, l.unblockDone);
      _reload();
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(context, l.blockFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.blockedUsersTitle),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                l.blockedEmpty,
                style: const TextStyle(color: HD.inkMuted),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = items[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('${u['name'] ?? 'Người dùng'}'),
                trailing: OutlinedButton(
                  onPressed: () => _unblock((u['user_id'] as num).toInt()),
                  child: Text(l.unblock),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
