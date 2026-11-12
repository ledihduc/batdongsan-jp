/// Tóm tắt action AI chờ xác nhận: tên action, tin (giá ¥/₫, 間取り), giờ xin xem (JST), ghi chú, hạn dùng
/// (Phase 11, F-6, F-7). Ghi chú `note` được gửi nguyên văn cho người phụ trách dưới tên người bấm ⇒ PHẢI hiện
/// trước khi xác nhận để link lạ không gửi được nội dung ẩn (QA H1).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/format/currency.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class AiActionSummaryCard extends StatelessWidget {
  const AiActionSummaryCard({super.key, required this.title, this.listing, this.params = const {}, this.expiresAt});

  final String title;
  final AiPendingListing? listing;
  final Map<String, dynamic> params;
  final DateTime? expiresAt;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmt(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  /// Giờ slot luôn hiển thị theo JST (`yyyy/MM/dd HH:mm`), bất kể múi giờ máy. Chuỗi hỏng ⇒ giữ nguyên.
  static String jst(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : _fmt(d.toUtc().add(const Duration(hours: 9)));
  }

  /// Giá theo tiền tệ tin: `VND` ⇒ ₫ (vi_VN), còn lại ⇒ ¥ (ja_JP) — cùng quy tắc thẻ chat Phase 10.
  static String? priceText(AiPendingListing l) =>
      l.price == null ? null : formatPrice(l.price!, locale: l.currency == 'VND' ? 'vi_VN' : 'ja_JP');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final slots = params['slots'] is List ? (params['slots'] as List).map((e) => '$e').toList() : const <String>[];
    final item = listing;
    final memo = params['note'] is String ? (params['note'] as String).trim() : '';
    const muted = TextStyle(color: HD.inkMuted);
    return DsCard(
      padding: const EdgeInsets.all(HD.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: HD.ink)),
          if (item != null) ...[
            const SizedBox(height: HD.s8),
            Text(item.title, style: const TextStyle(color: HD.ink)),
            if (priceText(item) != null)
              Text(priceText(item)!, style: const TextStyle(fontWeight: FontWeight.w600, color: HD.accent)),
            if (item.layout != null && item.layout!.isNotEmpty) Text(item.layout!, style: muted),
          ],
          if (slots.isNotEmpty) ...[
            const SizedBox(height: HD.s8),
            Text(l.aiConfirmSlots, style: muted),
            for (final s in slots) Text(jst(s), style: const TextStyle(color: HD.ink)),
          ],
          if (memo.isNotEmpty) ...[
            const SizedBox(height: HD.s8),
            Text(l.aiConfirmNote, style: muted),
            Text(memo, style: const TextStyle(color: HD.ink)),
          ],
          if (expiresAt != null) ...[
            const SizedBox(height: HD.s8),
            Text(l.aiConfirmExpiresAt(_fmt(expiresAt!.toLocal())), style: muted),
          ],
        ],
      ),
    );
  }
}
