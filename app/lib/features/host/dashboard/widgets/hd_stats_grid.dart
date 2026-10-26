import 'package:flutter/material.dart';
import '../host_dashboard_tokens.dart';

/// Asymmetric stat strip — one dominant numeral on the left, two stacked
/// secondary numerals on the right, all separated by hairlines.
///
/// Defies the standard "three equal cards" SaaS dashboard slop.
class HDStatsGrid extends StatelessWidget {
  const HDStatsGrid({
    super.key,
    required this.primary,
    required this.secondaries,
  });

  final HDStat primary;
  final List<HDStat> secondaries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: _PrimaryCell(stat: primary),
            ),
            Container(width: 1, color: HD.hairline),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  for (var i = 0; i < secondaries.length; i++) ...[
                    Expanded(child: _SecondaryCell(stat: secondaries[i])),
                    if (i != secondaries.length - 1)
                      Container(height: 1, color: HD.hairline),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat record — numerals are stored as strings to allow units ("3 tin",
/// "30d", "—") without forcing the caller into formatting gymnastics.
class HDStat {
  const HDStat({
    required this.eyebrow,
    required this.value,
    this.caption,
    this.accent = false,
  });

  final String eyebrow;
  final String value;
  final String? caption;

  /// When true, the numeral is set in [HD.accent] (masthead red).
  final bool accent;
}

class _PrimaryCell extends StatelessWidget {
  const _PrimaryCell({required this.stat});
  final HDStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s24, HD.s20, HD.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(stat.eyebrow, style: HD.eyebrow()),
          Text(
            stat.value,
            style: HD.bigNumeral(
              color: stat.accent ? HD.accent : HD.ink,
              size: 72,
            ),
          ),
          if (stat.caption != null)
            Text(stat.caption!, style: HD.caption()),
        ],
      ),
    );
  }
}

class _SecondaryCell extends StatelessWidget {
  const _SecondaryCell({required this.stat});
  final HDStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(stat.eyebrow, style: HD.eyebrow()),
                if (stat.caption != null) ...[
                  const SizedBox(height: 2),
                  Text(stat.caption!, style: HD.caption()),
                ],
              ],
            ),
          ),
          const SizedBox(width: HD.s12),
          Text(
            stat.value,
            style: HD.bigNumeral(
              color: stat.accent ? HD.accent : HD.ink,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
