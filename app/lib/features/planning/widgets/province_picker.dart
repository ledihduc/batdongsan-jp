import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/services/geo_location_service.dart';

import 'package:house_booking/data/models/planning_search_hit_model.dart';
import 'package:house_booking/data/models/province_model.dart';
import 'package:house_booking/features/planning/providers/planning_map_provider.dart';
import 'package:house_booking/features/planning/utils/debouncer.dart';

/// Pill hiển thị tỉnh đang active. Tap → modal bottom sheet với search
/// kết hợp: gõ để tìm cả tỉnh/thành (local) lẫn địa chỉ (Nominatim).
class ProvincePicker extends StatelessWidget {
  const ProvincePicker({
    super.key,
    required this.onPick,
    required this.onAddressPick,
  });

  /// Gọi sau khi user chọn tỉnh — cha fly-to center của tỉnh (zoom rộng).
  final void Function(LatLng center, Province province) onPick;

  /// Gọi khi user chọn một địa chỉ Nominatim — cha fly-to (zoom street level).
  final void Function(LatLng position) onAddressPick;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanningMapProvider>(
      builder: (context, provider, _) {
        final l = AppLocalizations.of(context);
        final p = provider.selectedProvince;
        final label = p?.name ?? l.planProvSelectHint;
        final hasTiles = p?.hasTiles ?? false;
        final iconData = p == null
            ? Icons.search
            : (hasTiles ? Icons.layers : Icons.location_city);
        return Material(
          color: Colors.white,
          elevation: 3,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openSheet(context, provider),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 16,
                    color: hasTiles
                        ? HD.accent
                        : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      size: 18, color: Colors.grey.shade700),
                  if (p != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => provider.setSelectedProvince(null),
                      child: Icon(Icons.close,
                          size: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSheet(
    BuildContext context,
    PlanningMapProvider provider,
  ) async {
    final result = await showModalBottomSheet<Province>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ProvinceSheet(
        provider: provider,
        onAddressPick: onAddressPick,
      ),
    );
    if (result != null) {
      provider.setSelectedProvince(result);
      onPick(LatLng(result.lat, result.lng), result);
    }
  }
}

class _ProvinceSheet extends StatefulWidget {
  const _ProvinceSheet({
    required this.provider,
    required this.onAddressPick,
  });

  final PlanningMapProvider provider;
  final void Function(LatLng position) onAddressPick;

  @override
  State<_ProvinceSheet> createState() => _ProvinceSheetState();
}

class _ProvinceSheetState extends State<_ProvinceSheet> {
  final _ctrl = TextEditingController();
  final _debouncer = Debouncer();
  final _geo = const GeoLocationService();
  bool _loading = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  Future<void> _pickCurrentLocation() async {
    setState(() {
      _locating = true;
      _loading = true;
    });

    try {
      final res = await _geo.getCurrentLocation();
      if (res.isOk && res.lat != null && res.lng != null) {
        final hit = await widget.provider.reverseGeocode(res.lat!, res.lng!);
        if (hit != null && mounted) {
          _onAddressTap(hit);
          return;
        }
      }
      
      if (mounted) {
        String msg = "Không thể xác định vị trí hiện tại.";
        if (res.status == GeoLocationStatus.serviceOff) {
          msg = "Dịch vụ định vị trên thiết bị đang tắt.";
        } else if (res.status == GeoLocationStatus.denied || res.status == GeoLocationStatus.deniedForever) {
          msg = "Ứng dụng chưa được cấp quyền định vị.";
        } else if (res.status == GeoLocationStatus.outOfVietnam) {
          msg = "Vị trí của bạn đang ở ngoài Việt Nam.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi xảy ra khi lấy vị trí.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    setState(() => _loading = true);
    final trimmed = q.trim();

    // Province search luôn chạy — empty query trả full 63 tỉnh.
    final futures = <Future<void>>[
      widget.provider.searchProvinces(trimmed),
    ];
    if (trimmed.length >= 3) {
      // Nominatim chỉ trigger từ 3 ký tự (rate-limit friendly).
      futures.add(widget.provider.searchSuggest(trimmed));
    } else if (widget.provider.searchHits.isNotEmpty) {
      // Clear address hits còn sót từ query dài trước đó.
      widget.provider.searchSuggest('');
    }

    await Future.wait(futures);
    if (mounted) setState(() => _loading = false);
  }

  void _onChanged(String q) {
    _debouncer.run(() => _runSearch(q));
  }

  void _onAddressTap(SearchHit hit) {
    final valid = widget.provider.selectHit(hit);
    Navigator.pop(context);
    if (valid) {
      widget.onAddressPick(LatLng(hit.lat, hit.lon));
    }
    // Nếu invalid (ngoài bbox VN) → provider đã bump outOfBboxTick,
    // map screen tự show SnackBar qua Consumer.
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
        // Modal sheets sống ngoài Provider tree của PlanningMapScreen
        // → không dùng Consumer<PlanningMapProvider> được. ListenableBuilder
        // subscribe trực tiếp vào reference widget.provider mà cha truyền vào.
        child: ListenableBuilder(
          listenable: widget.provider,
          builder: (context, _) {
            final provinceHits = widget.provider.provinceHits;
            final addressHits = widget.provider.searchHits;
            final isQuerying = _ctrl.text.trim().isNotEmpty;
            final hasResults =
                provinceHits.isNotEmpty || addressHits.isNotEmpty;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        l.planProvTitle,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l.planProvSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onChanged,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, color: HD.accent),
                  title: const Text(
                    "Sử dụng vị trí hiện tại",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: HD.accent,
                    ),
                  ),
                  onTap: _locating ? null : _pickCurrentLocation,
                ),
                const Divider(height: 1),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                Expanded(
                  child: !hasResults
                      ? Center(
                          child: Text(
                            isQuerying
                                ? l.planProvNoResults
                                : l.planProvEmptyPrompt,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            if (provinceHits.isNotEmpty) ...[
                              _sectionHeader(l.planProvSectionProvince),
                              for (final p in provinceHits) _provinceTile(p),
                            ],
                            if (addressHits.isNotEmpty) ...[
                              _sectionHeader(l.planProvSectionAddress),
                              for (final h in addressHits) _addressTile(h),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      color: Colors.grey.shade50,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _provinceTile(Province p) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(
        p.hasTiles ? Icons.layers : Icons.location_city,
        color:
            p.hasTiles ? HD.accent : Colors.grey.shade500,
        size: 22,
      ),
      title: Text(
        p.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        p.hasTiles
            ? l.planProvHasOverlay
            : l.planProvNoOverlay,
        style: TextStyle(
          color: p.hasTiles ? Colors.green.shade700 : Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(context, p),
    );
  }

  Widget _addressTile(SearchHit hit) {
    return ListTile(
      leading: Icon(Icons.place_outlined,
          color: Colors.grey.shade600, size: 22),
      title: Text(
        hit.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      onTap: () => _onAddressTap(hit),
      minVerticalPadding: 8,
    );
  }
}
