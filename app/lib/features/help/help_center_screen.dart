/// Help Center screen — searchable FAQ list grouped by category.
///
/// Route: /help (JP-gated, registered in app_router.dart).
/// Provider: none — data loaded from bundled [kHelpArticles] constant.
/// API: none — fully offline-first.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/help/help_models.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Route: /help
///
/// Displays all 14 FAQ articles grouped by [HelpCategory].
/// Search bar filters by local string match on title (no backend call).
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<HelpArticle> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kHelpArticles;
    return kHelpArticles
        .where(
          (a) =>
              a.titleJa.toLowerCase().contains(q) ||
              a.titleEn.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered;

    // Group filtered articles by category in the original display order.
    final grouped = <HelpCategory, List<HelpArticle>>{};
    for (final cat in kHelpCategories) {
      final articles = filtered.where((a) => a.categoryId == cat.id).toList();
      if (articles.isNotEmpty) {
        grouped[cat] = articles;
      }
    }

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l10n.helpCenterTitle,
        showBack: true,
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Material(
            color: HD.paperRaised,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.helpCenterSearchHint,
                  prefixIcon: const Icon(Icons.search, color: HD.inkMuted),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: HD.inkMuted),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: HD.paperSunken,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          // ── Article list ──────────────────────────────────────────────────
          Expanded(
            child: grouped.isEmpty
                ? _EmptySearch(query: _query)
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final entry in grouped.entries) ...[
                        _CategoryHeader(category: entry.key),
                        // Material ancestor required so ListTile ink-splash works
                        // inside a Container that carries BoxDecoration.
                        Material(
                          color: HD.paperRaised,
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            children: [
                              for (int i = 0; i < entry.value.length; i++) ...[
                                _ArticleTile(article: entry.value[i]),
                                if (i < entry.value.length - 1)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: HD.hairline,
                                  ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final HelpCategory category;

  @override
  Widget build(BuildContext context) {
    // Display Japanese label; English label is the subtitle.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        category.labelJa,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: HD.inkMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article});

  final HelpArticle article;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        article.titleJa,
        style: const TextStyle(fontSize: 14, color: HD.ink),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: HD.inkMuted,
        size: 20,
      ),
      onTap: () => context.push('/help/${article.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: HD.inkMuted),
            const SizedBox(height: 16),
            Text(
              l10n.helpCenterNoResults,
              style: const TextStyle(fontSize: 15, color: HD.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
