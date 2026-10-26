import 'package:flutter/material.dart';
import '../host_dashboard_tokens.dart';

/// Editorial masthead — date eyebrow, large mixed-style greeting, hairline.
///
/// Visual reference: front-page nameplate of a Vietnamese broadsheet. The
/// greeting uses Instrument Serif in regular + italic mix to feel "set in
/// metal" rather than typed.
class HDHeroSection extends StatelessWidget {
  const HDHeroSection({super.key, required this.name});

  final String name;

  /// "Thứ Bảy, 28 tháng 6" — manual Vietnamese formatting so we don't pull in
  /// a heavier locale package than necessary.
  String _today() {
    final now = DateTime.now();
    const weekday = [
      'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm',
      'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
    ];
    final wd = weekday[now.weekday - 1];
    return '$wd · ${now.day} tháng ${now.month} · ${now.year}';
  }

  String _greetingTime() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Khuya muộn';
    if (h < 11) return 'Sáng nay';
    if (h < 14) return 'Trưa nay';
    if (h < 18) return 'Chiều nay';
    return 'Tối nay';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(HD.s20, HD.s24, HD.s20, HD.s20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ANCU365 · BẢN HOST', style: HD.eyebrow(color: HD.accent)),
              const SizedBox(width: HD.s8),
              Expanded(child: Container(height: 1, color: HD.hairline)),
              const SizedBox(width: HD.s8),
              Text(_today(), style: HD.eyebrow()),
            ],
          ),
          const SizedBox(height: HD.s20),
          // Greeting — two-line treatment.
          RichText(
            text: TextSpan(
              style: HD.masthead(),
              children: [
                TextSpan(
                  text: '${_greetingTime()},\n',
                  style: HD.masthead(color: HD.inkSoft),
                ),
                TextSpan(text: 'kính chào '),
                TextSpan(
                  text: name,
                  style: HD.mastheadItalic(color: HD.accent),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: HD.s12),
          Text(
            'Nhật báo vận hành — tổng quan tin đăng, lịch xem, và nhà trọ của anh chị.',
            style: HD.body(),
          ),
        ],
      ),
    );
  }
}
