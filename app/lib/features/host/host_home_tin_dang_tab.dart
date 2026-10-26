import 'package:flutter/material.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/features/host/availability/host_availability_screen.dart';
import 'package:house_booking/features/host/post/post_house_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/providers/house_provider.dart';

import 'dashboard/host_dashboard_tokens.dart';
import 'dashboard/widgets/hd_appointment_row.dart';
import 'dashboard/widgets/hd_listing_row.dart';
import 'dashboard/widgets/hd_section_label.dart';
import 'dashboard/widgets/hd_stats_grid.dart';
import 'host_home_dialogs.dart';

// ── Tab 1: Tin đăng ──────────────────────────────────────────────────────────

class HostHomeTinDangTab extends StatelessWidget {
  const HostHomeTinDangTab({super.key, required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final houseProvider = Provider.of<HouseProvider>(context);
    final appointmentProvider = Provider.of<ViewingAppointmentProvider>(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;

    final myHouses = houseProvider.myHouses;
    final pendingCount = myHouses.where((h) => h.status == 'pending').length;
    final approvedCount = myHouses.where((h) => h.status == 'approved').length;
    final pendingAppointments = appointmentProvider.appointments
        .where((b) => b.status == 'pending')
        .toList();

    return RefreshIndicator(
      color: HD.accent,
      backgroundColor: HD.paperRaised,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          HDStatsGrid(
            primary: HDStat(
              eyebrow: l.hHomeListingsTotalEyebrow,
              value: myHouses.length.toString().padLeft(2, '0'),
              caption: l.hHomeListingsTotalCaption,
            ),
            secondaries: [
              HDStat(
                eyebrow: l.hHomeListingsPendingEyebrow,
                value: pendingCount.toString(),
                caption: l.hHomeListingsPendingCaption,
                accent: pendingCount > 0,
              ),
              HDStat(
                eyebrow: l.hHomeListingsApprovedEyebrow,
                value: approvedCount.toString(),
                caption: l.hHomeListingsApprovedCaption,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HD.s20),
            child: HDSectionLabel(
              index: 'I',
              title: l.hHomeListingsSectionListings,
              count: myHouses.length,
              action: _PostNewLink(onRefresh: onRefresh),
            ),
          ),
          if (myHouses.isEmpty)
            _EmptyMessage(
              line: l.hHomeListingsEmptyListingsLine,
              hint: l.hHomeListingsEmptyListingsHint,
            )
          else
            for (var i = 0; i < myHouses.length; i++)
              HDListingRow(
                house: myHouses[i],
                index: i + 1,
                onTap: () => context.push('/house/${myHouses[i].id}'),
                onEdit: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostHouseScreen(editing: myHouses[i]),
                    ),
                  );
                  await houseProvider.fetchMyHouses(user.id!);
                },
                onDelete: () => confirmDelete(
                    context, myHouses[i], houseProvider, user.id!),
                onCloseOneUnit: () => confirmCloseUnit(
                    context, myHouses[i], houseProvider, user.id!),
                onSchedule: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HostAvailabilityScreen(
                      houseId: myHouses[i].id!,
                      houseTitle: myHouses[i].title,
                    ),
                  ),
                ),
              ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HD.s20),
            child: HDSectionLabel(
              index: 'II',
              title: l.hHomeListingsSectionAppointments,
              count: pendingAppointments.length,
            ),
          ),
          if (pendingAppointments.isEmpty)
            _EmptyMessage(
              line: l.hHomeListingsEmptyAppointmentsLine,
              hint: l.hHomeListingsEmptyAppointmentsHint,
            )
          else
            for (final b in pendingAppointments)
              HDAppointmentRow(
                appointment: b,
                onApprove: () => appointmentProvider.updateStatus(
                    b.id!, 'approved', user.id!, 'host'),
                onReject: () => appointmentProvider.updateStatus(
                    b.id!, 'rejected', user.id!, 'host'),
                onLock: () =>
                    confirmLock(context, b, appointmentProvider, user.id!),
              ),
          const SizedBox(height: HD.s56),
        ],
      ),
    );
  }
}

class _PostNewLink extends StatelessWidget {
  const _PostNewLink({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostHouseScreen()),
        );
        await onRefresh();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s8),
        decoration: BoxDecoration(
          color: HD.ink,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.hHomeListingsPostNew,
              style: HD.eyebrow(color: HD.paperRaised).copyWith(fontSize: 10.5),
            ),
            const SizedBox(width: HD.s8),
            const Icon(Icons.arrow_forward, size: 12, color: HD.paperRaised),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.line, required this.hint});
  final String line;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s8, HD.s20, HD.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line, style: HD.body()),
          const SizedBox(height: HD.s4),
          Text(hint, style: HD.caption()),
        ],
      ),
    );
  }
}
