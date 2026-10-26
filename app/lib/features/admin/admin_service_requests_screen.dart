import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/service_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Admin xử lý YÊU CẦU DỊCH VỤ (khách bấm "Sửa điện", "Thông tắc"… rồi để lại
/// SĐT). Route: push. API: GET/PATCH /api/services/requests.
///
/// Vì sao màn này tồn tại: yêu cầu khách gửi phải có người NHÌN THẤY rồi gọi
/// lại, nếu không nó chỉ nằm chết trong cơ sở dữ liệu. Đây là khúc cuối khép
/// vòng của luồng đặt dịch vụ.
///
/// Ưu tiên thiết kế: **gọi được trong một chạm**. SĐT là thứ admin cần nhất,
/// nên nó nằm ngay hàng đầu mỗi thẻ, chạm là gọi.
class AdminServiceRequestsScreen extends StatefulWidget {
  const AdminServiceRequestsScreen({super.key, this.api});

  /// Chỉ để test bơm API giả.
  final ServiceApi? api;

  @override
  State<AdminServiceRequestsScreen> createState() =>
      _AdminServiceRequestsScreenState();
}

/// Bộ lọc nhanh theo trạng thái. 'doing' gộp hai trạng thái vì với admin đó là
/// cùng một việc: đã chạm tới nhưng chưa xong.
enum _Loc { tatCa, moi, dangXuLy, xong }

class _AdminServiceRequestsScreenState
    extends State<AdminServiceRequestsScreen> {
  ServiceApi get _api => widget.api ?? const ServiceApi();

  final _timCtrl = TextEditingController();
  _Loc _loc = _Loc.tatCa;
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _timCtrl.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() => _loading = true);
    try {
      // 'Đang xử lý' gồm 2 trạng thái nên không lọc được ở server bằng một
      // tham số — lấy về rồi lọc ở client. Danh sách tối đa 200 dòng.
      final ds = await _api.adminDanhSach(
        status: switch (_loc) {
          _Loc.moi => 'new',
          _Loc.xong => 'done',
          _ => null,
        },
        q: _timCtrl.text.trim(),
        limit: 200,
      );
      final loc = _loc == _Loc.dangXuLy
          ? ds
              .where((r) => r['status'] == 'contacted' || r['status'] == 'scheduled')
              .toList()
          : ds;
      if (mounted) setState(() => _rows = loc);
    } catch (_) {
      if (mounted) setState(() => _rows = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _capNhat(
    int id, {
    String? status,
    DateTime? scheduledAt,
    String? adminNote,
  }) async {
    try {
      await _api.adminCapNhat(id,
          status: status, scheduledAt: scheduledAt, adminNote: adminNote);
      await _nap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.svcReqTitle),
      body: Column(
        children: [
          _thanhLoc(l),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? DsEmptyState(
                        icon: Icons.handyman_outlined, title: l.svcReqEmpty)
                    : RefreshIndicator(
                        onRefresh: _nap,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(HD.s12),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: HD.s12),
                          itemBuilder: (_, i) => _the(_rows[i], l),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _thanhLoc(AppLocalizations l) {
    final nhan = {
      _Loc.tatCa: l.svcReqFilterAll,
      _Loc.moi: l.svcReqFilterNew,
      _Loc.dangXuLy: l.svcReqFilterDoing,
      _Loc.xong: l.svcReqFilterDone,
    };
    return Container(
      color: HD.paperRaised,
      padding: const EdgeInsets.fromLTRB(HD.s12, HD.s8, HD.s12, HD.s8),
      child: Column(
        children: [
          TextField(
            controller: _timCtrl,
            onSubmitted: (_) => _nap(),
            decoration: InputDecoration(
              hintText: l.svcReqSearchHint,
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HD.rPill),
              ),
            ),
          ),
          const SizedBox(height: HD.s8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in nhan.entries) ...[
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _loc == e.key,
                    onSelected: (_) {
                      setState(() => _loc = e.key);
                      _nap();
                    },
                  ),
                  const SizedBox(width: HD.s8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _the(Map<String, dynamic> r, AppLocalizations l) {
    final id = (r['id'] as num).toInt();
    final phone = (r['phone'] as String?) ?? '';
    final status = (r['status'] as String?) ?? 'new';
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
                  '${r['service_name'] ?? r['service_slug'] ?? ''} · ${r['name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _nhanTrangThai(status, l),
            ],
          ),
          const SizedBox(height: HD.s4),
          // SĐT là thứ admin cần nhất — để nguyên, chọn/copy được, chạm là gọi.
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: HD.accent),
              const SizedBox(width: 6),
              SelectableText(phone,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: HD.accent)),
              const Spacer(),
              TextButton.icon(
                onPressed: phone.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: phone));
                        _capNhat(id, status: 'contacted');
                      },
                icon: const Icon(Icons.call, size: 16),
                label: Text(l.svcReqCall),
              ),
            ],
          ),
          if ((r['location_text'] ?? r['area']) != null)
            Text('${r['location_text'] ?? r['area']}', style: HD.caption()),
          if ((r['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: HD.s4),
            Text(r['description'] as String),
          ],
          if (r['scheduled_at'] != null) ...[
            const SizedBox(height: HD.s4),
            Row(children: [
              const Icon(Icons.event_available_outlined,
                  size: 15, color: HD.positive),
              const SizedBox(width: 4),
              Text(_gonNgay(r['scheduled_at'] as String),
                  style: const TextStyle(color: HD.positive, fontSize: 12)),
            ]),
          ],
          if ((r['admin_note'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: HD.s4),
            Text('📝 ${r['admin_note']}', style: HD.caption()),
          ],
          const Divider(height: HD.s20),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: status,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in _trangThai(l).entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => v == null ? null : _capNhat(id, status: v),
                ),
              ),
              TextButton.icon(
                onPressed: () => _chonLich(id),
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(l.svcReqSchedule),
              ),
              IconButton(
                tooltip: l.svcReqNote,
                onPressed: () => _ghiChu(id, r['admin_note'] as String?, l),
                icon: const Icon(Icons.edit_note_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Chỉ liệt kê trạng thái của luồng DỊCH VỤ NHANH. Trạng thái của sàn nhà
  /// thầu (assigned/quoted/won/lost) do luồng báo giá tự đặt — đưa vào đây thì
  /// admin dễ bấm nhầm và phá trạng thái của một cuộc đấu thầu đang chạy.
  Map<String, String> _trangThai(AppLocalizations l) => {
        'new': l.svcStatusNew,
        'contacted': l.svcStatusContacted,
        'scheduled': l.svcStatusScheduled,
        'done': l.svcStatusDone,
        'cancelled': l.svcStatusCancelled,
        'spam': l.svcStatusSpam,
      };

  Widget _nhanTrangThai(String status, AppLocalizations l) {
    final mau = switch (status) {
      'done' => HD.positive,
      'cancelled' || 'spam' || 'lost' => HD.inkMuted,
      'new' => HD.accent,
      _ => HD.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HD.rPill),
      ),
      child: Text(
        _trangThai(l)[status] ?? status,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mau),
      ),
    );
  }

  Future<void> _chonLich(int id) async {
    final now = DateTime.now();
    final ngay = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (ngay == null || !mounted) return;
    final gio = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (gio == null) return;
    await _capNhat(
      id,
      status: 'scheduled',
      scheduledAt: DateTime(ngay.year, ngay.month, ngay.day, gio.hour, gio.minute),
    );
  }

  Future<void> _ghiChu(int id, String? hienTai, AppLocalizations l) async {
    final ctrl = TextEditingController(text: hienTai ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.svcReqNote),
        content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
        actions: [
          TextButton(
            // Đóng bằng context của BUILDER, không phải context của màn — hộp
            // thoại mở trong Navigator lồng theo tab sẽ treo nếu pop nhầm.
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.svcReqSave),
          ),
        ],
      ),
    );
    if (ok == true) await _capNhat(id, adminNote: ctrl.text.trim());
    ctrl.dispose();
  }

  static String _gonNgay(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}
