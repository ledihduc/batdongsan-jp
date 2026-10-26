import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_link_api.dart';
import 'package:house_booking/data/models/building_model.dart';

/// Chủ phòng nhập mã sale để liên kết. Route: push.
/// API: POST /api/owner-links/resolve-code · POST /api/owner-links.
///
/// Bắt buộc **tra mã → xem sale là ai → mới xác nhận** (spec mục 2 bước 5–6).
/// Liên kết mở quyền cho người lạ chạm vào phòng của mình; nhập mù một chuỗi
/// 6 ký tự rồi bấm xong là cách tốt nhất để bị lừa.
class LinkSaleScreen extends StatefulWidget {
  const LinkSaleScreen({super.key, this.api});

  final SaleLinkApi? api;

  @override
  State<LinkSaleScreen> createState() => _LinkSaleScreenState();
}

class _LinkSaleScreenState extends State<LinkSaleScreen> {
  SaleLinkApi get _api => widget.api ?? const SaleLinkApi();

  final _o = TextEditingController();
  SaleTomTat? _sale;
  String? _loi;
  bool _dangChay = false;
  bool _dangTaiToa = true;
  String? _loiToa;
  List<BuildingModel> _toa = const [];
  int? _buildingId;

  @override
  void initState() {
    super.initState();
    _napToa();
  }

  Future<void> _napToa() async {
    setState(() {
      _dangTaiToa = true;
      _loiToa = null;
    });
    try {
      final toa = await _api.toaCuaToi();
      if (!mounted) return;
      setState(() => _toa = toa);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _loiToa = 'Không tải được toà nhà. Kiểm tra kết nối mạng.',
      );
    } finally {
      if (mounted) setState(() => _dangTaiToa = false);
    }
  }

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  /// Người ta gõ đủ kiểu: "sl-8k4d2q", "8K4D2Q", có cả dấu cách. Backend đã
  /// chuẩn hoá, ở đây chỉ cần đủ 6 ký tự phần đuôi để bật nút.
  String get _ma => _o.text.trim().toUpperCase().replaceAll(' ', '');
  bool get _duDai => _ma.replaceAll('SL-', '').replaceAll('-', '').length >= 6;

  bool get _coTheTim => _duDai && _buildingId != null && !_dangChay;

  Future<void> _tim() async {
    if (!_coTheTim) return;
    setState(() {
      _dangChay = true;
      _loi = null;
      _sale = null;
    });
    try {
      final s = await _api.traMa(_ma, buildingId: _buildingId!);
      if (!mounted) return;
      setState(() => _sale = s);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loi = 'Không tra được mã. Kiểm tra kết nối mạng.');
    } finally {
      if (mounted) setState(() => _dangChay = false);
    }
  }

  Future<void> _lienKet() async {
    if (_buildingId == null || _sale == null || _dangChay) return;
    setState(() {
      _dangChay = true;
      _loi = null;
    });
    try {
      await _api.lienKet(_ma, buildingId: _buildingId!);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã liên kết với ${_sale?.ten ?? "sale"}')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loi = 'Không liên kết được.');
    } finally {
      if (mounted) setState(() => _dangChay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _sale;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(title: const Text('Liên kết với sale')),
      body: ListView(
        padding: const EdgeInsets.all(HD.s16),
        children: [
          Text(
            'Chọn toà nhà và nhập mã sale. Sale sẽ phụ trách tất cả phòng '
            'trong toà đã chọn.',
            style: HD.body(size: 13.5, color: HD.inkMuted),
          ),
          const SizedBox(height: HD.s20),
          if (_dangTaiToa)
            const LinearProgressIndicator()
          else if (_loiToa != null) ...[
            Text(_loiToa!, style: HD.body(size: 13, color: HD.accent)),
            TextButton(onPressed: _napToa, child: const Text('Thử lại')),
          ] else if (_toa.isEmpty)
            Text(
              'Bạn chưa có toà nhà. Tạo hoặc nhận bàn giao toà nhà trước khi liên kết sale.',
              style: HD.body(size: 13, color: HD.inkMuted),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _buildingId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Toà nhà',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Chọn toà nhà'),
              items: _toa
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _dangChay
                  ? null
                  : (id) => setState(() {
                      _buildingId = id;
                      _sale = null;
                      _loi = null;
                    }),
            ),
          const SizedBox(height: HD.s16),
          TextField(
            controller: _o,
            enabled: !_dangChay,
            textCapitalization: TextCapitalization.characters,
            maxLength: 12,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
            ],
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'SL-8K4D2Q',
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {
              _sale = null;
              _loi = null;
            }),
            onSubmitted: (_) => _coTheTim ? _tim() : null,
          ),
          const SizedBox(height: HD.s12),
          if (_loi != null) ...[
            Text(_loi!, style: HD.body(size: 13, color: HD.accent)),
            const SizedBox(height: HD.s12),
          ],
          if (s == null)
            DsButton(
              label: 'Tìm sale',
              expand: true,
              isLoading: _dangChay,
              onPressed: _coTheTim ? _tim : null,
            )
          else ...[
            _TheSale(s: s),
            const SizedBox(height: HD.s16),
            if (s.daLienKet)
              Text(
                'Toà nhà này đã liên kết với sale này rồi.',
                style: HD.body(size: 13, color: HD.inkMuted),
              )
            else
              DsButton(
                label: 'Liên kết với ${s.ten}',
                expand: true,
                isLoading: _dangChay,
                onPressed: _dangChay ? null : _lienKet,
              ),
          ],
        ],
      ),
    );
  }
}

class _TheSale extends StatelessWidget {
  const _TheSale({required this.s});

  final SaleTomTat s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HD.s16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: HD.accentSoft,
            backgroundImage: (s.avatar != null && s.avatar!.isNotEmpty)
                ? CachedNetworkImageProvider(_abs(s.avatar!))
                : null,
            child: (s.avatar == null || s.avatar!.isEmpty)
                ? Text(
                    s.ten.isEmpty ? '?' : s.ten[0].toUpperCase(),
                    style: HD.bodyBold(size: 20).copyWith(color: HD.accent),
                  )
                : null,
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.ten, style: HD.bodyBold(size: 17)),
                if (s.gioiThieu != null && s.gioiThieu!.trim().isNotEmpty) ...[
                  const SizedBox(height: HD.s4),
                  Text(
                    s.gioiThieu!.trim(),
                    style: HD.body(size: 13, color: HD.inkMuted),
                  ),
                ],
                if (s.khuVuc.isNotEmpty) ...[
                  const SizedBox(height: HD.s8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: s.khuVuc
                        .map(
                          (k) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HD.s8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HD.paper,
                              borderRadius: BorderRadius.circular(HD.rPill),
                            ),
                            child: Text(k, style: HD.caption()),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
