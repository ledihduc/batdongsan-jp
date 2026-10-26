import 'package:flutter/material.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/ds_quality_stars.dart';
import 'package:house_booking/data/services/quality_service.dart';
import 'package:house_booking/features/host/quality/quality_editor_screen.dart';

/// Card "Chất lượng cơ sở" trên trang chi tiết tin nhà trọ.
/// Fetch GET /quality; hiển thị vạch terracotta + 5 tiêu chí ✓/✗ + gợi ý giá.
/// Tách bạch hoàn toàn với khối review (sao vàng) để không nhầm.
/// Chủ tin thấy nút "Khai/Cập nhật chất lượng".
class QualityCard extends StatefulWidget {
  const QualityCard({super.key, required this.houseId, required this.isOwner});

  final int houseId;
  final bool isOwner;

  @override
  State<QualityCard> createState() => _QualityCardState();
}

class _QualityCardState extends State<QualityCard> {
  final _service = QualityService();
  QualityRating? _rating;
  bool _loading = true;
  bool _verifRequested = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _service.get(widget.houseId);
      if (mounted) {
        setState(() {
          _rating = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _fmtVnd(int v) {
    final s = v.abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '$b đ';
  }

  Future<void> _openEditor() async {
    final res = await Navigator.push<QualityRating>(
      context,
      MaterialPageRoute(
        builder: (_) => QualityEditorScreen(
          houseId: widget.houseId,
          initial: _rating?.criteria,
        ),
      ),
    );
    if (res != null && mounted) setState(() => _rating = res);
  }

  Future<void> _requestVerification() async {
    final l = AppLocalizations.of(context);
    try {
      await _service.requestVerification(widget.houseId);
      if (mounted) {
        setState(() => _verifRequested = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.qualityVerifSubmitted)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.qualityRequestFailed(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) return const SizedBox.shrink();
    final r = _rating;
    final hasRating = r?.hasRating ?? false;

    // Chưa khai + không phải chủ → ẩn hẳn (tránh nhiễu).
    if (!hasRating && !widget.isOwner) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HD.accentTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.qualityTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: HD.ink,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              if (hasRating)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (r!.isVerified ? HD.accent : HD.inkMuted).withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.isVerified ? l.qualityVerified : l.qualitySelfDeclared,
                    style: TextStyle(
                      fontSize: 11,
                      color: r.isVerified ? HD.accent : HD.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.qualitySubtitle,
            style: const TextStyle(color: HD.inkSoft, fontSize: 12),
          ),
          if (hasRating) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                DsQualityStars(
                  value: r!.star!,
                  verified: r.isVerified,
                  width: 16,
                ),
                const SizedBox(width: 10),
                Text(
                  l.qualityStarRating(r.star!),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HD.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final e in kQualityCriteriaLabels.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      (r.criteria[e.key] ?? false)
                          ? Icons.check_circle
                          : Icons.remove_circle_outline,
                      size: 16,
                      color: (r.criteria[e.key] ?? false)
                          ? HD.positive
                          : HD.inkMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.value,
                      style: const TextStyle(fontSize: 13, color: HD.ink),
                    ),
                  ],
                ),
              ),
            if (r.suggestedPrice != null) ...[
              const SizedBox(height: 8),
              Text(
                l.qualitySuggestedPrice(_fmtVnd(r.suggestedPrice!)),
                style: const TextStyle(
                  fontSize: 12,
                  color: HD.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.qualityNotDeclared,
                style: const TextStyle(color: HD.inkMuted, fontSize: 13),
              ),
            ),
          if (widget.isOwner) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: HD.accent,
                side: const BorderSide(color: HD.accent),
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(
                hasRating ? l.qualityUpdateButton : l.qualityDeclareButton,
              ),
              onPressed: _openEditor,
            ),
            if (!(r?.isVerified ?? false)) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: HD.accent),
                onPressed: _verifRequested ? null : _requestVerification,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: Text(
                  _verifRequested
                      ? l.qualityVerifRequested
                      : l.qualityRequestVerification,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
