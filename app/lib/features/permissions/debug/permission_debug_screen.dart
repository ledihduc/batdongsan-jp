// Debug-only screen for permission priming QA (AC-V4).
// MUST NOT be reachable in release builds — route is gated by kDebugMode in app_router.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';

import 'package:house_booking/core/permissions/permission_service.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/helpers/priming_presenter.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Debug screen — exposes priming state, reset tools, and force-show buttons.
///
/// Only reachable via `/permission-debug` route which is conditionally added
/// when [kDebugMode] is true (app_router.dart). In release builds, this class
/// is unreachable and may be tree-shaken.
class PermissionDebugScreen extends StatefulWidget {
  const PermissionDebugScreen({super.key});

  @override
  State<PermissionDebugScreen> createState() => _PermissionDebugScreenState();
}

class _PermissionDebugScreenState extends State<PermissionDebugScreen> {
  Map<String, dynamic> _stateSnapshot = {};
  bool _loading = false;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    // Guard: only proceed in debug mode.
    assert(kDebugMode, 'PermissionDebugScreen must only be used in debug builds');
    _reload();
  }

  String _userId(BuildContext ctx) {
    final user = Provider.of<AuthProvider>(ctx, listen: false).currentUser;
    return user?.id?.toString() ?? 'anonymous';
  }

  PermissionService _service(BuildContext ctx) =>
      Provider.of<PermissionService>(ctx, listen: false);

  Future<void> _reload() async {
    final service = _service(context);
    final userId = _userId(context);

    setState(() => _loading = true);

    final notifState =
        await service.getFcmToken(); // proxy to test service availability

    // Collect raw state from storage via PermissionService accessors.
    // We read via the storage directly through the service's exposed debug API.
    // PermissionStorage is internal — we surface key fields as a flat map.
    final snapshot = <String, dynamic>{
      'userId': userId,
      'installId': await service.getInstallId(),
      'fcmToken': notifState != null ? '***${notifState.substring(notifState.length > 8 ? notifState.length - 8 : 0)}' : null,
      'cameraContexts': {
        for (final ctx in CameraContext.values) ctx.name: '(see storage)',
      },
      'note': 'Use Reset / SkipDays buttons to manipulate cooldowns',
    };

    if (mounted) {
      setState(() {
        _stateSnapshot = snapshot;
        _loading = false;
      });
    }
  }

  Future<void> _resetAll() async {
    // PermissionStorage is not directly accessible here — we use the debug helper
    // exposed via PermissionService.
    // We resolve PermissionStorage from the context indirectly: PermissionService
    // internally owns it. For debug screen we expose resetAll via a dedicated helper
    // injected through the service locator pattern.
    //
    // Since PermissionService does not expose resetAll directly, we use the storage
    // that was injected at construction time. This requires a small accessor on
    // PermissionService (see note in phase-04 spec: "adding a small accessor is OK").
    // If the accessor is absent, we degrade with a message.
    final service = _service(context);
    await service.debugResetAll();
    setState(() => _statusMsg = 'Reset all priming state done.');
    await _reload();
  }

  Future<void> _skipDays(int days) async {
    final userId = _userId(context);
    final service = _service(context);
    await service.debugSkipDays(userId, days);
    setState(() => _statusMsg = 'Skipped $days days for user $userId.');
    await _reload();
  }

  Future<void> _forceNotificationSheet(UserRole role) async {
    if (!mounted) return;
    final outcome = await PrimingPresenter.presentNotification(context, role);
    setState(() => _statusMsg = 'Notification sheet outcome: ${outcome.name}');
  }

  Future<void> _forceCameraSheet(CameraContext ctx) async {
    if (!mounted) return;
    final outcome = await PrimingPresenter.presentCamera(context, ctx);
    setState(() => _statusMsg = 'Camera sheet outcome: ${outcome.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Debug'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_statusMsg.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_statusMsg,
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                ],

                // State snapshot
                _sectionTitle('State Snapshot'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _stateSnapshot.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),

                // Cooldown controls
                _sectionTitle('Cooldown Controls'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                      label: const Text('Reset All'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white),
                      onPressed: _resetAll,
                    ),
                    OutlinedButton(
                      onPressed: () => _skipDays(7),
                      child: const Text('Skip 7 days'),
                    ),
                    OutlinedButton(
                      onPressed: () => _skipDays(30),
                      child: const Text('Skip 30 days'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Force-show notification sheets
                _sectionTitle('Force Notification Sheet'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in UserRole.values)
                      OutlinedButton(
                        onPressed: () => _forceNotificationSheet(role),
                        child: Text('role: ${role.name}'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Force-show camera sheets
                _sectionTitle('Force Camera Sheet'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ctx in CameraContext.values)
                      OutlinedButton(
                        onPressed: () => _forceCameraSheet(ctx),
                        child: Text(ctx.name),
                      ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: HD.inkSoft,
          ),
        ),
      );
}
