import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/data/models/risky_house_model.dart';
import 'package:house_booking/data/services/planning_service.dart';
import 'package:house_booking/core/widgets/ds.dart';

// i18n: TODO(i18n) — thay bằng AppLocalizations khi setup ARB.
const _kAppBarTitle = 'Listing rủi ro quy hoạch';
const _kEmpty = 'Không có listing rủi ro';
const _kForbidden = 'Bạn không có quyền truy cập';

/// Màn hình admin xem danh sách BDS nằm trong zone rủi ro (US-06, AC-19).
/// Chỉ hiển thị title + zone info — KHÔNG hiển thị PII (host phone, email).
class RiskyListingsScreen extends StatefulWidget {
  const RiskyListingsScreen({super.key}) : _service = null;

  /// Test-only constructor: inject a [PlanningService] to avoid real HTTP calls.
  /// Only use in unit/widget tests.
  @visibleForTesting
  const RiskyListingsScreen.forTest({super.key, required PlanningService this._service});

  /// Injected service (null = use internal default).
  final PlanningService? _service;

  @override
  State<RiskyListingsScreen> createState() => _RiskyListingsScreenState();
}

class _RiskyListingsScreenState extends State<RiskyListingsScreen> {
  // Dùng service được inject qua forTest constructor nếu có; fallback về default.
  late final PlanningService _svc;
  late Future<List<RiskyHouse>> _future;

  @override
  void initState() {
    super.initState();
    _svc = widget._service ?? PlanningService();
    _future = _svc.getRiskyHouses();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _svc.getRiskyHouses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DsAppBar(title: _kAppBarTitle),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<RiskyHouse>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              final err = snap.error;
              // 403 — yêu cầu quyền admin (AC-19)
              if (err is PlanningApiException && err.statusCode == 403) {
                return _centeredMessage(
                  Icons.lock_outline,
                  _kForbidden,
                  Colors.red.shade300,
                );
              }
              return _centeredMessage(
                Icons.error_outline,
                'Lỗi: ${err.toString()}',
                Colors.red.shade300,
              );
            }

            final items = snap.data ?? [];
            if (items.isEmpty) {
              return _centeredMessage(
                Icons.check_circle_outline,
                _kEmpty,
                Colors.green.shade400,
              );
            }

            return ListView.separated(
              // Thêm padding dưới cho safe area
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (_, i) => _buildTile(ctx, items[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, RiskyHouse h) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        h.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            // Chip mã vùng màu amber (phân biệt zone rủi ro)
            Chip(
              label: Text(
                h.zoneCode ?? '?',
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: Colors.amber.shade100,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                h.zoneName ?? '—',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/house/${h.id}'),
    );
  }

  Widget _centeredMessage(IconData icon, String message, Color iconColor) {
    // Wrap trong ListView để RefreshIndicator hoạt động khi kéo xuống
    return ListView(
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: iconColor),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: HD.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
