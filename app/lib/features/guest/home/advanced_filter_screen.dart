import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/geo_location_service.dart';

class AdvancedFilterScreen extends StatefulWidget {
  const AdvancedFilterScreen({super.key});

  @override
  State<AdvancedFilterScreen> createState() => _AdvancedFilterScreenState();
}

class _AdvancedFilterScreenState extends State<AdvancedFilterScreen> {
  late double _priceValue;
  final TextEditingController _minAreaController = TextEditingController();
  final TextEditingController _maxAreaController = TextEditingController();

  int? _selectedBedrooms; // null means Any, 1, 2, 3, 4
  int? _tempCategoryId;

  // ── Tìm kiếm nâng cao (0071) ───────────────────────────────────────────────
  // Hướng nhà (phong thuỷ): slug -> nhãn tiếng Việt.
  static const Map<String, String> _directionLabels = {
    'north': 'Bắc',
    'northeast': 'Đông Bắc',
    'east': 'Đông',
    'southeast': 'Đông Nam',
    'south': 'Nam',
    'southwest': 'Tây Nam',
    'west': 'Tây',
    'northwest': 'Tây Bắc',
  };
  final Set<String> _selectedDirections = {};
  bool _trustedOnly = false;
  double _minRating = 0; // 0 = không lọc
  int _minQualityStar = 0; // 0 = không lọc
  String _sort = ''; // '' | rating | trust | price_asc | price_desc

  // ── Khu vực tìm kiếm (địa danh / quanh đây) ────────────────────────────────
  final _geo = const GeoLocationService();
  final TextEditingController _placeController = TextEditingController();
  SearchMode _geoMode = SearchMode.browse;
  double _radiusKm = 3;
  double? _geoLat;
  double? _geoLng;
  bool _locating = false;
  String? _locMsg; // thông báo trạng thái lấy vị trí (lỗi / thành công)

  static const _radii = [1.0, 3.0, 5.0, 10.0];

  @override
  void initState() {
    super.initState();
    final houseProvider = Provider.of<HouseProvider>(context, listen: false);
    _priceValue =
        houseProvider.maxPrice / 1000000; // convert to million scale for slider
    _minAreaController.text = houseProvider.minArea.toStringAsFixed(0);
    _maxAreaController.text = houseProvider.maxArea.toStringAsFixed(0);
    _tempCategoryId = houseProvider.selectedCategoryId;
    _selectedDirections.addAll(houseProvider.directions);
    _trustedOnly = houseProvider.trustedOnly;
    _minRating = houseProvider.minRating;
    _minQualityStar = houseProvider.minQualityStar;
    _sort = houseProvider.sort;
    // Khôi phục trạng thái geo hiện hành để mở lại không mất lựa chọn.
    _geoMode = houseProvider.searchMode;
    _radiusKm = houseProvider.radiusKm;
    _placeController.text = houseProvider.placeQuery;
    _geoLat = houseProvider.nearLat;
    _geoLng = houseProvider.nearLng;
  }

  @override
  void dispose() {
    _minAreaController.dispose();
    _maxAreaController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickCurrentLocation() async {
    final l = AppLocalizations.of(context);
    final ok = await _showLocationPriming();
    if (ok != true) return;
    setState(() {
      _locating = true;
      _locMsg = null;
    });
    final res = await _geo.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.isOk) {
        _geoLat = res.lat;
        _geoLng = res.lng;
        _locMsg = l.filterLocationAcquired;
      } else {
        _geoLat = null;
        _geoLng = null;
        _locMsg = _messageFor(res.status);
      }
    });
  }

  String _messageFor(GeoLocationStatus s) {
    final l = AppLocalizations.of(context);
    switch (s) {
      case GeoLocationStatus.serviceOff:
        return l.filterLocServiceOff;
      case GeoLocationStatus.insecureContext:
        return l.mapLocationInsecure;
      case GeoLocationStatus.denied:
        return kIsWeb ? l.mapLocationBlocked : l.filterLocDenied;
      case GeoLocationStatus.deniedForever:
        return l.filterLocDeniedForever;
      case GeoLocationStatus.outOfVietnam:
        return l.filterLocOutOfVietnam;
      case GeoLocationStatus.error:
      case GeoLocationStatus.ok:
        return l.filterLocError;
    }
  }

  Future<bool?> _showLocationPriming() {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.near_me, color: HD.accent),
        title: Text(l.filterPrimingTitle),
        content: Text(l.filterPrimingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.filterPrimingLater),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HD.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.filterEnableLocation),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    final l = AppLocalizations.of(context);
    final houseProvider = Provider.of<HouseProvider>(context, listen: false);
    final minPrice = houseProvider.minPrice;
    final maxPrice = _priceValue * 1000000;
    final minArea = double.tryParse(_minAreaController.text) ?? 0.0;
    final maxArea = double.tryParse(_maxAreaController.text) ?? 500.0;

    // Quanh đây nhưng chưa có vị trí → không áp dụng, nhắc lấy vị trí.
    if (_geoMode == SearchMode.nearby && (_geoLat == null || _geoLng == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.filterNeedLocationFirst)));
      return;
    }

    final place = _placeController.text.trim();
    // Địa danh trống → coi như duyệt thường.
    final mode = (_geoMode == SearchMode.place && place.isEmpty)
        ? SearchMode.browse
        : _geoMode;

    houseProvider.applySearch(
      minPrice: minPrice,
      maxPrice: maxPrice,
      minArea: minArea,
      maxArea: maxArea,
      categoryId: _tempCategoryId,
      mode: mode,
      nearLat: _geoLat,
      nearLng: _geoLng,
      placeQuery: place,
      radiusKm: _radiusKm,
      // Tìm kiếm nâng cao (0071)
      // Chip "4+" gửi 4 → backend lọc bedrooms >= 4.
      minBedrooms: _selectedBedrooms,
      directions: _selectedDirections.toList(),
      trustedOnly: _trustedOnly,
      minRating: _minRating,
      minQualityStar: _minQualityStar,
      sort: _sort,
    );

    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      _priceValue = 50.0;
      _minAreaController.text = '0';
      _maxAreaController.text = '500';
      _tempCategoryId = null;
      _selectedBedrooms = null;
      _selectedDirections.clear();
      _trustedOnly = false;
      _minRating = 0;
      _minQualityStar = 0;
      _sort = '';
      _geoMode = SearchMode.browse;
      _radiusKm = 3;
      _geoLat = null;
      _geoLng = null;
      _placeController.clear();
      _locMsg = null;
    });

    Provider.of<HouseProvider>(context, listen: false).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final houseProvider = Provider.of<HouseProvider>(context);

    return Scaffold(
      appBar: DsAppBar(
        title: l.filterTitle,
        actions: [
          IconButton(
            tooltip: l.filterReset,
            icon: const Icon(Icons.refresh),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Khu vực tìm kiếm ───────────────────────────────────────────
            _buildSectionHeader(Icons.place, l.filterSectionSearchArea),
            _buildGeoModeSelector(),
            const SizedBox(height: 12),
            if (_geoMode == SearchMode.place) _buildPlaceField(),
            if (_geoMode == SearchMode.nearby) _buildNearbyControls(),
            if (_geoMode != SearchMode.browse) ...[
              const SizedBox(height: 12),
              _buildRadiusChips(),
            ],
            const SizedBox(height: 24),

            // Price Range Section
            _buildSectionHeader(Icons.payments, l.filterSectionPriceRange),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.filterMaxPriceLabel),
                Text(
                  l.filterPriceValueVnd(_priceValue.toStringAsFixed(0)),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Slider(
              value: _priceValue,
              min: 0,
              max: 100,
              divisions: 20,
              label: l.filterPriceValueShort(_priceValue.toStringAsFixed(0)),
              onChanged: (val) {
                setState(() {
                  _priceValue = val;
                });
              },
            ),
            const SizedBox(height: 24),

            // Area Section
            _buildSectionHeader(Icons.square_foot, l.filterSectionArea),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minAreaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.filterAreaFrom,
                      hintText: '0',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maxAreaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.filterAreaTo,
                      hintText: '500+',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bedrooms Section
            _buildSectionHeader(Icons.bed, l.filterSectionBedrooms),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChoiceChip(l.filterAny, _selectedBedrooms == null, () {
                    setState(() => _selectedBedrooms = null);
                  }),
                  _buildChoiceChip('1', _selectedBedrooms == 1, () {
                    setState(() => _selectedBedrooms = 1);
                  }),
                  _buildChoiceChip('2', _selectedBedrooms == 2, () {
                    setState(() => _selectedBedrooms = 2);
                  }),
                  _buildChoiceChip('3', _selectedBedrooms == 3, () {
                    setState(() => _selectedBedrooms = 3);
                  }),
                  _buildChoiceChip('4+', _selectedBedrooms == 4, () {
                    setState(() => _selectedBedrooms = 4);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Property Type
            _buildSectionHeader(Icons.home_work, l.filterSectionPropertyType),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: houseProvider.categories.map((cat) {
                  final isSelected = _tempCategoryId == cat['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(cat['name']),
                      onSelected: (_) {
                        setState(() {
                          _tempCategoryId = isSelected ? null : cat['id'];
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Hướng nhà (phong thuỷ) — chọn nhiều ──────────────────────────
            _buildSectionHeader(Icons.explore, 'Hướng nhà (phong thuỷ)'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _directionLabels.entries.map((e) {
                final sel = _selectedDirections.contains(e.key);
                return ChoiceChip(
                  selected: sel,
                  label: Text(e.value),
                  onSelected: (_) => setState(() {
                    sel
                        ? _selectedDirections.remove(e.key)
                        : _selectedDirections.add(e.key);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Uy tín & Chất lượng ─────────────────────────────────────────
            _buildSectionHeader(Icons.verified, 'Uy tín & Chất lượng'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chỉ hiện nhà Uy tín'),
              secondary: const Icon(Icons.verified_user, color: HD.accent),
              value: _trustedOnly,
              onChanged: (v) => setState(() => _trustedOnly = v),
            ),
            const SizedBox(height: 8),
            const Text('Điểm đánh giá tối thiểu'),
            Wrap(
              spacing: 8,
              children: [
                _buildChoiceChip(
                  'Tất cả',
                  _minRating == 0,
                  () => setState(() => _minRating = 0),
                ),
                _buildChoiceChip(
                  '★ 3.5+',
                  _minRating == 3.5,
                  () => setState(() => _minRating = 3.5),
                ),
                _buildChoiceChip(
                  '★ 4.0+',
                  _minRating == 4.0,
                  () => setState(() => _minRating = 4.0),
                ),
                _buildChoiceChip(
                  '★ 4.5+',
                  _minRating == 4.5,
                  () => setState(() => _minRating = 4.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Sao chất lượng tối thiểu'),
            Wrap(
              spacing: 8,
              children: [0, 3, 4, 5].map((s) {
                return _buildChoiceChip(
                  s == 0 ? 'Tất cả' : '$s sao',
                  _minQualityStar == s,
                  () => setState(() => _minQualityStar = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Sắp xếp ──────────────────────────────────────────────────────
            _buildSectionHeader(Icons.sort, 'Sắp xếp'),
            Wrap(
              spacing: 8,
              children: [
                _buildChoiceChip(
                  'Mới nhất',
                  _sort == '',
                  () => setState(() => _sort = ''),
                ),
                _buildChoiceChip(
                  'Uy tín',
                  _sort == 'trust',
                  () => setState(() => _sort = 'trust'),
                ),
                _buildChoiceChip(
                  'Đánh giá cao',
                  _sort == 'rating',
                  () => setState(() => _sort = 'rating'),
                ),
                _buildChoiceChip(
                  'Giá thấp→cao',
                  _sort == 'price_asc',
                  () => setState(() => _sort = 'price_asc'),
                ),
                _buildChoiceChip(
                  'Giá cao→thấp',
                  _sort == 'price_desc',
                  () => setState(() => _sort = 'price_desc'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 100), // Space for bottom action bar
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            TextButton(onPressed: _clearAll, child: Text(l.filterClearAll)),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _applyFilters,
                child: Text(l.filterApply),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeoModeSelector() {
    final l = AppLocalizations.of(context);
    Widget chip(String label, IconData icon, SearchMode mode) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 18,
          color: _geoMode == mode ? Colors.white : HD.inkMuted,
        ),
        label: Text(label),
        selected: _geoMode == mode,
        onSelected: (_) => setState(() {
          _geoMode = mode;
          _locMsg = null;
        }),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(l.filterModeAll, Icons.public, SearchMode.browse),
          chip(l.filterModeNearby, Icons.near_me, SearchMode.nearby),
          chip(l.filterModePlace, Icons.place_outlined, SearchMode.place),
        ],
      ),
    );
  }

  Widget _buildPlaceField() {
    final l = AppLocalizations.of(context);
    return TextField(
      controller: _placeController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _applyFilters(),
      decoration: InputDecoration(
        hintText: l.filterPlaceHint,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildNearbyControls() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _locating ? null : _pickCurrentLocation,
          icon: _locating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _geoLat != null ? Icons.check_circle : Icons.my_location,
                  color: _geoLat != null ? Colors.green : null,
                ),
          label: Text(
            _geoLat != null
                ? l.filterLocationUpdate
                : l.filterGetCurrentLocation,
          ),
        ),
        if (_locMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _locMsg!,
              style: const TextStyle(color: HD.inkMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildRadiusChips() {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Text(l.filterRadiusLabel, style: const TextStyle(color: HD.inkMuted)),
        const SizedBox(width: 8),
        ..._radii.map(
          (r) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(l.filterRadiusKm(r.toStringAsFixed(0))),
              selected: _radiusKm == r,
              onSelected: (_) => setState(() => _radiusKm = r),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(
    String label,
    bool isSelected,
    VoidCallback onSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
