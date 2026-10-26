import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/su_kien_lich_su.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/host/journey/chi_tiet_yeu_cau_xem_screen.dart';
import 'package:house_booking/features/host/journey/ket_qua_buoi_xem_chu_nha_screen.dart';
import 'package:house_booking/features/host/journey/lich_xem_da_xac_nhan_chu_nha_screen.dart';

/// Trung tâm lịch xem của Chủ nhà. Không tạo bottom nav riêng; màn này giữ
/// nguyên shell Hoạt động hiện tại của ứng dụng.
class HostAppointmentsScreen extends StatefulWidget {
  const HostAppointmentsScreen({
    super.key,
    this.lichXemApi = const LichXemApi(),
    this.journeyApi = const RentalJourneyApi(),
    this.managementApi,
    this.viewingV2Api = const ViewingV2Api(),
    this.now,
  });

  final LichXemApi lichXemApi;
  final RentalJourneyApi journeyApi;
  final ManagementReadModelApi? managementApi;
  final ViewingV2Api viewingV2Api;
  final DateTime? now;

  @override
  State<HostAppointmentsScreen> createState() => _HostAppointmentsScreenState();
}

class _HostAppointmentsScreenState extends State<HostAppointmentsScreen> {
  List<ViewingAppointmentModel> _appointments = const [];
  List<RentalJourney> _journeys = const [];
  List<CanonicalViewing>? _canonical;
  bool _loading = true;
  String? _error;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      try {
        final capabilities = await widget.managementApi?.capabilities();
        if (capabilities?.viewingV2Enabled == true) {
          final canonical = await widget.viewingV2Api.list(
            mode: ViewingMode.owner,
          );
          if (!mounted) return;
          setState(() {
            _canonical = canonical;
            _appointments = const [];
            _journeys = const [];
            _loading = false;
          });
          return;
        }
      } catch (_) {
        // Backend cũ/flag không khả dụng: giữ nguyên nguồn legacy bên dưới.
      }
      final data = await Future.wait<Object>([
        widget.journeyApi.workQueue(view: 'owner'),
        widget.journeyApi.list(view: 'owner'),
      ]);
      if (!mounted) return;
      setState(() {
        _appointments = data[0] as List<ViewingAppointmentModel>;
        _journeys = data[1] as List<RentalJourney>;
        _canonical = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Chưa tải được lịch xem. Kéo xuống để thử lại.';
      });
    }
  }

  List<_Entry> get _entries {
    final canonical = _canonical;
    if (canonical != null) {
      final result = canonical.map(_Entry.fromCanonical).toList();
      result.sort((a, b) => b.sortMoment.compareTo(a.sortMoment));
      return result;
    }
    final byAppointment = <int, RentalJourney>{
      for (final j in _journeys) j.appointmentId: j,
    };
    final result = <_Entry>[];
    for (final a in _appointments) {
      result.add(_Entry.fromAppointment(a, byAppointment.remove(a.id), _now));
    }
    for (final j in byAppointment.values) {
      result.add(_Entry.fromJourney(j));
    }
    result.sort((a, b) => b.sortMoment.compareTo(a.sortMoment));
    return result;
  }

  List<_Entry> _group(_Group group) =>
      _entries.where((e) => e.group == group).toList();

  Future<void> _openGroup(_Group group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _GroupScreen(
          group: group,
          entries: _group(group),
          api: widget.lichXemApi,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final recent = _entries.isEmpty ? null : _entries.first;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _Hero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              sliver: SliverList.list(
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: HD.accent,
                        backgroundColor: HD.accentTint,
                      ),
                    ),
                  if (_error != null) _Error(message: _error!, retry: _load),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.22,
                    children: [
                      for (final group in _Group.values)
                        _GroupCard(
                          group: group,
                          count: _group(group).length,
                          onTap: () => _openGroup(group),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: HD.accent, size: 25),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lịch gần đây',
                          style: HD.bodyBold(size: 19),
                        ),
                      ),
                      TextButton(
                        onPressed: _entries.isEmpty
                            ? null
                            : () => _openGroup(_Group.history),
                        child: const Text('Xem tất cả'),
                      ),
                    ],
                  ),
                  if (recent == null)
                    const _Empty()
                  else
                    _EntryCard(
                      entry: recent,
                      compact: true,
                      onTap: () =>
                          _openEntry(context, recent, widget.lichXemApi),
                    ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD6DA)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 25,
                          backgroundColor: HD.accent,
                          child: Icon(
                            Icons.lightbulb_outline,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chọn 1 nhóm để vào danh sách chi tiết',
                                style: HD.bodyBold(size: 13, color: HD.accent),
                              ),
                              Text(
                                'Quản lý lịch xem nhà dễ dàng, nhanh chóng hơn',
                                style: HD.body(size: 11.5, color: HD.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 210,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Image(
          image: AssetImage('assets/branding/owner_viewing_hero_v3.png'),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFFCF1425).withValues(alpha: .88),
                const Color(0xFFE92636).withValues(alpha: .48),
                Colors.transparent,
              ],
              stops: const [0, .42, .76],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: .08), Colors.transparent],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .14),
                      ),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lịch xem nhà',
                            style: HD.bodyBold(size: 24, color: Colors.white),
                          ),
                          Text(
                            'Chọn nhóm để xem và quản lý',
                            style: HD.body(size: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9E1020).withValues(alpha: .74),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white54),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.apartment,
                            color: Colors.white,
                            size: 21,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Chủ nhà\nVuaNhà',
                            style: HD.bodyBold(size: 10.5, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Kết nối đúng người\nCho tổ ấm đúng nhà',
                  style: HD
                      .bodyBold(size: 15.5, color: Colors.white)
                      .copyWith(fontStyle: FontStyle.italic, height: 1.3),
                ),
                const SizedBox(height: 5),
                Container(width: 30, height: 3, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

enum _Group { action, upcoming, afterViewing, history }

extension _GroupUi on _Group {
  String get title => switch (this) {
    _Group.action => 'Cần xử lý',
    _Group.upcoming => 'Sắp tới',
    _Group.afterViewing => 'Sau khi xem',
    _Group.history => 'Lịch sử',
  };
  String get subtitle => switch (this) {
    _Group.action => 'Yêu cầu mới, chờ bạn phản hồi',
    _Group.upcoming => 'Lịch đã xác nhận, chuẩn bị xem',
    _Group.afterViewing => 'Phản hồi, cân nhắc, muốn thuê',
    _Group.history => 'Đã thuê, đã hủy, báo cáo…',
  };
  IconData get icon => switch (this) {
    _Group.action => Icons.receipt_long,
    _Group.upcoming => Icons.event_available,
    _Group.afterViewing => Icons.groups_2,
    _Group.history => Icons.history,
  };
  Color get color => switch (this) {
    _Group.action => const Color(0xFFE51C2A),
    _Group.upcoming => const Color(0xFF15973D),
    _Group.afterViewing => const Color(0xFFC24A08),
    _Group.history => const Color(0xFF1754A5),
  };
  Color get tint => switch (this) {
    _Group.action => const Color(0xFFFFF0F2),
    _Group.upcoming => const Color(0xFFECFFF2),
    _Group.afterViewing => const Color(0xFFFFF5E9),
    _Group.history => const Color(0xFFEEF6FF),
  };
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.count,
    required this.onTap,
  });
  final _Group group;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    elevation: 1.5,
    shadowColor: group.color.withValues(alpha: .12),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: Key('owner-viewing-${group.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, group.tint],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: group.color.withValues(alpha: .12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: group.color.withValues(alpha: .12),
                    child: Icon(group.icon, size: 25, color: group.color),
                  ),
                  const Spacer(),
                  Container(
                    constraints: const BoxConstraints(minWidth: 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: HD.accent,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: HD.bodyBold(size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 17, color: group.color),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: HD.inkSoft),
                ],
              ),
              Text(
                group.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 11.5, color: HD.inkSoft),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _Stage {
  waitingOwner,
  waitingGuest,
  confirmed,
  cancelled,
  noFeedback,
  declined,
  considering,
  interested,
  paperwork,
  rented,
  noShow,
  ownerUnavailable,
  saleDelayed,
  complaint,
}

extension _StageUi on _Stage {
  String get label => switch (this) {
    _Stage.waitingOwner => 'Chờ bạn xử lý',
    _Stage.waitingGuest => 'Chờ khách xác nhận',
    _Stage.confirmed => 'Đã xác nhận',
    _Stage.cancelled => 'Đã hủy',
    _Stage.noFeedback => 'Đã xem · Chưa phản hồi',
    _Stage.declined => 'Không thuê',
    _Stage.considering => 'Đang cân nhắc',
    _Stage.interested => 'Muốn thuê',
    _Stage.paperwork => 'Đang làm thủ tục',
    _Stage.rented => 'Đã thuê · Đang ở',
    _Stage.noShow => 'Khách không đến',
    _Stage.ownerUnavailable => 'Chủ nhà không tiếp',
    _Stage.saleDelayed => 'Sale chưa xử lý kịp',
    _Stage.complaint => 'Có báo cáo · Khiếu nại',
  };
  Color get color => switch (this) {
    _Stage.waitingOwner ||
    _Stage.declined ||
    _Stage.noShow ||
    _Stage.complaint => HD.accent,
    _Stage.waitingGuest ||
    _Stage.considering ||
    _Stage.ownerUnavailable ||
    _Stage.saleDelayed => HD.warning,
    _Stage.confirmed || _Stage.rented => HD.positive,
    _Stage.cancelled => HD.inkMuted,
    _Stage.noFeedback => const Color(0xFF2463B5),
    _Stage.interested => const Color(0xFFDC3366),
    _Stage.paperwork => const Color(0xFF7656C8),
  };
  String get helper => switch (this) {
    _Stage.waitingOwner =>
      'Khách vừa gửi yêu cầu. Hãy xác nhận hoặc đề xuất giờ khác.',
    _Stage.waitingGuest =>
      'Bạn hoặc Sale đã đề xuất giờ mới và đang chờ khách đồng ý.',
    _Stage.confirmed => 'Khung giờ đã chốt. Chuẩn bị đón khách đến xem.',
    _Stage.cancelled => 'Mở chi tiết để xem ai hủy và lý do hủy.',
    _Stage.noFeedback => 'Buổi xem đã diễn ra nhưng khách chưa chọn kết quả.',
    _Stage.declined => 'Khách không thuê; mở chi tiết để xem nhóm lý do.',
    _Stage.considering => 'Khách chưa từ chối; Sale vẫn đang theo sát.',
    _Stage.interested => 'Khách muốn thuê, chuẩn bị cọc và hợp đồng.',
    _Stage.paperwork => 'Đang chờ hợp đồng, tiền cọc hoặc xác nhận cuối.',
    _Stage.rented => 'Hồ sơ hoàn tất và đã chuyển sang quản lý đang ở.',
    _Stage.noShow => 'Lịch đã hẹn nhưng khách không có mặt.',
    _Stage.ownerUnavailable => 'Chủ nhà bận hoặc không có mặt để tiếp khách.',
    _Stage.saleDelayed => 'Sale chưa xử lý kịp, chủ nhà cần hỗ trợ.',
    _Stage.complaint => 'Có thông tin sai, hủy không báo hoặc yêu cầu hỗ trợ.',
  };
}

class _Entry {
  const _Entry({
    required this.appointmentId,
    required this.title,
    required this.customer,
    required this.date,
    required this.time,
    required this.stage,
    required this.sortMoment,
    this.image,
    this.price,
  });

  factory _Entry.fromAppointment(
    ViewingAppointmentModel a,
    RentalJourney? journey,
    DateTime now,
  ) {
    final moment = _appointmentMoment(a) ?? a.createdAt;
    return _Entry(
      appointmentId: a.id ?? journey?.appointmentId ?? 0,
      title: a.houseTitle ?? journey?.subject.title ?? 'Căn nhà đang xem',
      customer: a.guestName ?? journey?.customer.name ?? 'Khách thuê',
      date: a.bookingDate,
      time: a.bookingTime,
      image: a.houseImage ?? journey?.subject.image,
      price: a.housePrice,
      stage: journey == null
          ? _appointmentStage(a, moment, now)
          : _journeyStage(journey),
      sortMoment: moment,
    );
  }

  factory _Entry.fromJourney(RentalJourney j) => _Entry(
    appointmentId: j.appointmentId,
    title: j.subject.title,
    customer: j.customer.name,
    date: j.appointmentDate ?? '',
    time: j.appointmentTime ?? '',
    image: j.subject.image,
    stage: _journeyStage(j),
    sortMoment:
        DateTime.tryParse(j.appointmentDate ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  factory _Entry.fromCanonical(CanonicalViewing value) => _Entry(
    appointmentId: value.id,
    title: value.title,
    customer: value.customerName,
    date: value.bookingDate,
    time: value.bookingTime,
    image: value.image,
    price: value.price?.toDouble(),
    stage: _canonicalStage(value),
    sortMoment:
        DateTime.tryParse(value.bookingDate) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  final int appointmentId;
  final String title;
  final String customer;
  final String date;
  final String time;
  final String? image;
  final double? price;
  final _Stage stage;
  final DateTime sortMoment;

  _Group get group => switch (stage) {
    _Stage.waitingOwner || _Stage.waitingGuest => _Group.action,
    _Stage.confirmed => _Group.upcoming,
    _Stage.noFeedback ||
    _Stage.declined ||
    _Stage.considering ||
    _Stage.interested ||
    _Stage.paperwork => _Group.afterViewing,
    _ => _Group.history,
  };
}

_Stage _appointmentStage(
  ViewingAppointmentModel a,
  DateTime moment,
  DateTime now,
) => switch (a.status) {
  'pending' => _Stage.waitingOwner,
  'doi_gio' => _Stage.waitingGuest,
  'approved' ||
  'locked' => moment.isBefore(now) ? _Stage.noFeedback : _Stage.confirmed,
  'completed' => _Stage.noFeedback,
  'awaiting_guest' => _Stage.considering,
  'lost' => _Stage.noShow,
  'cancelled' || 'rejected' => _Stage.cancelled,
  _ => _Stage.considering,
};

_Stage _journeyStage(RentalJourney j) => switch (j.status) {
  RentalJourneyStatus.waitingViewing => _Stage.noFeedback,
  RentalJourneyStatus.customerDeclined => _Stage.declined,
  RentalJourneyStatus.customerInterested => _Stage.interested,
  RentalJourneyStatus.contractReady ||
  RentalJourneyStatus.depositsPending ||
  RentalJourneyStatus.customerConfirmationPending => _Stage.paperwork,
  RentalJourneyStatus.completed => _Stage.rented,
  RentalJourneyStatus.cancelled => _Stage.cancelled,
  RentalJourneyStatus.disputed => _Stage.complaint,
  _ => _Stage.considering,
};

_Stage _canonicalStage(CanonicalViewing value) {
  if (value.issues.isNotEmpty) {
    final codes = value.issues.map((issue) => issue.code).toSet();
    if (codes.contains('CUSTOMER_NO_SHOW')) return _Stage.noShow;
    if (codes.contains('OWNER_NO_SHOW')) return _Stage.ownerUnavailable;
    if (codes.contains('SALE_NO_SHOW')) return _Stage.saleDelayed;
    return _Stage.complaint;
  }
  return switch (value.resultStatus) {
    'CONSIDERING' => _Stage.considering,
    'INTERESTED' => _Stage.interested,
    'DECLINED' => _Stage.declined,
    _ => switch (value.status) {
      'REQUESTED' => _Stage.waitingOwner,
      'PROPOSAL_SENT' || 'WAITING_CUSTOMER' => _Stage.waitingGuest,
      'CONFIRMED' => _Stage.confirmed,
      'COMPLETED' => _Stage.noFeedback,
      'NO_SHOW' => _Stage.noShow,
      'CANCELLED' || 'FAILED' => _Stage.cancelled,
      _ => _Stage.complaint,
    },
  };
}

DateTime? _appointmentMoment(ViewingAppointmentModel a) {
  final date = DateTime.tryParse(a.bookingDate);
  if (date == null) return null;
  final parts = a.bookingTime.split('-').first.split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.tryParse(parts.first) ?? 0,
    parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

class _GroupScreen extends StatefulWidget {
  const _GroupScreen({
    required this.group,
    required this.entries,
    required this.api,
  });
  final _Group group;
  final List<_Entry> entries;
  final LichXemApi api;

  @override
  State<_GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<_GroupScreen> {
  _Stage? _filter;

  @override
  Widget build(BuildContext context) {
    final stages = <_Stage>{for (final e in widget.entries) e.stage}.toList();
    final visible = _filter == null
        ? widget.entries
        : widget.entries.where((e) => e.stage == _filter).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FB),
      appBar: AppBar(
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.group.title,
          style: HD.bodyBold(size: 18, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: widget.group.tint,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.subtitle,
                  style: HD.body(size: 12.5, color: HD.inkSoft),
                ),
                if (stages.length > 1) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _Chip(
                          label: 'Tất cả',
                          count: widget.entries.length,
                          selected: _filter == null,
                          color: widget.group.color,
                          onTap: () => setState(() => _filter = null),
                        ),
                        for (final stage in stages)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _Chip(
                              label: stage.label,
                              count: widget.entries
                                  .where((e) => e.stage == stage)
                                  .length,
                              selected: _filter == stage,
                              color: stage.color,
                              onTap: () => setState(() => _filter = stage),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const _GroupEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _EntryCard(
                      entry: visible[index],
                      onTap: () =>
                          _openEntry(context, visible[index], widget.api),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: selected ? color : HD.hairline),
      ),
      child: Text(
        '$label ($count)',
        style: HD.bodyBold(
          size: 11,
          color: selected ? Colors.white : HD.inkSoft,
        ),
      ),
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onTap,
    this.compact = false,
  });
  final _Entry entry;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 1,
    shadowColor: Colors.black12,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(url: entry.image, size: compact ? 72 : 82),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 13.5),
                  ),
                  if (entry.price != null)
                    Text(
                      '${PriceFormat.full(entry.price!)}/tháng',
                      style: HD.bodyBold(size: 12, color: HD.accent),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${_prettyDate(entry.date)} · ${entry.time.replaceAll('-', ' - ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 11.5, color: HD.inkSoft),
                  ),
                  Text(
                    entry.customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: entry.stage.color.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.stage.helper,
                        style: HD.body(size: 10.5, color: HD.inkSoft),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 105),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: entry.stage.color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.stage.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: HD.bodyBold(size: 10.5, color: entry.stage.color),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right, color: HD.inkMuted),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = _absoluteUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: value == null
          ? _placeholder()
          : CachedNetworkImage(
              imageUrl: value,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => _placeholder(),
              errorWidget: (_, _, _) => _placeholder(),
            ),
    );
  }

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: HD.paperSunken,
    child: const Icon(Icons.apartment, color: HD.inkMuted),
  );
}

Future<void> _openEntry(
  BuildContext context,
  _Entry entry,
  LichXemApi api,
) async {
  if (entry.appointmentId <= 0) return;
  final Widget page;
  if (entry.stage == _Stage.waitingOwner) {
    page = ChiTietYeuCauXemScreen(appointmentId: entry.appointmentId, api: api);
  } else if (entry.stage == _Stage.confirmed ||
      entry.stage == _Stage.waitingGuest ||
      entry.stage == _Stage.noFeedback) {
    page = LichXemDaXacNhanChuNhaScreen(
      appointmentId: entry.appointmentId,
      api: api,
    );
  } else if (entry.stage == _Stage.cancelled || entry.stage == _Stage.noShow) {
    page = _CancelledDetail(
      appointmentId: entry.appointmentId,
      api: api,
      entry: entry,
    );
  } else {
    page = KetQuaBuoiXemChuNhaScreen(
      appointmentId: entry.appointmentId,
      api: api,
    );
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _CancelledDetail extends StatefulWidget {
  const _CancelledDetail({
    required this.appointmentId,
    required this.api,
    required this.entry,
  });
  final int appointmentId;
  final LichXemApi api;
  final _Entry entry;

  @override
  State<_CancelledDetail> createState() => _CancelledDetailState();
}

class _CancelledDetailState extends State<_CancelledDetail> {
  List<SuKienLichSu>? _history;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.api.lichSu(widget.appointmentId);
      if (mounted) setState(() => _history = value);
    } catch (_) {
      if (mounted) setState(() => _history = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = _history
        ?.where(
          (e) => e.tong == 'huy' || e.hanhDong.toLowerCase().contains('huy'),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FB),
      appBar: AppBar(
        title: const Text('Chi tiết lịch đã hủy'),
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EntryCard(entry: widget.entry, onTap: () {}),
          const SizedBox(height: 16),
          Text('Người hủy và lý do', style: HD.bodyBold(size: 16)),
          const SizedBox(height: 10),
          if (_history == null)
            const Center(child: CircularProgressIndicator(color: HD.accent))
          else if (cancelled == null || cancelled.isEmpty)
            const _History(
              title: 'Chưa có chi tiết hủy',
              detail: 'Lịch cũ có thể chưa lưu người thao tác và lý do.',
            )
          else
            for (final event in cancelled)
              _History(
                title: event.ai.ten.isEmpty
                    ? event.tieuDe
                    : '${event.ai.ten} · ${event.tieuDe}',
                detail: event.chiTiet.isEmpty
                    ? 'Không ghi lý do'
                    : event.chiTiet,
              ),
          const SizedBox(height: 18),
          Text('Toàn bộ hoạt động', style: HD.bodyBold(size: 16)),
          const SizedBox(height: 10),
          if (_history != null)
            for (final event in _history!)
              _History(
                title: event.tieuDe,
                detail: [
                  if (event.ai.ten.isNotEmpty) event.ai.ten,
                  if (event.chiTiet.isNotEmpty) event.chiTiet,
                ].join(' · '),
              ),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.title, required this.detail});
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.history, color: HD.accent, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HD.bodyBold(size: 13)),
              if (detail.isNotEmpty)
                Text(detail, style: HD.body(size: 11.5, color: HD.inkMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off, color: HD.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: HD.body(size: 12))),
        TextButton(onPressed: retry, child: const Text('Thử lại')),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: HD.hairline),
    ),
    child: Column(
      children: [
        const Icon(Icons.event_busy, color: HD.inkMuted, size: 32),
        const SizedBox(height: 8),
        Text('Chưa có lịch xem nhà', style: HD.bodyBold(size: 13)),
        Text(
          'Yêu cầu mới sẽ xuất hiện tại nhóm Cần xử lý.',
          textAlign: TextAlign.center,
          style: HD.body(size: 11.5, color: HD.inkMuted),
        ),
      ],
    ),
  );
}

class _GroupEmpty extends StatelessWidget {
  const _GroupEmpty();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 44, color: HD.inkMuted),
          const SizedBox(height: 10),
          Text('Nhóm này đang trống', style: HD.bodyBold(size: 15)),
          Text(
            'Trạng thái sẽ tự động cập nhật khi lịch xem thay đổi.',
            textAlign: TextAlign.center,
            style: HD.body(size: 12, color: HD.inkMuted),
          ),
        ],
      ),
    ),
  );
}

String _prettyDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? 'Chưa có ngày' : value;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String? _absoluteUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final clean = value.trim();
  if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
  return '${ApiConfig.baseUrl}${clean.startsWith('/') ? '' : '/'}$clean';
}
