import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/user_preferences.dart';
import 'package:house_booking/data/services/location_input_service.dart';
import 'package:house_booking/data/services/preferences_service.dart';

/// Khảo sát phân loại người dùng (redesign v2 P1). Đa chọn mục đích → suy ra
/// "thế giới mặc định" (BĐS/Thi công). Bỏ qua được. Dùng cả lần đầu (onboarding)
/// lẫn sửa lại trong Hồ sơ ([editMode] = true → tiêu đề & nút "Lưu").
class IntroSurveyScreen extends StatefulWidget {
  const IntroSurveyScreen({super.key, required this.onDone, this.editMode = false});

  /// Gọi sau khi lưu/bỏ qua (đóng survey, tiếp tục vào app).
  final VoidCallback onDone;
  final bool editMode;

  @override
  State<IntroSurveyScreen> createState() => _IntroSurveyScreenState();
}

class _IntroSurveyScreenState extends State<IntroSurveyScreen> {
  // Mục đích BĐS (KHÔNG có "là đơn vị" — đó là CTA riêng "Trở thành đơn vị").
  // Bỏ 'buy' (Mua nhà đất): app đã pivot chỉ còn thuê/cho thuê. Nhánh Xây dựng
  // KHÔNG còn chip ý định trung gian (find_service/follow_construction) — người
  // dùng chọn thẳng dịch vụ ở [_services] bên dưới.
  static const _interests = <(String, IconData)>[
    ('rent', Icons.home_outlined),
    ('sell_or_list', Icons.vpn_key_outlined),
  ];
  static const _services = <String>[
    'design',
    'build',
    'interior',
    'industrial',
  ];

  String _interestLabel(AppLocalizations l, String key) => switch (key) {
        'rent' => l.surveyInterestRent,
        'sell_or_list' => l.surveyInterestSellOrList,
        _ => key,
      };

  String _serviceLabel(AppLocalizations l, String key) => switch (key) {
        'design' => l.surveyServiceDesign,
        'build' => l.surveyServiceBuild,
        'interior' => l.surveyServiceInterior,
        'industrial' => l.surveyServiceIndustrial,
        _ => key,
      };

  final Set<String> _pickedInterests = {};
  final Set<String> _pickedServices = {};
  String? _province;
  List<AdminUnit> _provinces = const [];
  bool _saving = false;
  /// Tự khai "tôi là đơn vị thi công/thiết kế" — KHÔNG bắt buộc.
  bool _laDonVi = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.editMode) {
      final p = await PreferencesService.instance.getLocal();
      if (mounted) {
        setState(() {
          _pickedInterests.addAll(p.interests);
          _pickedServices.addAll(p.serviceSlugs);
          _province = p.provinces.isNotEmpty ? p.provinces.first : null;
        });
      }
      final donVi = await PreferencesService.instance.hasProviderIntent();
      if (mounted) {
        setState(() => _laDonVi = donVi);
      }
    }
    try {
      final list = await const LocationInputService().provinces();
      if (mounted) setState(() => _provinces = list);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    final interests = _pickedInterests.toList();
    // Thế giới Xây dựng nay biểu thị QUA việc chọn dịch vụ (_pickedServices),
    // không còn qua interest 'find_service'/'follow_construction'. Thứ tự ưu tiên
    // suy defaultWorld:
    //   1. Tự khai là đơn vị → Xây dựng (họ vào để BÁN dịch vụ, không xem nhà).
    //   2. Có chọn dịch vụ nào → Xây dựng.
    //   3. Còn lại → computeWorld(interests) (rent/sell_or_list → BĐS).
    // Lưu ý: nhánh 'construction' trong UserPreferences.computeWorld nay chỉ còn
    // phục vụ ĐỌC prefs cũ đã lưu — đường vào khảo sát mới không sinh ra nó nữa.
    final defaultWorld = _laDonVi || _pickedServices.isNotEmpty
        ? kWorldConstruction
        : UserPreferences.computeWorld(interests);
    final prefs = UserPreferences(
      interests: interests,
      provinces: _province != null ? [_province!] : const [],
      serviceSlugs: _pickedServices.toList(),
      defaultWorld: defaultWorld,
    );
    await PreferencesService.instance.setProviderIntent(_laDonVi);
    await PreferencesService.instance.saveSurvey(prefs);
    if (mounted) {
      if (widget.editMode) {
        AppFeedback.success(context, l.surveyPrefsUpdated);
      }
      widget.onDone();
    }
  }

  Future<void> _skip() async {
    await PreferencesService.instance.markPrompted();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return HDGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: widget.editMode
            ? DsAppBar(
                eyebrow: l.surveyEyebrow, title: l.surveyMyInterestsTitle)
            : null,
        body: SafeArea(
          child: Column(
            children: [
              if (!widget.editMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saving ? null : _skip,
                    child: Text(l.surveySkip),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    if (!widget.editMode) ...[
                      const SizedBox(height: 8),
                      Text(l.surveyGreeting,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: HD.ink)),
                      const SizedBox(height: 6),
                      Text(l.surveyIntro,
                          style: const TextStyle(
                              color: HD.inkSoft, fontSize: 14)),
                      const SizedBox(height: 20),
                    ],
                    // "Bạn muốn làm gì?" chia THÀNH HAI mảng nghiệp vụ rõ rệt để
                    // người dùng phân biệt ngay từ bước đầu.
                    _section(l.surveyWhatDoYouWant),
                    // ── Bất động sản ──────────────────────────────────────────
                    _subLabel(l.surveyRealEstateSection),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (key, icon) in _interests)
                          FilterChip(
                            avatar: Icon(icon,
                                size: 18,
                                color: _pickedInterests.contains(key)
                                    ? Colors.white
                                    : HD.accent),
                            selected: _pickedInterests.contains(key),
                            label: Text(_interestLabel(l, key)),
                            onSelected: (v) => setState(() => v
                                ? _pickedInterests.add(key)
                                : _pickedInterests.remove(key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Xây dựng (4 dịch vụ hiện thẳng) ───────────────────────
                    _subLabel(l.surveyConstructionSection),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final key in _services)
                          FilterChip(
                            selected: _pickedServices.contains(key),
                            label: Text(_serviceLabel(l, key)),
                            onSelected: (v) => setState(() => v
                                ? _pickedServices.add(key)
                                : _pickedServices.remove(key)),
                          ),
                      ],
                    ),
                    // "Tôi là đơn vị" — KHÔNG bắt buộc và tách khỏi nhóm mục
                    // đích ở trên: mục đích là thứ người ta muốn LƯỚT, còn đây
                    // là vai trò. Chọn ô này chỉ để định tuyến giao diện (mở
                    // vào thế giới Thi công + ưu tiên thẻ đơn vị sau khi đăng
                    // ký); danh tính đơn vị thật vẫn phải qua hồ sơ + duyệt.
                    const SizedBox(height: 20),
                    _section(l.surveyYouAreTitle),
                    CheckboxListTile(
                      value: _laDonVi,
                      onChanged: (v) => setState(() => _laDonVi = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l.surveyIAmProvider,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: HD.ink)),
                      subtitle: Text(l.surveyIAmProviderHint,
                          style: const TextStyle(
                              fontSize: 12, color: HD.inkMuted)),
                    ),
                    const SizedBox(height: 20),
                    _section(l.surveyAreaOptional),
                    DropdownButtonFormField<String>(
                      initialValue: _province,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: l.surveyProvinceHint,
                        filled: true,
                        fillColor: HD.paperRaised,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: [
                        for (final p in _provinces)
                          DropdownMenuItem(value: p.code, child: Text(p.name)),
                      ],
                      onChanged: (v) => setState(() => _province = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: HD.accent,
                            minimumSize: const Size.fromHeight(52)),
                        onPressed: _submit,
                        child: Text(
                            widget.editMode ? l.surveySave : l.surveyStartExploring),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: HD.ink)),
      );

  /// Nhãn phụ cho 2 mảng nghiệp vụ (Bất động sản / Xây dựng) bên dưới câu hỏi.
  Widget _subLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: HD.inkSoft)),
      );
}
