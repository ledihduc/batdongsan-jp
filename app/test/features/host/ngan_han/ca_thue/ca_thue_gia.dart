import 'package:house_booking/data/services/ca_thue_api.dart';

/// Dữ liệu mẫu + API giả dùng chung cho bốn màn quầy lễ tân.
///
/// Một bộ mẫu duy nhất: bốn màn đọc CÙNG một payload nên nếu mỗi test tự bịa
/// một hình dạng khác thì lỗi kiểu "màn này cộng cọc, màn kia không" sẽ lọt.
Map<String, dynamic> mauCa({
  String trangThai = 'checked_in',
  String vao = '2026-09-12T14:00',
  String ra = '2026-09-12T18:00',
  String bayGio = '2026-09-12T16:45',
  int tongPhut = 240,
  int daOPhut = 165,
  int conPhut = 75,
  bool quaGio = false,
  int conToiGioVao = 0,
  bool xemTaiChinh = true,
  double tienPhong = 370000,
  double phuThuTong = 65000,
  double coc = 200000,
  double daThu = 200000,
  double conLai = 235000,
  List<Map<String, dynamic>>? phuThu,
  List<Map<String, dynamic>> thanhToan = const [],
  Map<String, dynamic>? deXuatQuaGio,
}) => {
  'id': 88,
  'ma_dat': 'BK-8821',
  'trang_thai': trangThai,
  'kieu': 'theo_gio',
  'nhan_kieu': 'Theo giờ',
  'nguon': 'direct',
  'vao': vao,
  'ra': ra,
  'bay_gio': bayGio,
  'phong': {
    'id': 1,
    'ma': 'P201',
    'tang': 2,
    'suc_chua': 2,
    'anh': <String>[],
    'hang': 'Studio VIP',
    'giuong': '1 giường đôi',
  },
  'toa': {'id': 10, 'ten': 'An Cư Garden', 'dia_chi': '25 Hoàng Văn Thụ'},
  'tien_do': {
    'tong_phut': tongPhut,
    'da_o_phut': daOPhut,
    'con_phut': conPhut,
    'phan_tram': tongPhut == 0 ? 0.0 : daOPhut / tongPhut * 100,
    'qua_gio': quaGio,
    'con_toi_gio_vao': conToiGioVao,
  },
  'xem_tai_chinh': xemTaiChinh,
  'de_xuat_qua_gio': deXuatQuaGio,
  'gia_gio': 60000,
  if (xemTaiChinh) ...{
    'khach': {'ten': 'Nguyễn Văn An', 'sdt': '0982345678', 'email': null},
    'tien': {
      'tien_phong': tienPhong,
      'phu_thu': phuThuTong,
      'phai_thu': tienPhong + phuThuTong,
      'coc': coc,
      'da_thu': daThu,
      'con_lai': conLai,
      'hoan_lai': conLai < 0 ? -conLai : 0.0,
    },
    'phu_thu': phuThu ??
        [
          {
            'id': 1,
            'loai': 'minibar',
            'ten': 'Nước khoáng Lavie',
            'don_gia': 10000,
            'so_luong': 2,
            'thanh_tien': 20000,
            'ghi_chu': null,
          },
          {
            'id': 2,
            'loai': 'minibar',
            'ten': 'Redbull',
            'don_gia': 25000,
            'so_luong': 1,
            'thanh_tien': 25000,
            'ghi_chu': null,
          },
          {
            'id': 3,
            'loai': 'dich_vu',
            'ten': 'Mì ly Omachi',
            'don_gia': 20000,
            'so_luong': 1,
            'thanh_tien': 20000,
            'ghi_chu': null,
          },
        ],
    'thanh_toan': thanhToan,
  },
};

/// Ghi lại MỌI lệnh gửi lên server để test khẳng định "bấm nút gọi đúng thứ".
class CaThueGia implements CaThueApi {
  CaThueGia(this.du);

  Map<String, dynamic> du;
  final ghi = <String>[];

  @override
  Future<CaThue> lay(int id) async {
    ghi.add('lay:$id');
    return CaThue.fromMap(du);
  }

  @override
  Future<void> themPhuThu(
    int id, {
    required String ten,
    required double donGia,
    double soLuong = 1,
    String loai = 'dich_vu',
    String? ghiChu,
  }) async {
    ghi.add('phu_thu:$id:$ten:${donGia.toStringAsFixed(0)}x${soLuong.toStringAsFixed(0)}:$loai');
  }

  @override
  Future<void> xoaPhuThu(int id, int phuThuId) async {
    ghi.add('xoa_phu_thu:$id:$phuThuId');
  }

  @override
  Future<void> ghiThanhToan(
    int id, {
    required double soTien,
    String loai = 'thu',
    String hinhThuc = 'tien_mat',
    String? ghiChu,
  }) async {
    ghi.add('thanh_toan:$id:${soTien.toStringAsFixed(0)}:$loai:$hinhThuc');
  }

  @override
  Future<void> giaHan(int id, {required int themPhut, bool tinhTien = true}) async {
    ghi.add('gia_han:$id:$themPhut:$tinhTien');
  }

  @override
  Future<void> nhanPhong(
    int id, {
    double thu = 0,
    String hinhThuc = 'tien_mat',
    String? ghiChu,
  }) async {
    ghi.add('nhan_phong:$id:${thu.toStringAsFixed(0)}:$hinhThuc:${ghiChu ?? ''}');
  }

  @override
  Future<Map<String, dynamic>> traPhong(
    int id, {
    double thuThem = 0,
    double hoanLai = 0,
    String hinhThuc = 'tien_mat',
    int? phutDon,
    String? kiemPhong,
    String? ghiChu,
  }) async {
    ghi.add(
      'tra_phong:$id:thu=${thuThem.toStringAsFixed(0)}:hoan=${hoanLai.toStringAsFixed(0)}'
      ':$hinhThuc:don=$phutDon:${kiemPhong ?? ''}',
    );
    return {'reservation_id': id, 'trang_thai': 'checked_out'};
  }
}
