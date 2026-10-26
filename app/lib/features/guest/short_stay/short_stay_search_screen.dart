import 'package:flutter/material.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/guest/booking/room_booking_screen.dart';
import 'package:house_booking/features/guest/short_stay/stay_picker.dart';

class ShortStaySearchScreen extends StatefulWidget {
  const ShortStaySearchScreen({
    super.key,
    this.api = const ShortStayApi(),
    this.datPhongApi = const DatPhongApi(),
  });
  final ShortStayApi api;

  /// API của màn đặt phòng mở ra khi chạm một phòng.
  final DatPhongApi datPhongApi;
  @override
  State<ShortStaySearchScreen> createState() => _ShortStaySearchScreenState();
}

class _ShortStaySearchScreenState extends State<ShortStaySearchScreen> {
  final _query = TextEditingController();
  String _mode = 'theo_gio';
  late DateTime _start, _end;
  List<Map<String, dynamic>> _rooms = [];
  String? _error;
  bool _loading = false, _searched = false;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    final (a, b) = StayPicker.defaults(_mode);
    _start = a;
    _end = b;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.api.search(
        query: _query.text,
        mode: _mode,
        start: _start,
        end: _end,
      );
      if (mounted && version == _version) {
        setState(() {
          _rooms = rows;
          _searched = true;
        });
      }
    } catch (e) {
      if (mounted && version == _version) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(title: const Text('Ở ngắn hạn')),
    body: ListView(
      padding: const EdgeInsets.all(HD.s16),
      children: [
        TextField(
          controller: _query,
          decoration: const InputDecoration(
            labelText: 'Địa điểm, thành phố hoặc tên toà nhà',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {
            _version++;
            _rooms = [];
            _searched = false;
          }),
        ),
        StayPicker(
          mode: _mode,
          start: _start,
          end: _end,
          onChanged: (m, a, b) => setState(() {
            _mode = m;
            _start = a;
            _end = b;
            _rooms = [];
            _searched = false;
            _version++;
          }),
        ),
        const SizedBox(height: HD.s16),
        DsButton(
          label: 'Tìm phòng trống',
          isLoading: _loading,
          onPressed: _loading ? null : _search,
          expand: true,
        ),
        if (_error != null) Text(_error!, style: HD.body(color: HD.accent)),
        if (_searched && _rooms.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Chưa có phòng phù hợp. Thử đổi địa điểm hoặc thời gian.',
            ),
          ),
        ..._rooms.map((r) {
          final q = r['quote'] as Map<String, dynamic>;
          return Card(
            child: ListTile(
              title: Text('${r['building_name']} · Phòng ${r['room_code']}'),
              subtitle: Text(
                '${r['address']} · ${r['city']}\n${shortStayModes[_mode]} · Tổng ${stayMoney(q['total_amount'])}\n${q['cancellation_policy']}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomBookingScreen(
                    api: widget.datPhongApi,
                    args: RoomBookingArgs(
                      roomId: r['room_id'] as int,
                      roomCode: r['room_code'] as String,
                      buildingName: r['building_name'] as String,
                      price: 0,
                      saleName: '',
                      mode: _mode,
                      start: _start,
                      end: _end,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),
  );
}
