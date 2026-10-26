import 'package:flutter/material.dart';

// i18n: App chưa dùng ARB/gen_l10n — dùng const string VI trực tiếp.
// TODO(i18n): Thay bằng AppLocalizations.of(context)!.planningDisclaimer khi setup ARB.
const String _kDisclaimerText =
    'Dữ liệu tham khảo. Vui lòng đối chiếu với cơ quan có thẩm quyền.';

/// Banner disclaimer pháp lý hiển thị ở footer màn hình + bottom sheet (AC-09).
/// Dùng const string nhất quán — không được inline string trùng lặp ở nơi khác.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, this.compact = false});

  /// compact = true: padding nhỏ hơn khi dùng trong bottom sheet.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.amber.shade50,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 4 : 8,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.amber.shade800),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _kDisclaimerText,
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
