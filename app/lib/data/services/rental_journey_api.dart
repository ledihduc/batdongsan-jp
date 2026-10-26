import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/api_client.dart';

abstract final class RentalJourneyStatus {
  static const waitingViewing = 'WAITING_VIEWING';
  static const customerInterested = 'CUSTOMER_INTERESTED';
  static const customerDeclined = 'CUSTOMER_DECLINED';
  static const contractReady = 'CONTRACT_READY';
  static const depositsPending = 'DEPOSITS_PENDING';
  static const customerConfirmationPending = 'CUSTOMER_CONFIRMATION_PENDING';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';
  static const disputed = 'DISPUTED';
}

abstract final class RentalJourneyAction {
  static const uploadContract = 'UPLOAD_CONTRACT';
  static const submitAppDeposit = 'SUBMIT_APP_DEPOSIT';
  static const submitOwnerDeposit = 'SUBMIT_OWNER_DEPOSIT';
  static const acknowledgeOwnerDeposit = 'ACKNOWLEDGE_OWNER_DEPOSIT';
  static const confirmRental = 'CONFIRM_RENTAL';
  static const cancelJourney = 'CANCEL_JOURNEY';
  static const reportParticipant = 'REPORT_PARTICIPANT';
}

class JourneyPerson {
  const JourneyPerson({required this.id, required this.name});

  final int id;
  final String name;

  factory JourneyPerson.fromMap(Map<String, dynamic> map) => JourneyPerson(
    id: (map['id'] as num?)?.toInt() ?? 0,
    name: map['name'] as String? ?? 'Chưa cập nhật',
  );
}

class JourneySubject {
  const JourneySubject({
    required this.title,
    this.image,
    this.roomId,
    this.houseId,
  });

  final String title;
  final String? image;
  final int? roomId;
  final int? houseId;

  factory JourneySubject.fromMap(Map<String, dynamic> map) => JourneySubject(
    title: map['title'] as String? ?? 'Phòng thuê',
    image: map['image'] as String?,
    roomId: (map['room_id'] as num?)?.toInt(),
    houseId: (map['house_id'] as num?)?.toInt(),
  );
}

class JourneyPayment {
  const JourneyPayment({
    required this.kind,
    required this.amount,
    required this.status,
    this.proofUrls = const [],
    this.submittedAt,
    this.acknowledgedAt,
  });

  final String kind;
  final int amount;
  final String status;
  final List<String> proofUrls;
  final DateTime? submittedAt;
  final DateTime? acknowledgedAt;

  bool get hasProof => proofUrls.isNotEmpty && submittedAt != null;
  bool get acknowledged => acknowledgedAt != null;

  factory JourneyPayment.fromMap(Map<String, dynamic> map) => JourneyPayment(
    kind: map['kind'] as String? ?? '',
    amount: (map['amount'] as num?)?.toInt() ?? 0,
    status: map['status'] as String? ?? 'PENDING',
    proofUrls: List<String>.from(map['proof_urls'] as List? ?? const []),
    submittedAt: DateTime.tryParse(map['submitted_at'] as String? ?? ''),
    acknowledgedAt: DateTime.tryParse(map['acknowledged_at'] as String? ?? ''),
  );
}

/// Projection returned by the server only after the Sale-mediated contract is
/// complete.  Do not infer a phone/email from `participants`: that object is
/// intentionally identity-only.
class JourneyContact {
  const JourneyContact({
    required this.role,
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String role;
  final int id;
  final String name;
  final String phone;
  final String email;

  factory JourneyContact.fromMap(Map<String, dynamic> map) => JourneyContact(
    role: map['role'] as String? ?? '',
    id: (map['id'] as num?)?.toInt() ?? 0,
    name: map['name'] as String? ?? 'Chưa cập nhật',
    phone: map['phone'] as String? ?? '',
    email: map['email'] as String? ?? '',
  );
}

class JourneyContactAccess {
  const JourneyContactAccess({
    required this.available,
    required this.reason,
    this.contacts = const [],
  });

  final bool available;
  final String reason;
  final List<JourneyContact> contacts;

  factory JourneyContactAccess.fromMap(Map<String, dynamic> map) =>
      JourneyContactAccess(
        available: map['available'] == true,
        reason: map['reason'] as String? ?? 'CONTRACT_NOT_FINALIZED',
        contacts: [
          for (final item in map['contacts'] as List? ?? const [])
            JourneyContact.fromMap((item as Map).cast<String, dynamic>()),
        ],
      );
}

class RentalJourney {
  const RentalJourney({
    required this.id,
    required this.appointmentId,
    required this.status,
    required this.viewerRole,
    required this.subject,
    required this.customer,
    required this.owner,
    this.sale,
    this.appointmentDate,
    this.appointmentTime,
    this.appointmentStatus,
    this.contractUrls = const [],
    this.contractNote,
    this.totalDeposit = 0,
    this.payments = const [],
    this.availableActions = const [],
    this.cancelReason,
    this.contactAccess,
    this.hopDongDaKy,
  });

  final int id;
  final int appointmentId;
  final String status;
  final String viewerRole;
  final JourneySubject subject;
  final JourneyPerson customer;
  final JourneyPerson? sale;
  final JourneyPerson owner;
  final String? appointmentDate;
  final String? appointmentTime;
  final String? appointmentStatus;
  final List<String> contractUrls;
  final String? contractNote;
  final int totalDeposit;
  final List<JourneyPayment> payments;
  final List<String> availableActions;
  final String? cancelReason;
  final JourneyContactAccess? contactAccess;

  /// Hợp đồng THẬT trong sổ chủ nhà, sinh ra lúc chốt thuê (backend 0131).
  /// Khác `contractUrls` — đó chỉ là ảnh chụp giấy tờ sale gửi lên.
  final HopDongDaKy? hopDongDaKy;

  bool can(String action) => availableActions.contains(action);

  /// Khách đã thực sự vào ở chưa — đọc từ trạng thái PHÒNG, không suy từ
  /// trạng thái hồ sơ (hồ sơ "hoàn tất" mà phòng vẫn trống là bệnh cũ).
  bool get daVaoO => hopDongDaKy?.dangO ?? false;

  JourneyPayment? payment(String kind) {
    for (final payment in payments) {
      if (payment.kind == kind) return payment;
    }
    return null;
  }

  factory RentalJourney.fromMap(Map<String, dynamic> map) {
    final participants =
        (map['participants'] as Map?)?.cast<String, dynamic>() ?? const {};
    final appointment =
        (map['appointment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final contract =
        (map['contract'] as Map?)?.cast<String, dynamic>() ?? const {};
    Map<String, dynamic> person(String key) =>
        (participants[key] as Map?)?.cast<String, dynamic>() ?? const {};
    final saleMap = participants['sale'] as Map?;
    final contactAccess = map['contact_access'] as Map?;
    return RentalJourney(
      id: (map['id'] as num?)?.toInt() ?? 0,
      appointmentId: (map['appointment_id'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? '',
      viewerRole: map['viewer_role'] as String? ?? '',
      subject: JourneySubject.fromMap(
        (map['subject'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      customer: JourneyPerson.fromMap(person('customer')),
      sale: saleMap == null
          ? null
          : JourneyPerson.fromMap(saleMap.cast<String, dynamic>()),
      owner: JourneyPerson.fromMap(person('owner')),
      appointmentDate: appointment['date'] as String?,
      appointmentTime: appointment['time'] as String?,
      appointmentStatus: appointment['status'] as String?,
      contractUrls: List<String>.from(contract['urls'] as List? ?? const []),
      contractNote: contract['note'] as String?,
      totalDeposit: (map['total_deposit'] as num?)?.toInt() ?? 0,
      payments: [
        for (final item in map['payments'] as List? ?? const [])
          JourneyPayment.fromMap((item as Map).cast<String, dynamic>()),
      ],
      availableActions: List<String>.from(
        map['available_actions'] as List? ?? const [],
      ),
      cancelReason: map['cancel_reason'] as String?,
      contactAccess: contactAccess == null
          ? null
          : JourneyContactAccess.fromMap(contactAccess.cast<String, dynamic>()),
      hopDongDaKy: (map['hop_dong_da_ky'] as Map?) == null
          ? null
          : HopDongDaKy.fromMap(
              (map['hop_dong_da_ky'] as Map).cast<String, dynamic>(),
            ),
    );
  }
}

/// Hợp đồng đã ký + câu trả lời "khách vào ở chưa".
class HopDongDaKy {
  const HopDongDaKy({
    required this.id,
    this.trangThai = 'draft',
    this.tu,
    this.den,
    this.giaThue = 0,
    this.tienCoc = 0,
    this.phong = '',
    this.dangO = false,
  });

  factory HopDongDaKy.fromMap(Map<String, dynamic> m) => HopDongDaKy(
    id: (m['id'] as num?)?.toInt() ?? 0,
    trangThai: m['trang_thai'] as String? ?? 'draft',
    tu: m['tu'] as String?,
    den: m['den'] as String?,
    giaThue: (m['gia_thue'] as num?)?.toDouble() ?? 0,
    tienCoc: (m['tien_coc'] as num?)?.toDouble() ?? 0,
    phong: m['phong'] as String? ?? '',
    dangO: m['dang_o'] == true,
  );

  final int id;
  final String trangThai;
  final String? tu;
  final String? den;
  final double giaThue;
  final double tienCoc;
  final String phong;
  final bool dangO;
}

class RentalJourneyEvent {
  const RentalJourneyEvent({
    required this.eventType,
    required this.actorRole,
    required this.actorName,
    required this.payload,
    this.createdAt,
  });

  final String eventType;
  final String actorRole;
  final String actorName;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  String? get viewingReason {
    if (eventType != 'VIEWING_RESULT_RECORDED') return null;
    final value = payload['reason']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  factory RentalJourneyEvent.fromMap(Map<String, dynamic> map) =>
      RentalJourneyEvent(
        eventType: map['event_type'] as String? ?? '',
        actorRole: map['actor_role'] as String? ?? '',
        actorName: map['actor_name'] as String? ?? '',
        payload: (map['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      );
}

class PlatformPaymentAccount {
  const PlatformPaymentAccount({
    required this.isConfigured,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    required this.transferPrefix,
  });

  final bool isConfigured;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolder;
  final String transferPrefix;

  factory PlatformPaymentAccount.fromMap(Map<String, dynamic> map) =>
      PlatformPaymentAccount(
        isConfigured: map['is_configured'] as bool? ?? false,
        bankName: map['bank_name'] as String?,
        accountNumber: map['account_number'] as String?,
        accountHolder: map['account_holder'] as String?,
        transferPrefix: map['transfer_prefix'] as String? ?? 'ANCU',
      );
}

class RentalJourneyApi {
  const RentalJourneyApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<List<RentalJourney>> list({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final data = await _c.get(
      '/api/rental-journeys',
      queryParameters: {
        'view': view,
        'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return [
      for (final item in data['data'] as List? ?? const [])
        RentalJourney.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<RentalJourney> detail(int id) async =>
      RentalJourney.fromMap(await _c.get('/api/rental-journeys/$id'));

  Future<List<RentalJourneyEvent>> events(int id) async {
    final data = await _c.get('/api/rental-journeys/$id/events');
    return [
      for (final item in data['data'] as List? ?? const [])
        RentalJourneyEvent.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<RentalJourney> submitViewingResult(
    int appointmentId, {
    required bool interested,
    String? reason,
  }) async => RentalJourney.fromMap(
    await _c.post(
      '/api/rental-journeys/from-appointment/$appointmentId/viewing-result',
      body: {
        'outcome': interested ? 'INTERESTED' : 'NOT_INTERESTED',
        'reason': reason,
      },
    ),
  );

  Future<RentalJourney> submitContract(
    int id, {
    required List<String> urls,
    required int totalDeposit,
    String? note,
  }) async => RentalJourney.fromMap(
    await _c.put(
      '/api/rental-journeys/$id/contract',
      body: {'urls': urls, 'total_deposit': totalDeposit, 'note': note},
    ),
  );

  Future<RentalJourney> submitPaymentProof(
    int id, {
    required String kind,
    required List<String> urls,
  }) async => RentalJourney.fromMap(
    await _c.put(
      '/api/rental-journeys/$id/payments/$kind/proof',
      body: {'urls': urls},
    ),
  );

  Future<RentalJourney> acknowledgeOwnerDeposit(int id) async =>
      RentalJourney.fromMap(
        await _c.post(
          '/api/rental-journeys/$id/payments/OWNER_DEPOSIT/acknowledge',
        ),
      );

  Future<RentalJourney> confirm(int id) async =>
      RentalJourney.fromMap(await _c.post('/api/rental-journeys/$id/confirm'));

  Future<RentalJourney> cancel(int id, String reason) async =>
      RentalJourney.fromMap(
        await _c.post(
          '/api/rental-journeys/$id/cancel',
          body: {'reason': reason},
        ),
      );

  Future<void> report(
    int id, {
    required int reportedUserId,
    required String reasonCode,
    required String detail,
    List<String> evidenceUrls = const [],
  }) async {
    await _c.post(
      '/api/rental-journeys/$id/reports',
      body: {
        'reported_user_id': reportedUserId,
        'reason_code': reasonCode,
        'detail': detail,
        'evidence_urls': evidenceUrls,
      },
    );
  }

  Future<List<ViewingAppointmentModel>> workQueue({
    required String view,
    String? date,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final data = await _c.get(
      '/api/viewing-appointments/work-queue',
      queryParameters: {
        'view': view,
        'date': date,
        'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return [
      for (final item in data['data'] as List? ?? const [])
        ViewingAppointmentModel.fromMap((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<PlatformPaymentAccount> paymentAccount() async =>
      PlatformPaymentAccount.fromMap(
        await _c.get('/api/rental-journeys/payment-account'),
      );
}
