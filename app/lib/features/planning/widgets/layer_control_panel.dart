import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/planning/providers/planning_map_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Điều khiển lớp quy hoạch: bật/tắt + thanh độ mờ DỌC bám mép phải bản đồ.
///
/// Trước đây panel này thu gọn thành một icon, phải bấm mở mới chỉnh được độ mờ
/// — trong khi so lớp quy hoạch với ảnh nền là thao tác kéo tới kéo lui liên
/// tục. Nay thanh trượt luôn hiện, nằm dọc theo chiều cao màn hình để không ăn
/// chiều ngang của bản đồ.
class LayerControlPanel extends StatelessWidget {
  const LayerControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Consumer<PlanningMapProvider>(
      builder: (context, provider, _) {
        final visible = provider.planningLayerVisible;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Cao tối đa 45% khoảng trống được cấp, chặn trên 240 để trên màn
            // hình cao thanh trượt không dài lê thê.
            final trackLength = math.min(
              240.0,
              math.max(120.0, constraints.maxHeight * 0.45),
            );
            return Material(
              color: HD.paperRaised.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(HD.r8),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: l.planningLayerToggle,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          icon: Icon(
                            visible ? Icons.layers : Icons.layers_clear_outlined,
                            color: visible ? HD.accent : HD.inkMuted,
                          ),
                          onPressed: () =>
                              provider.toggleLayer(visible: !visible),
                        ),
                      ),
                    ),
                    // Tắt lớp thì thanh trượt vô nghĩa — ẩn đi, chỉ còn nút bật.
                    if (visible) ...[
                      SizedBox(
                        height: trackLength,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              activeTrackColor: HD.accent,
                              thumbColor: HD.accent,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 9,
                              ),
                            ),
                            child: Slider(
                              min: 0,
                              max: 1,
                              // divisions 20 = mỗi bước 5% (AC-05)
                              divisions: 20,
                              value: provider.layerOpacity,
                              label:
                                  '${(provider.layerOpacity * 100).round()}%',
                              semanticFormatterCallback: (v) =>
                                  '${l.planningOpacityLabel} ${(v * 100).round()}%',
                              onChanged: provider.setOpacity,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${(provider.layerOpacity * 100).round()}%',
                          style: HD.caption(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
