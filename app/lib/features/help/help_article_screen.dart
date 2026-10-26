/// Help article detail screen — renders bundled Markdown content.
///
/// Route: /help/:id (JP-gated, registered in app_router.dart).
/// Provider: none — loads asset via [DefaultAssetBundle].
/// API: none — fully offline-first.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/help/help_models.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Route: /help/:id
///
/// Loads and renders the Markdown file for the matching [HelpArticle].
/// Falls back to an error state when [articleId] is not in [kHelpArticles].
class HelpArticleScreen extends StatefulWidget {
  const HelpArticleScreen({super.key, required this.articleId});

  /// Article identifier that matches [HelpArticle.id] (e.g. '01').
  final String articleId;

  @override
  State<HelpArticleScreen> createState() => _HelpArticleScreenState();
}

class _HelpArticleScreenState extends State<HelpArticleScreen> {
  late final HelpArticle? _article;
  String? _content;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _article = kHelpArticles.where((a) => a.id == widget.articleId).firstOrNull;
    if (_article != null) {
      _loadContent(_article!.assetPath);
    } else {
      _loading = false;
    }
  }

  String _stripFrontmatter(String raw) {
    if (!raw.startsWith('---')) return raw;
    final end = raw.indexOf('\n---', 3);
    if (end < 0) return raw;
    final after = end + 4;
    return raw.substring(after).trimLeft();
  }

  Future<void> _loadContent(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      // Strip YAML frontmatter so the markdown body renders cleanly without
      // leaking `title:` / `category:` metadata.
      final content = _stripFrontmatter(raw);
      if (mounted) {
        setState(() {
          _content = content;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _article?.titleJa ?? l10n.helpCenterArticleNotFound;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: title, showBack: true),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: HD.accent, strokeWidth: 2),
      );
    }

    if (_article == null) {
      return _ErrorState(message: l10n.helpCenterArticleNotFound);
    }

    if (_error != null) {
      return _ErrorState(message: l10n.helpCenterLoadError);
    }

    final content = _content ?? '';

    // Placeholder articles show a friendly "coming soon" message instead of
    // raw "TBD" text so users see something polished at launch.
    if (content.trim() == 'TBD') {
      return _ComingSoon(l10n: l10n);
    }

    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 14, height: 1.7, color: HD.ink),
        h1: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: HD.ink,
        ),
        h2: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: HD.inkSoft,
        ),
        h3: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: HD.inkSoft,
        ),
        listBullet: const TextStyle(fontSize: 14, color: HD.inkSoft),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: HD.accent, width: 3),
          ),
          color: HD.accentTint,
        ),
        code: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          backgroundColor: HD.paperSunken,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: HD.inkMuted,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 15, color: HD.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.article_outlined,
              size: 48,
              color: HD.inkMuted,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.helpCenterComingSoon,
              style: const TextStyle(fontSize: 15, color: HD.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
