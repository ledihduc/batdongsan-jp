/// Electronic contract signing screen.
///
/// Shows status pill + attempts to embed CloudSign URL via url_launcher
/// (WebView not available in pubspec — using url_launcher external fallback
/// per spec). Polls status every 5s until terminal.
///
/// Route: /econtracts/:id (GoRoute).
/// API: /api/jp/econtracts (GET by id).
///
/// Note: webview_flutter is NOT in pubspec.yaml. Using url_launcher external
/// open as the primary path. If webview_flutter is added later, replace
/// _openSigning with a WebView widget.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/econtract/models/econtract.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Stub repository interface for eContracts (BE parallel work).
abstract interface class IEcontractRepository {
  Future<Econtract> getById(int econtractId);
}

/// Mock for local FE dev.
class MockEcontractRepository implements IEcontractRepository {
  @override
  Future<Econtract> getById(int econtractId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return Econtract(
      id: econtractId,
      applicationId: 2001,
      status: EcontractStatus.pending,
      signingUrl: 'https://app.cloudsign.jp/documents/mock-doc-id/sign',
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}

class EcontractSigningScreen extends StatefulWidget {
  /// Route: /econtracts/:id
  const EcontractSigningScreen({
    super.key,
    required this.econtractId,
    this.repository,
  });

  final int econtractId;
  final IEcontractRepository? repository;

  @override
  State<EcontractSigningScreen> createState() =>
      _EcontractSigningScreenState();
}

class _EcontractSigningScreenState extends State<EcontractSigningScreen> {
  late final IEcontractRepository _repo;
  Econtract? _contract;
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockEcontractRepository();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contract = await _repo.getById(widget.econtractId);
      if (!mounted) return;
      setState(() {
        _contract = contract;
        _loading = false;
      });
      if (!kTerminalEcontractStatuses.contains(contract.status)) {
        _startPolling();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final contract = await _repo.getById(widget.econtractId);
        if (!mounted) return;
        setState(() => _contract = contract);
        if (kTerminalEcontractStatuses.contains(contract.status)) {
          _pollTimer?.cancel();
        }
      } catch (_) {
        // Continue polling.
      }
    });
  }

  Future<void> _openSigning() async {
    final url = _contract?.signingUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      // External browser — CloudSign does not permit iframe embedding on
      // most plans; url_launcher is the correct fallback per spec.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _downloadSigned() async {
    final url = _contract?.downloadUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: '電子契約', title: l.econtract_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _contract == null
              ? DsEmptyState(
                  icon: Icons.error_outline,
                  title: '契約書が見つかりませんでした',
                )
              : _buildBody(l),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    final c = _contract!;
    final isSigned = c.status == EcontractStatus.signed;
    final isTerminal = kTerminalEcontractStatuses.contains(c.status);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status pill
          Center(
            child: _StatusPill(status: c.status, l: l),
          ),
          const SizedBox(height: 24),
          // Status message + icon
          Center(
            child: Icon(
              isSigned
                  ? Icons.check_circle_rounded
                  : c.status == EcontractStatus.pending
                      ? Icons.edit_document
                      : Icons.cancel_rounded,
              color: isSigned
                  ? Colors.green
                  : c.status == EcontractStatus.pending
                      ? HD.accent
                      : HD.inkMuted,
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          // Status label
          Text(
            _statusLabel(c.status, l),
            style: HD.masthead(size: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Signing note
          if (c.status == EcontractStatus.pending)
            Text(
              l.econtract_signing_note,
              style: HD.body(size: 13)
                  .copyWith(color: HD.inkMuted),
              textAlign: TextAlign.center,
            ),
          // Polling indicator
          if (!isTerminal) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(
                  color: HD.accent, strokeWidth: 2),
            ),
          ],
          const Spacer(),
          // Action buttons
          if (c.status == EcontractStatus.pending &&
              c.signingUrl != null) ...[
            DsButton(
              label: l.econtract_sign_button,
              variant: DsButtonVariant.primary,
              size: DsButtonSize.large,
              expand: true,
              onPressed: _openSigning,
            ),
            const SizedBox(height: 8),
            DsButton(
              label: l.econtract_open_external,
              variant: DsButtonVariant.secondary,
              size: DsButtonSize.compact,
              expand: true,
              onPressed: _openSigning,
            ),
          ],
          if (isSigned && c.downloadUrl != null) ...[
            DsButton(
              label: l.econtract_download_signed,
              variant: DsButtonVariant.primary,
              size: DsButtonSize.large,
              expand: true,
              onPressed: _downloadSigned,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _statusLabel(EcontractStatus s, AppLocalizations l) {
    switch (s) {
      case EcontractStatus.pending:
        return l.econtract_status_pending;
      case EcontractStatus.signed:
        return l.econtract_status_signed;
      case EcontractStatus.expired:
        return l.econtract_status_expired;
      case EcontractStatus.cancelled:
        return l.econtract_status_cancelled;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.l});

  final EcontractStatus status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _forStatus(status, l);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  static (String, Color) _forStatus(EcontractStatus s, AppLocalizations l) {
    switch (s) {
      case EcontractStatus.pending:
        return (l.econtract_status_pending, HD.warning);
      case EcontractStatus.signed:
        return (l.econtract_status_signed, Colors.green);
      case EcontractStatus.expired:
        return (l.econtract_status_expired, HD.inkMuted);
      case EcontractStatus.cancelled:
        return (l.econtract_status_cancelled, HD.accent);
    }
  }
}
