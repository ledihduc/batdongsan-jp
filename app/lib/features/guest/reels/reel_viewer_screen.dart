import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/reel_model.dart';
import 'package:house_booking/data/services/reel_api.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/guest/reels/reel_comments_sheet.dart';
import 'package:house_booking/l10n/app_localizations.dart';

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

/// Xem reel toàn màn hình — cuộn DỌC như Facebook/TikTok.
///
/// Web: autoplay BẮT BUỘC muted (chính sách trình duyệt) → mở tiếng bằng nút loa.
class ReelViewerScreen extends StatefulWidget {
  const ReelViewerScreen({
    super.key,
    required this.reels,
    this.initialIndex = 0,
  });

  final List<Reel> reels;
  final int initialIndex;

  @override
  State<ReelViewerScreen> createState() => _ReelViewerScreenState();
}

class _ReelViewerScreenState extends State<ReelViewerScreen>
    with WidgetsBindingObserver {
  static const _api = ReelApi();
  late final PageController _pc = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  late final List<Reel> _reels = List.of(widget.reels);
  bool _muted = true; // web autoplay policy
  // App bị đưa xuống nền → dừng phát (không phát tiếng ngầm, không tốn dữ liệu).
  bool _appActive = true;
  // Tiết kiệm dữ liệu: không tự phát, không nạp trước trang kế. Người dùng bấm
  // mới phát — quan trọng với người dùng 3G/4G ở VN.
  bool _dataSaver = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trang đầu cũng phải được tính lượt xem — trước đây chỉ tính khi CHUYỂN trang.
    _startWatch(_index);
    _loadDataSaver();
  }

  Future<void> _loadDataSaver() async {
    final on = await ReelPrefs.dataSaver();
    if (mounted && on) setState(() => _dataSaver = on);
  }

  Future<void> _toggleDataSaver() async {
    final next = !_dataSaver;
    setState(() => _dataSaver = next);
    await ReelPrefs.setDataSaver(next);
    if (mounted) {
      final l = AppLocalizations.of(context);
      AppFeedback.success(
        context,
        next ? l.reelViewDataSaverOn : l.reelViewDataSaverOff,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _appActive) setState(() => _appActive = active);
  }

  @override
  void dispose() {
    _flushWatch();
    WidgetsBinding.instance.removeObserver(this);
    _pc.dispose();
    super.dispose();
  }

  // ── Đo thời lượng xem thật ─────────────────────────────────────────────────
  // Backend chỉ tính 1 lượt khi xem ≥3s, nên phải đo mốc vào/ra từng reel.
  int? _watchingId;
  DateTime? _watchStart;

  void _startWatch(int i) {
    _flushWatch();
    if (i < 0 || i >= _reels.length) return;
    _watchingId = _reels[i].id;
    _watchStart = DateTime.now();
  }

  void _flushWatch() {
    final id = _watchingId;
    final t0 = _watchStart;
    _watchingId = null;
    _watchStart = null;
    if (id == null || t0 == null) return;
    final ms = DateTime.now().difference(t0).inMilliseconds;
    if (ms >= 3000) _api.addView(id, watchedMs: ms);
  }

  Future<void> _toggleLike(int i) async {
    if (!GuestGate.requireAuth(
      context,
      message: AppLocalizations.of(context).reelViewLoginToLike,
    )) {
      return;
    }
    final r = _reels[i];
    // Optimistic
    setState(
      () => _reels[i] = r.copyWith(
        likedByMe: !r.likedByMe,
        likeCount: (r.likeCount + (r.likedByMe ? -1 : 1)).clamp(0, 1 << 30),
      ),
    );
    try {
      final res = await _api.toggleLike(r.id);
      if (mounted) {
        setState(
          () => _reels[i] = _reels[i].copyWith(
            likedByMe: res.liked,
            likeCount: res.likeCount,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _reels[i] = r); // revert
    }
  }

  /// Báo cáo reel vi phạm → vào hàng đợi admin (đủ 3 báo cáo tự ẩn).
  Future<void> _report(int i) async {
    final l = AppLocalizations.of(context);
    if (!GuestGate.requireAuth(context, message: l.reelViewLoginToReport)) {
      return;
    }
    final reasons = <(String, String)>[
      ('spam', l.reelViewReasonSpam),
      ('inappropriate', l.reelViewReasonInappropriate),
      ('copyright', l.reelViewReasonCopyright),
      ('misleading', l.reelViewReasonMisleading),
      ('other', l.reelViewReasonOther),
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                l.reelViewReportTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: HD.ink,
                ),
              ),
            ),
            for (final (key, label) in reasons)
              ListTile(
                title: Text(label, style: const TextStyle(color: HD.ink)),
                onTap: () => Navigator.pop(ctx, key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await _api.report(_reels[i].id, reason: picked);
      if (mounted) {
        AppFeedback.success(context, l.reelViewReportSuccess);
      }
    } catch (_) {
      if (mounted) AppFeedback.error(context, l.reelViewReportFailed);
    }
  }

  /// Chia sẻ reel — web chưa có share sheet gốc nên chép link vào clipboard.
  Future<void> _share(int i) async {
    final url = '${ApiConfig.baseUrl}/reels/${_reels[i].id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      AppFeedback.success(
        context,
        AppLocalizations.of(context).reelViewLinkCopied,
      );
    }
  }

  Future<void> _openComments(int i) async {
    final r = _reels[i];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReelCommentsSheet(
        reelId: r.id,
        onCountChanged: (n) {
          if (mounted) {
            setState(() => _reels[i] = _reels[i].copyWith(commentCount: n));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            itemCount: _reels.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _startWatch(i);
            },
            itemBuilder: (context, i) => _ReelPage(
              key: ValueKey(_reels[i].id),
              reel: _reels[i],
              isActive: i == _index && _appActive,
              // Nạp sẵn trang kế để cuộn tới là phát ngay, không phải chờ buffer.
              // Chỉ 1 trang kề — nạp nhiều hơn thì tốn dữ liệu vô ích.
              preload: !_dataSaver && (i - _index).abs() == 1,
              dataSaver: _dataSaver,
              muted: _muted,
              onToggleLike: () => _toggleLike(i),
              onToggleMute: () => setState(() => _muted = !_muted),
              onReport: () => _report(i),
              onOpenComments: () => _openComments(i),
              onShare: () => _share(i),
            ),
          ),
          // Nút đóng
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Tiết kiệm dữ liệu
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              tooltip: _dataSaver
                  ? l.reelViewDataSaverTooltipOn
                  : l.reelViewDataSaverTooltipOff,
              icon: Icon(
                _dataSaver ? Icons.data_saver_on : Icons.data_saver_off,
                color: _dataSaver ? HD.accent : Colors.white70,
                size: 26,
              ),
              onPressed: _toggleDataSaver,
            ),
          ),
        ],
      ),
    );
  }
}

/// 1 trang reel — tự quản VideoPlayerController (init/dispose theo vòng đời).
class _ReelPage extends StatefulWidget {
  const _ReelPage({
    super.key,
    required this.reel,
    required this.isActive,
    required this.preload,
    required this.dataSaver,
    required this.muted,
    required this.onToggleLike,
    required this.onToggleMute,
    required this.onReport,
    required this.onOpenComments,
    required this.onShare,
  });

  final Reel reel;
  final bool isActive;

  /// Trang kề trang đang xem — khởi tạo sẵn controller nhưng KHÔNG phát.
  final bool preload;

  /// Bật → không tự phát; người dùng chạm mới phát.
  final bool dataSaver;
  final bool muted;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleMute;
  final VoidCallback onReport;
  final VoidCallback onOpenComments;
  final VoidCallback onShare;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;
  bool _initStarted = false;
  // Tim bay khi double-tap (phản hồi tức thì, giống Facebook/TikTok).
  bool _burst = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive || widget.preload) _init();
  }

  Future<void> _init() async {
    if (_initStarted) return;
    _initStarted = true;
    final url = widget.reel.videoUrl;
    if (url.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(_abs(url)));
    _c = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(widget.muted ? 0 : 1);
      if (!mounted) return;
      // Cập nhật thanh tiến trình theo thời gian phát.
      c.addListener(_onTick);
      setState(() => _ready = true);
      if (widget.isActive && !widget.dataSaver) await c.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onTick() {
    if (mounted && widget.isActive) setState(() {});
  }

  /// Double-tap = thích (không bao giờ bỏ thích — tránh lỡ tay hủy tim).
  void _onDoubleTap() {
    if (!widget.reel.likedByMe) widget.onToggleLike();
    setState(() => _burst = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _burst = false);
    });
  }

  @override
  void didUpdateWidget(covariant _ReelPage old) {
    super.didUpdateWidget(old);
    // Vừa được nạp sẵn / vừa thành trang đang xem → mới khởi tạo controller.
    if ((widget.isActive || widget.preload) && !_initStarted) _init();
    final c = _c;
    if (c == null || !_ready) return;
    if (widget.isActive != old.isActive) {
      (widget.isActive && !widget.dataSaver) ? c.play() : c.pause();
    }
    if (widget.muted != old.muted) c.setVolume(widget.muted ? 0 : 1);
  }

  @override
  void dispose() {
    _c?.removeListener(_onTick);
    _c?.dispose();
    super.dispose();
  }

  /// Tỉ lệ đã phát (0..1) cho thanh tiến trình.
  double get _progress {
    final v = _c?.value;
    if (v == null || !v.isInitialized) return 0;
    final total = v.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (v.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _togglePlay() {
    final c = _c;
    if (c == null || !_ready) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;
    final l = AppLocalizations.of(context);
    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video (hoặc ảnh bìa khi chưa sẵn sàng / lỗi)
          if (_ready && _c != null)
            Center(
              child: AspectRatio(
                aspectRatio: _c!.value.aspectRatio,
                child: VideoPlayer(_c!),
              ),
            )
          else if (r.thumbnailUrl != null && r.thumbnailUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: _abs(r.thumbnailUrl!),
              fit: BoxFit.cover,
            )
          else
            const ColoredBox(color: Colors.black),

          if (!_ready && !_failed)
            const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          if (_failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l.reelViewVideoError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),

          // Lớp phủ gradient để chữ nổi
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),

          // Thông tin + hành động
          Positioned(
            left: 16,
            right: 76,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: HD.accentTint,
                      backgroundImage: (r.authorAvatar?.isNotEmpty ?? false)
                          ? CachedNetworkImageProvider(_abs(r.authorAvatar!))
                          : null,
                      child: (r.authorAvatar?.isNotEmpty ?? false)
                          ? null
                          : const Icon(
                              Icons.person,
                              size: 18,
                              color: HD.accent,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (r.caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    r.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  l.reelViewViewCount(r.viewCount),
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),

          // Tim bay khi double-tap
          if (_burst)
            const Center(
              child: Icon(Icons.favorite, size: 110, color: Colors.white70),
            ),

          // Thanh tiến trình phát
          if (_ready && _c != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 2.5,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(HD.accent),
              ),
            ),

          // Cột hành động bên phải
          Positioned(
            right: 12,
            bottom: 40,
            child: Column(
              children: [
                _action(
                  icon: r.likedByMe ? Icons.favorite : Icons.favorite_border,
                  label: '${r.likeCount}',
                  color: r.likedByMe ? HD.accent : Colors.white,
                  onTap: widget.onToggleLike,
                ),
                const SizedBox(height: 18),
                _action(
                  icon: Icons.mode_comment_outlined,
                  label: '${r.commentCount}',
                  color: Colors.white,
                  onTap: widget.onOpenComments,
                ),
                const SizedBox(height: 18),
                _action(
                  icon: Icons.share_outlined,
                  label: l.reelViewShare,
                  color: Colors.white,
                  onTap: widget.onShare,
                ),
                const SizedBox(height: 18),
                _action(
                  icon: widget.muted ? Icons.volume_off : Icons.volume_up,
                  label: widget.muted ? l.reelViewUnmute : l.reelViewMute,
                  color: Colors.white,
                  onTap: widget.onToggleMute,
                ),
                const SizedBox(height: 18),
                _action(
                  icon: Icons.flag_outlined,
                  label: l.reelViewReport,
                  color: Colors.white70,
                  onTap: widget.onReport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
