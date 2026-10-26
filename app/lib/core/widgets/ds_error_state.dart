/// Editorial Cockpit — full-screen error state with optional retry action.
///
/// The 3-state pattern for data-fetching screens:
///
/// ```dart
/// if (loading && items.isEmpty) return const DsRowSkeleton();
/// if (error != null && items.isEmpty) {
///   return DsErrorState(message: error, onRetry: refresh);
/// }
/// if (items.isEmpty) return const DsEmptyState(...);
/// return content;
/// ```
library;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'ds_button.dart';

class DsErrorState extends StatelessWidget {
  const DsErrorState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryLabel = 'Thử lại',
  });

  final String message;
  final String? title;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HD.s40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(HD.s20),
              decoration: const BoxDecoration(
                color: HD.negativeTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: HD.negative),
            ),
            const SizedBox(height: HD.s20),
            Text(
              title ?? 'Đã có lỗi xảy ra',
              textAlign: TextAlign.center,
              style: HD.sectionTitle(size: 20),
            ),
            const SizedBox(height: HD.s8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: HD.body(size: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: HD.s20),
              DsButton(
                label: retryLabel,
                onPressed: onRetry,
                variant: DsButtonVariant.secondary,
                size: DsButtonSize.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen blocking overlay for form submits, uploads, and other
/// non-cancelable long-running actions. Prefer inline spinners inside
/// a button for shorter interactions.
class DsLoadingOverlay extends StatelessWidget {
  const DsLoadingOverlay({
    super.key,
    this.message,
    this.semanticLabel = 'Đang xử lý',
  });

  final String? message;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      child: AbsorbPointer(
        child: ColoredBox(
          color: HD.ink.withValues(alpha: 0.45),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(HD.s24),
              decoration: BoxDecoration(
                color: HD.paperRaised,
                borderRadius: BorderRadius.circular(HD.r12),
                boxShadow: HD.modalShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: HD.accent,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: HD.s16),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: HD.body(size: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
