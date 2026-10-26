import 'package:house_booking/features/guest/short_stay/short_stay_search_screen.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/recent_search_service.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Tìm kiếm TOÀN HỆ THỐNG: gõ → gọi /api/search → kết quả gom nhóm (Tin đăng /
/// Đơn vị / Bài viết). Ô trống → lịch sử tìm gần đây. Mở từ icon search ở header.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _api = const ApiClient();
  Timer? _debounce;

  List<String> _recent = [];
  Map<String, dynamic>? _results;
  bool _loading = false;
  String _q = '';

  static String _abs(String u) =>
      u.startsWith('http') ? u : '${ApiConfig.baseUrl}$u';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final r = await RecentSearchService.instance.getAll();
    if (mounted) setState(() => _recent = r);
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _search(v));
  }

  Future<void> _search(String v) async {
    final q = v.trim();
    setState(() => _q = q);
    if (q.length < 2) {
      setState(() => _results = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _api.get('/api/search', queryParameters: {'q': q});
      if (mounted) setState(() => _results = Map<String, dynamic>.from(res));
    } catch (_) {
      if (mounted)
        setState(
          () => _results = {'houses': [], 'contractors': [], 'posts': []},
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit(String q) {
    if (q.trim().length < 2) return;
    RecentSearchService.instance.add(q.trim()).then((_) => _loadRecent());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) {
            _submit(v);
            _search(v);
          },
          decoration: InputDecoration(
            hintText: l.searchHint,
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {
                        _q = '';
                        _results = null;
                      });
                    },
                  ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TextButton.icon(
            icon: const Icon(Icons.bed_outlined),
            label: const Text('短期滞在 · 時間・一泊・日単位'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShortStaySearchScreen()),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_results == null ? _recentView() : _resultsView()),
    );
  }

  // ── Lịch sử tìm gần đây ────────────────────────────────────────────────────
  Widget _recentView() {
    final l = AppLocalizations.of(context);
    if (_recent.isEmpty) {
      return EmptyState(
        icon: Icons.search,
        title: l.searchEmptyTitle,
        subtitle: l.searchEmptySubtitle,
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s8, 0),
          child: Row(
            children: [
              Text(l.searchRecentTitle, style: HD.eyebrow()),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await RecentSearchService.instance.clear();
                  _loadRecent();
                },
                child: Text(l.searchClearAll),
              ),
            ],
          ),
        ),
        ..._recent.map(
          (q) => ListTile(
            leading: const Icon(Icons.history, color: HD.inkMuted),
            title: Text(q),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18, color: HD.inkMuted),
              onPressed: () async {
                await RecentSearchService.instance.remove(q);
                _loadRecent();
              },
            ),
            onTap: () {
              _ctrl.text = q;
              _submit(q);
              _search(q);
            },
          ),
        ),
      ],
    );
  }

  // ── Kết quả gom nhóm ───────────────────────────────────────────────────────
  Widget _resultsView() {
    final l = AppLocalizations.of(context);
    final houses = List<Map<String, dynamic>>.from(
      _results!['houses'] ?? const [],
    );
    final contractors = List<Map<String, dynamic>>.from(
      _results!['contractors'] ?? const [],
    );
    final posts = List<Map<String, dynamic>>.from(
      _results!['posts'] ?? const [],
    );
    if (houses.isEmpty && contractors.isEmpty && posts.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: l.searchNoResults(_q),
        subtitle: l.searchNoResultsSubtitle,
      );
    }
    return ListView(
      children: [
        if (houses.isNotEmpty)
          _group(l.searchGroupHouses, houses.map(_houseTile)),
        if (contractors.isNotEmpty)
          _group(l.searchGroupContractors, contractors.map(_contractorTile)),
        if (posts.isNotEmpty) _group(l.searchGroupPosts, posts.map(_postTile)),
        const SizedBox(height: HD.s24),
      ],
    );
  }

  Widget _group(String title, Iterable<Widget> tiles) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, HD.s4),
        child: Text(title, style: HD.eyebrow()),
      ),
      ...tiles,
    ],
  );

  Widget _thumb(String? url, IconData fallback) => ClipRRect(
    borderRadius: BorderRadius.circular(HD.r8),
    child: SizedBox(
      width: 48,
      height: 48,
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: _abs(url),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: HD.paperSunken),
            )
          : Container(
              color: HD.paperSunken,
              child: Icon(fallback, color: HD.inkMuted, size: 22),
            ),
    ),
  );

  Widget _houseTile(Map<String, dynamic> h) {
    final l = AppLocalizations.of(context);
    final imgs = List.from(h['images'] as List? ?? const []);
    return ListTile(
      leading: _thumb(
        imgs.isNotEmpty ? imgs.first as String : null,
        Icons.home_work_outlined,
      ),
      title: Text(
        h['title'] as String? ?? l.searchHouseFallback,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        h['address'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => context.push('/house/${h['id']}'),
    );
  }

  Widget _contractorTile(Map<String, dynamic> c) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: _thumb(c['logo_path'] as String?, Icons.business_outlined),
      title: Row(
        children: [
          Flexible(
            child: Text(
              c['company_name'] as String? ?? l.searchContractorFallback,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (c['verified'] == true) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, size: 14, color: HD.positive),
          ],
        ],
      ),
      subtitle: Text(
        l.searchRating(
          ((c['rating_avg'] ?? 0) as num).toStringAsFixed(1),
          '${c['rating_count'] ?? 0}',
        ),
      ),
      // Hồ sơ nhà thầu đã gỡ cùng mảng thi công.
      onTap: null,
    );
  }

  Widget _postTile(Map<String, dynamic> p) {
    final imgs = List.from(p['images'] as List? ?? const []);
    return ListTile(
      leading: _thumb(
        imgs.isNotEmpty ? imgs.first as String : null,
        Icons.article_outlined,
      ),
      title: Text(
        p['content'] as String? ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
