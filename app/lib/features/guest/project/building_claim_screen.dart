import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/phong_xem_truoc.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/host/property/widgets/danh_sach_phong_xem_truoc.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Chủ nhà nhận tài sản do Sale tạo hộ bằng mã xác nhận ngắn.
class BuildingClaimScreen extends StatefulWidget {
  const BuildingClaimScreen({super.key, this.api});

  /// Chỉ để test bơm client giả — màn này gọi thẳng API, không qua provider.
  final ApiClient? api;

  @override
  State<BuildingClaimScreen> createState() => _BuildingClaimScreenState();
}

class _BuildingClaimScreenState extends State<BuildingClaimScreen> {
  final _code = TextEditingController();
  ApiClient get _api => widget.api ?? const ApiClient();
  Map<String, dynamic>? _preview;
  String? _error;
  bool _loading = false;
  bool _claiming = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _previewBuilding() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Nhập mã Sale gửi cho bạn');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final result = await _api.get('/api/buildings/claim/$code');
      if (!mounted) return;
      setState(() {
        _preview = result;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể kiểm tra mã lúc này';
        _loading = false;
      });
    }
  }

  Future<void> _claim() async {
    final code = _code.text.trim().toUpperCase();
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      await _api.post('/api/buildings/claim', body: {'code': code});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshCurrentUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã nhận tài sản. Bạn có thể quản lý ngay.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _claiming = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Chưa nhận được tài sản, thử lại sau';
        _claiming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Nhận tài sản từ Sale'),
        backgroundColor: const Color(0xFFF5F6F8),
        surfaceTintColor: const Color(0xFFF5F6F8),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bạn không cần tự tạo phòng', style: HD.sectionTitle()),
          const SizedBox(height: 6),
          Text(
            'Sale đã nhập sẵn tòa nhà và phòng. Bạn chỉ cần nhập mã để kiểm tra rồi xác nhận.',
            style: HD.body(color: HD.inkMuted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Mã xác nhận',
              hintText: 'Ví dụ: 7K4M2P9A',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key_outlined),
            ),
            onSubmitted: (_) => _previewBuilding(),
          ),
          const SizedBox(height: 12),
          DsButton(
            label: _loading ? 'Đang kiểm tra...' : 'Kiểm tra tài sản',
            icon: Icons.search,
            expand: true,
            onPressed: _loading ? null : _previewBuilding,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: HD.body(color: HD.negative)),
          ],
          if (p != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HD.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tài sản được gửi cho bạn',
                    style: HD.eyebrow(color: HD.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p['name']?.toString() ?? '',
                    style: HD.bodyBold(size: 18),
                  ),
                  if ((p['address']?.toString() ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      p['address'].toString(),
                      style: HD.body(color: HD.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    (p['so_phong']?.toString() ?? '0') +
                        ' phòng · Người tạo: ' +
                        (p['nguoi_dang_giu']?.toString() ?? 'Sale'),
                    style: HD.caption(),
                  ),
                  const SizedBox(height: 12),
                  // Nút dưới hỏi "đúng tài sản của tôi?" — trước đây hỏi mà
                  // không đưa gì để đối chiếu ngoài cái tên. Bảng phòng này
                  // chính là thứ trả lời được câu hỏi đó.
                  DanhSachPhongXemTruoc(
                    phong: PhongXemTruoc.danhSach(p['phong']),
                    conLai: (p['con_lai'] as num?)?.toInt() ?? 0,
                  ),
                  const SizedBox(height: 16),
                  DsButton(
                    label: _claiming
                        ? 'Đang xác nhận...'
                        : 'Đúng tài sản của tôi',
                    icon: Icons.check_circle_outline,
                    expand: true,
                    onPressed: _claiming ? null : _claim,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
