import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/features/guest/browse/widgets/property_list_card.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Trang riêng để **xem danh sách + tìm kiếm** tin đăng BĐS (thay cho việc
/// cuộn trang chủ). Dùng cho: Thuê nhà / Cho thuê (transaction_type='rent') và
/// BĐS công nghiệp (lọc theo category "BĐS công nghiệp").
class PropertyListingScreen extends StatefulWidget {
  const PropertyListingScreen({
    super.key,
    required this.title,
    this.transactionType = 'rent',
    this.categoryName,
    this.groupKey,
  });

  final String title;

  /// Lọc theo loại giao dịch; `null` = KHÔNG lọc (hiện cả thuê lẫn bán) —
  /// dùng cho ô "Mua bán · Cho thuê" ở trang chủ.
  final String? transactionType;

  /// Nếu có → lọc theo danh mục (VD 'Kho xưởng'); id resolve khi tải.
  ///
  /// ⚠️ So khớp theo TÊN nên đổi tên danh mục là vỡ (đã xảy ra: migration 0074
  /// đổi "BĐS công nghiệp" → "Kho xưởng"). Ưu tiên dùng [groupKey] cho các lối
  /// vào mới; tham số này giữ cho các call site cũ.
  final String? categoryName;

  /// Lọc theo NHÓM master (stay_long|stay_short|business) — bền hơn tên vì key
  /// do backend định nghĩa, không đổi theo nhãn hiển thị.
  final String? groupKey;

  @override
  State<PropertyListingScreen> createState() => _PropertyListingScreenState();
}

class _PropertyListingScreenState extends State<PropertyListingScreen> {
  final _repo = ApiHouseRepository();
  final _searchCtl = TextEditingController();
  List<HouseModel> _houses = const [];
  bool _loading = true;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (widget.categoryName != null) {
      try {
        final cats = await _repo.getCategories();
        final m = cats.firstWhere(
          (c) => (c['name'] as String?)?.trim() == widget.categoryName,
          orElse: () => const {},
        );
        _categoryId = m['id'] as int?;
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _houses = await _repo.getHouses(
        transactionType:
            (widget.categoryName == null && widget.groupKey == null)
            ? widget.transactionType
            : null,
        group: widget.groupKey,
        categoryId: _categoryId,
        query: _searchCtl.text.trim().isEmpty ? null : _searchCtl.text.trim(),
        limit: 50,
      );
    } catch (_) {
      _houses = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return HDGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: DsAppBar(title: widget.title),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: l.plistSearchHint,
                  prefixIcon: const Icon(Icons.search, color: HD.inkMuted),
                  suffixIcon: _searchCtl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtl.clear();
                            _load();
                          },
                        ),
                  filled: true,
                  fillColor: HD.paperRaised,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: HD.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: HD.hairline),
                  ),
                ),
                onChanged: (_) => setState(() {}), // cập nhật nút xoá
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _houses.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _houses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            PropertyListCard(house: _houses[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    final l = AppLocalizations.of(context);
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.search_off, size: 48, color: HD.inkMuted),
        const SizedBox(height: 12),
        Text(
          l.plistEmptyTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: HD.inkSoft,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.plistEmptySubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: HD.inkMuted, fontSize: 13),
        ),
      ],
    );
  }
}
