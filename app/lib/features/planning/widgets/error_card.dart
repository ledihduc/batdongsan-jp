import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/features/planning/providers/planning_map_provider.dart';

/// Error card overlay (AC-07).
/// Hiển thị thông báo lỗi + nút "Thử lại" (sau 3 lần → message cuối).
/// OUT_OF_BBOX không còn dùng error state — đã chuyển sang SnackBar transient.
class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.errorMessage,
    required this.retryCount,
    this.lastTapLat,
    this.lastTapLng,
  });

  final String errorMessage;
  final int retryCount;

  /// Tọa độ tap cuối — cần để retry đúng điểm.
  final double? lastTapLat;
  final double? lastTapLng;

  bool get _isFinalRetry => retryCount >= 3;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlanningMapProvider>();

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Đóng error card
                  InkWell(
                    onTap: () => provider.clearError(),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isFinalRetry &&
                      lastTapLat != null &&
                      lastTapLng != null)
                    ElevatedButton.icon(
                      onPressed: () => provider.retry(lastTapLat!, lastTapLng!),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Thử lại'),
                    )
                  else
                    TextButton(
                      onPressed: () => provider.clearError(),
                      child: const Text('Đóng'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _displayMessage {
    if (_isFinalRetry) return 'Vui lòng kiểm tra mạng hoặc thử lại sau.';
    return errorMessage;
  }
}
