import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/telemetry/telemetry_service.dart';

void main() {
  group('TelemetryService', () {
    late TelemetryService sut;

    setUp(() => sut = TelemetryService());

    test('starts empty', () {
      expect(sut.events, isEmpty);
    });

    test('track() enqueues a TelemetryEvent with correct fields', () {
      sut.track('analytics_opened', props: {'period': 'month'});

      expect(sut.events, hasLength(1));
      final event = sut.events.first;
      expect(event.name, 'analytics_opened');
      expect(event.props['period'], 'month');
      expect(event.timestamp, isA<DateTime>());
    });

    test('track() without props uses empty map', () {
      sut.track('export_clicked');

      expect(sut.events.first.props, isEmpty);
    });

    test('enqueues multiple events in insertion order', () {
      sut.track('e1');
      sut.track('e2');
      sut.track('e3');

      expect(sut.events.map((e) => e.name).toList(), ['e1', 'e2', 'e3']);
    });

    test('FIFO eviction at 100 events — oldest dropped first', () {
      for (int i = 0; i < 100; i++) {
        sut.track('event_$i');
      }
      expect(sut.events, hasLength(100));
      expect(sut.events.first.name, 'event_0');

      // Adding one more should evict event_0.
      sut.track('event_100');

      expect(sut.events, hasLength(100));
      expect(sut.events.first.name, 'event_1');
      expect(sut.events.last.name, 'event_100');
    });

    test('queue cap is exactly 100', () {
      for (int i = 0; i < 200; i++) {
        sut.track('e$i');
      }
      expect(sut.events, hasLength(100));
    });

    test('events getter returns unmodifiable list', () {
      sut.track('test_event');
      final snapshot = sut.events;
      expect(() => (snapshot as List).add(sut.events.first), throwsUnsupportedError);
    });

    test('clear() empties the queue', () {
      sut.track('e1');
      sut.track('e2');
      sut.clear();
      expect(sut.events, isEmpty);
    });

    test('tracks 5 standard analytics events', () {
      final events = [
        ('analytics_opened', {'period': 'month'}),
        ('kpi_drilled', {'kpi': 'gross'}),
        ('export_clicked', {'period': '2026-06'}),
        ('filter_applied', {'source_ids': <int>[], 'building_ids': <int>[]}),
        ('period_swiped', {'direction': 'prev'}),
      ];

      for (final (name, props) in events) {
        sut.track(name, props: props);
      }

      expect(sut.events, hasLength(5));
      expect(sut.events.map((e) => e.name).toList(), [
        'analytics_opened',
        'kpi_drilled',
        'export_clicked',
        'filter_applied',
        'period_swiped',
      ]);
    });
  });
}
