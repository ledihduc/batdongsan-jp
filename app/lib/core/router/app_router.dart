import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/preferences_service.dart';
import 'package:house_booking/features/onboarding/intro_survey_screen.dart';
import 'package:house_booking/core/models/displayed_role.dart';
import 'package:house_booking/core/permissions/permission_analytics_uploader.dart';
import 'package:house_booking/core/permissions/permission_service.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/core/router/deferred_route_widget.dart';
import 'package:house_booking/core/router/route_guards.dart';
import 'package:house_booking/features/permissions/helpers/priming_presenter.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/delegation_provider.dart';
import 'package:house_booking/providers/displayed_role_provider.dart';

// ───────────────────────── Eager routes (light weight) ─────────────────────
import 'package:house_booking/features/auth/login_screen.dart';
import 'package:house_booking/features/auth/splash_screen.dart';
import 'package:house_booking/features/guest/guest_shell.dart';
import 'package:house_booking/features/guest/booking/room_booking_screen.dart';
import 'package:house_booking/features/host/ekyc/ekyc_chu_nha_screen.dart';
import 'package:house_booking/features/host/onboarding/become_host_intro_screen.dart';
import 'package:house_booking/features/onboarding/onboarding_screen.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/providers/chat_provider.dart';

// ───────────────────────── Delegation feature routes (Phase 07) ──────────────
import 'package:house_booking/features/operator/portfolio/operator_portfolio_screen.dart';
import 'package:house_booking/features/operator/workspace/operator_workspace_shell.dart';
import 'package:house_booking/features/operator/invitations/invitation_inbox_screen.dart';
import 'package:house_booking/features/host/delegation/delegation_invite_screen.dart';
import 'package:house_booking/features/host/delegation/delegation_detail_screen.dart';
import 'package:house_booking/features/host/approvals/approval_inbox_screen.dart';
import 'package:house_booking/features/audit/activity_feed_screen.dart';
import 'package:house_booking/features/tenant/screens/report_unauthorized_operator_screen.dart';

// Debug-only import — tree-shaken in release because all usages are inside
// `if (kDebugMode)` blocks which the compiler eliminates in AOT mode.
import 'package:house_booking/features/permissions/debug/permission_debug_screen.dart'
    if (dart.library.html) 'package:house_booking/features/permissions/debug/permission_debug_screen.dart';

// ───────────────────────── Deferred routes (web chunk splitting) ───────────
// Mỗi `deferred as` => 1 chunk JS riêng trên web. Symbol chỉ được resolve
// runtime sau khi `loadLibrary()` hoàn tất.
import 'package:house_booking/features/host/analytics/screens/analytics_home_screen.dart'
    deferred as analytics_home;
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart'
    deferred as broker_profile;
import 'package:house_booking/features/guest/project/building_public_screen.dart'
    deferred as building_public;
import 'package:house_booking/features/host/analytics/screens/revenue_trend_screen.dart'
    deferred as analytics_trend;
import 'package:house_booking/features/host/analytics/screens/occupancy_heatmap_screen.dart'
    deferred as analytics_heatmap;
import 'package:house_booking/features/host/analytics/screens/drill_room_screen.dart'
    deferred as drill_room;
import 'package:house_booking/features/host/analytics/screens/drill_contract_screen.dart'
    deferred as drill_contract;
import 'package:house_booking/features/host/analytics/screens/drill_tenant_screen.dart'
    deferred as drill_tenant;
import 'package:house_booking/features/host/analytics/screens/drill_invoice_screen.dart'
    deferred as drill_invoice;
import 'package:house_booking/features/host/analytics/screens/source_management_screen.dart'
    deferred as source_management;
import 'package:house_booking/features/admin/admin_home_screen.dart'
    deferred as admin;
import 'package:house_booking/features/guest/house_detail/house_detail_screen.dart'
    deferred as detail;
import 'package:house_booking/features/map/map_shell_screen.dart'
    deferred as map_shell;

// ── JP market routes (Phase 01) — deferred for chunk splitting ───────────
// Each `deferred as` creates a separate JS chunk on web. JP-only screens
// are excluded from the base bundle — VN builds tree-shake these at link time
// when the routes are never registered (gated behind FeatureFlags.isJapan).
import 'package:house_booking/features/guest/viewing/viewing_status_screen.dart'
    deferred as jp_viewing_status;
import 'package:house_booking/features/guest/application/application_wizard_screen.dart'
    deferred as jp_application_wizard;
import 'package:house_booking/features/sales/dashboard_screen.dart'
    deferred as jp_sales_dashboard;
import 'package:house_booking/features/sales/viewing_inbox_screen.dart'
    deferred as jp_sales_viewings;
import 'package:house_booking/features/sales/application_queue_screen.dart'
    deferred as jp_sales_applications;

// ── JP market routes (Phase 04) — Help Center (eager, small widget tree) ──
import 'package:house_booking/features/help/help_center_screen.dart'
    deferred as jp_help_center;
import 'package:house_booking/features/help/help_article_screen.dart'
    deferred as jp_help_article;

// ── JP market routes (Phase 03) — deferred for chunk splitting ───────────
import 'package:house_booking/features/renewal/renewal_detail_screen.dart'
    deferred as jp_renewal_detail;
import 'package:house_booking/features/deposit_settlement/owner_itemize_screen.dart'
    deferred as jp_owner_itemize;
import 'package:house_booking/features/deposit_settlement/tenant_review_screen.dart'
    deferred as jp_tenant_review;
import 'package:house_booking/features/admin/jp_kpi_dashboard_screen.dart'
    deferred as jp_admin_kpi;
import 'package:house_booking/features/consent/account_deletion_screen.dart'
    deferred as jp_account_deletion;

// ── JP market routes (Phase 02) — deferred for chunk splitting ───────────
import 'package:house_booking/features/checkout/jp_checkout_screen.dart'
    deferred as jp_checkout;
import 'package:house_booking/features/checkout/konbini_voucher_screen.dart'
    deferred as jp_konbini_voucher;
import 'package:house_booking/features/checkout/payment_status_screen.dart'
    deferred as jp_payment_status;
import 'package:house_booking/features/consent/consent_settings_screen.dart'
    deferred as jp_consent_settings;
import 'package:house_booking/features/sales/application_review_screen.dart'
    deferred as jp_application_review;
import 'package:house_booking/features/it_session/it_session_join_screen.dart'
    deferred as jp_it_session;
import 'package:house_booking/features/econtract/econtract_signing_screen.dart'
    deferred as jp_econtract;

/// GoRouter chính của app.
///
/// Tách top-level routes có URL riêng (deep link, browser back/forward) khỏi
/// các flow con (host onboarding step1→2→3, building→room→contract…) — các
/// flow con vẫn `Navigator.push` bình thường vì không cần URL.
GoRouter buildAppRouter(AuthProvider auth, {DelegationProvider? delegation}) {
  // Chain auth + delegation so redirect re-evaluates when delegation list
  // loads (avoids cold-start flash of GuestShell for operator deep-link).
  final refresh = delegation == null
      ? auth
      : Listenable.merge(<Listenable>[auth, delegation]);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // Chưa bootstrap xong → KHÔNG redirect. Tránh kick deep-link về /login
      // rồi đẩy về / (mất target). _RootGate render Splash trong lúc chờ;
      // các deferred route khác cũng giữ nguyên target để retry sau khi
      // refreshListenable notify (auth bootstrap done).
      if (auth.isBootstrapping) return null;

      final loc = state.matchedLocation;
      final isAuth = auth.isAuthenticated;

      // Derive DisplayedRole. Prefer the provider (already reactive to
      // delegation changes) — fall back to pure derive() when the provider
      // isn't in context yet (e.g. very first frame before ProxyProvider
      // resolves).
      final role = _resolveDisplayedRole(context, auth);

      final adminGuard = guardAdminRoutes(
        location: loc,
        role: role,
        isAuthenticated: isAuth,
      );
      if (adminGuard != null) return adminGuard;

      final operatorGuard = guardOperatorRoutes(
        location: loc,
        role: role,
        isAuthenticated: isAuth,
      );
      if (operatorGuard != null) return operatorGuard;

      final tenantGuard = guardTenantRoutes(
        location: loc,
        role: role,
        isAuthenticated: isAuth,
      );
      if (tenantGuard != null) return tenantGuard;

      // /host permits authenticated guests too — they'll hit the become-host
      // intro screen at /host or the auto-upgrade path. Only gate on auth.
      if (_matchesPrefix(loc, '/host') && !isAuth) return '/login';

      // /house/:id: cho khách xem chi tiết khi browse-first bật (màn chi tiết đã
      // guard mọi hành động cá nhân). Không bật flag → giữ chặn như cũ.
      if (loc.startsWith('/house/') && !isAuth && !FeatureFlags.guestBrowse) {
        return '/login';
      }

      // JP market (Phase 00): VN-only routes are hidden in Japan builds.
      // /planning — Vietnam real-estate map planning tool.
      // /sale/:id  — Vietnamese broker public profile (VN-only sales feature).
      // /du-an/:id — VN real-estate project listing (buildings/units for sale).
      // Redirect to /not-available so users get a clear explanation, not a 404.
      if (FeatureFlags.isJapan) {
        if (loc == '/planning' ||
            loc.startsWith('/sale/') ||
            loc.startsWith('/du-an/')) {
          return '/not-available';
        }
      }

      // Authenticated user hitting /login → send to role-appropriate home.
      if (isAuth && loc == '/login') {
        return auth.loginAccountType == null
            ? defaultHomeFor(role)
            : auth.loginLocation;
      }

      // Phase 04 progressive rollout — operator lands on /operator instead of
      // GuestShell when the flag is enabled. Behind flag so we can dark-launch
      // and roll back with a build config change.
      if (FeatureFlags.roleShellsV2Enabled &&
          isAuth &&
          loc == '/' &&
          auth.loginAccountType == null &&
          role == DisplayedRole.operator_) {
        return '/operator';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (ctx, state) => _fadePage(
          state: state,
          child: _RootGate(
            initialTab: state.uri.queryParameters['tab'] == 'activity' ? 3 : 0,
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (ctx, state) =>
            _fadePage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/host',
        pageBuilder: (ctx, state) =>
            _fadePage(state: state, child: const BecomeHostIntroScreen()),
      ),
      // ───── Deferred: AnalyticsHomeScreen — Revenue analytics dashboard
      GoRoute(
        path: '/host/analytics',
        pageBuilder: (ctx, state) => _fadePage(
          state: state,
          child: DeferredRouteWidget(
            loadLibrary: analytics_home.loadLibrary,
            builder: (_) => analytics_home.AnalyticsHomeScreen(),
          ),
        ),
      ),
      // ───── Deferred: RevenueTrendScreen — dual-line trend chart (Phase 06)
      GoRoute(
        path: '/host/analytics/trend',
        pageBuilder: (ctx, state) => _fadePage(
          state: state,
          child: DeferredRouteWidget(
            loadLibrary: analytics_trend.loadLibrary,
            builder: (_) => analytics_trend.RevenueTrendScreen(),
          ),
        ),
      ),
      // ───── Deferred: OccupancyHeatmapScreen — room×day heatmap (Phase 06)
      GoRoute(
        path: '/host/analytics/heatmap',
        pageBuilder: (ctx, state) => _fadePage(
          state: state,
          child: DeferredRouteWidget(
            loadLibrary: analytics_heatmap.loadLibrary,
            builder: (_) => analytics_heatmap.OccupancyHeatmapScreen(),
          ),
        ),
      ),
      // ───── Deferred: Drill Level 1 — Room list (Phase 07)
      GoRoute(
        path: '/host/analytics/drill/rooms',
        pageBuilder: (ctx, state) => _fadePage(
          state: state,
          child: DeferredRouteWidget(
            loadLibrary: drill_room.loadLibrary,
            builder: (_) => drill_room.DrillRoomScreen(),
          ),
        ),
      ),
      // ───── Deferred: Drill Level 2 — Contracts for room
      GoRoute(
        path: '/host/analytics/drill/room/:roomId/contracts',
        pageBuilder: (ctx, state) {
          final roomId =
              int.tryParse(state.pathParameters['roomId'] ?? '') ?? 0;
          return _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: drill_contract.loadLibrary,
              builder: (_) =>
                  drill_contract.DrillContractScreen(roomId: roomId),
            ),
          );
        },
      ),
      // ───── Deferred: Drill Level 3 — Tenants for contract
      GoRoute(
        path: '/host/analytics/drill/contract/:contractId/tenants',
        pageBuilder: (ctx, state) {
          final contractId =
              int.tryParse(state.pathParameters['contractId'] ?? '') ?? 0;
          return _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: drill_tenant.loadLibrary,
              builder: (_) =>
                  drill_tenant.DrillTenantScreen(contractId: contractId),
            ),
          );
        },
      ),
      // ───── Deferred: Drill Level 4 — Invoices for tenant
      GoRoute(
        path: '/host/analytics/drill/tenant/:tenantId/invoices',
        pageBuilder: (ctx, state) {
          final tenantId =
              int.tryParse(state.pathParameters['tenantId'] ?? '') ?? 0;
          final contractId =
              int.tryParse(state.uri.queryParameters['contract_id'] ?? '') ?? 0;
          return _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: drill_invoice.loadLibrary,
              builder: (_) => drill_invoice.DrillInvoiceScreen(
                tenantId: tenantId,
                contractId: contractId,
              ),
            ),
          );
        },
      ),
      // ───── Deferred: SourceManagementScreen — CRUD for revenue sources (Phase 08)
      GoRoute(
        path: '/host/analytics/sources',
        pageBuilder: (ctx, state) => _fadePage(
          state: state,
          child: DeferredRouteWidget(
            loadLibrary: source_management.loadLibrary,
            builder: (_) => source_management.SourceManagementScreen(),
          ),
        ),
      ),
      // ───── Deferred: AdminHomeScreen + admin module
      GoRoute(
        path: '/admin',
        pageBuilder: (ctx, state) => _fadePage(
          state: state,
          child: DeferredRouteWidget(
            loadLibrary: admin.loadLibrary,
            builder: (_) => admin.AdminHomeScreen(),
          ),
        ),
      ),
      // ───── Deferred: MapShellScreen — bản đồ gộp (nhà đăng + quy hoạch).
      // /map mở mode listings; chunk quy hoạch chỉ tải khi user bấm toggle.
      GoRoute(
        path: '/map',
        // Query params: ?lat=..&lng=..&zoom=..  → mở thẳng vào một tin cụ thể.
        // Clamp giống /planning: toạ độ rác làm flutter_map nổ khi tính ô tile.
        pageBuilder: (ctx, state) {
          final qp = state.uri.queryParameters;
          final lat = _parseInRange(qp['lat'], -90, 90);
          final lng = _parseInRange(qp['lng'], -180, 180);
          final zoom = _parseInRange(qp['zoom'], 1, 20);
          return _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: map_shell.loadLibrary,
              builder: (_) => map_shell.MapShellScreen(
                initialMode: map_shell.MapMode.listings,
                initialCenter: (lat != null && lng != null)
                    ? LatLng(lat, lng)
                    : null,
                initialZoom: zoom,
                focusHouseId: int.tryParse(qp['houseId'] ?? ''),
              ),
            ),
          );
        },
      ),
      // ───── Deferred: MapShellScreen — mở thẳng mode quy hoạch.
      // Query params: ?lat=10.77&lng=106.70&zoom=16
      // Lat/lng clamp về range hợp lệ (tránh flutter_map crash khi compute tile).
      // Zoom clamp [1, 20] — khớp minZoom/maxZoom của map.
      GoRoute(
        path: '/planning',
        pageBuilder: (ctx, state) {
          final qp = state.uri.queryParameters;
          final lat = _parseInRange(qp['lat'], -90, 90);
          final lng = _parseInRange(qp['lng'], -180, 180);
          final zoom = _parseInRange(qp['zoom'], 1, 20);
          final center = (lat != null && lng != null) ? LatLng(lat, lng) : null;
          return _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: map_shell.loadLibrary,
              builder: (_) => map_shell.MapShellScreen(
                initialMode: map_shell.MapMode.planning,
                initialCenter: center,
                houseMarker: center != null,
                initialZoom: zoom,
              ),
            ),
          );
        },
      ),
      // ───── TRANG CÁ NHÂN SALE — có URL để CHIA SẺ được.
      //
      // Đây là lý do route này tồn tại: môi giới cần một đường link gửi cho
      // khách. Trước đây màn hồ sơ chỉ push trong tab, không có URL nào, mà nút
      // "Chia sẻ" thì copy link sang site SSR — site đó đã gỡ ngày 03/09 nên
      // link gửi đi là link chết.
      //
      // Chấp nhận cả `/sale/12-nguyen-van-a`: phần chữ chỉ để link đọc được,
      // phân giải thì lấy đúng số ở đầu. Sai định dạng → trang lỗi của router,
      // KHÔNG được ném (id rác từ link người khác dán vào là chuyện thường).
      GoRoute(
        path: '/sale/:id',
        pageBuilder: (ctx, state) {
          final raw = state.pathParameters['id'] ?? '';
          final id = int.tryParse(RegExp(r'^\d+').stringMatch(raw) ?? '');
          return _fadePage(
            state: state,
            child: id == null
                ? const _KhongTimThay()
                : DeferredRouteWidget(
                    loadLibrary: broker_profile.loadLibrary,
                    builder: (_) =>
                        broker_profile.BrokerProfileScreen(userId: id),
                  ),
          );
        },
      ),
      // ───── TRANG DỰ ÁN CÔNG KHAI — bảng giá từng phòng, kiểu trang khách
      // sạn. Có URL để sale gửi thẳng "toà S1, còn 4 phòng" cho khách.
      GoRoute(
        path: '/du-an/:id',
        pageBuilder: (ctx, state) {
          final raw = state.pathParameters['id'] ?? '';
          final id = int.tryParse(RegExp(r'^\d+').stringMatch(raw) ?? '');
          return _fadePage(
            state: state,
            child: id == null
                ? const _KhongTimThay()
                : DeferredRouteWidget(
                    loadLibrary: building_public.loadLibrary,
                    builder: (_) =>
                        building_public.BuildingPublicScreen(buildingId: id),
                  ),
          );
        },
      ),
      // eKYC chủ nhà — mở từ LINK `/ekyc?t=<token>` trên thiết bị khác (không
      // cần đăng nhập: token chỉ mở đúng hồ sơ eKYC của người tạo link), hoặc
      // không token khi đã đăng nhập.
      GoRoute(
        path: '/ekyc',
        pageBuilder: (ctx, state) => _fadePage(
          state: state,
          child: EkycChuNhaScreen(token: state.uri.queryParameters['t']),
        ),
      ),
      GoRoute(
        path: '/dat-phong/:id',
        pageBuilder: (ctx, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return _fadePage(state: state, child: const _KhongTimThay());
          }
          final extra = state.extra;
          final args = extra is RoomBookingArgs
              ? extra
              : RoomBookingArgs(
                  roomId: id,
                  roomCode: 'P$id',
                  buildingName: 'Phòng đang chọn',
                  price: 0,
                  saleName: 'sale phụ trách',
                );
          return _fadePage(
            state: state,
            child: RoomBookingScreen(args: args),
          );
        },
      ),
      // ───── Deferred: HouseDetailScreen
      GoRoute(
        path: '/house/:id',
        pageBuilder: (ctx, state) {
          final raw = state.pathParameters['id'];
          final id = int.tryParse(raw ?? '');
          if (id == null) {
            return _fadePage(
              state: state,
              child: const Scaffold(
                body: Center(child: Text('ID nhà không hợp lệ')),
              ),
            );
          }
          return _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: detail.loadLibrary,
              builder: (_) => detail.HouseDetailScreen(houseId: id),
            ),
          );
        },
      ),
      // ───────────── Delegation feature routes (Phase 07) ─────────────────────
      // /operator              → Operator portfolio (list of delegated owners)
      // /operator/owner/:id    → Operator workspace shell (acting-as context)
      // /operator/owner/:id/audit → Activity feed for delegation
      // /operator/invitations  → Operator invitation inbox
      // /host/delegation/invite → Owner: invite new operator
      // /host/delegation/:id   → Owner: manage existing delegation
      // /host/approvals        → Owner: approval inbox
      // /tenant/report-unauthorized/:id → Tenant: report unauthorized operator
      GoRoute(
        path: '/operator',
        pageBuilder: (ctx, state) =>
            _fadePage(state: state, child: const OperatorPortfolioScreen()),
      ),
      GoRoute(
        path: '/operator/owner/:ownerId',
        pageBuilder: (ctx, state) {
          final ownerId = state.pathParameters['ownerId'] ?? '';
          return _fadePage(
            state: state,
            child: OperatorWorkspaceShell(ownerId: ownerId),
          );
        },
      ),
      GoRoute(
        path: '/operator/owner/:ownerId/audit',
        pageBuilder: (ctx, state) {
          final delegationId =
              state.uri.queryParameters['delegation_id'] ??
              state.pathParameters['ownerId'] ??
              '';
          return _fadePage(
            state: state,
            child: ActivityFeedScreen(delegationId: delegationId),
          );
        },
      ),
      GoRoute(
        path: '/operator/invitations',
        pageBuilder: (ctx, state) =>
            _fadePage(state: state, child: const InvitationInboxScreen()),
      ),
      GoRoute(
        path: '/host/delegation/invite',
        pageBuilder: (ctx, state) {
          final buildingId = state.uri.queryParameters['building_id'];
          return _fadePage(
            state: state,
            child: DelegationInviteScreen(buildingId: buildingId),
          );
        },
      ),
      GoRoute(
        path: '/host/delegation/:id',
        pageBuilder: (ctx, state) {
          final delegationId = state.pathParameters['id'] ?? '';
          return _fadePage(
            state: state,
            child: DelegationDetailScreen(delegationId: delegationId),
          );
        },
      ),
      GoRoute(
        path: '/host/approvals',
        pageBuilder: (ctx, state) =>
            _fadePage(state: state, child: const ApprovalInboxScreen()),
      ),
      GoRoute(
        path: '/tenant/report-unauthorized/:delegationId',
        pageBuilder: (ctx, state) {
          final delegationId = state.pathParameters['delegationId'] ?? '';
          return _fadePage(
            state: state,
            child: ReportUnauthorizedOperatorScreen(delegationId: delegationId),
          );
        },
      ),
      // ───── JP market (Phase 01): 内見ステータス screen (deep-link for push notif).
      // Gated behind FeatureFlags.isJapan — redirect to /not-available in VN build.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/viewings/:id',
          pageBuilder: (ctx, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return _fadePage(
              state: state,
              child: id == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_viewing_status.loadLibrary,
                      builder: (_) =>
                          jp_viewing_status.ViewingStatusScreen(viewingId: id),
                    ),
            );
          },
        ),

      // ───── JP market (Phase 01): 入居申込 wizard.
      // :id == '0' → create new (listing_id in query params).
      // :id > 0    → resume draft application.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/applications/:id',
          pageBuilder: (ctx, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            final listingId =
                int.tryParse(state.uri.queryParameters['listing_id'] ?? '');
            return _fadePage(
              state: state,
              child: DeferredRouteWidget(
                loadLibrary: jp_application_wizard.loadLibrary,
                builder: (_) => jp_application_wizard.ApplicationWizardScreen(
                  applicationId: id,
                  listingId: listingId,
                ),
              ),
            );
          },
        ),

      // ───── JP market (Phase 01): Sales persona routes.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/sales',
          pageBuilder: (ctx, state) => _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: jp_sales_dashboard.loadLibrary,
              builder: (_) => jp_sales_dashboard.SalesDashboardScreen(),
            ),
          ),
        ),

      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/sales/viewings',
          pageBuilder: (ctx, state) => _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: jp_sales_viewings.loadLibrary,
              builder: (_) => jp_sales_viewings.ViewingInboxScreen(),
            ),
          ),
        ),

      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/sales/applications',
          pageBuilder: (ctx, state) => _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: jp_sales_applications.loadLibrary,
              builder: (_) => jp_sales_applications.ApplicationQueueScreen(),
            ),
          ),
        ),

      // ───── JP market (Phase 02): Checkout + payment routes.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/checkout/:invoiceId',
          pageBuilder: (ctx, state) {
            final invoiceId =
                int.tryParse(state.pathParameters['invoiceId'] ?? '');
            return _fadePage(
              state: state,
              child: invoiceId == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_checkout.loadLibrary,
                      builder: (_) => jp_checkout.JpCheckoutScreen(
                        invoiceId: invoiceId,
                      ),
                    ),
            );
          },
        ),

      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/payments/:intentId/voucher',
          pageBuilder: (ctx, state) {
            final intentId =
                int.tryParse(state.pathParameters['intentId'] ?? '');
            return _fadePage(
              state: state,
              child: intentId == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_konbini_voucher.loadLibrary,
                      builder: (_) => jp_konbini_voucher.KonbiniVoucherScreen(
                        intentId: intentId,
                      ),
                    ),
            );
          },
        ),

      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/payments/:intentId/status',
          pageBuilder: (ctx, state) {
            final intentId =
                int.tryParse(state.pathParameters['intentId'] ?? '');
            return _fadePage(
              state: state,
              child: intentId == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_payment_status.loadLibrary,
                      builder: (_) => jp_payment_status.PaymentStatusScreen(
                        intentId: intentId,
                      ),
                    ),
            );
          },
        ),

      // ───── JP market (Phase 02): APPI consent settings.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/settings/privacy',
          pageBuilder: (ctx, state) => _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: jp_consent_settings.loadLibrary,
              builder: (_) => jp_consent_settings.ConsentSettingsScreen(),
            ),
          ),
        ),

      // ───── JP market (Phase 02): Application review (for sales/owner).
      // Path: /applications/:id/review — note: /applications/:id (draft wizard)
      // is already registered in Phase 01; GoRouter matches the more specific
      // /review sub-path first.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/applications/:id/review',
          pageBuilder: (ctx, state) {
            final id =
                int.tryParse(state.pathParameters['id'] ?? '');
            return _fadePage(
              state: state,
              child: id == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_application_review.loadLibrary,
                      builder: (_) =>
                          jp_application_review.ApplicationReviewScreen(
                        applicationId: id,
                      ),
                    ),
            );
          },
        ),

      // ───── JP market (Phase 02): IT重説 join screen.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/viewings/:id/it-session',
          pageBuilder: (ctx, state) {
            final viewingId =
                int.tryParse(state.pathParameters['id'] ?? '');
            return _fadePage(
              state: state,
              child: viewingId == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_it_session.loadLibrary,
                      builder: (_) => jp_it_session.ItSessionJoinScreen(
                        viewingId: viewingId,
                      ),
                    ),
            );
          },
        ),

      // ───── JP market (Phase 02): eContract signing screen.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/econtracts/:id',
          pageBuilder: (ctx, state) {
            final id =
                int.tryParse(state.pathParameters['id'] ?? '');
            return _fadePage(
              state: state,
              child: id == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_econtract.loadLibrary,
                      builder: (_) => jp_econtract.EcontractSigningScreen(
                        econtractId: id,
                      ),
                    ),
            );
          },
        ),

      // ───── JP market (Phase 03): Renewal detail screen.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/renewals/:id',
          pageBuilder: (ctx, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return _fadePage(
              state: state,
              child: id == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_renewal_detail.loadLibrary,
                      builder: (_) => jp_renewal_detail.RenewalDetailScreen(
                        renewalId: id,
                      ),
                    ),
            );
          },
        ),

      // ───── JP market (Phase 03): Deposit settlement — owner itemize.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/settlements/:id/itemize',
          pageBuilder: (ctx, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return _fadePage(
              state: state,
              child: id == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_owner_itemize.loadLibrary,
                      builder: (_) => jp_owner_itemize.OwnerItemizeScreen(
                        settlementId: id,
                      ),
                    ),
            );
          },
        ),

      // ───── JP market (Phase 03): Deposit settlement — tenant review.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/settlements/:id/review',
          pageBuilder: (ctx, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return _fadePage(
              state: state,
              child: id == null
                  ? const _KhongTimThay()
                  : DeferredRouteWidget(
                      loadLibrary: jp_tenant_review.loadLibrary,
                      builder: (_) => jp_tenant_review.TenantReviewScreen(
                        settlementId: id,
                      ),
                    ),
            );
          },
        ),

      // ───── JP market (Phase 03): Admin JP KPI dashboard.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/admin/jp-kpi',
          pageBuilder: (ctx, state) => _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: jp_admin_kpi.loadLibrary,
              builder: (_) => jp_admin_kpi.JpKpiDashboardScreen(),
            ),
          ),
        ),

      // ───── JP market (Phase 03): Account deletion schedule screen.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/settings/account-deletion',
          pageBuilder: (ctx, state) => _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: jp_account_deletion.loadLibrary,
              builder: (_) => jp_account_deletion.AccountDeletionScreen(),
            ),
          ),
        ),

      // ───── JP market (Phase 04): Help Center — list screen.
      // Gated behind FeatureFlags.isJapan; redirected to /not-available in VN.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/help',
          pageBuilder: (ctx, state) => _fadePage(
            state: state,
            child: DeferredRouteWidget(
              loadLibrary: jp_help_center.loadLibrary,
              builder: (_) => jp_help_center.HelpCenterScreen(),
            ),
          ),
        ),

      // ───── JP market (Phase 04): Help Center — article detail screen.
      if (FeatureFlags.isJapan)
        GoRoute(
          path: '/help/:id',
          pageBuilder: (ctx, state) {
            final id = state.pathParameters['id'] ?? '';
            return _fadePage(
              state: state,
              child: DeferredRouteWidget(
                loadLibrary: jp_help_article.loadLibrary,
                builder: (_) => jp_help_article.HelpArticleScreen(
                  articleId: id,
                ),
              ),
            );
          },
        ),

      // ───── JP market (Phase 00): VN-only feature not available in this region.
      // Shown when region=jp user tries to access /planning, /sale/:id, /du-an/:id.
      GoRoute(
        path: '/not-available',
        pageBuilder: (ctx, state) =>
            _fadePage(state: state, child: const _NotAvailableScreen()),
      ),
      // ───── Debug: Permission priming debug screen (kDebugMode only)
      // In release builds this block is dead code and tree-shaken by the AOT
      // compiler — PermissionDebugScreen is never reachable in production.
      if (kDebugMode)
        GoRoute(
          path: '/permission-debug',
          pageBuilder: (ctx, state) =>
              _fadePage(state: state, child: const PermissionDebugScreen()),
        ),
    ],
    errorPageBuilder: (ctx, state) => _fadePage(
      state: state,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Không tìm thấy trang',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(state.error?.toString() ?? state.uri.toString()),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ctx.go('/'),
                  child: const Text('Về trang chủ'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Match `path == prefix` hoặc `path == prefix + '/...'` — KHÔNG match
/// `/hostess`, `/host-tools` (tránh auth bypass tương lai khi thêm route trùng
/// prefix mà quên cập nhật redirect).
bool _matchesPrefix(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// Resolves the current [DisplayedRole] from provider context if available,
/// otherwise falls back to pure derivation from AuthProvider only.
///
/// The provider path handles delegation changes reactively; the fallback path
/// covers the very first redirect fire (before the ProxyProvider has resolved)
/// or unit tests that build the router without a provider tree.
DisplayedRole _resolveDisplayedRole(BuildContext context, AuthProvider auth) {
  try {
    return context.read<DisplayedRoleProvider>().current;
  } catch (_) {
    // Provider not in scope — fall back to auth-only derivation.
  }
  DelegationProvider? delegation;
  try {
    delegation = context.read<DelegationProvider>();
  } catch (_) {
    delegation = null;
  }
  final hasActiveDelegation =
      delegation != null &&
      delegation.myDelegationsAsOperator.any((d) => d.isActive);
  return DisplayedRoleProvider.derive(
    authRole: auth.currentUser?.role,
    hasActiveDelegation: hasActiveDelegation,
    hasTenantJwt: false,
  );
}

/// Parse số trong range [min, max]. Trả null nếu null/non-numeric/out-of-range.
/// `!v.isFinite` chặn NaN + ±Infinity — `NaN < x` luôn false nên phải check
/// trước khi so sánh, nếu không attacker có thể truyền `?lat=NaN` để bypass
/// guard và crash flutter_map khi compute tile coords.
double? _parseInRange(String? raw, double min, double max) {
  final v = double.tryParse(raw ?? '');
  if (v == null || !v.isFinite || v < min || v > max) return null;
  return v;
}

/// CustomTransitionPage với fade — feels native với browser back/forward.
/// Mobile platform transition cũng OK với fade (hơi khác Material default chút
/// nhưng nhanh hơn nên scroll back-stack rất mượt).
CustomTransitionPage<T> _fadePage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    transitionsBuilder: (ctx, anim, secondary, c) =>
        FadeTransition(opacity: anim, child: c),
  );
}

/// `/` route — AuthWrapper cũ. Splash khi bootstrapping, Onboarding lần đầu,
/// Login nếu chưa auth, GuestShell nếu auth (admin sẽ được redirect sang /admin
/// trước khi tới đây).
class _RootGate extends StatefulWidget {
  const _RootGate({this.initialTab = 0});

  final int initialTab;

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  // Static để giữ trạng thái qua các lần _RootGate State được recreate
  // (vd. khi GoRouter rebuild stack sau redirect). Reset về false khi logout
  // để hydrate lại sau khi user khác login. Trade-off: nếu sau này test
  // multi-session trong cùng process cần reset thủ công.
  static bool _hydratedAfterLogin = false;

  /// Browse-first: đã hydrate dữ liệu công khai (danh sách nhà) cho khách chưa
  /// đăng nhập chưa. Tách khỏi [_hydratedAfterLogin] (chỉ chạy sau login).
  static bool _guestHydrated = false;

  bool? _showOnboarding;

  /// Redesign v2 P1: khảo sát đã hiện cho user này chưa (null = chưa resolve).
  /// true = đã hiện/không cần → bỏ qua survey. Backfill user cũ (chưa từng hiện).
  bool? _surveyPrompted;

  @override
  void initState() {
    super.initState();
    shouldShowOnboarding().then((v) {
      if (mounted) setState(() => _showOnboarding = v);
    });
    if (FeatureFlags.redesignV2) {
      PreferencesService.instance.hasBeenPrompted().then((p) {
        if (mounted) setState(() => _surveyPrompted = p);
      });
    } else {
      _surveyPrompted = true; // flag off → không hiện survey
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isBootstrapping ||
        _showOnboarding == null ||
        _surveyPrompted == null) {
      return const SplashScreen();
    }
    if (_showOnboarding == true) {
      return OnboardingScreen(
        onFinish: () => setState(() => _showOnboarding = false),
      );
    }
    // Redesign v2 P1: khảo sát phân loại sau onboarding (1 lần, kể cả khách &
    // user cũ — backfill). Bỏ qua được. Chỉ khi flag bật (_surveyPrompted=false).
    if (_surveyPrompted == false) {
      return IntroSurveyScreen(
        onDone: () => setState(() => _surveyPrompted = true),
      );
    }
    if (!authProvider.isAuthenticated) {
      _hydratedAfterLogin = false;
      // Browse-first: khách xem app không cần đăng nhập (FeatureFlags.guestBrowse).
      // Render GuestShell chế độ khách; hydrate CHỈ dữ liệu công khai (danh sách
      // nhà) — tuyệt đối không gọi fetch nào cần user.id (tránh crash null).
      if (FeatureFlags.guestBrowse) {
        if (!_guestHydrated) {
          _guestHydrated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Provider.of<HouseProvider>(
              context,
              listen: false,
            ).fetchInitialData();
          });
        }
        return const GuestShell();
      }
      // Không có lối thoát: ở nhánh này màn đăng nhập CHÍNH LÀ '/', bấm thoát
      // chỉ quay về chính nó.
      return const LoginScreen(coLoiThoat: false);
    }
    _guestHydrated = false;

    final user = authProvider.currentUser!;

    // Hydrate initial data lần đầu sau login (kể cả restore session).
    if (!_hydratedAfterLogin) {
      _hydratedAfterLogin = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Redesign v2 P1: hợp nhất prefs khách (nếu có) vào tài khoản sau login.
        if (FeatureFlags.redesignV2) {
          PreferencesService.instance.mergeOnLogin(user.id!);
        }
        Provider.of<HouseProvider>(context, listen: false).fetchInitialData();
        Provider.of<HouseProvider>(
          context,
          listen: false,
        ).fetchMyHouses(user.id!);
        Provider.of<ViewingAppointmentProvider>(
          context,
          listen: false,
        ).fetchAppointments(user.id!, user.role);
        Provider.of<ViewingAppointmentProvider>(
          context,
          listen: false,
        ).refreshBadgeCounts(user.id!);
        Provider.of<WishlistProvider>(context, listen: false).fetch(user.id!);
        final notif = Provider.of<NotificationProvider>(context, listen: false);
        notif.fetch(user.id!);
        notif.startPolling(user.id!);
        final chat = Provider.of<ChatProvider>(context, listen: false);
        notif.attachStatusRealtime(chat.statusEvents);
        notif.attachNotificationRealtime(chat.notificationEvents);
        chat.fetchConversations(user.id!);
        chat.connect(user.id!);

        // Wire FCM to NotificationProvider for foreground messages + tap routing.
        // PermissionService exposes the FcmService that was built at app startup.
        // Pass the uploader so a post-login analytics flush fires immediately.
        //
        // All context reads happen BEFORE the first await to avoid
        // use_build_context_synchronously lint across async gaps.
        PermissionService? permService;
        GoRouter? router;
        PermissionAnalyticsUploader? uploader;
        try {
          permService = Provider.of<PermissionService>(context, listen: false);
          router = GoRouter.of(context);
          uploader = Provider.of<PermissionAnalyticsUploader>(
            context,
            listen: false,
          );
        } catch (_) {
          // PermissionService or GoRouter not yet in context — non-fatal.
        }

        if (permService != null && router != null) {
          notif.attachFcm(permService.fcm, router, uploader: uploader);

          // Wire user context into FcmService for token-refresh re-registration.
          // getInstallId is async — context is NOT used after this point.
          final userId = user.id?.toString() ?? '';
          if (userId.isNotEmpty) {
            try {
              final installId = await permService.getInstallId();
              permService.fcm.attachUserContext(
                userId: userId,
                installId: installId,
              );
            } catch (_) {
              // Non-fatal — token refresh re-registration won't fire.
            }
          }
        }

        // Trigger notification priming if appropriate for this user + role.
        _maybePresentNotificationPriming(context, user);
      });
    }

    // Admin role được redirect sang /admin trước khi vào đây. Default → GuestShell.
    return _NotificationPrimingGate(
      child: GuestShell(
        key: ValueKey('user-${user.id}-tab-${widget.initialTab}'),
        initialTab: widget.initialTab,
      ),
    );
  }

  /// Fire-and-forget priming check. Runs after first login per session.
  /// The once-per-session guard is [_hydratedAfterLogin] (already set to true).
  Future<void> _maybePresentNotificationPriming(
    BuildContext context,
    dynamic user,
  ) async {
    if (!mounted) return;
    try {
      final service = Provider.of<PermissionService>(context, listen: false);
      final userId = user.id?.toString() ?? '';
      if (userId.isEmpty) return;

      final roleStr = user.role as String? ?? 'guest';
      final role = _parseRole(roleStr);

      final shouldShow = await service.shouldShowNotificationPriming(
        userId,
        role,
      );
      if (!shouldShow) return;
      if (!mounted) return;

      final outcome = await PrimingPresenter.presentNotification(context, role);

      if (outcome == PrimingOutcome.accept) {
        await service.grantNotification(
          userId: userId,
          role: role,
          useProvisionalIos: true,
        );
      } else {
        await service.deferNotification(userId, role);
      }
    } catch (_) {
      // Non-fatal — priming will retry on next eligible session.
    }
  }

  static UserRole _parseRole(String role) {
    switch (role) {
      case 'host':
        return UserRole.host;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.guest;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationPrimingGate — wraps home screen; no-op gate today,
// reserved for future in-session re-priming triggers (e.g. app resume).
// ─────────────────────────────────────────────────────────────────────────────

/// Transparent wrapper around [child] that can intercept post-frame events
/// for notification priming without modifying the child widget.
///
/// Currently delegates all priming logic to [_RootGateState._maybePresentNotificationPriming]
/// which runs once per session in the post-login post-frame callback.
/// This widget is kept as the recommended injection point for Phase 5
/// (platform-specific edge cases: iOS provisional, app resume checks).
class _NotificationPrimingGate extends StatelessWidget {
  const _NotificationPrimingGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Link `/sale/<rác>` — id không phân giải được.
///
/// Người dùng dán nhầm link hoặc link bị cắt khi chuyển tiếp qua Zalo là
/// chuyện thường; ném ra lỗi ở đây thì cả app trắng màn.
class _KhongTimThay extends StatelessWidget {
  const _KhongTimThay();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text(AppLocalizations.of(context).brokerNotFound)),
  );
}

/// Shown to JP-region users who navigate to a VN-only route.
///
/// Route: /not-available
class _NotAvailableScreen extends StatelessWidget {
  const _NotAvailableScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 64,
                  color: HD.inkMuted,
                ),
                SizedBox(height: 24),
                Text(
                  'この機能はご利用いただけません',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: HD.ink,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'この機能は日本マーケットではご利用いただけません。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: HD.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
