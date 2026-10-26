/// JP terms edit section for the listing edit form.
///
/// Wraps [JpMoneyMatrixInput] inside a [DsFormSection] header.
/// Mount in the host/sales listing edit screen when `FeatureFlags.isJapan`.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_rental_terms.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'jp_money_matrix_input.dart';

class JpTermsEditSection extends StatelessWidget {
  const JpTermsEditSection({
    super.key,
    required this.onChanged,
    this.initialTerms,
  });

  final void Function(Map<String, dynamic> values) onChanged;
  final JpRentalTerms? initialTerms;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DsFormSection(
      title: '賃貸条件',
      helper: '敷金・礼金は実額または月数倍率のいずれかを入力してください。',
      children: [
        JpMoneyMatrixInput(
          initialTerms: initialTerms,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
