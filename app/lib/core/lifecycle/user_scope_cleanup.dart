/// Orchestrates cleanup of every user-scoped provider when the auth session
/// changes (logout, actual role change, actor context enter/exit).
///
/// This is data hygiene — not security. Backend still authoritative on every
/// request. The goal: user B on a shared device never observes user A's
/// cached lists/badges when they log in.
///
/// Not invoked on persona toggle (guest↔host UI mode swap) — that's the same
/// auth identity so cached data remains valid (Q5 lock).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/providers/meter_reading_provider.dart';
import 'package:house_booking/features/host/billing/providers/service_fee_provider.dart';
import 'package:house_booking/features/host/homestay/providers/homestay_calendar_provider.dart';
import 'package:house_booking/features/host/homestay/providers/pricing_rule_provider.dart';
import 'package:house_booking/features/host/homestay/providers/reservation_provider.dart';
import 'package:house_booking/features/host/khaibao/providers/khaibao_provider.dart';
import 'package:house_booking/features/host/marketplace/providers/marketplace_provider.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/providers/actor_context_provider.dart';
import 'package:house_booking/providers/approval_provider.dart';
import 'package:house_booking/providers/chat_provider.dart';
import 'package:house_booking/providers/dashboard_provider.dart';
import 'package:house_booking/providers/delegation_provider.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/providers/report_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';
import 'package:provider/provider.dart';

/// Contract for providers that hold user-scoped state and must clear when the
/// active identity changes.
///
/// Implement in the provider directly — no base class, mixin coupling is
/// tighter than necessary and providers already extend [ChangeNotifier].
abstract class UserScoped {
  /// Clear all cached data and reset back to the initial post-construction
  /// state. MUST call `notifyListeners()` if the provider extends
  /// [ChangeNotifier] and had any listeners.
  void resetUserScope();
}

class UserScopeCleanup {
  const UserScopeCleanup(this._context);

  final BuildContext _context;

  /// Clears every user-scoped provider that participates in this session.
  ///
  /// Order: request-context first (ActorContext), then per-feature caches,
  /// then cross-role. Each call is best-effort — a throw in one provider must
  /// not block cleanup of the rest.
  void resetAll() {
    // Actor context first so downstream provider fetches after cleanup don't
    // race an already-invalid delegation header.
    _safeReset(() => _context.read<ActorContextProvider>().clear());

    // Providers that already ship a clear() method.
    _safeReset(() => _context.read<WishlistProvider>().clear());
    _safeReset(() => _context.read<NotificationProvider>().clear());
    _safeReset(() => _context.read<ChatProvider>().clear());

    // Host domain providers (UserScoped).
    _safeReset(() => _context.read<HostProfileProvider>().resetUserScope());
    _safeReset(() => _context.read<HouseProvider>().resetUserScope());
    _safeReset(
        () => _context.read<ViewingAppointmentProvider>().resetUserScope());
    _safeReset(() => _context.read<BuildingProvider>().resetUserScope());
    _safeReset(() => _context.read<RoomProvider>().resetUserScope());
    _safeReset(() => _context.read<ContractProvider>().resetUserScope());

    // Billing / khai báo.
    _safeReset(() => _context.read<InvoiceProvider>().resetUserScope());
    _safeReset(() => _context.read<ServiceFeeProvider>().resetUserScope());
    _safeReset(() => _context.read<MeterReadingProvider>().resetUserScope());
    _safeReset(() => _context.read<KhaiBaoProvider>().resetUserScope());

    // Analytics.
    _safeReset(() => _context.read<ReportProvider>().resetUserScope());
    _safeReset(() => _context.read<DrillProvider>().resetUserScope());
    _safeReset(() => _context.read<DashboardProvider>().resetUserScope());

    // Homestay + marketplace.
    _safeReset(
        () => _context.read<HomestayCalendarProvider>().resetUserScope());
    _safeReset(() => _context.read<PricingRuleProvider>().resetUserScope());
    _safeReset(() => _context.read<ReservationProvider>().resetUserScope());
    _safeReset(() => _context.read<MarketplaceProvider>().resetUserScope());

    // Delegation + approval.
    _safeReset(() => _context.read<DelegationProvider>().resetUserScope());
    _safeReset(() => _context.read<ApprovalProvider>().resetUserScope());
  }

  void _safeReset(VoidCallback fn) {
    try {
      fn();
    } catch (_) {
      // Provider not in scope or reset failed — non-fatal. Continue cleanup
      // of remaining providers.
    }
  }
}
