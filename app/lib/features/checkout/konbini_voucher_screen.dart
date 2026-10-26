/// Konbini voucher display screen.
///
/// Shows the voucher number large with copy button, store list,
/// deadline countdown, and payment instructions.
///
/// Route: /payments/:intentId/voucher (GoRoute).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:house_booking/core/format/currency.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/checkout/models/konbini_voucher.dart';
import 'package:house_booking/features/checkout/models/payment_intent.dart';
import 'package:house_booking/features/checkout/repositories/i_payment_repository.dart';
import 'package:house_booking/features/checkout/repositories/mock_payment_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class KonbiniVoucherScreen extends StatefulWidget {
  /// Route: /payments/:intentId/voucher
  const KonbiniVoucherScreen({
    super.key,
    required this.intentId,
    this.repository,
  });

  final int intentId;
  final IPaymentRepository? repository;

  @override
  State<KonbiniVoucherScreen> createState() => _KonbiniVoucherScreenState();
}

class _KonbiniVoucherScreenState extends State<KonbiniVoucherScreen> {
  late final IPaymentRepository _repo;
  KonbiniVoucher? _voucher;
  JpPaymentIntent? _intent;
  bool _loading = true;
  bool _copied = false;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockPaymentRepository();
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.getKonbiniVoucher(widget.intentId),
        _repo.getPaymentIntent(widget.intentId),
      ]);
      if (!mounted) return;
      final voucher = results[0] as KonbiniVoucher;
      final intent = results[1] as JpPaymentIntent;
      final deadline = DateTime.tryParse(voucher.deadline);
      setState(() {
        _voucher = voucher;
        _intent = intent;
        _loading = false;
        if (deadline != null) {
          _timeLeft = deadline.difference(DateTime.now());
        }
      });
      _startCountdown();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  Future<void> _copyNumber() async {
    if (_voucher == null) return;
    await Clipboard.setData(ClipboardData(text: _voucher!.voucherNumber));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2)).then((_) {
      if (mounted) setState(() => _copied = false);
    });
    final l = AppLocalizations.of(context);
    AppFeedback.success(context, l.konbini_number_copied);
  }

  String _formatCountdown() {
    final h = _timeLeft.inHours;
    final m = _timeLeft.inMinutes.remainder(60);
    final s = _timeLeft.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: HD.paper,
        appBar: DsAppBar(eyebrow: 'コンビニ払い', title: l.konbini_voucher_title),
        body:
            const Center(child: CircularProgressIndicator(color: HD.accent)),
      );
    }
    if (_voucher == null) {
      return Scaffold(
        backgroundColor: HD.paper,
        appBar: DsAppBar(eyebrow: 'コンビニ払い', title: l.konbini_voucher_title),
        body: DsEmptyState(
          icon: Icons.error_outline,
          title: 'エラーが発生しました',
        ),
      );
    }
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: 'コンビニ払い', title: l.konbini_voucher_title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount
            if (_intent != null) ...[
              Center(
                child: Text(
                  formatPrice(_intent!.amountJpy, locale: 'ja_JP'),
                  style: HD.masthead(size: 32),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Voucher number — large, prominent
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HD.paperRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HD.hairline),
              ),
              child: Column(
                children: [
                  Text(l.konbini_voucher_number, style: HD.eyebrow()),
                  const SizedBox(height: 8),
                  SelectableText(
                    _voucher!.voucherNumber,
                    style: HD.masthead(size: 28)
                        .copyWith(letterSpacing: 4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  DsButton(
                    label: _copied
                        ? l.konbini_number_copied
                        : l.konbini_copy_number,
                    variant: DsButtonVariant.secondary,
                    size: DsButtonSize.compact,
                    onPressed: _copyNumber,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Deadline + countdown
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _timeLeft.inHours < 24
                    ? HD.warning.withOpacity(0.08)
                    : HD.paperRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _timeLeft.inHours < 24
                        ? HD.warning.withOpacity(0.3)
                        : HD.hairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.konbini_voucher_deadline, style: HD.body()),
                  Text(
                    _formatCountdown(),
                    style: HD.masthead(size: 18).copyWith(
                        color: _timeLeft.inHours < 24
                            ? HD.warning
                            : HD.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HD.paperRaised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(l.konbini_voucher_instructions,
                  style: HD.body(size: 13)),
            ),
            const SizedBox(height: 16),
            // Accepted stores
            Text(l.konbini_stores, style: HD.eyebrow()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _voucher!.acceptedStores
                  .map((s) => Chip(label: Text(konbiniStoreName(s))))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
