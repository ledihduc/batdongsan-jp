import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/permissions/role_guard.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Screen: Transfer contract to a new vacant room (C7).
///
/// Step 1 — pick building from BuildingProvider.
/// Step 2 — pick vacant room from that building (fetched via RoomProvider).
/// Includes confirmation dialog (H4) before mutation.
class ContractTransferRoomScreen extends StatefulWidget {
  final int contractId;

  const ContractTransferRoomScreen({super.key, required this.contractId});

  @override
  State<ContractTransferRoomScreen> createState() =>
      _ContractTransferRoomScreenState();
}

class _ContractTransferRoomScreenState
    extends State<ContractTransferRoomScreen> {
  BuildingModel? _selectedBuilding;
  RoomModel? _selectedRoom;
  bool _loadingRooms = false;
  bool _saving = false;
  List<RoomModel> _vacantRooms = [];
  String? _roomLoadError;

  Future<void> _onBuildingSelected(BuildingModel building) async {
    setState(() {
      _selectedBuilding = building;
      _selectedRoom = null;
      _vacantRooms = [];
      _loadingRooms = true;
      _roomLoadError = null;
    });

    try {
      final roomProvider = context.read<RoomProvider>();
      await roomProvider.fetchRooms(building.id);
      if (!mounted) return;
      final vacant = roomProvider.rooms
          .where((r) => r.status == 'vacant')
          .toList();
      setState(() {
        _vacantRooms = vacant;
        _loadingRooms = false;
      });
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() {
          _roomLoadError = l.hContractXferLoadRoomsError;
          _loadingRooms = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (!RoleGuard.enforceHost(context, action: l.hContractXferActionTransfer)) {
      return;
    }
    if (_selectedRoom == null) return;

    final roomName = _selectedRoom!.code;
    final ok = await showDsConfirm(
      context: context,
      eyebrow: l.hContractXferTransferRoom,
      title: l.hContractXferConfirmTitle,
      message: l.hContractXferConfirmMessage(roomName),
      confirmLabel: l.hContractXferTransferRoom,
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    final provider = context.read<ContractProvider>();
    final result =
        await provider.transferRoom(widget.contractId, _selectedRoom!.id);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hContractXferSuccess(roomName))),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? l.hContractXferFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final buildings = context.watch<BuildingProvider>().buildings;

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hContractXferTransferRoom,
        eyebrow: l.hContractXferContractEyebrow,
      ),
      body: Padding(
        padding: const EdgeInsets.all(HD.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.hContractXferIntro,
              style: HD.body(color: HD.inkSoft),
            ),
            const SizedBox(height: HD.s16),

            // Step 1: building dropdown
            _DsDropdownField<BuildingModel>(
              label: l.hContractXferBuildingLabel,
              value: _selectedBuilding,
              hint: buildings.isEmpty
                  ? l.hContractXferNoBuildings
                  : l.hContractXferSelectBuilding,
              items: buildings
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.name, style: HD.body(color: HD.ink)),
                      ))
                  .toList(),
              onChanged: buildings.isEmpty
                  ? null
                  : (b) {
                      if (b != null) _onBuildingSelected(b);
                    },
            ),
            const SizedBox(height: HD.s16),

            // Step 2: room dropdown (shown after building selected)
            if (_selectedBuilding != null) ...[
              if (_loadingRooms)
                const Center(
                  child: CircularProgressIndicator(
                    color: HD.accent,
                    strokeWidth: 1.6,
                  ),
                )
              else if (_roomLoadError != null)
                Text(_roomLoadError!, style: HD.body(color: HD.negative))
              else if (_vacantRooms.isEmpty)
                Text(
                  l.hContractXferNoVacantRooms,
                  style: HD.body(color: HD.warning),
                )
              else
                _DsDropdownField<RoomModel>(
                  label: l.hContractXferVacantRoomLabel,
                  value: _selectedRoom,
                  hint: l.hContractXferSelectRoom,
                  items: _vacantRooms
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              l.hContractXferRoomOption(
                                r.code,
                                r.basePrice.toStringAsFixed(0),
                              ),
                              style: HD.body(color: HD.ink),
                            ),
                          ))
                      .toList(),
                  onChanged: (r) => setState(() => _selectedRoom = r),
                ),
            ],

            const SizedBox(height: HD.s24),
            DsButton(
              label: l.hContractXferTransferRoom,
              icon: Icons.swap_horiz,
              expand: true,
              isLoading: _saving,
              onPressed: (_saving || _selectedRoom == null) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Local helper — labeled dropdown matching DS field styling.
class _DsDropdownField<T> extends StatelessWidget {
  const _DsDropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: HD.eyebrow()),
        const SizedBox(height: HD.s4),
        Container(
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r8),
            border: Border.all(color: HD.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: HD.s12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: Text(hint, style: HD.body(color: HD.inkMuted)),
              items: items,
              onChanged: onChanged,
              dropdownColor: HD.paperRaised,
              icon: const Icon(Icons.keyboard_arrow_down, color: HD.inkMuted),
            ),
          ),
        ),
      ],
    );
  }
}
