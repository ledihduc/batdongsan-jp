import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/community_category.dart';
import 'package:house_booking/data/models/social_post_model.dart';
import 'package:house_booking/data/services/social_api.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/social_feed_provider.dart';
import 'package:house_booking/features/guest/social/post_composer_screen.dart';
import 'package:house_booking/features/guest/social/post_comments_screen.dart';
import 'package:house_booking/features/guest/social/widgets/post_card.dart';

/// Bảng tin (mạng xã hội kiểu Facebook): dòng thời gian toàn cục + ô soạn bài
/// nhanh trên đầu, kéo để làm mới, cuộn để tải thêm.
class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialFeedProvider>().loadInitial();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      context.read<SocialFeedProvider>().loadMore();
    }
  }

  bool _requireLogin() => GuestGate.requireAuth(
    context,
    message: AppLocalizations.of(context).socialLoginToInteract,
  );

  Future<void> _openComposer() async {
    if (!_requireLogin()) return;
    final provider = context.read<SocialFeedProvider>();
    final created = await Navigator.push<SocialPost>(
      context,
      MaterialPageRoute(
        builder: (_) => PostComposerScreen(initialCategory: provider.category),
      ),
    );
    if (created != null && mounted) {
      provider.addPostToTop(created);
    }
  }

  Future<void> _openEdit(SocialPost post) async {
    final provider = context.read<SocialFeedProvider>();
    final edited = await Navigator.push<SocialPost>(
      context,
      MaterialPageRoute(builder: (_) => PostComposerScreen(editPost: post)),
    );
    if (edited != null && mounted) {
      provider.updatePost(edited);
    }
  }

  void _openComments(SocialPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostCommentsScreen(post: post)),
    );
  }

  Future<void> _confirmDelete(SocialPost post) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.socialDeletePostTitle),
        content: Text(l.socialDeletePostConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: HD.negative),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.socialDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = context.read<SocialFeedProvider>();
    try {
      await SocialApi().deletePost(post.id);
      provider.removePost(post.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.socialDeleteFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SocialFeedProvider>();
    final user = context.read<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: HD.paperSunken,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 56,
        title: _categoryFilterBar(provider),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refresh(),
        child: _buildBody(provider, user?.id),
      ),
    );
  }

  /// Thanh lọc chuyên mục kiểu Facebook (thay cho header "Cộng đồng").
  /// "Tất cả" + 6 khối; chọn khối → reload feed theo category.
  Widget _categoryFilterBar(SocialFeedProvider provider) {
    final l = AppLocalizations.of(context);
    final active = provider.category;
    final items = <({String? key, String label})>[
      (key: null, label: l.socialAll),
      ...kCommunityCategories.map((c) => (key: c.key, label: c.label)),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final selected = item.key == active;
          return ChoiceChip(
            label: Text(item.label),
            selected: selected,
            onSelected: (_) {
              if (item.key == active) return;
              provider.applyFilters(category: item.key);
            },
            selectedColor: HD.accent,
            labelStyle: TextStyle(
              color: selected ? Colors.white : HD.ink,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            backgroundColor: HD.paperSunken,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildBody(SocialFeedProvider provider, int? currentUserId) {
    if (provider.isLoading && provider.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.posts.isEmpty) {
      return _errorState(provider);
    }

    final posts = provider.posts;
    // +1 header (composer trigger), +1 footer (loader / empty state).
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: posts.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _composerTrigger();
        if (index == posts.length + 1) return _footer(provider);
        final post = posts[index - 1];
        final isOwner = currentUserId != null && post.userId == currentUserId;
        return PostCard(
          post: post,
          onLike: () {
            if (_requireLogin()) provider.toggleLike(post.id);
          },
          onComment: () => _openComments(post),
          onEdit: isOwner ? () => _openEdit(post) : null,
          onDelete: isOwner ? () => _confirmDelete(post) : null,
        );
      },
    );
  }

  Widget _composerTrigger() {
    final l = AppLocalizations.of(context);
    final user = context.read<AuthProvider>().currentUser;
    return Container(
      color: HD.paperRaised,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: HD.s16, vertical: HD.s12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: HD.accentTint,
            backgroundImage: (user?.avatarPath.isNotEmpty ?? false)
                ? CachedNetworkImageProvider(user!.avatarPath)
                : null,
            child: (user?.avatarPath.isEmpty ?? true)
                ? const Icon(Icons.person, color: HD.accent)
                : null,
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: InkWell(
              onTap: _openComposer,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HD.s16,
                  vertical: HD.s12,
                ),
                decoration: BoxDecoration(
                  color: HD.paperSunken,
                  borderRadius: BorderRadius.circular(HD.rPill),
                  border: Border.all(color: HD.hairline),
                ),
                child: Text(
                  l.socialWhatsOnMind,
                  style: const TextStyle(color: HD.inkMuted, fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: HD.s8),
          IconButton(
            onPressed: _openComposer,
            icon: const Icon(Icons.photo_library_outlined, color: HD.positive),
            tooltip: l.socialPostPhoto,
          ),
        ],
      ),
    );
  }

  Widget _footer(SocialFeedProvider provider) {
    final l = AppLocalizations.of(context);
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(HD.s16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.posts.isEmpty) {
      final filtered = provider.category != null;
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            const Icon(Icons.dynamic_feed, size: 56, color: HD.inkMuted),
            const SizedBox(height: HD.s12),
            Text(
              filtered ? l.socialNoPostsInCategory : l.socialNoPosts,
              style: const TextStyle(color: HD.inkMuted, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              l.socialBeFirstToShare,
              style: HD.body(size: 13, color: HD.inkSoft),
            ),
          ],
        ),
      );
    }
    if (!provider.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: HD.s24),
        child: Center(
          child: Text(
            l.socialEndOfFeed,
            style: const TextStyle(color: HD.inkMuted, fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox(height: HD.s24);
  }

  Widget _errorState(SocialFeedProvider provider) {
    final l = AppLocalizations.of(context);
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off, size: 56, color: HD.inkMuted),
        const SizedBox(height: HD.s12),
        Center(
          child: Text(
            provider.error ?? l.socialErrorOccurred,
            style: const TextStyle(color: HD.inkMuted),
          ),
        ),
        const SizedBox(height: HD.s16),
        Center(
          child: OutlinedButton(
            onPressed: () => provider.refresh(),
            child: Text(l.socialRetry),
          ),
        ),
      ],
    );
  }
}
