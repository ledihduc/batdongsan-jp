/// In-memory mock for [IAdminKpiRepository].
///
/// Returns realistic but fixed KPI numbers for any query.
/// Swap for [ApiAdminKpiRepository] when BE endpoint is live.
library;

import 'package:house_booking/data/models/jp/admin_kpi.dart';
import 'package:house_booking/domain/repositories/jp/i_admin_kpi_repository.dart';

class MockAdminKpiRepository implements IAdminKpiRepository {
  @override
  Future<JpAdminKpi> getKpi({
    required String prefecture,
    required DateTime from,
    required DateTime to,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final prefLabel = prefecture.isEmpty ? '全国' : prefecture;
    return JpAdminKpi(
      activeListings: const KpiMetric(
        value: '142',
        unit: '件',
        delta: '+8',
        deltaPositive: true,
        subtitle: '前期比',
      ),
      pendingApplications: const KpiMetric(
        value: '23',
        unit: '件',
        delta: '-4',
        deltaPositive: false,
        subtitle: '審査待ち',
      ),
      activeContracts: const KpiMetric(
        value: '318',
        unit: '件',
        delta: '+12',
        deltaPositive: true,
        subtitle: '稼働中',
      ),
      avgDaysToSign: const KpiMetric(
        value: '5.2',
        unit: '日',
        delta: '-1.1',
        deltaPositive: true,
        subtitle: '内見〜署名',
      ),
      monthlyRevenueYen: const KpiMetric(
        value: '2,780',
        unit: '万円',
        delta: '+9%',
        deltaPositive: true,
        subtitle: '前月比',
      ),
      prefecture: prefLabel,
      periodLabel: '${from.year}/${from.month.toString().padLeft(2, '0')} – '
          '${to.year}/${to.month.toString().padLeft(2, '0')}',
    );
  }
}
