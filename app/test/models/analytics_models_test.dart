/// fromJson round-trip tests for all 5 new analytics models.
///
/// JSON fixtures match the schema freeze doc (_analytics_shapes.md).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/data/models/drill_node_model.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/data/models/source_breakdown_model.dart';
import 'package:house_booking/data/models/revenue_report_model.dart';
import 'package:house_booking/data/models/trend_bucket_model.dart';

// ---------------------------------------------------------------------------
// Fixtures — match _analytics_shapes.md exactly
// ---------------------------------------------------------------------------

final _summaryJson = <String, dynamic>{
  'period': {
    'type': 'month',
    'date': '2026-07',
    'start_utc': '2026-06-30T17:00:00+00:00',
    'end_utc': '2026-07-31T17:00:00+00:00',
  },
  'kpis': {
    'gross_revenue': 5000000.0,
    'net_revenue': 4500000.0,
    'refund_total': 500000.0,
    'commission_total': 0.0,
    'occupancy_pct': 72.5,
    'adr': 350000.0,
    'booking_pace': 12,
  },
  'deltas': {
    'gross_revenue_pct': 15.0,
    'net_revenue_pct': null,
    'occupancy_pct_diff': 5.2,
  },
};

final _trendJson = <String, dynamic>{
  'periods': ['2025-08', '2025-09', '2026-07'],
  'current': [0.0, 0.0, 5000000.0],
  'current_net': [0.0, 0.0, 4500000.0],
  'prior': [0.0, 0.0, 3000000.0],
  'prior_net': [0.0, 0.0, 2800000.0],
};

final _heatmapJson = <String, dynamic>{
  'month': '2026-07',
  'days': 31,
  'rooms': [
    {
      'room_id': 101,
      'room_name': 'P.101',
      'building_name': 'Tòa A',
      'cells': [
        {'day': 1, 'status': 'paid'},
        {'day': 2, 'status': 'vacant'},
        {'day': 3, 'status': 'booked'},
        {'day': 4, 'status': 'overdue'},
      ],
    },
  ],
};

final _sourceJson = <String, dynamic>{
  'id': 1,
  'host_id': 42,
  'name': 'Trực tiếp',
  'display_name': 'Trực tiếp',
  'color_hex': '#4CAF50',
  'is_archived': false,
  'created_at': '2026-01-15T08:00:00',
  'updated_at': '2026-06-28T14:30:00',
};

final _archivedSourceJson = <String, dynamic>{
  'id': 2,
  'host_id': 42,
  'name': '__archived_2_Airbnb',
  'display_name': 'Airbnb',
  'color_hex': '#FF5722',
  'is_archived': true,
  'created_at': '2026-01-15T08:00:00',
  'updated_at': '2026-06-28T14:30:00',
};

final _breakdownJson = <String, dynamic>{
  'period': '2026-07',
  'total': 9800000.0,
  'items': [
    {
      'source_id': 1,
      'source_name': 'Trực tiếp',
      'color_hex': '#4CAF50',
      'amount': 5000000.0,
      'pct': 51.0,
    },
    {
      'source_id': null,
      'source_name': 'Khác',
      'color_hex': '#9E9E9E',
      'amount': 1800000.0,
      'pct': 18.4,
    },
  ],
};

final _drillRoomJson = <String, dynamic>{
  'items': [
    {
      'room_id': 101,
      'room_code': 'P.101',
      'room_status': 'occupied',
      'building_id': 1,
      'building_name': 'Tòa A',
    },
  ],
  'total_count': 25,
  'page': 1,
  'page_size': 50,
};

final _drillContractJson = <String, dynamic>{
  'items': [
    {
      'contract_id': 42,
      'start_date': '2026-01-01',
      'end_date': '2026-12-31',
      'status': 'active',
      'monthly_rent': 3000000.0,
    },
  ],
  'total_count': 3,
  'page': 1,
  'page_size': 50,
};

final _drillTenantJson = <String, dynamic>{
  'items': [
    {
      'tenant_id': 201,
      'full_name': 'Nguyễn Văn A',
      'phone': '0912345678',
      'is_primary': true,
      'joined_at': '2026-01-01',
    },
  ],
  'total_count': 2,
  'page': 1,
  'page_size': 50,
};

final _drillInvoiceJson = <String, dynamic>{
  'items': [
    {
      'invoice_id': 501,
      'invoice_number': 'INV-202607-C42',
      'period_start': '2026-07-01',
      'period_end': '2026-07-31',
      'total_amount': 3000000.0,
      'status': 'paid',
      'paid_at': '2026-07-05T10:00:00',
    },
  ],
  'total_count': 7,
  'page': 1,
  'page_size': 50,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AnalyticsSummaryModel.fromJson', () {
    late AnalyticsSummaryModel model;
    setUp(() => model = AnalyticsSummaryModel.fromJson(_summaryJson));

    test('period info parsed correctly', () {
      expect(model.period.type, equals('month'));
      expect(model.period.date, equals('2026-07'));
      expect(model.period.startUtc.isUtc, isTrue);
    });

    test('kpis parsed correctly', () {
      expect(model.kpis.grossRevenue, equals(5000000.0));
      expect(model.kpis.netRevenue, equals(4500000.0));
      expect(model.kpis.refundTotal, equals(500000.0));
      expect(model.kpis.occupancyPct, equals(72.5));
      expect(model.kpis.bookingPace, equals(12));
    });

    test('deltas with null net_revenue_pct', () {
      expect(model.deltas.grossRevenuePct, equals(15.0));
      expect(model.deltas.netRevenuePct, isNull); // AC-02
      expect(model.deltas.occupancyPctDiff, equals(5.2));
    });

    test('missing deltas key returns DeltaBlock with all nulls', () {
      final json = Map<String, dynamic>.from(_summaryJson)..remove('deltas');
      final m = AnalyticsSummaryModel.fromJson(json);
      expect(m.deltas.grossRevenuePct, isNull);
      expect(m.deltas.netRevenuePct, isNull);
    });
  });

  group('RevenueTrendModel.fromJson', () {
    late RevenueTrendModel model;
    setUp(() => model = RevenueTrendModel.fromJson(_trendJson));

    test('periods list parsed', () {
      expect(model.periods, hasLength(3));
      expect(model.periods.first, equals('2025-08'));
      expect(model.periods.last, equals('2026-07'));
    });

    test('current series length matches periods', () {
      expect(model.current, hasLength(3));
      expect(model.current.last, equals(5000000.0));
    });

    test('prior_net parsed', () {
      expect(model.priorNet.last, equals(2800000.0));
    });

    test('empty lists do not throw', () {
      final m = RevenueTrendModel.fromJson({'periods': [], 'current': []});
      expect(m.periods, isEmpty);
      expect(m.current, isEmpty);
    });
  });

  group('OccupancyHeatmapModel.fromJson', () {
    late OccupancyHeatmapModel model;
    setUp(() => model = OccupancyHeatmapModel.fromJson(_heatmapJson));

    test('month and days parsed', () {
      expect(model.month, equals('2026-07'));
      expect(model.days, equals(31));
    });

    test('room row count correct', () {
      expect(model.rooms, hasLength(1));
      expect(model.rooms.first.roomId, equals(101));
      expect(model.rooms.first.buildingName, equals('Tòa A'));
    });

    test('cell statuses parsed correctly', () {
      final cells = model.rooms.first.cells;
      expect(cells[0].status, equals(HeatmapCellStatus.paid));
      expect(cells[1].status, equals(HeatmapCellStatus.vacant));
      expect(cells[2].status, equals(HeatmapCellStatus.booked));
      expect(cells[3].status, equals(HeatmapCellStatus.overdue));
    });

    test('unknown status defaults to vacant', () {
      final m = OccupancyHeatmapModel.fromJson({
        'month': '2026-07',
        'days': 1,
        'rooms': [
          {
            'room_id': 1,
            'room_name': 'P.1',
            'building_name': 'A',
            'cells': [
              {'day': 1, 'status': 'unknown_future_value'},
            ],
          },
        ],
      });
      expect(m.rooms.first.cells.first.status, equals(HeatmapCellStatus.vacant));
    });
  });

  group('RevenueSourceModel.fromJson', () {
    test('active source parses displayName from display_name field', () {
      final model = RevenueSourceModel.fromJson(_sourceJson);
      expect(model.id, equals(1));
      expect(model.hostId, equals(42));
      expect(model.displayName, equals('Trực tiếp'));
      expect(model.name, equals('Trực tiếp'));
      expect(model.colorHex, equals('#4CAF50'));
      expect(model.isArchived, isFalse);
    });

    test('archived source: displayName stripped (backend strips suffix)', () {
      final model = RevenueSourceModel.fromJson(_archivedSourceJson);
      // display_name is already stripped by backend; Flutter just reads it
      expect(model.displayName, equals('Airbnb'));
      expect(model.name, equals('__archived_2_Airbnb')); // raw
      expect(model.isArchived, isTrue);
    });

    test('toJson round-trip preserves all fields', () {
      final model = RevenueSourceModel.fromJson(_sourceJson);
      final json = model.toJson();
      expect(json['id'], equals(1));
      expect(json['display_name'], equals('Trực tiếp'));
      expect(json['is_archived'], isFalse);
    });

    test('missing display_name falls back to name', () {
      final json = Map<String, dynamic>.from(_sourceJson)
        ..remove('display_name');
      final model = RevenueSourceModel.fromJson(json);
      expect(model.displayName, equals('Trực tiếp'));
    });
  });

  group('SourceBreakdownModel.fromJson', () {
    late SourceBreakdownModel model;
    setUp(() => model = SourceBreakdownModel.fromJson(_breakdownJson));

    test('period and total parsed', () {
      expect(model.period, equals('2026-07'));
      expect(model.total, equals(9800000.0));
    });

    test('items count correct', () {
      expect(model.items, hasLength(2));
    });

    test('named source item', () {
      final first = model.items.first;
      expect(first.sourceId, equals(1));
      expect(first.sourceName, equals('Trực tiếp'));
      expect(first.pct, closeTo(51.0, 0.01));
    });

    test('Khác bucket has null sourceId', () {
      final khac = model.items.last;
      expect(khac.sourceId, isNull);
      expect(khac.sourceName, equals('Khác'));
    });
  });

  group('RevenueReportModel.fromJson — Phase 04 extended fields', () {
    test('v1 JSON still parses (backward compat)', () {
      final json = <String, dynamic>{
        'period': 'month',
        'date': '2026-07',
        'total': 3000000.0,
        'breakdown': {'P.101': 3000000.0},
        'by_building': [],
      };
      final model = RevenueReportModel.fromJson(json);
      expect(model.total, equals(3000000.0));
      expect(model.gross, equals(3000000.0)); // falls back to total
      expect(model.deltaPct, isNull);
      expect(model.sourceBreakdown, isEmpty);
    });

    test('v2 JSON with gross_revenue and delta_pct', () {
      final json = <String, dynamic>{
        'period': 'month',
        'date': '2026-07',
        'total': 5000000.0,
        'gross': 5000000.0,
        'net': 4500000.0,
        'commission_total': 0.0,
        'delta_pct': 15.0,
        'source_breakdown': [
          {
            'source_id': 1,
            'source_name': 'Trực tiếp',
            'color_hex': '#4CAF50',
            'amount': 5000000.0,
            'pct': 100.0,
          },
        ],
        'breakdown': {},
        'by_building': [],
      };
      final model = RevenueReportModel.fromJson(json);
      expect(model.gross, equals(5000000.0));
      expect(model.net, equals(4500000.0));
      expect(model.deltaPct, equals(15.0));
      expect(model.sourceBreakdown, hasLength(1));
    });
  });

  group('DrillPage types', () {
    test('RoomListResponse.fromJson', () {
      final resp = RoomListResponse.fromJson(_drillRoomJson);
      expect(resp.totalCount, equals(25));
      expect(resp.items, hasLength(1));
      expect(resp.items.first.roomId, equals(101));
      expect(resp.items.first.roomStatus, equals('occupied'));
    });

    test('ContractByRoomResponse.fromJson', () {
      final resp = ContractByRoomResponse.fromJson(_drillContractJson);
      expect(resp.items.first.contractId, equals(42));
      expect(resp.items.first.monthlyRent, equals(3000000.0));
      expect(resp.items.first.status, equals('active'));
    });

    test('TenantByContractResponse.fromJson', () {
      final resp = TenantByContractResponse.fromJson(_drillTenantJson);
      expect(resp.items.first.tenantId, equals(201));
      expect(resp.items.first.isPrimary, isTrue);
      expect(resp.items.first.fullName, equals('Nguyễn Văn A'));
    });

    test('InvoiceByTenantResponse.fromJson', () {
      final resp = InvoiceByTenantResponse.fromJson(_drillInvoiceJson);
      expect(resp.totalCount, equals(7));
      expect(resp.items.first.invoiceId, equals(501));
      expect(resp.items.first.totalAmount, equals(3000000.0));
      expect(resp.items.first.paidAt, equals('2026-07-05T10:00:00'));
    });

    test('InvoiceByTenantResponse — paidAt null when not paid', () {
      final json = <String, dynamic>{
        'items': [
          {
            'invoice_id': 502,
            'invoice_number': 'INV-X',
            'period_start': '2026-07-01',
            'period_end': '2026-07-31',
            'total_amount': 1000000.0,
            'status': 'pending',
          },
        ],
        'total_count': 1,
        'page': 1,
        'page_size': 50,
      };
      final resp = InvoiceByTenantResponse.fromJson(json);
      expect(resp.items.first.paidAt, isNull);
    });

    test('DrillPage with empty items list', () {
      final resp = RoomListResponse.fromJson({
        'items': [],
        'total_count': 0,
        'page': 1,
        'page_size': 50,
      });
      expect(resp.items, isEmpty);
      expect(resp.totalCount, equals(0));
    });
  });
}
