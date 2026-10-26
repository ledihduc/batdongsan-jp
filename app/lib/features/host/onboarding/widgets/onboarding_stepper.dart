import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Horizontal step indicator for host onboarding (3 steps).
class OnboardingStepper extends StatelessWidget {
  const OnboardingStepper({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  final int currentStep; // 1-indexed
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final stepNum = index + 1;
        final isCompleted = stepNum < currentStep;
        final isActive = stepNum == currentStep;
        return Expanded(
          child: Row(
            children: [
              _StepCircle(
                step: stepNum,
                isCompleted: isCompleted,
                isActive: isActive,
              ),
              if (index < totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? HD.positive
                        : HD.hairline,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.step,
    required this.isCompleted,
    required this.isActive,
  });

  final int step;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color bg = isCompleted
        ? HD.positive
        : isActive
            ? HD.ink
            : HD.hairline;
    final Color fg = isCompleted || isActive ? HD.paperRaised : HD.inkMuted;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, size: 14, color: HD.paperRaised)
            : Text('$step', style: HD.bodyBold(color: fg, size: 13)),
      ),
    );
  }
}
