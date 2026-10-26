import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/empty_state.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/core/permissions/role_guard.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';

import 'dashboard/host_dashboard_tokens.dart';

// ── Confirmations ─────────────────────────────────────────────────────────────

Future<void> confirmDelete(
  BuildContext context,
  HouseModel h,
  HouseProvider hp,
  int userId,
) async {
  final l = AppLocalizations.of(context);
  if (!RoleGuard.enforceHost(context, action: l.hHomeDlgActionDelete)) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: HD.paperRaised,
      title: Text(l.hHomeDlgDeleteTitle, style: HD.sectionTitle()),
      content: Text(l.hHomeDlgDeleteBody(h.title),
          style: HD.body()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel, style: HD.bodyBold(color: HD.inkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.hHomeDlgDeleteConfirm, style: HD.bodyBold(color: HD.negative)),
        ),
      ],
    ),
  );
  if (ok == true) {
    final done = await hp.deleteHouse(h.id!);
    await hp.fetchMyHouses(userId);
    if (!context.mounted) return;
    if (done) {
      AppFeedback.success(context, l.hHomeDlgDeleteSuccess);
    } else {
      AppFeedback.error(context, l.hHomeDlgDeleteFail);
    }
  }
}

Future<void> confirmCloseUnit(
  BuildContext context,
  HouseModel h,
  HouseProvider hp,
  int userId,
) async {
  final l = AppLocalizations.of(context);
  if (!RoleGuard.enforceHost(context, action: l.hHomeDlgActionCloseUnit)) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: HD.paperRaised,
      title: Text(l.hHomeDlgCloseUnitTitle, style: HD.sectionTitle()),
      content: Text(
        l.hHomeDlgCloseUnitBody(h.title),
        style: HD.body(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel, style: HD.bodyBold(color: HD.inkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.hHomeDlgCloseUnitConfirm, style: HD.bodyBold(color: HD.warning)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final done = await hp.closeOneUnit(h.id!);
  await hp.fetchMyHouses(userId);
  if (!context.mounted) return;
  if (done) {
    AppFeedback.success(context, l.hHomeDlgCloseUnitSuccess);
  } else {
    AppFeedback.error(context, l.hHomeDlgCloseUnitFail);
  }
}

Future<void> confirmLock(
  BuildContext context,
  ViewingAppointmentModel b,
  ViewingAppointmentProvider ap,
  int userId,
) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: HD.paperRaised,
      title: Text(l.hHomeDlgLockTitle, style: HD.sectionTitle()),
      content: Text(
        l.hHomeDlgLockBody(
          b.houseTitle ?? l.hHomeDlgLockDefaultHouse,
          b.guestName ?? l.hHomeDlgLockDefaultGuest,
        ),
        style: HD.body(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel, style: HD.bodyBold(color: HD.inkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.hHomeDlgLockConfirm, style: HD.bodyBold(color: HD.positive)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final done = await ap.lockAppointment(b.id!, userId, 'host');
  if (!context.mounted) return;
  if (done) {
    AppFeedback.success(context, l.hHomeDlgLockSuccess);
    Provider.of<HouseProvider>(context, listen: false).fetchMyHouses(userId);
  } else {
    AppFeedback.error(context, l.hHomeDlgLockFail);
  }
}
