import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/tools/compare_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wishlist = Provider.of<WishlistProvider>(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.wishEyebrow,
        title: l.wishTitle,
        actions: [
          if (wishlist.items.length >= 2)
            Padding(
              padding: const EdgeInsets.only(right: HD.s8),
              child: DsIconButton(
                icon: Icons.compare_arrows,
                tooltip: l.wishCompareTooltip,
                onPressed: () {
                  final ids = wishlist.items
                      .map((h) => h.id)
                      .whereType<int>()
                      .take(4)
                      .toList();
                  if (ids.length < 2) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompareScreen(houseIds: ids),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: HD.s8),
            child: DsIconButton(
              icon: Icons.refresh,
              tooltip: l.wishRefreshTooltip,
              onPressed: user == null ? null : () => wishlist.fetch(user.id!),
            ),
          ),
        ],
      ),
      body: wishlist.isLoading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : wishlist.items.isEmpty
          ? _emptyState(l)
          : RefreshIndicator(
              onRefresh: () =>
                  user == null ? Future.value() : wishlist.fetch(user.id!),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: wishlist.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final h = wishlist.items[i];
                  return _favCard(context, h, user?.id, wishlist);
                },
              ),
            ),
    );
  }

  Widget _emptyState(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: HD.inkMuted),
            const SizedBox(height: 16),
            Text(
              l.wishEmptyTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: HD.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.wishEmptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HD.inkSoft, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favCard(
    BuildContext context,
    HouseModel h,
    int? userId,
    WishlistProvider wp,
  ) {
    final l = AppLocalizations.of(context);
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
              width: 120,
              height: 110,
              child: h.images.isNotEmpty
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
                          child: const Icon(
                            Icons.home_outlined,
                            color: HD.inkMuted,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: HD.paperSunken,
                      child: const Icon(
                        Icons.home_outlined,
                        color: HD.inkMuted,
                      ),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: HD.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: HD.inkMuted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${h.district}, ${h.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HD.inkMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatPrice(h.price),
                          style: const TextStyle(
                            color: HD.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(' · ', style: TextStyle(color: HD.inkMuted)),
                        Text(
                          '${h.area.toStringAsFixed(0)} m²',
                          style: const TextStyle(
                            fontSize: 12,
                            color: HD.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: l.wishUnfavoriteTooltip,
              icon: const Icon(Icons.favorite, color: HD.accent),
              onPressed: userId == null
                  ? null
                  : () async {
                      try {
                        await wp.toggle(userId, h);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.wishUnfavoriteError)),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    // JP build: display prices in yen (¥).
    if (price >= 10000) {
      final man = price / 10000;
      return '¥${man.toStringAsFixed(man % 1 == 0 ? 0 : 1)}万';
    }
    return '¥${price.toStringAsFixed(0)}';
  }
}
