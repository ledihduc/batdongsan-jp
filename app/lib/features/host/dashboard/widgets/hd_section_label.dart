import 'package:flutter/material.dart';
import '../host_dashboard_tokens.dart';

/// Editorial section header — italic serif title sitting on a hairline,
/// optionally with a count chip and a trailing action.
///
/// Pattern: ── SECTION INDEX ─── *Italic title*  [n]            Action →
class HDSectionLabel extends StatelessWidget {
  const HDSectionLabel({
    super.key,
    required this.index,
    required this.title,
    this.count,
    this.action,
  });

  /// Roman numeral / index displayed in the eyebrow rail. Keep short ("I", "II").
  final String index;
  final String title;
  final int? count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: HD.s32,
        bottom: HD.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(index, style: HD.eyebrow(color: HD.accent)),
              const SizedBox(width: HD.s8),
              Expanded(child: Container(height: 1, color: HD.hairline)),
            ],
          ),
          const SizedBox(height: HD.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: HD.s8,
                  children: [
                    Text(title, style: HD.sectionTitle()),
                    if (count != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _CountChip(count: count!),
                      ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: HD.hairline),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        count.toString(),
        style: HD.tabular(color: HD.inkSoft, size: 11),
      ),
    );
  }
}
