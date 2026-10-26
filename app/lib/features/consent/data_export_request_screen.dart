/// Personal data export request screen.
///
/// User taps "Request export" → BE starts an async job. Screen polls every 5s
/// until status = 'ready', then shows a download link.
///
/// Route: pushed via Navigator from ConsentSettingsScreen.
/// Provider: none — [IConsentRepository] injected by parent.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/domain/repositories/jp/i_consent_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class DataExportRequestScreen extends StatefulWidget {
  const DataExportRequestScreen({super.key, required this.repository});

  final IConsentRepository repository;

  @override
  State<DataExportRequestScreen> createState() =>
      _DataExportRequestScreenState();
}

class _DataExportRequestScreenState extends State<DataExportRequestScreen> {
  bool _requesting = false;
  String? _jobId;
  String _status = '';
  String? _downloadUrl;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestExport() async {
    setState(() => _requesting = true);
    try {
      final jobId = await widget.repository.requestExport();
      setState(() {
        _jobId = jobId;
        _status = 'processing';
        _requesting = false;
      });
      _startPolling(jobId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      AppFeedback.error(context, e.toString());
    }
  }

  void _startPolling(String jobId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final result = await widget.repository.getExportStatus(jobId);
        if (!mounted) return;
        setState(() {
          _status = result.status;
          _downloadUrl = result.downloadUrl;
        });
        if (result.status == 'ready' || result.status == 'failed') {
          _pollTimer?.cancel();
        }
      } catch (_) {
        // Silently continue polling on transient errors.
      }
    });
  }

  Future<void> _openDownload() async {
    if (_downloadUrl == null) return;
    final uri = Uri.parse(_downloadUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: '個人情報', title: l.data_export_title),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.data_export_description, style: HD.body()),
            const SizedBox(height: 24),
            if (_jobId == null) ...[
              DsButton(
                label: l.data_export_submit,
                variant: DsButtonVariant.primary,
                size: DsButtonSize.large,
                expand: true,
                isLoading: _requesting,
                onPressed: _requesting ? null : _requestExport,
              ),
            ] else ...[
              _StatusCard(status: _status, l: l),
              if (_status == 'ready' && _downloadUrl != null) ...[
                const SizedBox(height: 16),
                DsButton(
                  label: l.data_export_ready,
                  variant: DsButtonVariant.primary,
                  size: DsButtonSize.large,
                  expand: true,
                  onPressed: _openDownload,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.l});

  final String status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isReady = status == 'ready';
    final label = isReady ? l.data_export_ready : l.data_export_processing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReady
            ? Colors.green.withOpacity(0.08)
            : HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReady ? Colors.green.withOpacity(0.3) : HD.hairline,
        ),
      ),
      child: Row(
        children: [
          isReady
              ? const Icon(Icons.check_circle_outline, color: Colors.green)
              : const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: HD.accent),
                ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: HD.body())),
        ],
      ),
    );
  }
}
