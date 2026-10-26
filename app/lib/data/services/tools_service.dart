import 'package:house_booking/data/services/api_client.dart';

/// Kết quả máy tính vay từ backend /api/tools/loan-calculator.
class LoanResult {
  LoanResult.fromMap(Map<String, dynamic> m)
    : method = m['method'] as String? ?? 'reducing',
      principalVnd = (m['principal_vnd'] as num?)?.toInt() ?? 0,
      termMonths = (m['term_months'] as num?)?.toInt() ?? 0,
      monthlyPayment = (m['monthly_payment'] as num?)?.toInt(),
      monthlyPrincipal = (m['monthly_principal'] as num?)?.toInt(),
      firstMonthPayment = (m['first_month_payment'] as num?)?.toInt(),
      lastMonthPayment = (m['last_month_payment'] as num?)?.toInt(),
      avgMonthlyPayment = (m['avg_monthly_payment'] as num?)?.toInt(),
      totalPayment = (m['total_payment'] as num?)?.toInt() ?? 0,
      totalInterest = (m['total_interest'] as num?)?.toInt() ?? 0;

  final String method; // 'reducing' | 'annuity'
  final int principalVnd;
  final int termMonths;
  final int? monthlyPayment; // annuity
  final int? monthlyPrincipal; // reducing
  final int? firstMonthPayment; // reducing
  final int? lastMonthPayment; // reducing
  final int? avgMonthlyPayment; // reducing
  final int totalPayment;
  final int totalInterest;

  /// Khoản trả tháng đầu (reducing) hoặc cố định (annuity) — dùng hiển thị chính.
  int get headlineMonthly =>
      method == 'annuity' ? (monthlyPayment ?? 0) : (firstMonthPayment ?? 0);
}

class ToolsService {
  final ApiClient _client = const ApiClient();

  Future<LoanResult> calculateLoan({
    int? amountVnd,
    int? priceVnd,
    double downPaymentPct = 0,
    double annualRatePct = 10,
    int termMonths = 240,
    String method = 'reducing',
  }) async {
    final res = await _client.post(
      '/api/tools/loan-calculator',
      body: {
        if (amountVnd != null) 'amount_vnd': amountVnd,
        if (priceVnd != null) 'price_vnd': priceVnd,
        'down_payment_pct': downPaymentPct,
        'annual_rate_pct': annualRatePct,
        'term_months': termMonths,
        'method': method,
      },
    );
    return LoanResult.fromMap(res);
  }

  /// So sánh nhiều BĐS. Trả về danh sách house dict (tối đa 4, backend giới hạn).
  Future<List<Map<String, dynamic>>> compareHouses(List<int> ids) async {
    final res = await _client.get(
      '/api/tools/compare',
      queryParameters: {'ids': ids.join(',')},
    );
    return List<Map<String, dynamic>>.from(res['houses'] as List? ?? const []);
  }
}
