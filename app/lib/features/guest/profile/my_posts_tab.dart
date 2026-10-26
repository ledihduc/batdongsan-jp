import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/social_post_model.dart';
import 'package:house_booking/data/services/social_api.dart';
import 'package:house_booking/features/guest/social/post_comments_screen.dart';
import 'package:house_booking/features/guest/social/widgets/post_card.dart';

/// Tab "Bài viết" ở trang cá nhân — bài cộng đồng của chính người dùng.
///
/// Dùng `GET /api/social/feed?user_id=…`. Bộ lọc đó chỉ trả bài `published`
/// y như dòng thời gian chung, nên tab này KHÔNG lộ bài nháp/đã gỡ của ai.
class MyPostsTab extends StatefulWidget {
  const MyPostsTab({super.key, required this.userId, this.api});

  final int userId;

  /// Chỉ để TEST bơm API giả.
  final SocialApi? api;

  @override
  State<MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends State<MyPostsTab> {
  late final SocialApi _api = widget.api ?? SocialApi();

  List<SocialPost> _posts = const [];
  bool _loading = true;
  bool _loi = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() {
      _loading = true;
      _loi = false;
    });
    try {
      final r = await _api.fetchFeed(userId: widget.userId, limit: 20);
      if (!mounted) return;
      setState(() {
        _posts = r.posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loi = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_loi) {
      return _trangThai(
        Icons.wifi_off_outlined,
        l.myPostsLoadError,
        l.myPostsLoadErrorHint,
        nut: TextButton(onPressed: _nap, child: Text(l.myPostsRetry)),
      );
    }
    if (_posts.isEmpty) {
      // Trạng thái rỗng phải CHỈ ĐƯỜNG, không để trống trơn.
      return _trangThai(
        Icons.post_add_outlined,
        l.myPostsEmptyTitle,
        l.myPostsEmptyHint,
      );
    }
    return RefreshIndicator(
      onRefresh: _nap,
      color: HD.accent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length,
        itemBuilder: (context, i) {
          final p = _posts[i];
          return PostCard(
            post: p,
            onLike: () => _thich(i, p),
            onComment: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostCommentsScreen(post: p)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _thich(int i, SocialPost p) async {
    try {
      final r = await _api.toggleLike(p.id);
      if (!mounted) return;
      setState(
        () =>
            _posts[i] = p.copyWith(likedByMe: r.liked, likeCount: r.likeCount),
      );
    } catch (_) {}
  }

  Widget _trangThai(IconData icon, String tieuDe, String phu, {Widget? nut}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 32),
      children: [
        Icon(icon, size: 56, color: HD.inkMuted),
        const SizedBox(height: 12),
        Text(
          tieuDe,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: HD.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          phu,
          textAlign: TextAlign.center,
          style: const TextStyle(color: HD.inkMuted, fontSize: 14),
        ),
        if (nut != null) Center(child: nut),
      ],
    );
  }
}
