import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/permissions/with_camera_permission.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Nhập thông tin hồ sơ người bán. Route: không có URL (push).
/// Provider: AuthProvider. API: PUT /api/users/{id} (qua `updateProfile`).
///
/// Dùng ở HAI chỗ, cùng một biểu mẫu:
///  * Ngay sau khi đăng ký, với [batBuoc] = true — không có nút lùi.
///  * Từ thẻ "Hoàn thiện hồ sơ" ở tab Cá nhân, với [batBuoc] = false.
///
/// Vì sao đặt ngay sau đăng ký: mọi tài khoản mới đều là tài khoản bán
/// (`account_type='sale'`), nên đăng ký xong là đã có một trang công khai.
/// Form đăng ký chỉ hỏi tên/email/mật khẩu và để SĐT tuỳ chọn, nên trang đó ra
/// đời trống trơn; sau này không có gì buộc người ta quay lại điền.
///
/// SĐT và giới thiệu là BẮT BUỘC, ảnh thì không: chọn ảnh phải xin quyền thư
/// viện, ép ở đây thì người từ chối quyền bị chặn cứng ngay lần mở app đầu tiên
/// và không còn đường nào đi tiếp.
class HoanThienHoSoScreen extends StatefulWidget {
  const HoanThienHoSoScreen({super.key, this.batBuoc = false});

  /// Sau đăng ký thì đặt true: chặn nút back, ẩn "Để sau".
  final bool batBuoc;

  @override
  State<HoanThienHoSoScreen> createState() => _HoanThienHoSoScreenState();
}

class _HoanThienHoSoScreenState extends State<HoanThienHoSoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _api = const ApiClient();

  String? _anhMoi;
  bool _dangTaiAnh = false;
  bool _dangLuu = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().currentUser;
    _phoneCtrl.text = u?.phone ?? '';
    _bioCtrl.text = u?.bio ?? '';
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  /// Câu mở sẵn để bấm một cái là có phần giới thiệu dùng được.
  ///
  /// Người mới đăng ký hay khựng ở ô này — không phải vì lười mà vì không biết
  /// nên viết gì. Ô trống kèm một dòng gợi ý mờ là cách chắc chắn để họ bấm
  /// "Để sau"; câu chèn sẵn thì chỉ còn việc sửa lại cho đúng mình.
  static const _goiY = <String>[
    'Chuyên nhà phố và căn hộ khu vực ',
    'Nhận ký gửi bán, cho thuê tại ',
    'Hỗ trợ xem nhà ngoài giờ, tư vấn pháp lý sang tên ',
  ];

  void _chen(String mau) {
    final hienTai = _bioCtrl.text.trim();
    setState(() {
      _bioCtrl.text = hienTai.isEmpty ? mau : '$hienTai $mau';
      _bioCtrl.selection = TextSelection.collapsed(
        offset: _bioCtrl.text.length,
      );
    });
  }

  Future<void> _chonAnh() async {
    final auth = context.read<AuthProvider>();
    final tep = await withCameraPermission(
      context,
      source: ImageSource.gallery,
      primingContext: CameraContext.profileAvatar,
      userId: '${auth.currentUser?.id ?? ''}',
    );
    if (tep == null || !mounted) return; // bấm huỷ ở trình chọn ảnh
    setState(() => _dangTaiAnh = true);
    try {
      final url = await _api.uploadImage(await tep.readAsBytes(), tep.name);
      if (!mounted) return;
      setState(() {
        _anhMoi = url;
        _dangTaiAnh = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangTaiAnh = false);
      AppFeedback.error(context, 'Tải ảnh không được: $e');
    }
  }

  Future<void> _luu() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _dangLuu = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      phone: _phoneCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      // Chỉ gửi ảnh khi vừa chọn ảnh mới — gửi null thì repository bỏ qua
      // trường này, tránh ghi đè ảnh cũ bằng chuỗi rỗng.
      avatarPath: _anhMoi,
    );
    if (!mounted) return;
    setState(() => _dangLuu = false);
    if (!ok) {
      AppFeedback.error(context, auth.errorMessage ?? 'Lưu không được');
      return;
    }
    AppFeedback.success(context, 'Đã lưu hồ sơ');
    if (widget.batBuoc) {
      // Sau đăng ký: về thẳng shell chính, không để lại màn này trong ngăn xếp.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthProvider>().currentUser;
    final anhHienTai = _anhMoi ?? u?.avatarPath ?? '';
    return PopScope(
      // Bắt buộc = không lùi được. Nếu không, người dùng bấm back là thoát ra
      // shell với hồ sơ vẫn trống — đúng thứ màn này sinh ra để chặn.
      canPop: !widget.batBuoc,
      child: Scaffold(
        backgroundColor: HD.paper,
        appBar: DsAppBar(
          eyebrow: 'HỒ SƠ NGƯỜI BÁN',
          title: widget.batBuoc ? 'Còn một bước nữa' : 'Hoàn thiện hồ sơ',
          // Ẩn nút back ở luồng bắt buộc cho khớp với PopScope, thay vì vẽ một
          // nút bấm không có tác dụng.
          showBack: !widget.batBuoc,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(HD.s24),
                  children: [
                    Text(
                      widget.batBuoc
                          ? 'Tài khoản của bạn đã có một trang bán hàng công khai. '
                                'Điền nhanh để khách tìm thấy và liên hệ được.'
                          : 'Những mục này quyết định khách có bấm vào bạn hay không.',
                      style: HD.body(size: 13.5, color: HD.inkSoft),
                    ),
                    const SizedBox(height: HD.s24),
                    _oAnh(anhHienTai),
                    const SizedBox(height: HD.s24),
                    DsTextField(
                      controller: _phoneCtrl,
                      label: 'Số điện thoại',
                      hint: '09xx xxx xxx',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      ],
                      helper: 'Chỉ hiện cho khách khi bạn tự bật ở trang cá nhân.',
                      validator: _kiemTraSo,
                    ),
                    const SizedBox(height: HD.s16),
                    DsTextField(
                      controller: _bioCtrl,
                      label: 'Giới thiệu',
                      hint: 'Bạn mạnh ở khu nào, loại nhà nào, làm nghề bao lâu?',
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 500,
                      validator: _kiemTraGioiThieu,
                    ),
                    const SizedBox(height: HD.s8),
                    _chipGoiY(),
                    const SizedBox(height: HD.s32),
                    DsButton(
                      label: widget.batBuoc ? 'Xong, vào app' : 'Lưu',
                      isLoading: _dangLuu,
                      onPressed: _dangLuu ? null : _luu,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// SĐT bắt buộc: không có số thì công tắc "cho khách gọi" ở trang cá nhân bị
  /// khoá cứng (backend trả `co_so_dien_thoai=false`), và khách chỉ còn cách
  /// nhắn trong app — đúng dòng "Khách chỉ nhắn được trong app" đang hiện.
  String? _kiemTraSo(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return 'Nhập số điện thoại để khách liên hệ được';
    if (s.length < 9 || s.length > 11) return 'Số điện thoại không hợp lệ';
    return null;
  }

  String? _kiemTraGioiThieu(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Viết vài dòng để khách biết bạn làm gì';
    if (s.length < 20) return 'Viết thêm chút nữa (ít nhất 20 ký tự)';
    return null;
  }

  Widget _oAnh(String anh) {
    final a = anh.trim();
    final url = a.isEmpty
        ? null
        : (a.startsWith('http') ? a : '${ApiConfig.baseUrl}$a');
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: HD.accentTint,
          backgroundImage: url == null ? null : NetworkImage(url),
          child: url != null
              ? null
              : const Icon(Icons.person, size: 34, color: HD.accent),
        ),
        const SizedBox(width: HD.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ảnh đại diện', style: HD.bodyBold(size: 14)),
              const SizedBox(height: 2),
              Text(
                'Không bắt buộc, nhưng hồ sơ có ảnh được bấm vào nhiều hơn hẳn.',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
              const SizedBox(height: HD.s8),
              DsButton(
                label: url == null ? 'Chọn ảnh' : 'Đổi ảnh',
                variant: DsButtonVariant.secondary,
                size: DsButtonSize.compact,
                isLoading: _dangTaiAnh,
                onPressed: _dangTaiAnh ? null : _chonAnh,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipGoiY() {
    return Wrap(
      spacing: HD.s8,
      runSpacing: HD.s8,
      children: [
        for (final g in _goiY)
          ActionChip(
            label: Text(g.trim(), style: HD.body(size: 12)),
            onPressed: _dangLuu ? null : () => _chen(g),
            backgroundColor: HD.paperRaised,
            side: const BorderSide(color: HD.hairline),
          ),
      ],
    );
  }
}
