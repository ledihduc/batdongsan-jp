import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/khai_bao_model.dart';
import 'package:house_booking/features/host/billing/widgets/billing_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/khaibao/providers/khaibao_provider.dart';
import 'package:house_booking/features/host/khaibao/widgets/khaibao_deadline_countdown.dart';
import 'package:house_booking/features/host/khaibao/widgets/khaibao_status_badge.dart';

class KhaiBaoDetailScreen extends StatefulWidget {
  final int recordId;
  const KhaiBaoDetailScreen({super.key, required this.recordId});

  @override
  State<KhaiBaoDetailScreen> createState() => _KhaiBaoDetailScreenState();
}

class _KhaiBaoDetailScreenState extends State<KhaiBaoDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KhaiBaoProvider>().fetchDetail(widget.recordId);
    });
  }

  Future<void> _openPublicForm(KhaiBaoModel r) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/public/khai-bao/${r.publicToken}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await Share.share(url.toString(),
          subject: AppLocalizations.of(context).hKhaibaoShareSubject);
    }
  }

  Future<void> _markDeclared(KhaiBaoModel r) async {
    final l = AppLocalizations.of(context);
    final ok = await context.read<KhaiBaoProvider>().markDeclared(r.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(ok ? l.hKhaibaoDeclaredRecorded : l.hKhaibaoSaveFailed)),
    );
  }

  Future<void> _markSkipped(KhaiBaoModel r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _SkipReasonDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final ok =
        await context.read<KhaiBaoProvider>().markSkipped(r.id, reason.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l.hKhaibaoSkipped : l.hKhaibaoSaveFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prov = context.watch<KhaiBaoProvider>();
    final r = prov.selected;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: billingAppBar(l.hKhaibaoTitle),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : _body(r),
    );
  }

  Widget _body(KhaiBaoModel r) {
    final l = AppLocalizations.of(context);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(r.tenantName ?? '#${r.tenantId}',
                  style: HD.sectionTitle()),
            ),
            KhaiBaoStatusBadge(r.status),
          ],
        ),
        const SizedBox(height: 12),
        if (r.isActionable)
          KhaiBaoDeadlineCountdown(checkInAt: r.checkInAt),
        const SizedBox(height: 12),
        const HDHairline(),
        const SizedBox(height: 12),
        _kv(l.hKhaibaoPhone, r.tenantPhone ?? '—'),
        _kv(l.hKhaibaoRoom, r.roomCode ?? '—'),
        _kv(l.hKhaibaoBuilding, r.buildingName ?? '—'),
        _kv(l.hKhaibaoCheckInDate, fmt.format(r.checkInAt)),
        _kv(l.hKhaibaoLinkExpires, fmt.format(r.publicTokenExpiresAt)),
        if (r.declaredAt != null)
          _kv(l.hKhaibaoDeclaredAt, fmt.format(r.declaredAt!)),
        if (r.isSkipped && r.skipReason != null)
          _kv(l.hKhaibaoSkipReason, r.skipReason!),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _openPublicForm(r),
          icon: const Icon(Icons.open_in_new),
          label: Text(l.hKhaibaoViewForm),
        ),
        const SizedBox(height: 12),
        if (r.isActionable) ...[
          ElevatedButton.icon(
            onPressed: () => _markDeclared(r),
            icon: const Icon(Icons.check),
            label: Text(l.hKhaibaoMarkDeclared),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _markSkipped(r),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(l.hKhaibaoSkipEarlyLeave),
          ),
        ],
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 140,
                child: Text(k, style: HD.caption(color: HD.inkMuted))),
            Expanded(child: Text(v, style: HD.body())),
          ],
        ),
      );
}

class _SkipReasonDialog extends StatefulWidget {
  const _SkipReasonDialog();

  @override
  State<_SkipReasonDialog> createState() => _SkipReasonDialogState();
}

class _SkipReasonDialogState extends State<_SkipReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.hKhaibaoSkipReason),
      content: TextField(
        controller: _ctrl,
        decoration: InputDecoration(hintText: l.hKhaibaoSkipHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: Text(l.hKhaibaoSkip),
        ),
      ],
    );
  }
}
