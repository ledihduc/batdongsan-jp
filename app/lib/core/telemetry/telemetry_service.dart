import 'package:flutter/foundation.dart';

/// Lightweight record representing a single telemetry event.
class TelemetryEvent {
  const TelemetryEvent({
    required this.name,
    required this.props,
    required this.timestamp,
  });

  final String name;
  final Map<String, Object?> props;
  final DateTime timestamp;
}

/// In-memory telemetry service — FIFO queue capped at 100 events.
///
/// MVP: emits to [debugPrint] only. Backend sink deferred to V2.
/// Events are intentionally lightweight (no PII — tenant names, MST excluded).
///
/// Usage:
/// ```dart
/// Provider.of<TelemetryService>(context, listen: false)
///     .track('analytics_opened', props: {'period': 'month'});
/// ```
class TelemetryService {
  static const int _maxQueueSize = 100;

  final List<TelemetryEvent> _queue = [];

  /// Immutable snapshot of the current event queue — for testing.
  List<TelemetryEvent> get events => List.unmodifiable(_queue);

  /// Records [event] with optional [props]. FIFO eviction at [_maxQueueSize].
  void track(String event, {Map<String, Object?> props = const {}}) {
    if (_queue.length >= _maxQueueSize) {
      _queue.removeAt(0); // FIFO: drop oldest
    }
    final entry = TelemetryEvent(
      name: event,
      props: props,
      timestamp: DateTime.now(),
    );
    _queue.add(entry);
    debugPrint('[telemetry] $event $props');
  }

  /// Clears all queued events (test utility).
  void clear() => _queue.clear();
}
