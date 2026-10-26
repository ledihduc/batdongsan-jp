import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/image_grid_uploader.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';

/// Người thuê gửi chỉ số điện nước THÁNG NÀY kèm ảnh công tơ. Mở từ thẻ "Đang
/// thuê" ở tab Đã đặt. API: `POST /api/guest/dien-nuoc`.
///
/// Bước ĐẦU của luồng "người thuê gửi → chủ nhà duyệt". Không có tấm này thì
/// màn duyệt của chủ nhà mãi mãi trống — không ai có đường gửi lên.
///
/// Pop `true` khi đã gửi.
class GuiChiSoSheet extends StatefulWidget {
  const GuiChiSoSheet({
    super.key,
    required this.contractId,
    required this.maPhong,
    this.lyDoTraVe,
    this.api = const DienNuocApi(),
    this.uploadFn,
  });

  final int contractId;
  final String maPhong;

  /// Chủ nhà vừa bắt chụp lại thì nhắc lý do ngay đầu tấm — người ta mở tấm
  /// này chính là để sửa đúng chỗ đó.
  final String? lyDoTraVe;
  final DienNuocApi api;

  /// Chỉ để test thay chỗ tải ảnh thật.
  final ImageUploadFn? uploadFn;

  @override
  State<GuiChiSoSheet> createState() => _GuiChiSoSheetState();
}

class _GuiChiSoSheetState extends State<GuiChiSoSheet> {
  final _dien = TextEditingController();
  final _nuoc = TextEditingController();
  final _anhDien = <UploadImage>[];
  final _anhNuoc = <UploadImage>[];
  String? _loi;
  bool _dangGui = false;

  @override
  void dispose() {
    _dien.dispose();
    _nuoc.dispose();
    super.dispose();
  }

  static double? _so(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  static String? _url(List<UploadImage> a) =>
      a.isEmpty || a.first.failed ? null : a.first.url;

  bool get _dangTaiAnh => [..._anhDien, ..._anhNuoc].any((a) => a.uploading);

  Future<void> _gui() async {
    final d = _so(_dien.text);
    final n = _so(_nuoc.text);
    if (d == null || n == null) {
      setState(() => _loi = 'Nhập đủ chỉ số điện và nước.');
      return;
    }
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await widget.api.gui(
        contractId: widget.contractId,
        dien: d,
        nuoc: n,
        anhDien: _url(_anhDien),
        anhNuoc: _url(_anhNuoc),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      // NGUYÊN VĂN từ server: "Chỉ số nhỏ hơn tháng trước (điện 852, nước
      // 110)" nói rõ phải kiểm lại cái gì; "Có lỗi xảy ra" thì không.
      if (mounted) {
        setState(() {
          _dangGui = false;
          _loi = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dangGui = false;
          _loi = 'Không gửi được. Kiểm tra mạng rồi thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final upload = widget.uploadFn ?? const ApiClient().uploadImage;
    final thieuAnh = _url(_anhDien) == null || _url(_anhNuoc) == null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HD.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gửi chỉ số điện nước · Phòng ${widget.maPhong}',
                style: HD.bodyBold(size: 16),
              ),
              const SizedBox(height: HD.s4),
              Text(
                'Ghi đúng số trên công tơ và chụp rõ mặt số — chủ nhà duyệt '
                'dựa vào ảnh.',
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
              if ((widget.lyDoTraVe ?? '').isNotEmpty) ...[
                const SizedBox(height: HD.s12),
                Container(
                  padding: const EdgeInsets.all(HD.s12),
                  decoration: BoxDecoration(
                    color: HD.negativeTint,
                    borderRadius: BorderRadius.circular(HD.r8),
                  ),
                  child: Text(
                    'Chủ nhà yêu cầu chụp lại: ${widget.lyDoTraVe}',
                    style: HD.body(size: 13, color: HD.negative),
                  ),
                ),
              ],
              const SizedBox(height: HD.s16),
              DsTextField(
                controller: _dien,
                label: 'Chỉ số điện (kWh)',
                hint: 'Số đang hiện trên công tơ điện',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: HD.s8),
              Text('Ảnh công tơ điện', style: HD.caption()),
              const SizedBox(height: HD.s4),
              ImageGridUploader(
                images: _anhDien,
                maxImages: 1,
                uploadFn: upload,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: HD.s16),
              DsTextField(
                controller: _nuoc,
                label: 'Chỉ số nước (m³)',
                hint: 'Số đang hiện trên công tơ nước',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: HD.s8),
              Text('Ảnh công tơ nước', style: HD.caption()),
              const SizedBox(height: HD.s4),
              ImageGridUploader(
                images: _anhNuoc,
                maxImages: 1,
                uploadFn: upload,
                onChanged: () => setState(() {}),
              ),
              if (thieuAnh) ...[
                const SizedBox(height: HD.s8),
                // Không chặn: vẫn gửi được, nhưng nói trước hệ quả để người
                // thuê khỏi bất ngờ khi bị trả về.
                Text(
                  'Chưa đủ hai ảnh — chủ nhà sẽ thấy "Thiếu ảnh" và có thể yêu '
                  'cầu chụp lại.',
                  style: HD.body(size: 12, color: HD.svcOrange),
                ),
              ],
              if (_loi != null) ...[
                const SizedBox(height: HD.s8),
                Text(_loi!, style: HD.body(size: 13, color: HD.negative)),
              ],
              const SizedBox(height: HD.s16),
              DsButton(
                label: 'Gửi chủ nhà duyệt',
                expand: true,
                isLoading: _dangGui,
                // Ảnh đang tải lên mà bấm gửi thì server nhận "chưa có ảnh".
                onPressed: _dangTaiAnh ? null : _gui,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
