import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/marketplace/providers/marketplace_provider.dart';

/// Phase 08 — review sync fields before pushing Room → House. Empty fields fall
/// back to defaults (room.base_price + "Building - Code" title).
class PublishRoomScreen extends StatefulWidget {
  const PublishRoomScreen({
    super.key,
    required this.roomId,
    required this.roomCode,
    required this.buildingName,
  });

  final int roomId;
  final String roomCode;
  final String buildingName;

  @override
  State<PublishRoomScreen> createState() => _PublishRoomScreenState();
}

class _PublishRoomScreenState extends State<PublishRoomScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _productType = 'boarding_house';
  bool _submitting = false;

  static const _types = ['boarding_house', 'homestay', 'apartment'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final priceText = _priceCtrl.text.replaceAll(',', '').trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    final prov = context.read<MarketplaceProvider>();
    final ok = await prov.publishRoom(
      widget.roomId,
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      price: price,
      productType: _productType,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    final l = AppLocalizations.of(context);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.hPublishSyncSuccess)),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.error ?? l.hPublishError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hPublishTitle,
      ),
      body: ListView(
        padding: const EdgeInsets.all(HD.s20),
        children: [
          Text(
            '${widget.buildingName} • ${widget.roomCode}',
            style: HD.masthead(),
          ),
          const SizedBox(height: HD.s24),
          Text(l.hPublishListingType, style: HD.eyebrow()),
          const SizedBox(height: HD.s8),
          Wrap(
            spacing: 6,
            children: [
              for (final t in _types)
                ChoiceChip(
                  label: Text(_labelFor(t)),
                  selected: _productType == t,
                  onSelected: (_) => setState(() => _productType = t),
                ),
            ],
          ),
          const SizedBox(height: HD.s24),
          Text(l.hPublishTitleLabel, style: HD.eyebrow()),
          const SizedBox(height: HD.s8),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: HD.paperRaised,
              border: const OutlineInputBorder(),
              hintText: '${widget.buildingName} - ${widget.roomCode}',
            ),
          ),
          const SizedBox(height: HD.s20),
          Text(l.hPublishDescLabel, style: HD.eyebrow()),
          const SizedBox(height: HD.s8),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              filled: true,
              fillColor: HD.paperRaised,
              border: const OutlineInputBorder(),
              hintText: l.hPublishDescHint,
            ),
          ),
          const SizedBox(height: HD.s20),
          Text(l.hPublishPriceLabel, style: HD.eyebrow()),
          const SizedBox(height: HD.s8),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: HD.paperRaised,
              border: const OutlineInputBorder(),
              hintText: l.hPublishPriceHint,
            ),
          ),
          const SizedBox(height: HD.s32),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: HD.ink,
              padding: const EdgeInsets.symmetric(vertical: HD.s16),
            ),
            child: Text(_submitting ? l.hPublishSubmitting : l.hPublishSubmit),
          ),
          const SizedBox(height: HD.s12),
          Text(
            l.hPublishHelp,
            style: HD.caption(),
          ),
        ],
      ),
    );
  }

  String _labelFor(String t) {
    final l = AppLocalizations.of(context);
    switch (t) {
      case 'boarding_house':
        return l.hPublishTypeBoardingHouse;
      case 'homestay':
        return l.hPublishTypeHomestay;
      case 'apartment':
      default:
        return l.hPublishTypeApartment;
    }
  }
}
