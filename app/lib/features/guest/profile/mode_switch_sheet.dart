import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';

class ModeOption {
  const ModeOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
}

Future<void> showModeSwitchSheet(
  BuildContext context, {
  required String currentMode,
  required List<ModeOption> options,
  required ValueChanged<String> onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: HD.hairline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chuyển chế độ',
                    style: HD.sectionTitle(size: 22),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Chọn vai trò bạn muốn sử dụng',
              style: HD.body().copyWith(color: HD.inkMuted),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (option) => _ModeOptionTile(
                option: option,
                selected: option.id == currentMode,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSelected(option.id);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _ModeOptionTile extends StatelessWidget {
  const _ModeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ModeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? HD.accentSoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? HD.accent : HD.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: option.tint.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(option.icon, color: option.tint, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.title, style: HD.bodyBold(size: 16)),
                      const SizedBox(height: 3),
                      Text(option.subtitle, style: HD.caption()),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? HD.accent : HD.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
