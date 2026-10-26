/// Tests that all Phase 03 ARB keys are present in the JA locale.
///
/// Verifies: renewal, settlement, KPI dashboard, account deletion, enhanced facet keys.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> loadL10n(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
  }

  group('P3 renewal keys (JA)', () {
    testWidgets('jp_renewal_* keys are non-empty', (tester) async {
      await loadL10n(tester);
      expect(l.jp_renewal_eyebrow, isNotEmpty);
      expect(l.jp_renewal_title, isNotEmpty);
      expect(l.jp_renewal_contract_summary, isNotEmpty);
      expect(l.jp_renewal_property, isNotEmpty);
      expect(l.jp_renewal_room, isNotEmpty);
      expect(l.jp_renewal_current_term_end, isNotEmpty);
      expect(l.jp_renewal_new_term_end, isNotEmpty);
      expect(l.jp_renewal_total_fee, isNotEmpty);
      expect(l.jp_renewal_confirm_cta, isNotEmpty);
      expect(l.jp_renewal_decline_cta, isNotEmpty);
      expect(l.jp_renewal_confirm_title, isNotEmpty);
      expect(l.jp_renewal_confirm_notice, isNotEmpty);
      expect(l.jp_renewal_confirm_submit, isNotEmpty);
      expect(l.jp_renewal_status_confirmed, isNotEmpty);
      expect(l.jp_renewal_status_declined, isNotEmpty);
    });
  });

  group('P3 settlement keys (JA)', () {
    testWidgets('jp_settlement_* keys are non-empty', (tester) async {
      await loadL10n(tester);
      expect(l.jp_settlement_eyebrow, isNotEmpty);
      expect(l.jp_settlement_owner_title, isNotEmpty);
      expect(l.jp_settlement_tenant_title, isNotEmpty);
      expect(l.jp_settlement_deposit_summary, isNotEmpty);
      expect(l.jp_settlement_property, isNotEmpty);
      expect(l.jp_settlement_room, isNotEmpty);
      expect(l.jp_settlement_tenant, isNotEmpty);
      expect(l.jp_settlement_deductions, isNotEmpty);
      expect(l.jp_settlement_no_deductions, isNotEmpty);
      expect(l.jp_settlement_add_deduction, isNotEmpty);
      expect(l.jp_settlement_remove_deduction, isNotEmpty);
      expect(l.jp_settlement_deduction_item, isNotEmpty);
      expect(l.jp_settlement_deduction_title, isNotEmpty);
      expect(l.jp_settlement_deduction_amount, isNotEmpty);
      expect(l.jp_settlement_deduction_photos, isNotEmpty);
      expect(l.jp_settlement_net_refund, isNotEmpty);
      expect(l.jp_settlement_submit_to_tenant, isNotEmpty);
      expect(l.jp_settlement_accept_cta, isNotEmpty);
      expect(l.jp_settlement_dispute_cta, isNotEmpty);
      expect(l.jp_settlement_dispute_title, isNotEmpty);
      expect(l.jp_settlement_dispute_description, isNotEmpty);
      expect(l.jp_settlement_dispute_reason_label, isNotEmpty);
      expect(l.jp_settlement_dispute_submit, isNotEmpty);
      expect(l.jp_settlement_status_accepted, isNotEmpty);
      expect(l.jp_settlement_status_disputed, isNotEmpty);
    });
  });

  group('P3 KPI keys (JA)', () {
    testWidgets('jp_kpi_* keys are non-empty', (tester) async {
      await loadL10n(tester);
      expect(l.jp_kpi_eyebrow, isNotEmpty);
      expect(l.jp_kpi_dashboard_title, isNotEmpty);
      expect(l.jp_kpi_prefecture_label, isNotEmpty);
      expect(l.jp_kpi_all_japan, isNotEmpty);
      expect(l.jp_kpi_active_listings, isNotEmpty);
      expect(l.jp_kpi_pending_applications, isNotEmpty);
      expect(l.jp_kpi_active_contracts, isNotEmpty);
      expect(l.jp_kpi_avg_days_to_sign, isNotEmpty);
      expect(l.jp_kpi_monthly_revenue, isNotEmpty);
    });
  });

  group('P3 account deletion keys (JA)', () {
    testWidgets('jp_deletion_* keys are non-empty', (tester) async {
      await loadL10n(tester);
      expect(l.jp_deletion_eyebrow, isNotEmpty);
      expect(l.jp_deletion_title, isNotEmpty);
      expect(l.jp_deletion_settings_subtitle, isNotEmpty);
      expect(l.jp_deletion_warning, isNotEmpty);
      expect(l.jp_deletion_bullet_data, isNotEmpty);
      expect(l.jp_deletion_bullet_contracts, isNotEmpty);
      expect(l.jp_deletion_bullet_irreversible, isNotEmpty);
      expect(l.jp_deletion_cooloff_notice, isNotEmpty);
      expect(l.jp_deletion_schedule_cta, isNotEmpty);
      expect(l.jp_deletion_days_remaining, isNotEmpty);
      expect(l.jp_deletion_scheduled_notice, isNotEmpty);
      expect(l.jp_deletion_support_contact, isNotEmpty);
      expect(l.jp_deletion_cancel_cta, isNotEmpty);
      expect(l.jp_deletion_cancel_confirm_title, isNotEmpty);
      expect(l.jp_deletion_cancel_confirm_body, isNotEmpty);
      expect(l.jp_deletion_cancel_no, isNotEmpty);
      expect(l.jp_deletion_cancel_yes, isNotEmpty);
      expect(l.jp_deletion_confirm_sheet_title, isNotEmpty);
      expect(l.jp_deletion_confirm_sheet_body, isNotEmpty);
      expect(l.jp_deletion_confirm_email_label, isNotEmpty);
      expect(l.jp_deletion_confirm_email_hint, isNotEmpty);
      expect(l.jp_deletion_confirm_email_error, isNotEmpty);
      expect(l.jp_deletion_confirm_submit, isNotEmpty);
    });
  });

  group('P3 enhanced facet keys (JA)', () {
    testWidgets('jp_facet_* keys are non-empty', (tester) async {
      await loadL10n(tester);
      expect(l.jp_facet_pets_ok_label, isNotEmpty);
      expect(l.jp_facet_walk_min_label, isNotEmpty);
      expect(l.jp_facet_layout_label, isNotEmpty);
    });

    testWidgets('jp_facet_walk_min_value ICU plural works', (tester) async {
      await loadL10n(tester);
      final value = l.jp_facet_walk_min_value(10);
      expect(value, contains('10'));
    });
  });
}
