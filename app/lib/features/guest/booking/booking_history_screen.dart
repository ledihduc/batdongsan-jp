import 'dart:async';
import 'package:house_booking/core/widgets/ds.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/utils/vn_date.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/features/guest/booking/booking_detail_screen.dart';
import 'package:house_booking/features/guest/booking/widgets/appointment_status_chip.dart';
import 'package:house_booking/features/guest/review/write_review_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';

/// Trang lịch sử đặt lịch xem nhà (guest view).
///
/// 3 tab top-level — Chờ duyệt / Đã duyệt / Hoàn thành — kèm badge số lượng.
/// Tab "Hoàn thành" gom cả completed/cancelled/rejected/locked/lost với
/// strip sub-filter để zoom theo nhóm. Search field debounced 300ms theo
/// tên/địa chỉ nhà. Mỗi card tap để mở [BookingDetailScreen].
class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  String _activeTab = 'pending'; // 'pending' | 'approved' | 'completed'
  String _completedSubFilter =
      'all'; // all | completed | cancelled | rejected | locked | lost

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  static const Set<String> _completedStatuses = {
    'completed',
    'cancelled',
    'rejected',
    'locked',
    'lost',
  };

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refetchIfStale());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  void _refetchIfStale() {
    final auth = context.read<AuthProvider>();
    final provider = context.read<ViewingAppointmentProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    if (provider.isStale()) {
      // 'guest' CỐ ĐỊNH, không phải `user.role`: màn này là "lịch TÔI ĐÃ
      // ĐẶT". Truyền role của tài khoản thì người mang role='host' hỏi nhầm
      // sang góc nhìn chủ nhà và nhận về lịch khách đặt trên tin của họ —
      // lịch họ tự đặt biến mất. Góc nhìn chủ nhà đã có màn riêng
      // (HostAppointmentsScreen), nó tự truyền 'host'.
      provider.fetchAppointments(user.id!, 'guest');
    }
  }

  /// Trả list đã filter theo tab + sub-filter + search query.
  List<ViewingAppointmentModel> _filtered(List<ViewingAppointmentModel> all) {
    Iterable<ViewingAppointmentModel> result = all;

    if (_activeTab == 'pending') {
      // `doi_gio` = bên bán bận, chờ KHÁCH chọn giờ mới — vẫn là việc đang mở.
      result = result.where(
        (e) => e.status == 'pending' || e.status == 'doi_gio',
      );
    } else if (_activeTab == 'approved') {
      result = result.where((e) => e.status == 'approved');
    } else {
      result = result.where((e) => _completedStatuses.contains(e.status));
      if (_completedSubFilter != 'all') {
        result = result.where((e) => e.status == _completedSubFilter);
      }
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((e) {
        final t = (e.houseTitle ?? '').toLowerCase();
        final a = (e.houseAddress ?? '').toLowerCase();
        return t.contains(_searchQuery) || a.contains(_searchQuery);
      });
    }
    return result.toList();
  }

  /// Đếm số lượng theo từng tab (bỏ qua search query — tab count luôn tổng).
  Map<String, int> _counts(List<ViewingAppointmentModel> all) {
    var pending = 0, approved = 0, completed = 0;
    for (final e in all) {
      if (e.status == 'pending' || e.status == 'doi_gio') {
        pending++;
      } else if (e.status == 'approved') {
        approved++;
      } else if (_completedStatuses.contains(e.status)) {
        completed++;
      }
    }
    return {'pending': pending, 'approved': approved, 'completed': completed};
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final appointmentProvider = context.watch<ViewingAppointmentProvider>();
    final user = authProvider.currentUser;

    final all = appointmentProvider.appointments;
    final counts = _counts(all);
    final filtered = _filtered(all);

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.bkHistEyebrow,
        title: l.bkHistTitle,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: HD.s8),
            child: DsIconButton(
              icon: Icons.refresh,
              tooltip: l.bkHistRefresh,
              onPressed: user == null
                  ? null
                  : () => appointmentProvider.fetchAppointments(
                      user.id!,
                      'guest',
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildTabButton(
                  l.bkHistTabPending,
                  'pending',
                  counts['pending'] ?? 0,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  l.bkHistTabApproved,
                  'approved',
                  counts['approved'] ?? 0,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  l.bkHistCompleted,
                  'completed',
                  counts['completed'] ?? 0,
                ),
              ],
            ),
          ),

          // Sub-filter strip (only shown for "completed" tab)
          if (_activeTab == 'completed')
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _subFilterChip(l.bkHistFilterAll, 'all'),
                    _subFilterChip(l.bkHistCompleted, 'completed'),
                    _subFilterChip(l.bkHistStatusLocked, 'locked'),
                    _subFilterChip(l.bkHistStatusCancelled, 'cancelled'),
                    _subFilterChip(l.bkHistStatusRejected, 'rejected'),
                    _subFilterChip(l.bkHistStatusLost, 'lost'),
                  ],
                ),
              ),
            ),

          // Search field
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l.bkHistSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.bkHistClearSearch,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: HD.paperSunken,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // List
          Expanded(
            child: appointmentProvider.isLoading && all.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => user == null
                        ? Future.value()
                        : appointmentProvider.fetchAppointments(
                            user.id!,
                            'guest',
                          ),
                    child: filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 80),
                              _buildEmptyState(),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _buildAppointmentCard(context, filtered[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String tabId, int count) {
    final isSelected = _activeTab == tabId;
    final primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTab = tabId);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primary : HD.accentTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : HD.inkSoft,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _subFilterChip(String label, String value) {
    final isSelected = _completedSubFilter == value;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: primary.withOpacity(0.12),
        backgroundColor: HD.paperSunken,
        side: BorderSide(color: isSelected ? primary : Colors.transparent),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? primary : HD.inkSoft,
        ),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _completedSubFilter = value);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    ViewingAppointmentModel appointment,
  ) {
    final l = AppLocalizations.of(context);
    final provider = context.read<ViewingAppointmentProvider>();
    final user = context.read<AuthProvider>().currentUser!;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: HD.hairline.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(appointment: appointment),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 90,
                      height: 70,
                      child: Semantics(
                        label: appointment.houseTitle ?? l.bkHistRoomPhoto,
                        child: CachedNetworkImage(
                          imageUrl:
                              appointment.houseImage ??
                              'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=500',
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          fadeInDuration: const Duration(milliseconds: 150),
                          placeholder: (_, _) =>
                              Container(color: HD.paperSunken),
                          errorWidget: (_, _, _) => Container(
                            color: HD.paperSunken,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.home_outlined,
                              color: HD.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppointmentStatusChip(status: appointment.status),
                        const SizedBox(height: 6),
                        Text(
                          appointment.houseTitle ?? l.bkHistDefaultHouseTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: HD.ink,
                          ),
                        ),
                        if ((appointment.houseAddress ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: HD.inkMuted,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  appointment.houseAddress!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: HD.inkMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: HD.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                formatVnDate(
                                  appointment.bookingDate,
                                  withWeekday: false,
                                ),
                                style: const TextStyle(
                                  color: HD.inkMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.schedule_outlined,
                              size: 12,
                              color: HD.inkMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              appointment.bookingTime,
                              style: const TextStyle(
                                color: HD.inkMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: HD.accentTint),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatPrice(appointment.housePrice ?? 0),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      // Tin bán không có kỳ giá "/tháng".
                      if (appointment.housePricePeriodSuffix.isNotEmpty)
                        Text(
                          appointment.housePricePeriodSuffix,
                          style: const TextStyle(
                            fontSize: 10,
                            color: HD.inkMuted,
                          ),
                        ),
                    ],
                  ),
                  _buildActionButtons(appointment, provider, user),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    ViewingAppointmentModel appointment,
    ViewingAppointmentProvider provider,
    dynamic user,
  ) {
    final l = AppLocalizations.of(context);
    final status = appointment.status;

    if (status == 'pending') {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: HD.accentDeep,
          side: const BorderSide(color: HD.accentDeep),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
        ),
        icon: const Icon(Icons.cancel_outlined, size: 16),
        label: Text(l.cancel),
        onPressed: () => _confirmCancel(appointment, provider, user),
      );
    }

    if (status == 'approved' || status == 'locked') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.bkHistCallHost,
            icon: const Icon(Icons.phone, color: HD.positive),
            visualDensity: VisualDensity.compact,
            onPressed: () => _callHost(appointment),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            icon: const Icon(Icons.chat_outlined, size: 16),
            label: Text(l.bkHistMessage),
            onPressed: () => _openChat(appointment),
          ),
        ],
      );
    }

    if (status == 'completed') {
      // Lịch neo thẳng vào PHÒNG chưa có tin thì không có gì để đánh giá —
      // review gắn theo tin. Hiện nút rồi mở màn trắng là tệ hơn không hiện.
      if (!appointment.moDuocTin) return const SizedBox.shrink();
      if (appointment.hasReviewed) {
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            foregroundColor: HD.inkMuted,
          ),
          icon: const Icon(Icons.check, size: 16),
          label: Text(l.bkHistReviewed),
          onPressed: null,
        );
      }
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          backgroundColor: Colors.amber,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.star_rounded, size: 16),
        label: Text(l.bkHistReview),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WriteReviewScreen(
              houseId: appointment.houseId!,
              houseTitle: appointment.houseTitle ?? l.bkHistApartment,
            ),
          ),
        ),
      );
    }

    // rejected / cancelled / lost
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
      ),
      icon: const Icon(Icons.search, size: 16),
      label: Text(l.bkHistViewOtherHouses),
      onPressed: () => _openHouse(appointment),
    );
  }

  Future<void> _confirmCancel(
    ViewingAppointmentModel appointment,
    ViewingAppointmentProvider provider,
    dynamic user,
  ) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.bkHistCancelTitle),
        content: Text(l.bkHistCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l.bkHistClose),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l.bkHistCancelAppointment),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await provider.updateStatus(
      appointment.id!,
      'cancelled',
      user.id!,
      user.role,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.bkHistCancelSuccess : l.bkHistCancelFailed),
      ),
    );
  }

  Future<void> _callHost(ViewingAppointmentModel appointment) async {
    final l = AppLocalizations.of(context);
    final phone = appointment.hostPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.bkHistNoHostPhone)));
      return;
    }
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.bkHistPhoneCopied(phone))));
  }

  void _openChat(ViewingAppointmentModel appointment) {
    final l = AppLocalizations.of(context);
    if (appointment.hostId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.bkHistHostNotFound)));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: appointment.hostId!,
          peerName: appointment.hostName ?? l.bkHistHost,
          houseId: appointment.houseId,
        ),
      ),
    );
  }

  void _openHouse(ViewingAppointmentModel appointment) {
    if (!appointment.moDuocTin) return;
    context.push('/house/${appointment.houseId}');
  }

  Widget _buildEmptyState() {
    final l = AppLocalizations.of(context);
    final isSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearch ? Icons.search_off : Icons.calendar_today_outlined,
              size: 64,
              color: HD.inkMuted,
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? l.bkHistNoResults : l.bkHistNoRequests,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: HD.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch ? l.bkHistSearchEmpty : l.bkHistEmptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HD.inkSoft, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    // Dùng compact chung: ≥1 tỷ → "2,5 tỷ", ≥1tr → "8tr" (tin bán tiền tỷ hiển thị đúng).
    return PriceFormat.compact(price);
  }
}
