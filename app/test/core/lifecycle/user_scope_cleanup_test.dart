/// Verifies every user-scoped provider actually implements the [UserScoped]
/// contract. Contract-level test — no need to spin up widget tree.
///
/// Rationale: the compiler enforces `implements UserScoped` but silently
/// tolerates a `resetUserScope()` that forgets to notify listeners or misses
/// a field. The smoke test here catches accidental removal of the interface.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
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
import 'package:house_booking/providers/approval_provider.dart';
import 'package:house_booking/providers/dashboard_provider.dart';
import 'package:house_booking/providers/delegation_provider.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/report_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';

void main() {
  group('UserScoped contract — every user-scoped provider implements it', () {
    final providers = <String, UserScoped>{
      'HostProfileProvider': HostProfileProvider(),
      'HouseProvider': HouseProvider(),
      'ViewingAppointmentProvider': ViewingAppointmentProvider(),
      'BuildingProvider': BuildingProvider(),
      'RoomProvider': RoomProvider(),
      'ContractProvider': ContractProvider(),
      'InvoiceProvider': InvoiceProvider(),
      'ServiceFeeProvider': ServiceFeeProvider(),
      'MeterReadingProvider': MeterReadingProvider(),
      'KhaiBaoProvider': KhaiBaoProvider(),
      'ReportProvider': ReportProvider(),
      'DrillProvider': DrillProvider(),
      'DashboardProvider': DashboardProvider(),
      'HomestayCalendarProvider': HomestayCalendarProvider(),
      'PricingRuleProvider': PricingRuleProvider(),
      'ReservationProvider': ReservationProvider(),
      'MarketplaceProvider': MarketplaceProvider(),
      'ApprovalProvider': ApprovalProvider(),
      'DelegationProvider': DelegationProvider(),
    };

    for (final entry in providers.entries) {
      test('${entry.key}.resetUserScope() runs without throwing', () {
        expect(entry.value.resetUserScope, returnsNormally);
      });
    }

    test('19 user-scoped providers are covered', () {
      expect(providers.length, 19);
    });
  });
}
