/// Mock classes for planning tests using mocktail.
library;

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:house_booking/data/services/planning_service.dart';

/// Mock [PlanningService] — use in widget and provider tests.
class MockPlanningService extends Mock implements PlanningService {}

/// Fallback registration required by mocktail for [CancelToken].
/// Call [registerFallbacks] in [setUpAll] of any test file.
void registerFallbacks() {
  registerFallbackValue(CancelToken());
}
