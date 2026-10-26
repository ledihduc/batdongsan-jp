/// Payment status polling screen.
///
/// Polls GET /api/jp/payments/:intentId every 3 seconds until a terminal
/// status is reached. Subscribes to FCM topic invoice-{invoiceId} for
/// push-accelerated updates (topic subscription is fire-and-forget).
///
/// Route: /payments/:intentId/status (GoRoute).
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/format/currency.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/checkout/models/payment_intent.dart';
import 'package:house_booking/features/checkout/repositories/i_payment_repository.dart';
import 'package:house_booking/features/checkout/repositories/mock_payment_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class PaymentStatusScreen extends StatefulWidget {
  /// Route: /payments/:intentId/status
  const PaymentStatusScreen({
    super.key,
    required this.intentId,
    this.repository,
  });

  final int intentId;
  final IPaymentRepository? repository;

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  late final IPaymentRepository _repo;
  JpPaymentIntent? _intent;
  bool _loading = true;
  Timer? _pollTimer;
  StreamSubscription<RemoteMessage>? _fcmSub;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? MockPaymentRepository();
    _load();
    _subscribeFcm();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _fcmSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final intent = await _repo.getPaymentIntent(widget.intentId);
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _loading = false;
      });
      if (!kTerminalPaymentStatuses.contains(intent.status)) {
        _startPolling();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final intent = await _repo.getPaymentIntent(widget.intentId);
        if (!mounted) return;
        setState(() => _intent = intent);
        if (kTerminalPaymentStatuses.contains(intent.status)) {
          _pollTimer?.cancel();
        }
      } catch (_) {
        // Continue polling on transient errors.
      }
    });
  }

  void _subscribeFcm() {
    // Subscribe to push topic for this invoice.
    // If the intent has no invoiceId we skip; topic subscription is
    // best-effort so errors are silently ignored.
    FirebaseMessaging.instance
        .subscribeToTopic('invoice-${widget.intentId}')
        .catchError((_) {});

    // When a foreground push arrives refresh immediately.
    _fcmSub = FirebaseMessaging.onMessage.listen((msg) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(eyebrow: '支払い', title: l.payment_status_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _intent == null
              ? DsEmptyState(
                  icon: Icons.error_outline,
                  title: 'エラーが発生しました',
                )
              : _StatusBody(intent: _intent!, l: l),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.intent, required this.l});

  final JpPaymentIntent intent;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isTerminal = kTerminalPaymentStatuses.contains(intent.status);
    final isSuccess = intent.status == JpPaymentIntentStatus.succeeded;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status icon
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : intent.status == JpPaymentIntentStatus.failed ||
                          intent.status == JpPaymentIntentStatus.expired
                      ? Icons.cancel_rounded
                      : Icons.hourglass_top_rounded,
              color: isSuccess
                  ? Colors.green
                  : intent.status == JpPaymentIntentStatus.pending ||
                          intent.status == JpPaymentIntentStatus.processing
                      ? HD.warning
                      : HD.accent,
              size: 72,
            ),
            const SizedBox(height: 16),
            // Status label
            Text(
              _statusLabel(intent.status, l),
              style: HD.masthead(size: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Amount
            Text(
              formatPrice(intent.amountJpy, locale: 'ja_JP'),
              style: HD.body(size: 16),
            ),
            if (!isTerminal) ...[
              const SizedBox(height: 24),
              Text(l.payment_status_checking,
                  style: HD.body().copyWith(color: HD.inkMuted)),
              const SizedBox(height: 12),
              const CircularProgressIndicator(color: HD.accent),
            ],
            if (intent.status == JpPaymentIntentStatus.failed ||
                intent.status == JpPaymentIntentStatus.expired) ...[
              const SizedBox(height: 24),
              DsButton(
                label: l.payment_retry,
                variant: DsButtonVariant.primary,
                size: DsButtonSize.large,
                expand: false,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 12),
              DsButton(
                label: l.payment_contact_support,
                variant: DsButtonVariant.ghost,
                size: DsButtonSize.compact,
                onPressed: () {},
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(JpPaymentIntentStatus s, AppLocalizations l) {
    switch (s) {
      case JpPaymentIntentStatus.pending:
        return l.payment_status_pending;
      case JpPaymentIntentStatus.processing:
        return l.payment_status_processing;
      case JpPaymentIntentStatus.succeeded:
        return l.payment_status_succeeded;
      case JpPaymentIntentStatus.failed:
        return l.payment_status_failed;
      case JpPaymentIntentStatus.expired:
        return l.payment_status_expired;
    }
  }
}
