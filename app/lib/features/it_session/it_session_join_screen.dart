/// IT重説 join screen.
///
/// Shows 宅建士 info + license number, scrollable consent text (recording
/// notice + data retention), re-affirm checkbox, then enables Zoom join button.
///
/// Route: /viewings/:id/it-session (GoRoute).
/// API: /api/jp/it-sessions (GET by viewing_id).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/it_session/models/it_session.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Stub repository interface for IT session (BE parallel work).
abstract interface class IItSessionRepository {
  Future<ItSession> getByViewingId(int viewingId);
}

/// Mock for local FE dev.
class MockItSessionRepository implements IItSessionRepository {
  @override
  Future<ItSession> getByViewingId(int viewingId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return ItSession(
      id: 101,
      viewingId: viewingId,
      takkenShiName: '山田 太郎',
      takkenShiLicenseNumber: '東京都知事(3)第012345号',
      zoomUrl: 'https://zoom.us/j/12345678901',
      scheduledAt: DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      status: 'scheduled',
    );
  }
}

class ItSessionJoinScreen extends StatefulWidget {
  /// Route: /viewings/:viewingId/it-session
  const ItSessionJoinScreen({
    super.key,
    required this.viewingId,
    this.repository,
  });

  final int viewingId;
  final IItSessionRepository? repository;

  @override
  State<ItSessionJoinScreen> createState() => _ItSessionJoinScreenState();
}

class _ItSessionJoinScreenState extends State<ItSessionJoinScreen> {
  late final IItSessionRepository _repo;
  ItSession? _session;
  bool _loading = true;
  bool _consented = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockItSessionRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await _repo.getByViewingId(widget.viewingId);
      if (mounted) setState(() {
        _session = session;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinZoom() async {
    if (_session == null || !_consented) return;
    final uri = Uri.parse(_session!.zoomUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) AppFeedback.error(context, 'Zoomを開けませんでした');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: 'IT重説', title: l.it_session_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _session == null
              ? DsEmptyState(
                  icon: Icons.error_outline,
                  title: 'セッションが見つかりませんでした',
                )
              : _buildBody(l),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    final session = _session!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 宅建士 info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HD.paperRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HD.hairline),
                  ),
                  child: Row(
                    children: [
                      // Photo / avatar placeholder
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HD.hairline,
                        ),
                        child: const Icon(Icons.person_outline,
                            size: 36, color: HD.inkMuted),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.it_session_takken_shi_info,
                                style: HD.eyebrow()),
                            const SizedBox(height: 4),
                            Text(session.takkenShiName,
                                style: HD.masthead(size: 16)),
                            const SizedBox(height: 4),
                            Text(
                              '${l.it_session_license_number}: ${session.takkenShiLicenseNumber}',
                              style: HD.body(size: 12)
                                  .copyWith(color: HD.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Recording notice header
                Text(l.it_session_recording_notice,
                    style: HD.masthead(size: 16)),
                const SizedBox(height: 8),
                // Consent text (scrollable within the ListView)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: HD.paperRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HD.hairline),
                  ),
                  child: Text(
                    l.it_session_consent_notice,
                    style: HD.body(size: 13),
                  ),
                ),
                const SizedBox(height: 16),
                // Consent checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _consented,
                        onChanged: (v) =>
                            setState(() => _consented = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l.it_session_i_consent,
                          style: HD.body(size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_consented)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 34),
                    child: Text(
                      l.it_session_consent_required,
                      style: HD.caption()
                          .copyWith(color: HD.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Sticky Zoom button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: DsButton(
            label: l.it_session_join_zoom,
            variant: DsButtonVariant.primary,
            size: DsButtonSize.large,
            expand: true,
            onPressed: _consented ? _joinZoom : null,
          ),
        ),
      ],
    );
  }
}
