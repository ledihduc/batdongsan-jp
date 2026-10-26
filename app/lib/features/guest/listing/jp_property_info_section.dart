/// JP property info section widget for the listing detail screen.
///
/// Displays 間取り, 専有面積, 築年数, 構造, 階数, 向き, 入居可能日 and
/// transit access chips. Mount inside [HouseDetailScreen] when
/// `FeatureFlags.isJapan && listing.jpPropertyInfo != null`.
///
/// Route: n/a (embedded section widget).
/// Provider: none — receives data via constructor.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_property_info.dart';
import 'package:house_booking/data/models/jp/jp_station.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class JpPropertyInfoSection extends StatelessWidget {
  const JpPropertyInfoSection({
    super.key,
    required this.propertyInfo,
    this.transitAccesses = const [],
  });

  final JpPropertyInfo propertyInfo;
  final List<JpTransitAccess> transitAccesses;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Container(
      color: HD.paperRaised,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '物件情報',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: HD.ink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _InfoChip(
                icon: Icons.home_outlined,
                label: '${l.jp_layout}: ${propertyInfo.layout}',
              ),
              _InfoChip(
                icon: Icons.square_foot_outlined,
                label:
                    '${l.jp_floor_area}: ${propertyInfo.floorAreaM2.toStringAsFixed(1)}㎡',
              ),
              if (propertyInfo.buildingAgeYears != null)
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: '${l.jp_building_year}: 築${propertyInfo.buildingAgeYears}年',
                ),
              _InfoChip(
                icon: Icons.business_outlined,
                label: '${l.jp_layout.split('(').first.trim() == '' ? '構造' : '構造'}: ${_structureLabel(propertyInfo.structure, l)}',
              ),
              if (propertyInfo.floorNumber != null)
                _InfoChip(
                  icon: Icons.layers_outlined,
                  label:
                      '${l.jp_floor}: ${propertyInfo.floorNumber}階${propertyInfo.totalFloors != null ? '/${propertyInfo.totalFloors}階建' : ''}',
                ),
              if (propertyInfo.orientation != JpOrientation.unknown)
                _InfoChip(
                  icon: Icons.compass_calibration_outlined,
                  label: '向き: ${_orientationLabel(propertyInfo.orientation, l)}',
                ),
              if (propertyInfo.availableFrom != null)
                _InfoChip(
                  icon: Icons.event_available_outlined,
                  label: '${l.jp_available_from}: ${propertyInfo.availableFrom}',
                ),
            ],
          ),
          if (transitAccesses.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: HD.hairline, height: 1),
            const SizedBox(height: 12),
            const Text(
              '交通アクセス',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HD.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            ...transitAccesses.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.train_outlined,
                      size: 16,
                      color: HD.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${t.station.lineName} ${t.station.name}駅',
                      style: const TextStyle(
                        fontSize: 13,
                        color: HD.inkSoft,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '徒歩${t.walkMinutes}分',
                      style: const TextStyle(
                        fontSize: 13,
                        color: HD.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _structureLabel(JpStructure s, AppLocalizations l) {
    switch (s) {
      case JpStructure.rc:
        return l.jp_structure_rc;
      case JpStructure.wood:
        return l.jp_structure_wood;
      case JpStructure.steel:
        return l.jp_structure_steel;
      case JpStructure.src:
        return l.jp_structure_src;
      case JpStructure.unknown:
        return '−';
    }
  }

  static String _orientationLabel(JpOrientation o, AppLocalizations l) {
    switch (o) {
      case JpOrientation.n:
        return l.jp_orientation_n;
      case JpOrientation.ne:
        return l.jp_orientation_ne;
      case JpOrientation.e:
        return l.jp_orientation_e;
      case JpOrientation.se:
        return l.jp_orientation_se;
      case JpOrientation.s:
        return l.jp_orientation_s;
      case JpOrientation.sw:
        return l.jp_orientation_sw;
      case JpOrientation.w:
        return l.jp_orientation_w;
      case JpOrientation.nw:
        return l.jp_orientation_nw;
      case JpOrientation.unknown:
        return '−';
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HD.paperSunken,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: HD.inkMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: HD.inkSoft),
          ),
        ],
      ),
    );
  }
}
