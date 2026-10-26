/// Revenue trend model — mirrors GET /api/host/analytics/revenue-trend response.
///
/// JSON contract frozen in _analytics_shapes.md §2.
/// Always 12 elements per series; missing periods are zero-filled by backend.
class RevenueTrendModel {
  /// ISO period keys matching [PeriodType]: "YYYY-MM" for month, "YYYY" for year.
  final List<String> periods;

  /// Gross revenue for the current 12-period window ending at anchor.
  final List<double> current;

  /// Net revenue for the current 12-period window.
  final List<double> currentNet;

  /// Gross revenue for the same 12 periods from the prior year.
  final List<double> prior;

  /// Net revenue for the same 12 periods from the prior year.
  final List<double> priorNet;

  const RevenueTrendModel({
    required this.periods,
    required this.current,
    required this.currentNet,
    required this.prior,
    required this.priorNet,
  });

  factory RevenueTrendModel.fromJson(Map<String, dynamic> json) {
    List<double> parseDoubleList(String key) {
      return (json[key] as List? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return RevenueTrendModel(
      periods: (json['periods'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      current: parseDoubleList('current'),
      currentNet: parseDoubleList('current_net'),
      prior: parseDoubleList('prior'),
      priorNet: parseDoubleList('prior_net'),
    );
  }
}
