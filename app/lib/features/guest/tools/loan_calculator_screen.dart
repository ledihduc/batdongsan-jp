import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/tools_service.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Máy tính vay mua nhà — gọi backend /api/tools/loan-calculator.
/// [initialPrice] = giá BĐS (VND) để prefill khi mở từ trang chi tiết.
class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key, this.initialPrice});

  final int? initialPrice;

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _service = ToolsService();
  late final TextEditingController _priceCtrl;
  final _rateCtrl = TextEditingController(text: '10');

  double _downPct = 30;
  double _years = 20;
  String _method = 'reducing';
  bool _loading = false;
  LoanResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.initialPrice != null ? widget.initialPrice.toString() : '',
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  static String _fmtVnd(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()} đ';
  }

  Future<void> _calculate() async {
    final l = AppLocalizations.of(context);
    final price = int.tryParse(_priceCtrl.text.trim());
    final rate = double.tryParse(_rateCtrl.text.trim().replaceAll(',', '.'));
    if (price == null || price <= 0) {
      setState(() => _error = l.loanInvalidPrice);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.calculateLoan(
        priceVnd: price,
        downPaymentPct: _downPct,
        annualRatePct: rate ?? 10,
        termMonths: (_years * 12).round(),
        method: _method,
      );
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) setState(() => _error = l.loanCalcFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.loanTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label(l.loanHomePrice),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec(l.loanHomePriceHint),
          ),
          const SizedBox(height: 20),
          _label(l.loanDownPayment(_downPct.round())),
          Slider(
            value: _downPct,
            min: 0,
            max: 90,
            divisions: 18,
            activeColor: HD.accent,
            label: '${_downPct.round()}%',
            onChanged: (v) => setState(() => _downPct = v),
          ),
          const SizedBox(height: 8),
          _label(l.loanInterestRate),
          TextField(
            controller: _rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec(l.loanInterestRateHint),
          ),
          const SizedBox(height: 20),
          _label(l.loanTerm(_years.round())),
          Slider(
            value: _years,
            min: 1,
            max: 30,
            divisions: 29,
            activeColor: HD.accent,
            label: l.loanYearsShort(_years.round()),
            onChanged: (v) => setState(() => _years = v),
          ),
          const SizedBox(height: 8),
          _label(l.loanMethod),
          const SizedBox(height: 6),
          Row(
            children: [
              _methodChip('reducing', l.loanMethodReducing),
              const SizedBox(width: 8),
              _methodChip('annuity', l.loanMethodAnnuity),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HD.accent,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _loading ? null : _calculate,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l.loanTitle),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: HD.negative)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _resultCard(_result!),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: HD.ink,
        fontSize: 13,
      ),
    ),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: HD.paperRaised,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: HD.hairline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: HD.hairline),
    ),
  );

  Widget _methodChip(String value, String label) {
    final sel = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? HD.accent : HD.paperRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? HD.accent : HD.hairline),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? Colors.white : HD.ink,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultCard(LoanResult r) {
    final l = AppLocalizations.of(context);
    final monthlyLabel = r.method == 'annuity'
        ? l.loanMonthlyPayment
        : l.loanFirstMonthPayment;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthlyLabel,
            style: const TextStyle(color: HD.inkSoft, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            _fmtVnd(r.headlineMonthly),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: HD.accent,
            ),
          ),
          if (r.method == 'reducing' && r.lastMonthPayment != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l.loanLastMonth(_fmtVnd(r.lastMonthPayment!)),
                style: const TextStyle(color: HD.inkSoft, fontSize: 12),
              ),
            ),
          const Divider(height: 24, color: HD.hairline),
          _row(l.loanPrincipal, _fmtVnd(r.principalVnd)),
          _row(l.loanTotalInterest, _fmtVnd(r.totalInterest)),
          _row(l.loanTotalPayment, _fmtVnd(r.totalPayment)),
          _row(
            l.loanTermLabel,
            l.loanTermValue(r.termMonths, r.termMonths ~/ 12),
          ),
          const SizedBox(height: 10),
          Text(
            l.loanDisclaimer,
            style: const TextStyle(
              color: HD.inkMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: HD.inkSoft, fontSize: 13)),
        Text(
          v,
          style: const TextStyle(
            color: HD.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
