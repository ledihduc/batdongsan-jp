import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/features/host/post/post_house_screen.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/ds_trusted_badge.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        Provider.of<HouseProvider>(context, listen: false)
            .fetchMyHouses(user.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hp = Provider.of<HouseProvider>(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final mine = hp.myHouses;

    return Scaffold(
      appBar: DsAppBar(
        title: l.hListingsTitle,
        actions: [
          IconButton(
            tooltip: l.hListingsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                user == null ? null : hp.fetchMyHouses(user.id!),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostHouseScreen()),
          );
          if (user != null) hp.fetchMyHouses(user.id!);
        },
        icon: const Icon(Icons.add),
        label: Text(l.hListingsPostRoom),
      ),
      body: mine.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox_outlined,
                        size: 64, color: HD.inkMuted),
                    const SizedBox(height: 16),
                    Text(
                      l.hListingsEmptyTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.hListingsEmptyHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: HD.inkSoft),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: mine.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _listingCard(context, mine[i], hp),
            ),
    );
  }

  Widget _listingCard(BuildContext context, HouseModel h, HouseProvider hp) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/house/${h.id}'),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  h.images.isNotEmpty
                      ? Semantics(
                          label: h.title,
                          child: CachedNetworkImage(
                            imageUrl: h.images.first,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            fadeInDuration: const Duration(milliseconds: 150),
                            placeholder: (_, __) =>
                                Container(color: HD.paperSunken),
                            errorWidget: (_, __, ___) => Container(
                              color: HD.paperSunken,
                              child: const Icon(Icons.home_outlined,
                                  color: HD.inkMuted),
                            ),
                          ),
                        )
                      : Container(
                          color: HD.paperSunken,
                          child: const Icon(Icons.home_outlined,
                              color: HD.inkMuted),
                        ),
                  // Trusted badge — icon-only variant for compact card thumbnail
                  if (h.isTrusted)
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: DsTrustedBadge.iconOnly(),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    _statusBadge(context, h.status),
                    const SizedBox(height: 6),
                    Text(
                      '${h.district}, ${h.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: HD.inkMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      h.priceCompactLabel,
                      style: const TextStyle(
                        color: HD.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: HD.accent),
                  tooltip: AppLocalizations.of(context).hListingsEdit,
                  onPressed: () async {
                    final user = Provider.of<AuthProvider>(context,
                            listen: false)
                        .currentUser;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostHouseScreen(editing: h),
                      ),
                    );
                    if (user != null) hp.fetchMyHouses(user.id!);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: HD.accent),
                  tooltip: AppLocalizations.of(context).hListingsDelete,
                  onPressed: () => _confirmDelete(context, h, hp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, HouseModel h, HouseProvider hp) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.hListingsDeleteTitle),
        content: Text(l.hListingsDeleteConfirm(h.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.hListingsDeleteAction),
          ),
        ],
      ),
    );
    if (ok == true) {
      final done = await hp.deleteHouse(h.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  done ? l.hListingsDeleteSuccess : l.hListingsDeleteFailed)),
        );
      }
    }
  }

  Widget _statusBadge(BuildContext context, String status) {
    final l = AppLocalizations.of(context);
    Color bg;
    Color fg;
    String label;
    // Backend đã đổi sang 'published'/'pending_review' (xem app/house_status.py);
    // giữ 'approved'/'pending' legacy để tương thích client/dữ liệu cũ.
    switch (status) {
      case 'published':
      case 'approved':
        bg = HD.positive.withOpacity(0.12);
        fg = HD.positive;
        label = l.hListingsStatusApproved;
        break;
      case 'pending_review':
      case 'pending':
        bg = HD.warning.withOpacity(0.15);
        fg = HD.warning;
        label = l.hListingsStatusPending;
        break;
      case 'rejected':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = l.hListingsStatusRejected;
        break;
      case 'hidden':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = l.hListingsStatusHidden;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }

}
