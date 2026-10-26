import 'package:flutter/material.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/ds_quality_stars.dart';
import 'package:house_booking/data/services/quality_service.dart';

/// Hàng đợi thẩm định chất lượng (admin/thẩm-định-viên).
/// Xem yêu cầu → gắn verified_star sau khi kiểm tra thực tế.
class VerificationQueueScreen extends StatefulWidget {
  const VerificationQueueScreen({super.key});

  @override
  State<VerificationQueueScreen> createState() =>
      _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends State<VerificationQueueScreen> {
  final _service = QualityService();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.verificationQueue();
      if (mounted) setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = l.adminVerifLoadError(e.toString());
        _loading = false;
      });
    }
  }

  Future<void> _complete(Map<String, dynamic> row) async {
    final l = AppLocalizations.of(context);
    final star = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int selected = 3;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text(l.adminVerifRateDialogTitle(
                row['house_title'] ?? l.adminVerifProperty)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DsQualityStars(value: selected, verified: true, width: 20),
                Slider(
                  value: selected.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: l.adminVerifStarsLabel(selected),
                  activeColor: HD.accent,
                  onChanged: (v) => setD(() => selected = v.round()),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l.cancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: HD.accent),
                onPressed: () => Navigator.pop(ctx, selected),
                child: Text(l.adminVerifConfirm),
              ),
            ],
          ),
        );
      },
    );
    if (star == null) return;
    try {
      await _service.completeVerification(row['id'] as int, star);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.adminVerifRatedToast)),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.adminVerifError(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.adminVerifTitle),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _rows.isEmpty
                  ? Center(child: Text(l.adminVerifEmpty))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final r = _rows[i];
                          return Card(
                            child: ListTile(
                              title: Text('${r['house_title'] ?? l.adminVerifProperty} '
                                  '(#${r['house_id']})'),
                              subtitle: Text(l.adminVerifSubtitle(
                                  '${r['status']}', '${r['created_at'] ?? ''}')),
                              trailing: FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: HD.accent),
                                onPressed: () => _complete(r),
                                child: Text(l.adminVerifVerifyButton),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
