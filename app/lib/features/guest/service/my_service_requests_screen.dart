import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/service_api.dart';
import 'package:house_booking/features/guest/service/service_catalog_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Yêu cầu dịch vụ do CHÍNH người dùng gửi. Route: không có URL (push từ tab
/// Cá nhân). API: GET /api/services/requests/mine.
///
/// Trước đây chỉ admin xem được danh sách yêu cầu, nên khách đặt thợ xong là
/// mất dấu: không biết đã có ai nhận chưa, hẹn giờ nào. Màn này đóng đúng
/// khoảng hở đó.
class MyServiceRequestsScreen extends StatefulWidget {
  const MyServiceRequestsScreen({super.key, this.api});

  /// Chỉ để test bơm API giả.
  final ServiceApi? api;

  @override
  State<MyServiceRequestsScreen> createState() =>
      _MyServiceRequestsScreenState();
}

class _MyServiceRequestsScreenState extends State<MyServiceRequestsScreen> {
  ServiceApi get _api => widget.api ?? const ServiceApi();

  List<Map<String, dynamic>> _ds = const [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    final ds = await _api.yeuCauCuaToi();
    if (mounted) {
      setState(() {
        _ds = ds;
        _dangTai = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.myReqTitle),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator())
          : _ds.isEmpty
          ? _rong(context, l)
          : RefreshIndicator(
              onRefresh: _nap,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  HD.s16,
                  HD.s16,
                  HD.s16,
                  HD.s24,
                ),
                itemCount: _ds.length,
                separatorBuilder: (_, _) => const SizedBox(height: HD.s12),
                itemBuilder: (_, i) => _the(_ds[i], l),
              ),
            ),
    );
  }

  /// Trạng thái rỗng PHẢI dẫn đi tiếp, không để trống trơn: người mở màn này
  /// mà chưa đặt gì thì thứ họ cần là lối vào danh mục dịch vụ.
  Widget _rong(BuildContext context, AppLocalizations l) => DsEmptyState(
    icon: Icons.handyman_outlined,
    title: l.myReqEmpty,
    subtitle: l.myReqEmptyHint,
    actionLabel: l.myReqEmptyCta,
    // pushReplacement: người mở "yêu cầu của tôi" rồi bấm sang danh mục thì
    // nút back nên về trang cá nhân, không quay lại một danh sách rỗng.
    onAction: () => Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ServiceCatalogScreen()),
    ),
  );

  Widget _the(Map<String, dynamic> r, AppLocalizations l) {
    final tt = (r['status'] as String?) ?? 'new';
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (r['service_name'] as String?) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 15),
                ),
              ),
              const SizedBox(width: HD.s8),
              _huyHieu(tt, l),
            ],
          ),
          if ((r['description'] as String?)?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: HD.s4),
            Text(
              (r['description'] as String).trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HD.body(size: 13, color: HD.inkSoft),
            ),
          ],
          const SizedBox(height: HD.s8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: HD.inkMuted),
              const SizedBox(width: HD.s4),
              Expanded(
                child: Text(
                  // Đã có lịch hẹn thì hiện MỐC HẸN, không hiện ngày gửi: cái
                  // người ta cần biết lúc này là "mấy giờ thợ tới".
                  r['scheduled_at'] != null
                      ? l.myReqScheduledAt(_ngay(r['scheduled_at']))
                      : l.myReqSentAt(_ngay(r['created_at'])),
                  style: HD.caption(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Màu huy hiệu đi theo NGHĨA chứ không theo thứ tự: chỉ "đã hẹn" và "hoàn
  /// thành" mới là tin tốt, còn lại để trung tính — tô màu mọi trạng thái thì
  /// mắt không phân biệt được cái nào đáng chú ý.
  Widget _huyHieu(String tt, AppLocalizations l) {
    final (String nhan, Color mau) = switch (tt) {
      'contacted' => (l.myReqStatusContacted, HD.inkSoft),
      'scheduled' => (l.myReqStatusScheduled, HD.accent),
      'done' => (l.myReqStatusDone, HD.positive),
      'cancelled' || 'spam' => (l.myReqStatusCancelled, HD.inkMuted),
      _ => (l.myReqStatusNew, HD.inkSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 3),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HD.rPill),
      ),
      child: Text(
        nhan,
        style: HD.caption().copyWith(color: mau, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _ngay(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '';
    two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}
