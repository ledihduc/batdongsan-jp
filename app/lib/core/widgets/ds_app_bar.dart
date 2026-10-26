import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'ds_button.dart';

/// Editorial app bar — paper background, serif title, hairline bottom rule.
/// Optional [eyebrow] sits above the title in small caps.
class DsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DsAppBar({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.onBack,
    this.showBack = true,
    this.background,
    this.foreground,
    this.compact = false,
    this.centerTitle = false,
    this.titleAsSerif = false,
    this.bottom,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;
  final Color? background;
  final Color? foreground;

  /// Widget dưới đáy app bar (thường là [TabBar]). Cộng thêm chiều cao vào
  /// [preferredSize]. Null (mặc định) → app bar 1 dòng như cũ.
  final PreferredSizeWidget? bottom;

  /// If true, drops to 44pt height with a single body-bold title.
  /// Use for nested screens where a full masthead would feel excessive.
  final bool compact;

  final bool centerTitle;

  /// When true, uses the editorial serif [HD.sectionTitle] for the title.
  /// Default sans ([HD.bodyBold]) for scannability; opt into serif per screen.
  final bool titleAsSerif;

  double get _titleHeight {
    final base = compact ? 48.0 : 60.0;
    final extra = eyebrow != null ? 18.0 : 0.0;
    final extraSub = subtitle != null ? 16.0 : 0.0;
    return base + extra + extraSub;
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(_titleHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final showBackButton = showBack && canPop;
    final leadingWidget = leading ??
        (showBackButton
            ? Tooltip(
                message: 'Quay lại',
                child: DsIconButton(
                  icon: Icons.arrow_back,
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              )
            : null);

    final titleStyle = compact || !titleAsSerif
        ? HD.bodyBold(color: foreground, size: 16)
        : HD.sectionTitle(color: foreground);

    return Container(
      decoration: BoxDecoration(
        color: background ?? HD.paper,
        border: const Border(
          bottom: BorderSide(color: HD.hairline, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: HD.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ?leadingWidget,
                    if (leadingWidget == null) const SizedBox(width: HD.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: centerTitle
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (eyebrow != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                eyebrow!.toUpperCase(),
                                style: HD.eyebrow(),
                              ),
                            ),
                          Text(
                            title,
                            style: titleStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle!,
                                style: HD.caption(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}
