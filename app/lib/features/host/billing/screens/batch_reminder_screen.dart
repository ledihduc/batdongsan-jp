import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/invoice_model.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';

/// Nhắc nợ HÀNG LOẠT — gom mọi phòng cần nhắc vào 1 màn, nhắc Zalo 1 chạm.
/// Backend đã sẵn: /invoices/needs-reminder + /invoices/{id}/zalo-link.
class BatchReminderScreen extends StatefulWidget {
  const BatchReminderScreen({super.key});

  @override
  State<BatchReminderScreen> createState() => _BatchReminderScreenState();
}

class _BatchReminderScreenState extends State<BatchReminderScreen> {
  final Set<int> _reminded = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoiceProvider>().fetchNeedsReminder();
    });
  }

  static String _fmtVnd(double v) {
    final s = v.round().abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '$b đ';
  }

  Future<bool> _remindOne(NeedsReminderItem item) async {
    final url =
        await context.read<InvoiceProvider>().fetchZaloLink(item.invoiceId);
    if (url == null) return false;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) setState(() => _reminded.add(item.invoiceId));
      return true;
    }
    return false;
  }

  Future<void> _remindAll(List<NeedsReminderItem> items) async {
    setState(() => _busy = true);
    for (final item in items) {
      if (_reminded.contains(item.invoiceId)) continue;
      await _remindOne(item);
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inv = context.watch<InvoiceProvider>();
    final items = inv.needsReminder;
    final total = items.fold<double>(0, (s, e) => s + e.amountDue);

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.hBatchRemindTitle),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: HD.accentTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.hBatchRemindSummary(items.length, _fmtVnd(total)),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: HD.ink)),
                const SizedBox(height: 2),
                Text(l.hBatchRemindHint,
                    style: const TextStyle(fontSize: 12, color: HD.inkSoft)),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(l.hBatchRemindEmpty))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: HD.hairline),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final done = _reminded.contains(it.invoiceId);
                      return ListTile(
                        title: Text('${it.roomCode} · ${it.tenantName}'),
                        subtitle: Text(l.hBatchRemindOverdue(
                            _fmtVnd(it.amountDue), it.daysOverdue)),
                        trailing: done
                            ? Chip(
                                label: Text(l.hBatchRemindDone),
                                backgroundColor: const Color(0x1A2E7D32),
                                labelStyle: const TextStyle(
                                    color: HD.positive, fontSize: 12),
                              )
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: HD.accent,
                                    side: const BorderSide(color: HD.accent)),
                                icon: const Icon(Icons.send_outlined, size: 16),
                                label: Text(l.hBatchRemindRemind),
                                onPressed: () => _remindOne(it),
                              ),
                      );
                    },
                  ),
          ),
          if (items.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: HD.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _busy ? null : () => _remindAll(items),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(_busy
                      ? l.hBatchRemindReminding
                      : l.hBatchRemindRemindAll(
                          items.length - _reminded.length)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
