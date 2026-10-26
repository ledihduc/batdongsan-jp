import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/pricing_rule_model.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/homestay/providers/pricing_rule_provider.dart';
import 'package:house_booking/features/host/homestay/screens/pricing_rule_form_screen.dart';

class PricingRulesListScreen extends StatefulWidget {
  const PricingRulesListScreen({super.key, this.roomId});

  final int? roomId;

  @override
  State<PricingRulesListScreen> createState() => _PricingRulesListScreenState();
}

class _PricingRulesListScreenState extends State<PricingRulesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PricingRuleProvider>().fetch(roomId: widget.roomId);
    });
  }

  String _ruleLabel(String t) {
    switch (t) {
      case 'base':
        return 'CƠ BẢN';
      case 'weekend':
        return 'CUỐI TUẦN';
      case 'holiday':
        return 'LỄ TẾT';
      case 'manual':
        return 'TUỲ CHỈNH';
      default:
        return t.toUpperCase();
    }
  }

  Color _ruleColor(String t) {
    switch (t) {
      case 'base':
        return HD.inkMuted;
      case 'weekend':
        return HD.warning;
      case 'holiday':
        return HD.accent;
      case 'manual':
        return HD.ink;
      default:
        return HD.inkMuted;
    }
  }

  String _formatPrice(double v) {
    if (v >= 1_000_000) {
      final m = v / 1_000_000;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}M';
    }
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        title: 'Quy tắc giá',
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: HD.ink,
        foregroundColor: HD.paperRaised,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => PricingRuleFormScreen(roomId: widget.roomId),
            ),
          );
          if (created == true && mounted) {
            await context.read<PricingRuleProvider>().fetch(roomId: widget.roomId);
          }
        },
        label: const Text('Thêm'),
        icon: const Icon(Icons.add),
      ),
      body: Consumer<PricingRuleProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading && prov.rules.isEmpty) {
            return const Center(child: DsRowSkeleton());
          }
          if (prov.error != null && prov.rules.isEmpty) {
            return DsErrorState(
              message: prov.error!,
              onRetry: () => context.read<PricingRuleProvider>().fetch(roomId: widget.roomId),
            );
          }
          if (prov.rules.isEmpty) {
            return const DsEmptyState(
              icon: Icons.price_change_outlined,
              title: 'Chưa có quy tắc giá',
              subtitle: 'Thêm quy tắc để bắt đầu.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: HD.s8),
            itemCount: prov.rules.length,
            separatorBuilder: (_, __) => const HDHairline(indent: HD.s20),
            itemBuilder: (context, i) => _ruleTile(prov.rules[i], prov),
          );
        },
      ),
    );
  }

  Widget _ruleTile(PricingRuleModel r, PricingRuleProvider prov) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s20, vertical: HD.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: _ruleColor(r.ruleType)),
            ),
            child: Text(_ruleLabel(r.ruleType),
                style: HD.eyebrow(color: _ruleColor(r.ruleType))),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_formatPrice(r.pricePerNight)} VND / đêm',
                    style: HD.bodyBold()),
                const SizedBox(height: 2),
                Text('${r.startDate} → ${r.endDate}', style: HD.caption()),
                if (r.holidayName != null)
                  Text(r.holidayName!, style: HD.caption()),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: HD.inkMuted),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Xoá quy tắc?'),
                  content: const Text('Hành động không thể hoàn tác.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Xoá'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await prov.delete(r.id);
            },
          ),
        ],
      ),
    );
  }
}
