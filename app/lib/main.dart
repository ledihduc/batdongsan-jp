import 'dart:io' show Platform;
import 'dart:ui';

import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/theme/app_fonts.dart';
import 'package:house_booking/core/telemetry/error_reporter.dart';
import 'package:house_booking/core/permissions/fcm_background_handler.dart';
import 'package:house_booking/core/permissions/fcm_service.dart';
import 'package:house_booking/core/permissions/gms_detector.dart';
import 'package:house_booking/core/permissions/permission_analytics_uploader.dart';
import 'package:house_booking/core/permissions/permission_events.dart';
import 'package:house_booking/core/permissions/permission_install_id.dart';
import 'package:house_booking/core/permissions/permission_service.dart';
import 'package:house_booking/core/permissions/permission_storage.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:house_booking/core/router/app_router.dart';
import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/theme/app_theme.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/providers/chat_provider.dart';
import 'package:house_booking/providers/social_feed_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/billing/providers/invoice_provider.dart';
import 'package:house_booking/features/host/billing/providers/service_fee_provider.dart';
import 'package:house_booking/features/host/billing/providers/meter_reading_provider.dart';
import 'package:house_booking/providers/locale_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/features/host/khaibao/providers/khaibao_provider.dart';
import 'package:house_booking/features/host/homestay/providers/homestay_calendar_provider.dart';
import 'package:house_booking/features/host/homestay/providers/pricing_rule_provider.dart';
import 'package:house_booking/features/host/homestay/providers/reservation_provider.dart';
import 'package:house_booking/features/host/marketplace/providers/marketplace_provider.dart';
import 'package:house_booking/providers/dashboard_provider.dart';
import 'package:house_booking/providers/report_provider.dart';
import 'package:house_booking/features/host/analytics/providers/drill_provider.dart';
import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/features/host/analytics/services/export_service.dart';
// Phase 07 — Delegation feature providers
import 'package:house_booking/providers/actor_context_provider.dart';
import 'package:house_booking/providers/delegation_provider.dart';
import 'package:house_booking/providers/approval_provider.dart';
import 'package:house_booking/providers/displayed_role_provider.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/core/lifecycle/delegation_revoke_handler.dart';
import 'package:house_booking/core/lifecycle/session_expired_handler.dart';
import 'package:house_booking/data/services/api_client.dart'
    show wireActorContextToApiClient;

/// Builds the app-scoped [PermissionService] with all dependencies wired.
///
/// FCM support is conditional:
/// - [fcmAvailable] = true  → real [FcmService] backed by [FirebaseMessaging].
/// - [fcmAvailable] = false → [_NullFcmService] stub (Huawei / no GMS) so that
///   [PermissionService] can be constructed unconditionally without crashing.
PermissionService buildPermissionService({required bool fcmAvailable}) {
  const storage = FlutterSecureStorage();
  final permStorage = PermissionStorage(storage);
  final events = LocalPermissionEventSink(storage);
  final installId = PermissionInstallId(storage);

  final FcmService fcm;
  if (fcmAvailable) {
    fcm = FcmService(
      messaging: FirebaseMessaging.instance,
      events: events,
      webVapidKey: null, // TODO(ops): set VAPID key from env when deploying web push.
      jwtProvider: SessionService.instance.getToken,
    );
  } else {
    // Huawei / de-Googled device: stub so PermissionService still compiles.
    fcm = _NullFcmService(events: events);
  }

  return PermissionService(
    storage: permStorage,
    events: events,
    fcm: fcm,
    installId: installId,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // JP market (Phase 00): initialize timezone database and set default to JST
  // when region=jp. For VN builds this is a no-op (TzHelper initialises lazily).
  // tz_data.initializeTimeZones() is idempotent so calling it here and in
  // TzHelper is safe; the second call is a no-op.
  tz_data.initializeTimeZones();
  if (FeatureFlags.isJapan) {
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  }

  // Force google_fonts to load only from bundled assets (assets/google_fonts/).
  // Disables runtime CDN fetch → no FOUT on cold start, works offline, GDPR-clean web.
  // If a font weight is missing from assets, the call throws instead of silently fetching.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Detect GMS availability before any Firebase call (AC-N9 / R6 crash safety).
  bool fcmAvailable = false;
  try {
    fcmAvailable = await GmsDetector.isFcmAvailable();
  } catch (_) {
    // GMS detection itself failed — degrade to no-FCM mode.
  }

  // Phase 5 (AC-N9 / D9): log a per-install event when GMS is missing on Android.
  // This fires pre-login (no userId) and is used for fleet sizing of Huawei impact.
  // Failing to log is non-fatal — the event is best-effort telemetry.
  if (!fcmAvailable && !kIsWeb) {
    bool isAndroid = false;
    try {
      isAndroid = Platform.isAndroid;
    } catch (_) {}
    if (isAndroid) {
      try {
        const huaweiStorage = FlutterSecureStorage();
        final sink = LocalPermissionEventSink(huaweiStorage);
        await sink.capture(PermissionEvent(
          outcome: PrimingOutcome.fcmUnavailableGmsMissing,
          kind: PermissionKind.notification,
          platform: 'android',
          ts: DateTime.now(),
        ));
      } catch (_) {
        // Non-fatal: event logging must never block app startup.
      }
    }
  }

  if (fcmAvailable) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
    } catch (e) {
      // Firebase config may not be present yet (Ops blocker — google-services.json).
      // Log and continue in no-FCM mode; app MUST NOT crash here.
      debugPrint('[main] Firebase.initializeApp failed: $e — running in no-FCM mode.');
      fcmAvailable = false;
    }
  }

  // Path URL trên web: /house/42 thay vì /#/house/42.
  // Yêu cầu prod server SPA fallback (vd. nginx try_files $uri /index.html).
  usePathUrlStrategy();
  _installGlobalErrorHandlers();
  _tuneImageCache();
  runApp(MyApp(fcmAvailable: fcmAvailable));
}

/// Bump default image cache (1000 items / 100MB) lên (~250MB, 2000 items).
/// Cần thiết vì home/wishlist/detail load list ảnh house liên tục — cache mặc
/// định bị evict quá nhanh dẫn tới reload network khi scroll lên xuống.
void _tuneImageCache() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 2000;
  imageCache.maximumSizeBytes = 256 * 1024 * 1024;
}

/// Dump full stacktrace ra terminal `flutter run` (copy được) + browser console.
/// Khi web build trong release, mọi setup này tự no-op qua kReleaseMode.
void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('================= FLUTTER ERROR =================');
    debugPrint('Exception : ${details.exceptionAsString()}');
    debugPrint('Library   : ${details.library}');
    debugPrint('Context   : ${details.context}');
    debugPrint('Stack:\n${details.stack}');
    debugPrint('=================================================');
    // Gửi về backend cho pipeline self-heal (fire-and-forget, đã redact PII).
    ErrorReporter.report(
      details.exception,
      details.stack,
      context: {'library': details.library?.toString()},
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('============== UNCAUGHT ASYNC ERROR =============');
    debugPrint('Error: $error');
    debugPrint('Stack:\n$stack');
    debugPrint('=================================================');
    ErrorReporter.report(error, stack);
    return true;
  };

  // Override red error widget — render copy-friendly text trên màn hình.
  // Chỉ dùng trong debug; release dùng default (tránh leak detail tới user).
  if (!kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        // Đỏ vì mang nghĩa LỖI, không phải màu thương hiệu — đổi theme sang
        // xanh không được kéo màn hình lỗi thành xanh.
        color: HD.negative,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SelectableText(
              'FLUTTER ERROR\n'
              '──────────────\n'
              '${details.exceptionAsString()}\n\n'
              'Context: ${details.context}\n\n'
              'Stack:\n${details.stack}',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    };
  }
}

/// Stateful root để khởi tạo `AuthProvider` + `GoRouter` đúng 1 lần
/// trong `initState` — tránh recreate router khi parent rebuild
/// (router cũ không dispose → leak listener của `refreshListenable`).
class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.fcmAvailable});

  /// Whether Firebase was successfully initialized (false on Huawei / no config).
  final bool fcmAvailable;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AuthProvider _auth;
  late final GoRouter _router;
  late final PermissionService _permissionService;
  late final PermissionAnalyticsUploader _uploader;
  // Phase 07: ActorContextProvider — in-memory only, NOT persisted (AC-15, NFR-07).
  late final ActorContextProvider _actorContext;
  // Phase 02 v3: lifted into State so the router's refreshListenable can chain
  // auth+delegation → redirect re-evaluates when delegation list loads and
  // avoids a flash of the wrong shell on cold-start deep-link.
  late final DelegationProvider _delegation;

  @override
  void initState() {
    super.initState();
    _permissionService =
        buildPermissionService(fcmAvailable: widget.fcmAvailable);

    // Analytics uploader: shares the same sink instance as PermissionService to
    // avoid two separate in-memory caches reading/writing the same storage key.
    // JWT is fetched lazily at flush time via SessionService — never stored stale.
    _uploader = PermissionAnalyticsUploader(
      sink: _permissionService.eventSink,
      jwtProvider: SessionService.instance.getToken,
    );

    _auth = AuthProvider()..bootstrap();
    // Inject PermissionService into AuthProvider so logout can delete FCM token.
    _auth.setPermissionService(_permissionService);

    // Phase 07: Wire ActorContextProvider into ApiClient header interceptor.
    // This single call connects the in-memory delegation context to every HTTP
    // request without threading BuildContext through repositories (TL-8 decision).
    _actorContext = ActorContextProvider();
    wireActorContextToApiClient(() => _actorContext.currentDelegationId);

    _delegation = DelegationProvider();

    _router = buildAppRouter(_auth, delegation: _delegation);

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _auth.dispose();
    _actorContext.dispose();
    _delegation.dispose();
    super.dispose();
  }

  /// Flush analytics events on every app foreground — fire-and-forget.
  /// Only flushes when authenticated to avoid unauthenticated BE calls.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _auth.isAuthenticated) {
      _uploader.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // PermissionService is placed first so downstream providers can read it.
        Provider<PermissionService>.value(value: _permissionService),
        // i18n P0 — ngôn ngữ app (vi/en/zh), nạp lựa chọn đã lưu.
        ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
        // PermissionAnalyticsUploader is exposed so RootGate can pass it to
        // attachFcm for post-login flush triggering.
        Provider<PermissionAnalyticsUploader>.value(value: _uploader),
        // AuthProvider được tạo trong State → dùng `.value` để Provider không
        // tự dispose (State.dispose đã handle).
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider(create: (_) => HostProfileProvider()),
        ChangeNotifierProvider(create: (_) => HouseProvider()),
        ChangeNotifierProvider(create: (_) => ViewingAppointmentProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SocialFeedProvider()),
        ChangeNotifierProvider(create: (_) => BuildingProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => ContractProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => ServiceFeeProvider()),
        ChangeNotifierProvider(create: (_) => MeterReadingProvider()),
        ChangeNotifierProvider(create: (_) => KhaiBaoProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => DrillProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => HomestayCalendarProvider()),
        ChangeNotifierProvider(create: (_) => PricingRuleProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
        ChangeNotifierProvider(create: (_) => MarketplaceProvider()),
        Provider<TelemetryService>(create: (_) => TelemetryService()),
        Provider<ExportService>(
          create: (_) => ExportService(),
          dispose: (_, service) => service.dispose(),
        ),
        // Phase 07 — Delegation feature providers (append-only per phase spec).
        // ActorContextProvider: NOT persisted — request-scoped only (AC-15, NFR-07).
        // Created in State.initState and wired to ApiClient above.
        ChangeNotifierProvider<ActorContextProvider>.value(value: _actorContext),
        ChangeNotifierProvider<DelegationProvider>.value(value: _delegation),
        ChangeNotifierProvider(create: (_) => ApprovalProvider()),
        // Phase 03 — DisplayedRole computed provider (auth + delegation).
        // See docs/role-model.md for derivation matrix.
        ChangeNotifierProxyProvider2<AuthProvider, DelegationProvider,
            DisplayedRoleProvider>(
          create: (ctx) => DisplayedRoleProvider(
            auth: ctx.read<AuthProvider>(),
            delegation: ctx.read<DelegationProvider>(),
          ),
          update: (_, auth, delegation, prev) {
            final p = prev ??
                DisplayedRoleProvider(
                  auth: auth,
                  delegation: delegation,
                );
            p.updateDeps(auth: auth, delegation: delegation);
            return p;
          },
        ),
      ],
      child: _CleanupHookWiring(
        auth: _auth,
        // Consumer<LocaleProvider> để đổi ngôn ngữ rebuild lại MaterialApp.
        child: Consumer<LocaleProvider>(
          builder: (context, localeP, _) => MaterialApp.router(
            title: Brand.name,
            // JP market: override textTheme with Noto Sans JP when region=jp.
            theme: AppFonts.applyToTheme(AppTheme.lightTheme),
            debugShowCheckedModeBanner: false,
            // Delegates gồm cả AppLocalizations + Global* (Material/Widgets/Cupertino).
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeP.locale,
            routerConfig: _router,
            // WEB: app là mobile-first → trên màn rộng, bọc trong khung cố định
            // rộng 480px căn GIỮA (2 bên nền xám), giống app trên điện thoại.
            // Ép MediaQuery.width=480 cho child để layout hành xử đúng như mobile.
            builder: (context, child) {
              final content = child ?? const SizedBox.shrink();
              if (!kIsWeb) return content;
              final mq = MediaQuery.of(context);
              const frameWidth = 480.0;
              if (mq.size.width <= frameWidth) return content;
              return ColoredBox(
                color: const Color(0xFFE9EDF2),
                child: Center(
                  child: SizedBox(
                    width: frameWidth,
                    child: MediaQuery(
                      data: mq.copyWith(
                          size: Size(frameWidth, mq.size.height)),
                      // KHÔNG clip nội dung (tránh "mất góc/đỉnh" ở màn có cover/
                      // header sát mép). Chỉ đổ bóng nhẹ 2 bên bằng DecoratedBox.
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: content,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Null FCM stub for Huawei / no-GMS / web-without-config devices ─────────

/// No-op [FcmService] subclass used when Firebase is unavailable (AC-N9).
///
/// Passes `messaging: null` to the parent — `FirebaseMessaging.instance` is
/// NOT safe to touch when no default Firebase app exists (throws on web).
/// All public methods are overridden so the null field is never dereferenced.
class _NullFcmService extends FcmService {
  _NullFcmService({required super.events})
      : super(
          messaging: null,
          webVapidKey: null,
        );

  @override
  Future<void> init() async {}

  @override
  Future<PrimingOutcome> requestPermission({
    required UserRole role,
    required bool useProvisionalOnIos,
    String userId = '',
  }) async =>
      PrimingOutcome.fcmUnavailableGmsMissing;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<RemoteMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<RemoteMessage> get notificationTaps => const Stream.empty();

  @override
  Future<bool> checkProvisionalUpgrade() async => false;

  @override
  Future<bool> isWebAlreadyGranted() async => false;

  @override
  void attachUserContext({required String userId, required String installId}) {}

  @override
  void detachUserContext() {}

  @override
  Future<bool> registerToken({
    required String userId,
    required String installId,
  }) async =>
      false;

  @override
  Future<bool> unregisterToken({required String installId}) async => false;
}

// ─── Cleanup wiring ──────────────────────────────────────────────────────────

/// Wires [UserScopeCleanup] into [AuthProvider._userScopeCleanup] on mount.
///
/// This widget sits INSIDE the MultiProvider tree so it can read every
/// user-scoped provider. It captures a stable BuildContext at [initState] and
/// registers a closure with AuthProvider that will run at logout time.
class _CleanupHookWiring extends StatefulWidget {
  const _CleanupHookWiring({required this.auth, required this.child});

  final AuthProvider auth;
  final Widget child;

  @override
  State<_CleanupHookWiring> createState() => _CleanupHookWiringState();
}

class _CleanupHookWiringState extends State<_CleanupHookWiring> {
  @override
  void initState() {
    super.initState();
    // Register post-frame so the provider tree is fully mounted first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.auth.setUserScopeCleanup(
        () => UserScopeCleanup(context).resetAll(),
      );
      // Wire delegation-revoke handler on the same lifecycle. On revoke we
      // clear the actor context, refresh delegation list, and pop back to
      // /operator so the operator lands somewhere valid. The router redirect
      // will re-run once ActorContext notifies.
      DelegationRevokeHandler.register(() {
        if (!mounted) return;
        try {
          context.read<ActorContextProvider>().clear();
          context.read<DelegationProvider>().fetchMyDelegationsAsOperator();
        } catch (_) {
          // Providers not in scope — non-fatal.
        }
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Ủy quyền đã bị thu hồi. Quay về danh sách đại lý.'),
          ),
        );
        // Navigate back to /operator. Router redirect will re-evaluate too.
        try {
          GoRouter.of(context).go('/operator');
        } catch (_) {
          // GoRouter not in scope.
        }
      });

      // Phiên hết hạn (401 bất kỳ, không riêng ca thu hồi uỷ quyền): đăng xuất
      // sạch rồi đưa về màn đăng nhập kèm giải thích. Trước đây token hết hạn
      // giữa chừng chỉ làm từng màn báo "Yêu cầu thất bại" rời rạc trong khi
      // giao diện vẫn hiện tên người dùng như đang đăng nhập.
      SessionExpiredHandler.register(() async {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        try {
          await widget.auth.logout();
        } catch (_) {
          // Vẫn tiếp tục điều hướng — kẹt lại còn tệ hơn.
        }
        if (!mounted) {
          SessionExpiredHandler.reset();
          return;
        }
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
          ),
        );
        try {
          GoRouter.of(context).go('/login');
        } catch (_) {
          // GoRouter chưa sẵn sàng.
        }
        SessionExpiredHandler.reset();
      });
    });
  }

  @override
  void dispose() {
    widget.auth.setUserScopeCleanup(null);
    DelegationRevokeHandler.register(null);
    SessionExpiredHandler.register(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
