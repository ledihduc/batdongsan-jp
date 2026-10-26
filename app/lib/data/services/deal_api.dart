import 'package:house_booking/data/services/api_client.dart';

class DealApi {
  const DealApi({ApiClient client = const ApiClient()}) : _c = client;
  final ApiClient _c;

  Future<DealModel> chotPhong(int roomId, {String? ghiChu}) async => DealModel.fromMap(await _c.post('/api/deals', body: {'room_id': roomId, if (ghiChu != null) 'note': ghiChu}));
  Future<DealModel> chotTin(int houseId, {String? ghiChu}) async => DealModel.fromMap(await _c.post('/api/deals', body: {'house_id': houseId, if (ghiChu != null) 'note': ghiChu}));
  Future<List<DealModel>> cuaToi() async => _ds(await _c.getList('/api/deals/mine'));
  Future<List<DealModel>> hopChoDuyet() async => _ds(await _c.getList('/api/deals/inbox'));
  Future<void> xacNhan(int id) async => _c.post('/api/deals/$id/confirm');
  Future<void> xacNhanKhach(int id) async => _c.post('/api/deals/$id/confirm-customer');
  Future<void> tuChoi(int id, {String? lyDo}) async => _c.post('/api/deals/$id/reject', body: {if (lyDo != null) 'reason': lyDo});
  List<DealModel> _ds(List<dynamic> r) => r.whereType<Map>().map((e) => DealModel.fromMap(Map<String, dynamic>.from(e))).toList();
}

class DealModel {
  const DealModel({required this.id, required this.loai, required this.trangThai, required this.soTien, required this.tenDoiTuong, required this.tenKhach});
  final int id;
  final String loai;
  final String trangThai;
  final int soTien;
  final String tenDoiTuong;
  final String tenKhach;
  bool get dangCho => trangThai == 'pending';
  factory DealModel.fromMap(Map<String, dynamic> m) => DealModel(id: (m['id'] as num).toInt(), loai: m['deal_type'] as String? ?? 'rent', trangThai: m['status'] as String? ?? 'pending', soTien: (m['amount'] as num?)?.toInt() ?? 0, tenDoiTuong: m['ten_doi_tuong'] as String? ?? '', tenKhach: m['ten_khach'] as String? ?? '');
}
