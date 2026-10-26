import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/homestay/providers/reservation_provider.dart';
import 'package:house_booking/features/host/homestay/widgets/cancel_policy_display.dart';
import 'package:house_booking/features/host/homestay/widgets/reservation_status_badge.dart';

/// Phase 07 — reservation detail with lifecycle actions: approve / reject /
/// check-in / check-out / cancel. Refund + cancelled_at shown when applicable.
class ReservationDetailScreen extends StatefulWidget {
  const ReservationDetailScreen({super.key, required this.reservationId});

  final int reservationId;

  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReservationProvider>().fetchDetail(widget.reservationId);
    });
  }

  Future<void> _runAction(Future<bool> Function() act, String successMsg) async {
    final l = AppLocalizations.of(context);
    final ok = await act();
    if (!mounted) return;
    final err = context.read<ReservationProvider>().error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? successMsg : (err ?? l.hResvDetError))),
    );
  }

  Future<String?> _askReason(String title) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: l.hResvDetReasonHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(l.hResvDetConfirm),
          ),
        ],
      ),
    );
    return (reason == null || reason.isEmpty) ? null : reason;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hResvDetTitle,
      ),
      body: Consumer<ReservationProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading && prov.selected == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = prov.selected;
          if (r == null) {
            return Padding(
              padding: const EdgeInsets.all(HD.s24),
              child: Text(prov.error ?? l.hResvDetNotFound,
                  style: HD.body(color: HD.negative)),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(HD.s20),
            children: [
              Row(
                children: [
                  Expanded(child: Text(r.guestName, style: HD.masthead())),
                  ReservationStatusBadge(status: r.status),
                ],
              ),
              const SizedBox(height: HD.s12),
              Text('${r.buildingName ?? '—'} • ${r.roomCode ?? '—'}',
                  style: HD.body()),
              const SizedBox(height: HD.s24),
              _detailRow(l.hResvDetCheckIn, r.checkInDate),
              _detailRow(l.hResvDetCheckOut, r.checkOutDate),
              _detailRow(l.hResvDetNights, '${r.nights}'),
              _detailRow(l.hResvDetPhone, r.guestPhone.isEmpty ? '—' : r.guestPhone),
              if (r.guestEmail != null) _detailRow(l.hResvDetEmail, r.guestEmail!),
              _detailRow(l.hResvDetTotal,
                  '${(r.totalAmount / 1000).toStringAsFixed(0)}K VND'),
              if (r.refundAmount != null)
                _detailRow(l.hResvDetRefund,
                    '${(r.refundAmount! / 1000).toStringAsFixed(0)}K VND'),
              if (r.cancelledAt != null)
                _detailRow(l.hResvDetCancelledAt, r.cancelledAt!.toIso8601String()),
              if (r.rejectionReason != null)
                _detailRow(l.hResvDetReason, r.rejectionReason!),
              const SizedBox(height: HD.s24),
              CancelPolicyDisplay(snapshot: r.cancelPolicySnapshot),
              const SizedBox(height: HD.s32),
              ..._actionsFor(r, prov),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label.toUpperCase(), style: HD.eyebrow()),
          ),
          Expanded(child: Text(value, style: HD.body(color: HD.ink))),
        ],
      ),
    );
  }

  List<Widget> _actionsFor(ReservationModel r, ReservationProvider prov) {
    final l = AppLocalizations.of(context);
    final btns = <Widget>[];
    if (r.isPending) {
      btns.add(_actionBtn(l.hResvDetApprove, HD.positive, () async {
        await _runAction(() => prov.approve(r.id), l.hResvDetApproved);
      }));
      btns.add(_actionBtn(l.hResvDetReject, HD.negative, () async {
        final reason = await _askReason(l.hResvDetRejectReason);
        if (reason != null) {
          await _runAction(() => prov.reject(r.id, reason), l.hResvDetRejected);
        }
      }));
    } else if (r.isApproved) {
      btns.add(_actionBtn(l.hResvDetCheckIn, HD.accent, () async {
        await _runAction(() => prov.checkIn(r.id), l.hResvDetCheckedIn);
      }));
    } else if (r.isCheckedIn) {
      btns.add(_actionBtn(l.hResvDetCheckOut, HD.ink, () async {
        await _runAction(() => prov.checkOut(r.id), l.hResvDetCheckedOut);
      }));
    }
    if (r.isActive) {
      btns.add(_actionBtn(l.hResvDetCancel, HD.negative, () async {
        final reason = await _askReason(l.hResvDetCancelReason);
        await _runAction(
            () => prov.cancel(r.id, reason: reason), l.hResvDetCancelled);
      }, outlined: true));
    }
    return btns.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: HD.s12),
          child: b,
        )).toList();
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap,
      {bool outlined = false}) {
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                padding: const EdgeInsets.symmetric(vertical: HD.s12),
              ),
              child: Text(label),
            )
          : FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: HD.s12),
              ),
              child: Text(label),
            ),
    );
  }
}
