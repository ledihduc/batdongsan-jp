import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/tenant_model.dart';
import 'package:house_booking/data/repositories/api_tenant_repository.dart';

/// KHÁCH THUÊ — sổ người thuê của chủ nhà, mọi toà. Mở từ "Thao tác nhanh" ở
/// Trang chủ chủ nhà. API: `GET /api/host/tenants` (`ApiTenantRepository`).
///
/// Server có sổ người thuê từ lâu nhưng app chưa có màn nào liệt kê — người
/// thuê chỉ hiện lẻ bên trong từng hợp đồng.
class KhachThueScreen extends StatefulWidget {
  const KhachThueScreen({super.key, this.repo});

  final ApiTenantRepository? repo;

  @override
  State<KhachThueScreen> createState() => _KhachThueScreenState();
}

class _KhachThueScreenState extends State<KhachThueScreen> {
  late final ApiTenantRepository _repo = widget.repo ?? ApiTenantRepository();
  List<TenantModel> _ds = const [];
  bool _dangTai = true;
  String? _loi;
  String _tim = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ds = await _repo.fetchTenants();
      if (mounted) setState(() => _ds = ds);
    } catch (_) {
      if (mounted) {
        setState(
          () => _loi = 'Không tải được danh sách. Kéo xuống để thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _tim.trim().toLowerCase();
    final ds = q.isEmpty
        ? _ds
        : _ds
              .where(
                (t) =>
                    t.fullName.toLowerCase().contains(q) ||
                    t.phone.contains(q) ||
                    (t.email ?? '').toLowerCase().contains(q),
              )
              .toList();
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(title: const Text('Khách thuê')),
      body: RefreshIndicator(
        onRefresh: _nap,
        child: ListView(
          padding: const EdgeInsets.all(HD.s16),
          children: [
            TextField(
              onChanged: (v) => setState(() => _tim = v),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm tên, số điện thoại...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                  borderSide: const BorderSide(color: HD.hairline),
                ),
              ),
            ),
            const SizedBox(height: HD.s12),
            if (_dangTai && _ds.isEmpty)
              const Padding(
                padding: EdgeInsets.all(HD.s32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loi != null)
              Text(_loi!, style: HD.body(size: 13, color: HD.negative))
            else if (_ds.isEmpty)
              _rong('Chưa có khách thuê nào trong sổ.')
            else if (ds.isEmpty)
              _rong('Không có khách thuê nào khớp "$_tim".')
            else ...[
              Text('${ds.length} khách thuê', style: HD.caption()),
              const SizedBox(height: HD.s8),
              for (final t in ds) _TheKhach(t: t),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rong(String chu) => Padding(
    padding: const EdgeInsets.symmetric(vertical: HD.s32),
    child: Center(
      child: Text(
        chu,
        textAlign: TextAlign.center,
        style: HD.body(size: 14, color: HD.inkMuted),
      ),
    ),
  );
}

class _TheKhach extends StatelessWidget {
  const _TheKhach({required this.t});

  final TenantModel t;

  @override
  Widget build(BuildContext context) {
    // Thiếu CCCD là thứ chủ nhà phải đi đòi trước khi khai báo tạm trú.
    final duCccd = t.cccdFrontUploaded && t.cccdBackUploaded;
    final mau = duCccd ? HD.positive : HD.svcOrange;
    return Container(
      margin: const EdgeInsets.only(bottom: HD.s8),
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: HD.accentTint,
            child: Text(
              _chuCai(t.fullName),
              style: HD.bodyBold(color: HD.accent),
            ),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.fullName, style: HD.bodyBold(size: 15)),
                if (t.phone.isNotEmpty)
                  Text(t.phone, style: HD.body(size: 13, color: HD.inkMuted)),
                if ((t.email ?? '').isNotEmpty)
                  Text(t.email!, style: HD.body(size: 12, color: HD.inkMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 3),
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              duCccd ? 'Đủ CCCD' : 'Thiếu CCCD',
              style: HD.bodyBold(size: 11, color: mau),
            ),
          ),
        ],
      ),
    );
  }
}

String _chuCai(String ten) {
  final tu = ten.trim().split(RegExp(r'\s+'));
  if (tu.isEmpty || tu.last.isEmpty) return '?';
  return tu.last.characters.first.toUpperCase();
}
