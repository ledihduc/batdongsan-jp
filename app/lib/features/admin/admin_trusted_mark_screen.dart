import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';

/// Màn hình admin đánh dấu tin uy tín (F4 — Phase 06).
///
/// Tải danh sách tin 'published', cho phép toggle cờ [HouseModel.isTrusted]
/// qua PATCH /api/admin/houses/{id}/trusted. Optimistic UI — revert on error.
class AdminTrustedMarkScreen extends StatefulWidget {
  const AdminTrustedMarkScreen({super.key});

  @override
  State<AdminTrustedMarkScreen> createState() => _AdminTrustedMarkScreenState();
}

class _AdminTrustedMarkScreenState extends State<AdminTrustedMarkScreen> {
  final _repo = ApiHouseRepository();

  List<HouseModel> _houses = [];
  bool _loading = false;
  String? _errorMessage;

  // Track optimistic in-flight toggles to disable switch during call
  final Set<int> _pending = {};

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  Future<void> _loadHouses() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final houses = await _repo.getAdminHouses('published');
      if (mounted) {
        setState(() {
          _houses = houses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không tải được danh sách';
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleTrusted(int index) async {
    // M4: Capture original row BEFORE optimistic write so revert restores the
    // exact object (with real trustedAt from server), not a rebuilt copy that
    // would lose the authoritative server timestamp.
    final original = _houses[index];
    final id = original.id;
    if (id == null) return;
    if (_pending.contains(id)) return; // already in-flight

    final newValue = !original.isTrusted;

    // Optimistic update — swap in a rebuilt row (with locally-guessed timestamp).
    setState(() {
      _pending.add(id);
      _houses[index] = _buildUpdated(original, isTrusted: newValue);
    });

    try {
      // M7: go through repo, get server-authoritative HouseModel back.
      final serverHouse = await _repo.setTrusted(original, newValue);
      if (mounted) {
        setState(() => _houses[index] = serverHouse);
        _showSnackBar('Đã cập nhật', success: true);
      }
    } catch (e) {
      debugPrint('[AdminTrusted] toggle failed for house $id: $e');
      // M4: restore original object exactly — preserves the real trustedAt.
      if (mounted) {
        setState(() => _houses[index] = original);
        _showSnackBar('Không cập nhật được, thử lại', success: false);
      }
    } finally {
      if (mounted) {
        setState(() => _pending.remove(id));
      }
    }
  }

  /// Build a copy of [h] with [isTrusted] overridden (HouseModel is immutable).
  HouseModel _buildUpdated(HouseModel h, {required bool isTrusted}) {
    return HouseModel(
      id: h.id,
      hostId: h.hostId,
      title: h.title,
      description: h.description,
      categoryId: h.categoryId,
      categoryName: h.categoryName,
      price: h.price,
      area: h.area,
      address: h.address,
      city: h.city,
      district: h.district,
      latitude: h.latitude,
      longitude: h.longitude,
      bedrooms: h.bedrooms,
      bathrooms: h.bathrooms,
      status: h.status,
      createdAt: h.createdAt,
      images: h.images,
      amenities: h.amenities,
      hostName: h.hostName,
      hostAvatar: h.hostAvatar,
      hostPhone: h.hostPhone,
      listingType: h.listingType,
      totalUnits: h.totalUnits,
      availableUnits: h.availableUnits,
      genderPref: h.genderPref,
      distanceKm: h.distanceKm,
      rejectionReason: h.rejectionReason,
      transactionType: h.transactionType,
      isTrusted: isTrusted,
      trustedAt: isTrusted ? DateTime.now() : null,
      wardSlug: h.wardSlug,
      wardSlugLegacy: h.wardSlugLegacy,
    );
  }

  void _showSnackBar(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Đánh dấu tin uy tín',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadHouses);
    }
    if (_houses.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có tin nào',
          style: TextStyle(fontSize: 16, color: HD.inkMuted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHouses,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _houses.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => _TrustedMarkRow(
          house: _houses[i],
          isPending: _pending.contains(_houses[i].id),
          onToggle: () => _toggleTrusted(i),
        ),
      ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _TrustedMarkRow extends StatelessWidget {
  const _TrustedMarkRow({
    required this.house,
    required this.isPending,
    required this.onToggle,
  });

  final HouseModel house;
  final bool isPending;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final priceText = _formatPrice(house.price) + house.pricePeriodSuffix;
    // M5: show `district · city` — using raw wardSlug would leak the internal
    // identifier (e.g. "phuong-truc-bach-hoan-kiem-ha-noi") to admins.
    // When ward-name lookup ships, join here.
    final locationText = house.city.isNotEmpty
        ? '${house.district} · ${house.city}'
        : house.district;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: _Thumbnail(imageUrl: house.images.isNotEmpty ? house.images.first : null),
      title: Text(
        house.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            priceText,
            style: const TextStyle(
              fontSize: 13,
              color: HD.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            locationText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: HD.inkMuted),
          ),
        ],
      ),
      trailing: isPending
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Semantics(
              label: 'Đánh dấu uy tín: ${house.title}',
              child: Switch(
                value: house.isTrusted,
                onChanged: (_) => onToggle(),
                activeThumbColor: const Color(0xFFD4A017), // vàng Editorial tone
              ),
            ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      final mil = price / 1000000;
      return '${mil.toStringAsFixed(mil % 1 == 0 ? 0 : 1)}tr';
    }
    return '${price.toStringAsFixed(0)}đ';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: HD.paperSunken,
      child: const Icon(Icons.home_outlined, color: HD.inkMuted),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: HD.inkMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: HD.ink),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
