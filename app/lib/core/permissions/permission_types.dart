// Core permission enums and data classes.
// No UI imports — pure Dart logic consumed by PermissionService and Phase 3 widgets.
import 'dart:convert';

/// Roles that affect notification priming copy (AC-N8 role-upgrade detection).
enum UserRole { guest, host, admin }

/// All distinct contexts where camera permission is requested (AC-C2).
/// Each context gets its own priming state so priming fires once per context.
enum CameraContext {
  cccdUpload,
  postHousePhoto,
  contractPhoto,
  contractTerminatePhoto,
  profileAvatar,
  reportErrorPhoto,
}

/// Outcome events emitted at each step of the priming + OS grant flow.
enum PrimingOutcome {
  /// Priming sheet was displayed to the user.
  shown,

  /// User tapped the primary "accept" button — OS dialog will be triggered.
  accept,

  /// User tapped "Để sau" — no OS dialog, 7-day cooldown starts.
  defer,

  /// OS returned granted (Android / macOS / web).
  osGrant,

  /// OS returned denied (recoverable with soft re-ask after 30 days).
  osDeny,

  /// OS returned permanently denied (iOS / Android "Don't ask again").
  osPermDeny,

  /// iOS provisional grant — notifications delivered quietly.
  osProvisional,

  /// iOS user upgraded provisional → full in system Settings.
  osProvisionalUpgrade,

  /// User was directed to Settings via deep-link (AC-N4 / AC-C3).
  settingsOpened,

  /// Skipped FCM init because GMS is unavailable (AC-N9).
  fcmUnavailableGmsMissing,
}

/// Which permission type a [PrimingState] or [PermissionEvent] belongs to.
enum PermissionKind { notification, camera }

// ─── PrimingState ────────────────────────────────────────────────────────────

/// Persisted cooldown state for one `(userId, kind[, subContext])` tuple.
/// JSON-serialisable for [flutter_secure_storage] (AC-M3 / M3 storage rule).
class PrimingState {
  const PrimingState({
    this.lastShownAt,
    this.lastDeferAt,
    this.lastDenyAt,
    this.lastShownForRole,
    this.osGranted = false,
    this.osPermanentlyDenied = false,
    this.osProvisional = false,
  });

  /// Wall-clock time the priming sheet was last shown.
  final DateTime? lastShownAt;

  /// Wall-clock time the user last tapped "Để sau" (defer).
  final DateTime? lastDeferAt;

  /// Wall-clock time the OS dialog returned denied.
  final DateTime? lastDenyAt;

  /// Role that was active when priming was last shown (AC-N8 role-upgrade).
  final UserRole? lastShownForRole;

  /// True if OS previously returned granted (any level).
  final bool osGranted;

  /// True if OS permanently denied (iOS / "Don't ask again" Android).
  final bool osPermanentlyDenied;

  /// True if iOS provisional grant is in effect.
  final bool osProvisional;

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'lastShownAt': lastShownAt?.toIso8601String(),
        'lastDeferAt': lastDeferAt?.toIso8601String(),
        'lastDenyAt': lastDenyAt?.toIso8601String(),
        'lastShownForRole': lastShownForRole?.name,
        'osGranted': osGranted,
        'osPermanentlyDenied': osPermanentlyDenied,
        'osProvisional': osProvisional,
      };

  factory PrimingState.fromJson(Map<String, dynamic> json) => PrimingState(
        lastShownAt: _parseDate(json['lastShownAt']),
        lastDeferAt: _parseDate(json['lastDeferAt']),
        lastDenyAt: _parseDate(json['lastDenyAt']),
        lastShownForRole: _parseRole(json['lastShownForRole']),
        osGranted: (json['osGranted'] as bool?) ?? false,
        osPermanentlyDenied: (json['osPermanentlyDenied'] as bool?) ?? false,
        osProvisional: (json['osProvisional'] as bool?) ?? false,
      );

  /// Decode from the raw JSON string stored in secure storage.
  factory PrimingState.fromJsonString(String raw) =>
      PrimingState.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  /// Returns an empty (first-time) state — used as default when no key found.
  factory PrimingState.empty() => const PrimingState();

  PrimingState copyWith({
    DateTime? lastShownAt,
    DateTime? lastDeferAt,
    DateTime? lastDenyAt,
    UserRole? lastShownForRole,
    bool? osGranted,
    bool? osPermanentlyDenied,
    bool? osProvisional,
    // Pass explicit null sentinel via wrapper when clearing a nullable field.
    bool clearLastShownAt = false,
    bool clearLastDeferAt = false,
    bool clearLastDenyAt = false,
    bool clearLastShownForRole = false,
  }) =>
      PrimingState(
        lastShownAt:
            clearLastShownAt ? null : (lastShownAt ?? this.lastShownAt),
        lastDeferAt:
            clearLastDeferAt ? null : (lastDeferAt ?? this.lastDeferAt),
        lastDenyAt: clearLastDenyAt ? null : (lastDenyAt ?? this.lastDenyAt),
        lastShownForRole: clearLastShownForRole
            ? null
            : (lastShownForRole ?? this.lastShownForRole),
        osGranted: osGranted ?? this.osGranted,
        osPermanentlyDenied: osPermanentlyDenied ?? this.osPermanentlyDenied,
        osProvisional: osProvisional ?? this.osProvisional,
      );

  // ── Private helpers ────────────────────────────────────────────────────────

  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  static UserRole? _parseRole(dynamic v) {
    if (v == null) return null;
    try {
      return UserRole.values.byName(v as String);
    } catch (_) {
      return null;
    }
  }
}

// ─── PermissionEvent ─────────────────────────────────────────────────────────

/// Lightweight analytics event captured locally, batched to BE by Phase 6.
/// Payload contains NO PII (AC-M3 revised): outcome + kind + role + ctx + platform + ts.
class PermissionEvent {
  const PermissionEvent({
    required this.outcome,
    required this.kind,
    required this.ts,
    required this.platform,
    this.role,
    this.context,
  });

  final PrimingOutcome outcome;
  final PermissionKind kind;

  /// Role active when the event fired (null for camera events without a role).
  final UserRole? role;

  /// [CameraContext.name] for camera events; null for notification events.
  final String? context;

  /// 'ios' | 'android' | 'web' | 'macos' | 'windows' | 'linux'
  final String platform;

  final DateTime ts;

  Map<String, dynamic> toJson() => {
        'outcome': outcome.name,
        'kind': kind.name,
        'role': role?.name,
        'context': context,
        'platform': platform,
        'ts': ts.toIso8601String(),
      };

  factory PermissionEvent.fromJson(Map<String, dynamic> json) =>
      PermissionEvent(
        outcome: PrimingOutcome.values.byName(json['outcome'] as String),
        kind: PermissionKind.values.byName(json['kind'] as String),
        role: json['role'] == null
            ? null
            : UserRole.values.byName(json['role'] as String),
        context: json['context'] as String?,
        platform: json['platform'] as String,
        ts: DateTime.parse(json['ts'] as String),
      );
}
