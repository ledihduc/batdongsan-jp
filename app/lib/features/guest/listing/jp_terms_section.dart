/// JP rental terms section widget for the listing detail screen.
///
/// Displays the chintai money matrix (敷金/礼金/更新料/仲介手数料/管理費) with
/// legally-correct Japanese labels. Mount inside [HouseDetailScreen] when
/// `FeatureFlags.isJapan && listing.jpTerms != null`.
///
/// Route: n/a (embedded section widget).
/// Provider: none — receives data via constructor.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_rental_terms.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class JpTermsSection extends StatelessWidget {
  const JpTermsSection({super.key, required this.terms});

  final JpRentalTerms terms;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _buildRows(context, l);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      color: HD.paperRaised,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.jp_shikikin.split('(').first.trim().isEmpty
                ? '賃貸条件'
                : '賃貸条件',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: HD.ink,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  List<Widget> _buildRows(BuildContext context, AppLocalizations l) {
    final rows = <Widget>[];

    void addRow(String label, String value) {
      rows.add(_TermRow(label: label, value: value));
    }

    addRow(l.jp_monthly_rent, _yen(terms.monthlyRent));

    if (terms.managementFee != null && terms.managementFee! > 0) {
      addRow(l.jp_management_fee, _yen(terms.managementFee!));
    }
    if (terms.kyouekihi != null && terms.kyouekihi! > 0) {
      addRow(l.jp_kyouekihi, _yen(terms.kyouekihi!));
    }
    if (terms.shikikin != null) {
      addRow(l.jp_shikikin, _yen(terms.shikikin!));
    } else if (terms.shikikinMonths != null) {
      addRow(l.jp_shikikin, '${terms.shikikinMonths}ヶ月分');
    }
    if (terms.reikin != null) {
      addRow(l.jp_reikin, _yen(terms.reikin!));
    } else if (terms.reikinMonths != null) {
      addRow(l.jp_reikin, '${terms.reikinMonths}ヶ月分');
    }
    if (terms.hoshoukin != null) {
      addRow(l.jp_hoshou, _yen(terms.hoshoukin!));
    }
    if (terms.koushinryo != null) {
      addRow(l.jp_koushinryo, _yen(terms.koushinryo!));
    } else if (terms.koushinryoMonths != null) {
      addRow(l.jp_koushinryo, '${terms.koushinryoMonths}ヶ月分');
    }
    if (terms.brokerageFeeRate != null) {
      addRow(l.jp_brokerage,
          '${terms.brokerageFeeRate}ヶ月分${terms.taxIncluded ? '（税込）' : ''}');
    }
    if (terms.guaranteeCompanyFee != null && terms.guaranteeCompanyFee! > 0) {
      addRow('保証会社料', _yen(terms.guaranteeCompanyFee!));
    }

    return rows;
  }

  static String _yen(int amount) {
    // Simple ¥ formatter without intl dependency.
    final s = amount.toString();
    final buf = StringBuffer('¥');
    final start = s.length % 3;
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (i - start) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                color: HD.inkMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: HD.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
