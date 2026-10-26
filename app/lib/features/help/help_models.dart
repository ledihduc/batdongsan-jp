/// Help Center data models.
///
/// [HelpCategory] groups [HelpArticle] items for display in HelpCenterScreen.
/// Articles are loaded from bundled assets (offline-first, no backend call).
library;

/// A single FAQ article in the JP help center.
class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.categoryId,
    required this.titleJa,
    required this.titleEn,
    required this.assetPath,
  });

  /// Unique article identifier (slug matches asset filename stem).
  final String id;

  /// Parent category identifier — must match [HelpCategory.id].
  final String categoryId;

  /// Article title in Japanese (primary display language for JP market).
  final String titleJa;

  /// Article title in English (fallback for non-JP locales).
  final String titleEn;

  /// Asset path relative to the Flutter asset root.
  final String assetPath;
}

/// A category grouping one or more [HelpArticle] items.
class HelpCategory {
  const HelpCategory({
    required this.id,
    required this.labelJa,
    required this.labelEn,
  });

  final String id;
  final String labelJa;
  final String labelEn;
}

// ─────────────────────────────────────────────────────────────────────────────
// Static catalog — 6 categories, 14 articles.
// Keys (`id`, `categoryId`) are coupled to asset filenames + frontmatter.
// ─────────────────────────────────────────────────────────────────────────────

const List<HelpCategory> kHelpCategories = [
  HelpCategory(id: 'renewal', labelJa: '更新', labelEn: 'Renewal'),
  HelpCategory(
    id: 'settlement',
    labelJa: '敷金精算',
    labelEn: 'Deposit Settlement',
  ),
  HelpCategory(id: 'appi', labelJa: 'APPI/プライバシー', labelEn: 'APPI / Privacy'),
  HelpCategory(id: 'payment', labelJa: '支払い', labelEn: 'Payment'),
  HelpCategory(id: 'account', labelJa: 'アカウント', labelEn: 'Account'),
  HelpCategory(id: 'inquiry', labelJa: '問い合わせ', labelEn: 'Support'),
];

const List<HelpArticle> kHelpArticles = [
  // ── 更新 (Renewal) ──
  HelpArticle(
    id: 'renewal-overview',
    categoryId: 'renewal',
    titleJa: '更新手続きについて',
    titleEn: 'Lease renewal overview',
    assetPath: 'assets/jp/help/renewal-overview.md',
  ),
  HelpArticle(
    id: 'renewal-fee-breakdown',
    categoryId: 'renewal',
    titleJa: '更新費用の内訳',
    titleEn: 'Renewal fee breakdown',
    assetPath: 'assets/jp/help/renewal-fee-breakdown.md',
  ),
  HelpArticle(
    id: 'renewal-decline-process',
    categoryId: 'renewal',
    titleJa: '更新しない場合の手続き',
    titleEn: 'Declining a renewal',
    assetPath: 'assets/jp/help/renewal-decline-process.md',
  ),
  // ── 敷金精算 (Settlement) ──
  HelpArticle(
    id: 'settlement-overview',
    categoryId: 'settlement',
    titleJa: '敷金精算について',
    titleEn: 'Deposit settlement overview',
    assetPath: 'assets/jp/help/settlement-overview.md',
  ),
  HelpArticle(
    id: 'settlement-dispute',
    categoryId: 'settlement',
    titleJa: '敷金精算に異議がある場合',
    titleEn: 'Disputing a settlement',
    assetPath: 'assets/jp/help/settlement-dispute.md',
  ),
  HelpArticle(
    id: 'settlement-timeline',
    categoryId: 'settlement',
    titleJa: '敷金精算のタイムライン',
    titleEn: 'Settlement timeline',
    assetPath: 'assets/jp/help/settlement-timeline.md',
  ),
  // ── APPI/プライバシー ──
  HelpArticle(
    id: 'appi-your-rights',
    categoryId: 'appi',
    titleJa: 'あなたのデータに関する権利（APPI）',
    titleEn: 'Your rights under APPI',
    assetPath: 'assets/jp/help/appi-your-rights.md',
  ),
  HelpArticle(
    id: 'appi-data-export',
    categoryId: 'appi',
    titleJa: 'データをダウンロードする（データ請求）',
    titleEn: 'Export your personal data',
    assetPath: 'assets/jp/help/appi-data-export.md',
  ),
  HelpArticle(
    id: 'appi-account-deletion',
    categoryId: 'appi',
    titleJa: 'アカウントを削除する',
    titleEn: 'Delete your account',
    assetPath: 'assets/jp/help/appi-account-deletion.md',
  ),
  // ── 支払い (Payment) ──
  HelpArticle(
    id: 'payment-methods',
    categoryId: 'payment',
    titleJa: '支払い方法',
    titleEn: 'Supported payment methods',
    assetPath: 'assets/jp/help/payment-methods.md',
  ),
  HelpArticle(
    id: 'payment-failure',
    categoryId: 'payment',
    titleJa: '支払いが失敗した場合',
    titleEn: 'When a payment fails',
    assetPath: 'assets/jp/help/payment-failure.md',
  ),
  // ── アカウント (Account) ──
  HelpArticle(
    id: 'account-setup',
    categoryId: 'account',
    titleJa: 'アカウント設定',
    titleEn: 'Account setup',
    assetPath: 'assets/jp/help/account-setup.md',
  ),
  HelpArticle(
    id: 'account-verification',
    categoryId: 'account',
    titleJa: '本人確認（身分証アップロード）',
    titleEn: 'Identity verification',
    assetPath: 'assets/jp/help/account-verification.md',
  ),
  // ── 問い合わせ (Support) ──
  HelpArticle(
    id: 'contact-support',
    categoryId: 'inquiry',
    titleJa: 'サポートに問い合わせる',
    titleEn: 'Contact support',
    assetPath: 'assets/jp/help/contact-support.md',
  ),
];
