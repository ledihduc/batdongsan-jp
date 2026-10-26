/// Unit tests for [kHelpArticles] and [kHelpCategories] catalog.
///
/// Verifies the static catalog is consistent and complete.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/help/help_models.dart';

void main() {
  group('kHelpCategories', () {
    test('contains exactly 6 categories', () {
      expect(kHelpCategories.length, 6);
    });

    test('all category ids are unique', () {
      final ids = kHelpCategories.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all categories have non-empty labels', () {
      for (final cat in kHelpCategories) {
        expect(cat.labelJa.isNotEmpty, isTrue, reason: 'category ${cat.id} missing JA label');
        expect(cat.labelEn.isNotEmpty, isTrue, reason: 'category ${cat.id} missing EN label');
      }
    });
  });

  group('kHelpArticles', () {
    test('contains exactly 14 articles', () {
      expect(kHelpArticles.length, 14);
    });

    test('all article ids are unique', () {
      final ids = kHelpArticles.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all articles have non-empty titles', () {
      for (final article in kHelpArticles) {
        expect(article.titleJa.isNotEmpty, isTrue,
            reason: 'article ${article.id} missing JA title');
        expect(article.titleEn.isNotEmpty, isTrue,
            reason: 'article ${article.id} missing EN title');
      }
    });

    test('all articles reference a valid category', () {
      final categoryIds = kHelpCategories.map((c) => c.id).toSet();
      for (final article in kHelpArticles) {
        expect(
          categoryIds.contains(article.categoryId),
          isTrue,
          reason:
              'article ${article.id} references unknown category: ${article.categoryId}',
        );
      }
    });

    test('all article asset paths start with assets/jp/help/', () {
      for (final article in kHelpArticles) {
        expect(
          article.assetPath.startsWith('assets/jp/help/'),
          isTrue,
          reason: 'article ${article.id} assetPath: ${article.assetPath}',
        );
      }
    });

    test('renewal category has 3 articles', () {
      final renewalArticles =
          kHelpArticles.where((a) => a.categoryId == 'renewal').toList();
      expect(renewalArticles.length, 3);
    });

    test('settlement category has 3 articles', () {
      final settlementArticles =
          kHelpArticles.where((a) => a.categoryId == 'settlement').toList();
      expect(settlementArticles.length, 3);
    });

    test('appi category has 3 articles', () {
      final appiArticles =
          kHelpArticles.where((a) => a.categoryId == 'appi').toList();
      expect(appiArticles.length, 3);
    });

    test('payment category has 2 articles', () {
      final paymentArticles =
          kHelpArticles.where((a) => a.categoryId == 'payment').toList();
      expect(paymentArticles.length, 2);
    });

    test('account category has 2 articles', () {
      final accountArticles =
          kHelpArticles.where((a) => a.categoryId == 'account').toList();
      expect(accountArticles.length, 2);
    });

    test('inquiry category has 1 article', () {
      final inquiryArticles =
          kHelpArticles.where((a) => a.categoryId == 'inquiry').toList();
      expect(inquiryArticles.length, 1);
    });
  });
}
