import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';

/// Đơn thuê dài hạn của KHÁCH — cùng 7 bước với pipeline sale.
/// API: GET /api/guest/don-thue?nhom= · GET /api/guest/don-thue/{nguon}/{id}
class DonThueKhachApi {
  const DonThueKhachApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<BangDonThue> danhSach({String nhom = 'tat_ca'}) async =>
      BangDonThue.fromMap(
        await _c.get('/api/guest/don-thue', queryParameters: {'nhom': nhom}),
      );

  Future<DonThueChiTiet> chiTiet(String nguon, int id) async =>
      DonThueChiTiet.fromMap(await _c.get('/api/guest/don-thue/$nguon/$id'));
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

class BangDonThue {
  const BangDonThue({this.dem = const {}, this.don = const []});

  factory BangDonThue.fromMap(Map<String, dynamic> m) => BangDonThue(
    dem: {
      for (final e in (m['dem'] as Map? ?? const {}).entries)
        '${e.key}': _int(e.value),
    },
    don: [
      for (final x in (m['don'] as List? ?? const []))
        if (x is Map) MucDonThue.fromMap(Map<String, dynamic>.from(x)),
    ],
  );

  /// tat_ca · dang_xu_ly · cho_coc · da_chot · da_dong
  final Map<String, int> dem;
  final List<MucDonThue> don;
}

class MucDonThue {
  const MucDonThue({
    required this.nguon,
    required this.id,
    this.ma = '',
    this.buoc = 'lead_moi',
    this.buocSo = 1,
    this.tongBuoc = 7,
    this.nhan = '',
    this.viecTiep = '',
    this.dong = false,
    this.ten = '',
    this.diaChi = '',
    this.gia = 0,
    this.anh,
    this.soCan = 0,
    this.capNhat,
  });

  factory MucDonThue.fromMap(Map<String, dynamic> m) => MucDonThue(
    nguon: m['nguon'] as String? ?? 'lich_xem',
    id: _int(m['id']),
    ma: m['ma'] as String? ?? '',
    buoc: m['buoc'] as String? ?? 'lead_moi',
    buocSo: _int(m['buoc_so']),
    tongBuoc: _int(m['tong_buoc']),
    nhan: m['nhan'] as String? ?? '',
    viecTiep: m['viec_tiep'] as String? ?? '',
    dong: m['dong'] == true,
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    gia: (m['gia'] as num?)?.toDouble() ?? 0,
    anh: m['anh'] as String?,
    soCan: _int(m['so_can']),
    capNhat: gioVNTuUtc(m['cap_nhat'] as String?),
  );

  /// `lich_xem` — khách tự đặt lịch xem · `sale` — sale lập yêu cầu cho khách.
  final String nguon;
  final int id;
  final String ma;
  final String buoc;
  final int buocSo;
  final int tongBuoc;
  final String nhan;
  final String viecTiep;

  /// Đơn đã huỷ / khách không thuê — tiến trình dừng, không còn việc tiếp.
  final bool dong;
  final String ten;
  final String diaChi;
  final double gia;
  final String? anh;
  final int soCan;
  final DateTime? capNhat;
}

class DonThueChiTiet {
  const DonThueChiTiet({
    required this.muc,
    this.can = const [],
    this.pipeline = const [],
    this.lichNgay,
    this.lichGio,
    this.appointmentId,
    this.journeyId,
    this.contractId,
    this.sale,
    this.lyDoDong,
  });

  factory DonThueChiTiet.fromMap(Map<String, dynamic> m) {
    final lich = m['lich_xem'] as Map?;
    return DonThueChiTiet(
      muc: MucDonThue.fromMap(m),
      can: [
        for (final x in (m['can'] as List? ?? const []))
          if (x is Map) CanLienQuan.fromMap(Map<String, dynamic>.from(x)),
      ],
      pipeline: [
        for (final x in (m['pipeline'] as List? ?? const []))
          if (x is Map) BuocPipeline.fromMap(Map<String, dynamic>.from(x)),
      ],
      lichNgay: lich?['ngay'] as String?,
      lichGio: lich?['gio'] as String?,
      appointmentId: (m['appointment_id'] as num?)?.toInt(),
      journeyId: (m['journey_id'] as num?)?.toInt(),
      contractId: (m['contract_id'] as num?)?.toInt(),
      sale: m['sale'] as String?,
      lyDoDong: m['ly_do_dong'] as String?,
    );
  }

  final MucDonThue muc;
  final List<CanLienQuan> can;
  final List<BuocPipeline> pipeline;
  final String? lichNgay;
  final String? lichGio;
  final int? appointmentId;
  final int? journeyId;
  final int? contractId;
  final String? sale;
  final String? lyDoDong;
}
