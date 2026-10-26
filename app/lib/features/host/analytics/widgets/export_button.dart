import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/features/host/analytics/services/export_service.dart';
import 'package:house_booking/features/host/analytics/widgets/export_progress_dialog.dart';
import 'package:house_booking/features/host/analytics/widgets/reauth_modal.dart';

/// AppBar action button that drives the full TT200 export flow:
///
/// 1. Shows [ReauthModal] to obtain a short-lived reauth token.
/// 2. Shows [ExportProgressDialog] while downloading.
/// 3. On success: shares the xlsx file via `share_plus`.
/// 4. On error: shows a SnackBar.
///
/// [period] must be in YYYY-MM format (e.g. "2026-06").
///
/// [ExportService] is resolved from the Provider tree (registered in main.dart).
/// Constructor-injected [exportService] is retained for test scaffolding only —
/// production code paths always use the Provider value.
class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.period,
    ExportService? exportService,
  }) : _exportService = exportService; // ignore: prefer_initializing_formals

  final String period;

  /// Non-null only in test scaffolds. Production code uses Provider.
  final ExportService? _exportService;

  Future<void> _onTap(BuildContext context) async {
    // Resolve ExportService from Provider; fall back to injected instance in tests.
    final service = _exportService ??
        Provider.of<ExportService>(context, listen: false);

    // Track export intent before re-auth (user explicitly tapped the button).
    Provider.of<TelemetryService>(context, listen: false)
        .track('export_clicked', props: {'period': period});

    // Step 1: Re-auth modal — returns token or null (user cancelled).
    final token = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReauthModal(exportService: _exportService),
    );

    if (token == null) return; // cancelled

    if (!context.mounted) return;

    // Step 2: Show progress dialog (non-dismissible).
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ExportProgressDialog(),
    );

    try {
      final result = await service.downloadTt200(
        period: period,
        reauthToken: token,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // close progress dialog

      // Step 3: Share the downloaded file.
      await Share.shareXFiles(
        [XFile(result.filePath)],
        text: 'Sổ kế toán TT200 v${result.version}',
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xuất file thất bại: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Xuất sổ kế toán (Bản nháp)',
      child: IconButton(
        key: const Key('export_tt200_btn'),
        icon: const Icon(Icons.file_download),
        onPressed: () => _onTap(context),
      ),
    );
  }
}
