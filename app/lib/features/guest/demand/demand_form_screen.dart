import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/demand_api.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/data/services/location_input_service.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Form đăng tin NHU CẦU ("Cần thuê" / "Cần mua").
/// Route: không có URL (push từ [PostChooserScreen]). API: POST /api/demands.
///
/// Nguyên tắc: **KHÔNG có trường nào bắt buộc trừ loại hình.** Người đang tìm
/// nhà chưa biết chắc điều gì cả — ép họ điền đủ mới cho đăng thì họ bỏ đi.
/// Không có ảnh, không có địa chỉ chính xác, không có SĐT.
///
/// Vì sao KHÔNG hỏi số điện thoại: đăng nhu cầu kèm số công khai là mồi cho môi
/// giới gọi rác, và người dùng sẽ không đăng lần thứ hai. Liên hệ đi qua chat.
class DemandFormScreen extends StatefulWidget {
  const DemandFormScreen({super.key, required this.kind, this.api});

  /// 'rent' = cần thuê · 'buy' = cần mua.
  final String kind;

  /// Chỉ để test bơm API giả.
  final DemandApi? api;

  @override
  State<DemandFormScreen> createState() => _DemandFormScreenState();
}

class _DemandFormScreenState extends State<DemandFormScreen> {
  static const _loc = LocationInputService();
  final _repo = ApiHouseRepository();

  DemandApi get _api => widget.api ?? const DemandApi();
  bool get _laThue => widget.kind == 'rent';

  final _noteCtrl = TextEditingController();
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  final _areaMinCtrl = TextEditingController();

  List<Map<String, dynamic>> _cats = const [];
  List<AdminUnit> _provinces = const [];
  AdminUnit? _province;

  final Set<int> _catIds = {};
  final Set<String> _needs = {};
  int? _bedroomsMin;
  DateTime? _moveIn;
  int? _durationMonths;
  int? _occupants;
  String? _payment;
  String? _purpose;

  bool _dangGui = false;

  @override
  void initState() {
    super.initState();
    _napTinh();
    _napLoaiHinh();
  }

  /// Nạp danh mục THẲNG từ repository, không mượn `HouseProvider.fetchInitialData`
  /// — hàm đó kéo theo cả định vị GPS và tải danh sách tin, tức là màn hình này
  /// sẽ xin quyền vị trí mà không có lý do gì.
  Future<void> _napLoaiHinh() async {
    try {
      final ds = await _repo.getCategories();
      if (mounted) setState(() => _cats = ds);
    } catch (_) {
      // Không có danh mục thì nút Đăng sẽ chặn (phải chọn ít nhất một loại).
    }
  }

  Future<void> _napTinh() async {
    try {
      final ds = await _loc.provinces();
      if (mounted) setState(() => _provinces = ds);
    } catch (_) {
      // Không có danh sách tỉnh thì vẫn đăng được — khu vực là tuỳ chọn.
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _areaMinCtrl.dispose();
    super.dispose();
  }

  /// Người dùng gõ "5" nghĩa là 5 triệu (thuê) hoặc 5 tỷ (mua). Bắt họ gõ đủ
  /// "5000000" là cách chắc chắn nhận về những con số sai một chữ số 0.
  double? _tienTuO(TextEditingController c) {
    final s = c.text.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null) return null;
    return v * (_laThue ? 1000000 : 1000000000);
  }

  Future<void> _gui() async {
    final l = AppLocalizations.of(context);
    if (_catIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.demandPickTypeFirst)));
      return;
    }
    if (context.read<AuthProvider>().currentUser == null) {
      GuestGate.promptLogin(context, message: l.demandNeedLogin);
      return;
    }

    setState(() => _dangGui = true);
    try {
      await _api.create({
        'kind': widget.kind,
        'province_code': _province?.code,
        'province_name': _province?.name,
        'category_ids': _catIds.toList(),
        'budget_min': _tienTuO(_budgetMinCtrl),
        'budget_max': _tienTuO(_budgetMaxCtrl),
        'area_min': double.tryParse(_areaMinCtrl.text.trim()),
        'bedrooms_min': _bedroomsMin,
        if (_laThue)
          'move_in_date': _moveIn?.toIso8601String().split('T').first,
        if (_laThue) 'duration_months': _durationMonths,
        if (_laThue) 'occupants': _occupants,
        if (!_laThue) 'payment_method': _payment,
        if (!_laThue) 'purpose': _purpose,
        'needs': _needs.toList(),
        'note': _noteCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.demandSubmitted)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cats = _cats;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: _laThue ? l.demandFormTitleRent : l.demandFormTitleBuy,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          DsFormSection(
            title: l.demandSecArea,
            children: [
              DropdownButtonFormField<AdminUnit>(
                initialValue: _province,
                isExpanded: true,
                decoration: InputDecoration(hintText: l.demandProvinceHint),
                items: [
                  for (final p in _provinces)
                    DropdownMenuItem(value: p, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _province = v),
              ),
            ],
          ),
          DsFormSection(
            title: l.demandSecType,
            children: [
              Wrap(
                spacing: HD.s8,
                runSpacing: HD.s8,
                children: [
                  for (final c in cats)
                    FilterChip(
                      label: Text('${c['name']}'),
                      selected: _catIds.contains(c['id'] as int),
                      onSelected: (s) => setState(() {
                        final id = c['id'] as int;
                        s ? _catIds.add(id) : _catIds.remove(id);
                      }),
                    ),
                ],
              ),
            ],
          ),
          DsFormSection(
            title: l.demandSecBudget,
            helper: _laThue ? l.demandBudgetUnitRent : l.demandBudgetUnitBuy,
            children: [
              Row(
                children: [
                  Expanded(child: _oTien(_budgetMinCtrl, l.demandBudgetFrom)),
                  const SizedBox(width: HD.s12),
                  Expanded(child: _oTien(_budgetMaxCtrl, l.demandBudgetTo)),
                ],
              ),
            ],
          ),
          DsFormSection(
            title: l.demandSecMore,
            children: [
              DsTextField(
                controller: _areaMinCtrl,
                label: l.demandAreaMin,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              _dem(
                l.demandBedroomsMin,
                _bedroomsMin,
                (v) => setState(() => _bedroomsMin = v),
              ),
              if (_laThue) ...[
                _ngayDonVao(l),
                _dem(
                  l.demandDuration,
                  _durationMonths,
                  (v) => setState(() => _durationMonths = v),
                  buoc: 3,
                ),
                _dem(
                  l.demandOccupants,
                  _occupants,
                  (v) => setState(() => _occupants = v),
                ),
              ] else ...[
                _chonMot(l.demandPayment, _payment, {
                  'cash': l.demandPaymentCash,
                  'loan': l.demandPaymentLoan,
                }, (v) => setState(() => _payment = v)),
                _chonMot(l.demandPurpose, _purpose, {
                  'live': l.demandPurposeLive,
                  'invest': l.demandPurposeInvest,
                }, (v) => setState(() => _purpose = v)),
              ],
              _chonNhieuYeuCau(l),
              DsTextField(
                controller: _noteCtrl,
                label: l.demandNote,
                hint: l.demandNoteHint,
                maxLines: 3,
                maxLength: 2000,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HD.s16),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: HD.accent),
              onPressed: _dangGui ? null : _gui,
              child: _dangGui
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.demandSubmit),
            ),
          ),
        ),
      ),
    );
  }

  Widget _oTien(TextEditingController c, String nhan) => DsTextField(
    controller: c,
    label: nhan,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
  );

  /// Ô số bằng nút +/− thay vì bàn phím: các số ở đây đều nhỏ (0–20 phòng ngủ,
  /// vài người ở) và gõ bàn phím số trên web di động là thao tác nặng nhất của
  /// cả form.
  Widget _dem(
    String nhan,
    int? giaTri,
    ValueChanged<int?> doi, {
    int buoc = 1,
  }) {
    return Row(
      children: [
        Expanded(child: Text(nhan, style: HD.body())),
        IconButton(
          onPressed: giaTri == null || giaTri <= buoc
              ? (giaTri == null ? null : () => doi(null))
              : () => doi(giaTri - buoc),
          icon: const Icon(Icons.remove_circle_outline),
          color: HD.inkMuted,
        ),
        SizedBox(
          width: 34,
          child: Text(
            giaTri?.toString() ?? '—',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: () => doi((giaTri ?? 0) + buoc),
          icon: const Icon(Icons.add_circle_outline),
          color: HD.accent,
        ),
      ],
    );
  }

  Widget _ngayDonVao(AppLocalizations l) {
    final t = _moveIn == null
        ? '—'
        : '${_moveIn!.day}/${_moveIn!.month}/${_moveIn!.year}';
    return Row(
      children: [
        Expanded(child: Text(l.demandMoveIn, style: HD.body())),
        TextButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: _moveIn ?? now,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _moveIn = d);
          },
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text(t),
        ),
      ],
    );
  }

  Widget _chonMot(
    String nhan,
    String? giaTri,
    Map<String, String> lua,
    ValueChanged<String?> doi,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: HD.caption()),
        const SizedBox(height: HD.s4),
        Wrap(
          spacing: HD.s8,
          children: [
            for (final e in lua.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: giaTri == e.key,
                // Bấm lại chip đang chọn = bỏ chọn: mọi trường ở đây đều tuỳ
                // chọn, phải có đường lùi về "chưa trả lời".
                onSelected: (s) => doi(s ? e.key : null),
              ),
          ],
        ),
      ],
    );
  }

  Widget _chonNhieuYeuCau(AppLocalizations l) {
    final lua = {
      'parking': l.demandNeedParking,
      'free_hours': l.demandNeedFreeHours,
      'aircon': l.demandNeedAircon,
      'private': l.demandNeedPrivate,
      'pet': l.demandNeedPet,
      'balcony': l.demandNeedBalcony,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.demandNeeds, style: HD.caption()),
        const SizedBox(height: HD.s4),
        Wrap(
          spacing: HD.s8,
          runSpacing: HD.s8,
          children: [
            for (final e in lua.entries)
              FilterChip(
                label: Text(e.value),
                selected: _needs.contains(e.key),
                onSelected: (s) => setState(
                  () => s ? _needs.add(e.key) : _needs.remove(e.key),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
