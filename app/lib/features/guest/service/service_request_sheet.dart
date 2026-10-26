import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/service_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Gợi ý mô tả theo TỪNG dịch vụ nhanh. Ô "Mô tả nhu cầu" trống trơn thì khách
/// gõ "sửa giúp em cái" — admin gọi lại vẫn phải hỏi lại từ đầu. Một dòng ví dụ
/// đúng nghề kéo được thông tin thật ngay từ lần gửi đầu.
///
/// Cố ý là MAP TĨNH chứ không phải bảng định nghĩa trường động: khác biệt giữa
/// các dịch vụ ở đây chỉ là chữ gợi ý, dựng cả một cơ chế schema động cho việc
/// đó là thứ sẽ không ai bảo trì.
const Map<String, String> _goiYMoTa = {
  'electric': 'VD: aptomat nhảy liên tục, ổ cắm phòng ngủ mất điện…',
  'plumbing': 'VD: rò nước dưới bồn rửa, vòi sen yếu, thay khoá nước…',
  'unclog': 'VD: tắc bồn cầu 2 ngày, cống thoát sàn nhà tắm dâng ngược…',
  'ac_repair': 'VD: máy không lạnh, chảy nước ở dàn lạnh, cần vệ sinh 2 máy…',
  'appliance_repair': 'VD: máy giặt không vắt, tủ lạnh không mát ngăn dưới…',
  'cleaning': 'VD: nhà 60m² 2 tầng, tổng vệ sinh sau sửa chữa…',
  'moving': 'VD: chuyển từ Q7 sang Q2, có tủ lạnh + 1 giường + 10 thùng…',
  'painting': 'VD: sơn lại 2 phòng ngủ ~40m², tường có vết ố…',
  'waterproofing': 'VD: trần nhà vệ sinh tầng 2 thấm xuống, sân thượng nứt…',
  'pest_control': 'VD: gián nhiều ở bếp, nghi có mối ở tủ gỗ…',
  'hourly_helper': 'VD: dọn dẹp 3 buổi/tuần, mỗi buổi 3 tiếng, buổi sáng…',
};

/// Mở bottom-sheet ĐẶT DỊCH VỤ. API: POST /api/services/requests.
///
/// Khách vãng lai gửi được (chỉ cần Tên + SĐT) — người đang cần thợ gấp mà bắt
/// tạo tài khoản là mất khách ngay tại đó. Gửi xong, admin nhận thông báo trên
/// điện thoại rồi gọi lại và xếp thợ; app KHÔNG hứa hẹn thời gian cụ thể vì
/// không có gì bảo đảm được điều đó.
Future<void> showServiceRequestSheet(
  BuildContext context, {
  required String serviceSlug,
  required String serviceName,
  ServiceApi? api,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: HD.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ServiceRequestForm(
        serviceSlug: serviceSlug,
        serviceName: serviceName,
        api: api,
      ),
    ),
  );
}

class _ServiceRequestForm extends StatefulWidget {
  const _ServiceRequestForm({
    required this.serviceSlug,
    required this.serviceName,
    this.api,
  });
  final String serviceSlug;
  final String serviceName;

  /// Chỉ để test bơm API giả.
  final ServiceApi? api;

  @override
  State<_ServiceRequestForm> createState() => _ServiceRequestFormState();
}

class _ServiceRequestFormState extends State<_ServiceRequestForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _budget = TextEditingController();
  final _desc = TextEditingController();
  bool _sending = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _area, _budget, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.length < 9) {
      setState(() => _error = l.rfqValidation);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await (widget.api ?? const ServiceApi()).guiYeuCau({
        'service_slug': widget.serviceSlug,
        'name': name,
        'phone': phone,
        if (_area.text.trim().isNotEmpty) 'area': _area.text.trim(),
        if (_budget.text.trim().isNotEmpty) 'budget': _budget.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      });
      if (mounted) setState(() => _done = true);
    } catch (e) {
      // Báo lỗi THẬT để khách biết & thử lại (trước đây fail-silent → dễ mất
      // lead âm thầm khi backend 404/lỗi mạng).
      if (mounted) {
        setState(() => _error = l.rfqSendError);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_done) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: HD.positive,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              l.rfqSuccessTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: HD.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.svcBookedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HD.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(l.rfqClose),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KHÔNG tự vẽ thanh kéo: theme đã bật `showDragHandle: true`
            // (app_theme.dart), thêm cái nữa là hai vạch xám chồng nhau.
            Text(
              l.svcBookNow(widget.serviceName),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: HD.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l.rfqSubtitle,
              style: const TextStyle(color: HD.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _field(_name, l.rfqFieldName, TextInputType.name),
            const SizedBox(height: 10),
            _field(
              _phone,
              l.rfqFieldPhone,
              TextInputType.phone,
              digitsOnly: true,
            ),
            const SizedBox(height: 10),
            _field(_area, l.rfqFieldArea, TextInputType.text),
            const SizedBox(height: 10),
            _field(_budget, l.rfqFieldBudget, TextInputType.text),
            const SizedBox(height: 10),
            _field(
              _desc,
              _goiYMoTa[widget.serviceSlug] ?? l.rfqFieldDesc,
              TextInputType.multiline,
              lines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: HD.negative)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.rfqSubmit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    TextInputType type, {
    int lines = 1,
    bool digitsOnly = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLines: lines,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: HD.paperRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HD.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: HD.hairline),
        ),
      ),
    );
  }
}
