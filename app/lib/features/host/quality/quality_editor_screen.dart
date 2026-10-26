import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/ds_quality_stars.dart';
import 'package:house_booking/data/services/quality_service.dart';

/// Màn chủ nhà khai 5 tiêu chí chất lượng → PUT /api/houses/{id}/quality.
/// Trả về [QualityRating] mới khi lưu thành công (Navigator.pop).
class QualityEditorScreen extends StatefulWidget {
  const QualityEditorScreen({
    super.key,
    required this.houseId,
    this.initial,
  });

  final int houseId;
  final Map<String, bool>? initial;

  @override
  State<QualityEditorScreen> createState() => _QualityEditorScreenState();
}

class _QualityEditorScreenState extends State<QualityEditorScreen> {
  late final Map<String, bool> _criteria = {
    for (final k in kQualityCriteriaLabels.keys) k: widget.initial?[k] ?? false,
  };
  final _service = QualityService();
  bool _saving = false;
  String? _error;

  // Xem trước sao (khớp logic backend: PCCC thiếu → tối đa 3).
  int get _previewStar {
    final met = _criteria.values.where((v) => v).length;
    var star = (1 + met * 0.8).round();
    if (!(_criteria['pccc'] ?? false)) star = star > 3 ? 3 : star;
    return star.clamp(1, 5);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await _service.set(widget.houseId, _criteria);
      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không lưu được: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(title: 'Khai chất lượng nhà'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HD.accentTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                DsQualityStars(value: _previewStar, verified: false, width: 16),
                const SizedBox(width: 12),
                Text('Sao tự khai: $_previewStar/5',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: HD.ink)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Sao chất lượng phản ánh tiện nghi nhà — ảnh hưởng khung giá gợi ý. '
              'Thiếu PCCC sẽ giới hạn tối đa 3 sao.',
              style: TextStyle(color: HD.inkSoft, fontSize: 12),
            ),
          ),
          for (final entry in kQualityCriteriaLabels.entries)
            SwitchListTile(
              activeThumbColor: HD.accent,
              title: Text(entry.value),
              value: _criteria[entry.key] ?? false,
              onChanged: (v) => setState(() => _criteria[entry.key] = v),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: HD.negative)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HD.accent,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Lưu chất lượng'),
          ),
        ],
      ),
    );
  }
}
