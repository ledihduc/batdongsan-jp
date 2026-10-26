import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/preferences_service.dart'
    show PreferencesService;
import 'package:house_booking/l10n/app_localizations.dart';

/// Màn "Bạn đến với vai trò nào?" — hiện NGAY SAU đăng ký thành công
/// (đã cam kết → ma sát ~0). KHÔNG chặn: luôn có "Để sau".
///
/// Dung hoà với browse-first: người chọn "Tìm nhà" (đa số) vẫn browse-first
/// nguyên vẹn; chỉ nhóm CUNG (chủ nhà / đơn vị) được đưa vào đúng luồng sớm —
/// đúng nút thắt thị trường (thiếu nguồn cung).
class ChooseRoleScreen extends StatelessWidget {
  const ChooseRoleScreen({super.key});

  void _goHome(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.roleWelcomeTitle,
        showBack: false,
        actions: [
          TextButton(
            onPressed: () => _goHome(context),
            child: Text(l.roleLater),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HD.s20),
          children: [
            Text(l.roleQuestion,
                style: HD.mastheadItalic(color: HD.ink).copyWith(fontSize: 24)),
            const SizedBox(height: HD.s8),
            Text(
              l.roleSubtitle,
              style: HD.body(size: 14, color: HD.inkMuted),
            ),
            const SizedBox(height: HD.s24),
            // Ai đã tự khai "tôi là đơn vị" ở khảo sát thì thẻ Đơn vị ĐỨNG ĐẦU
            // — hỏi rồi mà vẫn bắt họ dò từ đáy danh sách là phí câu hỏi. KHÔNG
            // tự động bỏ qua màn này: khai ở khảo sát là tín hiệu, bấm ở đây
            // mới là quyết định. Chỉ đổi THỨ TỰ, không nhân đôi thẻ.
            FutureBuilder<bool>(
              future: PreferencesService.instance.hasProviderIntent(),
              builder: (context, snap) {
                final the = <Widget>[
                  _RoleCard(
                    icon: Icons.search,
                    color: HD.accent,
                    title: l.roleSeekerTitle,
                    subtitle: l.roleSeekerSubtitle,
                    onTap: () => _goHome(context),
                  ),
                  _RoleCard(
                    icon: Icons.home_work_outlined,
                    color: HD.positive,
                    title: l.roleHostTitle,
                    subtitle: l.roleHostSubtitle,
                    onTap: () => context.go('/host'),
                  ),
                ];
                return Column(
                  children: [
                    for (var i = 0; i < the.length; i++) ...[
                      if (i > 0) const SizedBox(height: HD.s12),
                      the[i],
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HD.r12),
        child: Container(
          padding: const EdgeInsets.all(HD.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(HD.r8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: HD.body(size: 15, color: HD.ink)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: HD.body(size: 12.5, color: HD.inkMuted)),
                  ]),
            ),
            const Icon(Icons.chevron_right, color: HD.inkMuted),
          ]),
        ),
      ),
    );
  }
}
