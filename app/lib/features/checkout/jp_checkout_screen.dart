/// JP Checkout screen — 3 payment method tabs (card / konbini / bank).
///
/// Shows invoice summary at top. On "Pay" → creates PaymentIntent then
/// navigates: konbini → KonbiniVoucherScreen; card/bank → PaymentStatusScreen.
///
/// Route: /checkout/:invoiceId (GoRoute).
/// Provider: none — [IPaymentRepository] injected or defaults to mock.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/format/currency.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/checkout/models/payment_intent.dart';
import 'package:house_booking/features/checkout/repositories/i_payment_repository.dart';
import 'package:house_booking/features/checkout/repositories/mock_payment_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class JpCheckoutScreen extends StatefulWidget {
  /// Route: /checkout/:invoiceId
  const JpCheckoutScreen({
    super.key,
    required this.invoiceId,
    this.repository,
  });

  final int invoiceId;
  final IPaymentRepository? repository;

  @override
  State<JpCheckoutScreen> createState() => _JpCheckoutScreenState();
}

class _JpCheckoutScreenState extends State<JpCheckoutScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final IPaymentRepository _repo;
  JpInvoiceSummary? _invoice;
  bool _loadingInvoice = true;
  bool _paying = false;
  String? _error;

  static const _tabs = [
    JpPaymentMethod.konbini,
    JpPaymentMethod.bankTransfer,
    JpPaymentMethod.card,
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _repo = widget.repository ?? MockPaymentRepository();
    _loadInvoice();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    try {
      final invoice = await _repo.getInvoiceSummary(widget.invoiceId);
      if (mounted) setState(() {
        _invoice = invoice;
        _loadingInvoice = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loadingInvoice = false;
      });
    }
  }

  Future<void> _pay() async {
    final method = _tabs[_tabCtrl.index];
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final intent = await _repo.createPaymentIntent(
        invoiceId: widget.invoiceId,
        method: method,
      );
      if (!mounted) return;
      if (method == JpPaymentMethod.konbini) {
        context.push('/payments/${intent.id}/voucher');
      } else {
        context.push('/payments/${intent.id}/status');
      }
    } catch (e) {
      if (mounted) setState(() {
        _paying = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: '支払い', title: l.checkout_title),
      body: _loadingInvoice
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : Column(
              children: [
                // Invoice summary card
                if (_invoice != null) _InvoiceSummaryCard(invoice: _invoice!, l: l),
                // Tab bar
                TabBar(
                  controller: _tabCtrl,
                  labelColor: HD.accent,
                  unselectedLabelColor: HD.inkMuted,
                  indicatorColor: HD.accent,
                  tabs: [
                    Tab(text: 'コンビニ'),
                    Tab(text: '振込'),
                    Tab(text: 'カード'),
                  ],
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _KonbiniTab(l: l),
                      _BankTransferTab(l: l),
                      _CardTab(l: l),
                    ],
                  ),
                ),
                // Error display
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(_error!,
                        style: HD.body(size: 12)
                            .copyWith(color: HD.accent)),
                  ),
                // Pay button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: DsButton(
                    label: l.econtract_sign_button.contains('署名')
                        ? '支払う'
                        : l.checkout_title,
                    variant: DsButtonVariant.primary,
                    size: DsButtonSize.large,
                    expand: true,
                    isLoading: _paying,
                    onPressed: _paying ? null : _pay,
                  ),
                ),
              ],
            ),
    );
  }
}

class _InvoiceSummaryCard extends StatelessWidget {
  const _InvoiceSummaryCard({required this.invoice, required this.l});

  final JpInvoiceSummary invoice;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.checkout_invoice_summary, style: HD.eyebrow()),
          const SizedBox(height: 8),
          Text(invoice.title, style: HD.body()),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.checkout_total,
                  style: HD.body().copyWith(fontWeight: FontWeight.w600)),
              Text(
                formatPrice(invoice.amountJpy, locale: 'ja_JP'),
                style: HD.masthead(size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KonbiniTab extends StatelessWidget {
  const _KonbiniTab({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.payment_method_konbini,
              style: HD.body().copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(l.konbini_voucher_instructions, style: HD.body(size: 13)),
          const SizedBox(height: 16),
          Text(l.konbini_stores, style: HD.eyebrow()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _StorePill('セブン-イレブン'),
              _StorePill('ファミリーマート'),
              _StorePill('ローソン'),
              _StorePill('ミニストップ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorePill extends StatelessWidget {
  const _StorePill(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HD.hairline),
      ),
      child: Text(name, style: HD.body(size: 12)),
    );
  }
}

class _BankTransferTab extends StatelessWidget {
  const _BankTransferTab({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.payment_method_bank_transfer,
              style: HD.body().copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HD.paperRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HD.hairline),
            ),
            child: Text(l.payment_bank_placeholder,
                style: HD.body(size: 13)),
          ),
        ],
      ),
    );
  }
}

class _CardTab extends StatelessWidget {
  const _CardTab({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.payment_method_card,
              style: HD.body().copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // Stub: Komoju Elements embed is out of scope for this phase.
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HD.paperRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: HD.hairline,
                  style: BorderStyle.values[0]),
            ),
            child: Center(
              child: Text(
                l.payment_card_placeholder,
                style: HD.body(size: 13)
                    .copyWith(color: HD.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
