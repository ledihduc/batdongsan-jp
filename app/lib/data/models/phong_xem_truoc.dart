/// Một phòng trong bản XEM TRƯỚC của toà — dùng chung cho hai chiều mã.
///
///     chủ nhà nhập mã bàn giao → GET /api/buildings/claim/{code}
///     sale nhập mã mời         → GET /api/buildings/moi-sale/{code}
///
/// Cả hai màn đều hỏi cùng một câu: *"toà này có đúng là toà tôi đang nghĩ tới
/// không"*. Tên với số phòng không trả lời được câu đó — phải thấy từng phòng.
///
/// Cố ý KHÔNG có khách thuê, hợp đồng, hoá đơn hay ghi chú nội bộ: mã tám ký tự
/// có thể lọt ra ngoài, nên bản xem trước chỉ được bày đúng những gì trang dự
/// án công khai đã bày cho bất kỳ ai.
class PhongXemTruoc {
  const PhongXemTruoc({
    required this.ma,
    this.dienTich,
    this.sucChua = 1,
    this.gia = 0,
    this.conTrong = true,
  });

  final String ma;
  final double? dienTich;
  final int sucChua;
  final double gia;
  final bool conTrong;

  factory PhongXemTruoc.fromMap(Map<String, dynamic> m) => PhongXemTruoc(
    ma: m['ma']?.toString() ?? '',
    dienTich: (m['dien_tich'] as num?)?.toDouble(),
    sucChua: (m['suc_chua'] as num?)?.toInt() ?? 1,
    gia: (m['gia'] as num?)?.toDouble() ?? 0,
    conTrong: m['con_trong'] != false,
  );

  static List<PhongXemTruoc> danhSach(dynamic raw) => (raw as List? ?? const [])
      .whereType<Map>()
      .map((e) => PhongXemTruoc.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}
