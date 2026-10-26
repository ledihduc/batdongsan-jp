import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/guest/short_stay/stay_picker.dart';

class ShortStayRoomsScreen extends StatefulWidget {
  const ShortStayRoomsScreen({super.key, this.api = const ShortStayApi()});
  final ShortStayApi api;
  @override
  State<ShortStayRoomsScreen> createState() => _ShortStayRoomsScreenState();
}

class _ShortStayRoomsScreenState extends State<ShortStayRoomsScreen> {
  List<Map<String, dynamic>> _rooms = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rooms = await widget.api.rooms();
      if (mounted) setState(() => _rooms = rooms);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(title: const Text('Giá & khoá phòng')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) Text(_error!),
              if (_rooms.isEmpty) const Text('Chưa có phòng được phân công.'),
              ..._rooms.map(
                (r) => Card(
                  child: ListTile(
                    title: Text('${r['building_name']} · ${r['room_code']}'),
                    subtitle: Text(
                      r['dang_bat'] == true
                          ? 'Đang mở ngắn hạn'
                          : 'Chưa mở ngắn hạn',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _RoomSettings(room: r, api: widget.api),
                        ),
                      );
                      _load();
                    },
                  ),
                ),
              ),
            ],
          ),
  );
}

class _RoomSettings extends StatefulWidget {
  const _RoomSettings({required this.room, required this.api});
  final Map<String, dynamic> room;
  final ShortStayApi api;
  @override
  State<_RoomSettings> createState() => _RoomSettingsState();
}

class _RoomSettingsState extends State<_RoomSettings> {
  final Map<String, TextEditingController> _fields = {};
  final _note = TextEditingController();
  final _roomType = TextEditingController();
  List<Map<String, dynamic>> _blocks = [];
  bool _enabled = false, _busy = false;
  String? _error, _success;
  late DateTime _start, _end;
  int get _id => widget.room['room_id'] as int;
  static const _labels = {
    'gia_theo_gio': 'Giá mỗi giờ (đ)',
    'gia_qua_dem': 'Giá qua đêm (đ)',
    'gia_theo_ngay': 'Giá mỗi ngày (đ)',
    'huy_truoc_gio': 'Huỷ theo giờ: trước giờ nhận (giờ)',
    'huy_truoc_dem': 'Huỷ qua đêm: trước giờ nhận (giờ)',
    'huy_truoc_ngay': 'Huỷ theo ngày: trước giờ nhận (giờ)',
  };
  @override
  void initState() {
    super.initState();
    _enabled = widget.room['dang_bat'] == true;
    _roomType.text = widget.room['room_type'] as String? ?? 'Phòng';
    for (final key in _labels.keys) {
      final value = (widget.room['rates'] as Map)[key];
      _fields[key] = TextEditingController(
        text: value == null ? '' : (value as num).toStringAsFixed(0),
      );
    }
    final (a, b) = StayPicker.defaults('theo_gio');
    _start = a;
    _end = b;
    _loadBlocks();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _note.dispose();
    _roomType.dispose();
    super.dispose();
  }

  Future<void> _loadBlocks() async {
    try {
      final rows = await widget.api.blocks(_id);
      if (mounted) setState(() => _blocks = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _run(Future<void> Function() task, String success) async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await task();
      await _loadBlocks();
      if (mounted) setState(() => _success = success);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    if (_roomType.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập loại phòng.');
      return;
    }
    final data = <String, dynamic>{
      'dang_bat': _enabled,
      'loai_phong': _roomType.text.trim(),
    };
    for (final entry in _fields.entries) {
      final text = entry.value.text.trim();
      final value = int.tryParse(text);
      if (text.isNotEmpty && value == null ||
          text.isEmpty && entry.key.startsWith('huy_')) {
        setState(() => _error = 'Vui lòng nhập số nguyên hợp lệ.');
        return;
      }
      data[entry.key] = value;
    }
    _run(() => widget.api.rates(_id, data), 'Đã lưu giá và chính sách');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(title: Text('Phòng ${widget.room['room_code']}')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.room['can_set_rates'] == true) ...[
          Text('Giá ngắn hạn', style: HD.bodyBold(size: 20)),
          TextField(
            controller: _roomType,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Loại phòng *'),
          ),
          const Text(
            'Để trống giá để tắt một hình thức. Giá không bao gồm thu tiền qua ứng dụng. Qua đêm: 21:00–09:00; theo ngày: mỗi ngày 24 giờ.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mở đặt ngắn hạn'),
            value: _enabled,
            onChanged: _busy ? null : (v) => setState(() => _enabled = v),
          ),
          ..._labels.entries.map(
            (e) => TextField(
              controller: _fields[e.key],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: e.value),
            ),
          ),
          const SizedBox(height: 16),
          DsButton(
            label: 'Lưu giá & chính sách',
            onPressed: _busy ? null : _save,
            expand: true,
          ),
        ] else
          const Text('Giá và chính sách do chủ phòng quyết định.'),
        const SizedBox(height: 24),
        Text('Khoá phòng thủ công', style: HD.bodyBold(size: 20)),
        StayPicker(
          mode: 'theo_gio',
          start: _start,
          end: _end,
          showModes: false,
          onChanged: (_, a, b) => setState(() {
            _start = a;
            _end = b;
          }),
        ),
        TextField(
          controller: _note,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Lý do khoá phòng'),
        ),
        DsButton(
          label: 'Khoá khoảng thời gian',
          onPressed: _busy
              ? null
              : () => _run(
                  () => widget.api.block(_id, _start, _end, _note.text),
                  'Đã khoá phòng',
                ),
          expand: true,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_error!, style: HD.body(color: HD.accent)),
          ),
        if (_success != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_success!),
          ),
        const SizedBox(height: 16),
        Text('Lịch khoá phòng', style: HD.bodyBold()),
        ..._blocks.map(
          (b) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${stayTime(b['check_in_at'])} – ${stayTime(b['check_out_at'])}',
            ),
            subtitle: Text(b['note'] as String? ?? ''),
            trailing: TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => widget.api.unblock(_id, b['id'] as int),
                      'Đã mở lại phòng',
                    ),
              child: const Text('Mở lại'),
            ),
          ),
        ),
      ],
    ),
  );
}
