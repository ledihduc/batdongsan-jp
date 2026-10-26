import 'package:flutter/material.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/tools_service.dart';

/// So sánh nhiều BĐS cạnh nhau — gọi backend /api/tools/compare.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, required this.houseIds});

  final List<int> houseIds;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _service = ToolsService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _houses = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _service.compareHouses(widget.houseIds);
      if (mounted) {
        setState(() {
          _houses = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không tải được: $e';
          _loading = false;
        });
      }
    }
  }

  static String _fmtVnd(num v) {
    final s = v.round().abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '$buf đ';
  }

  static String _legal(String? code) {
    switch (code) {
      case 'red_book':
        return 'Sổ đỏ';
      case 'pink_book':
        return 'Sổ hồng';
      case 'sale_contract':
        return 'HĐ mua bán';
      case 'pending':
        return 'Chưa sổ';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(title: l.compareTitle),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _houses.isEmpty
          ? Center(child: Text(l.compareEmpty))
          : _buildTable(),
    );
  }

  Widget _buildTable() {
    final l = AppLocalizations.of(context);
    final rows = <_Attr>[
      _Attr(l.compareLabelPrice, (h) => _fmtVnd((h['price'] as num?) ?? 0)),
      _Attr(
        l.compareLabelArea,
        (h) => '${((h['area'] as num?) ?? 0).toStringAsFixed(0)} m²',
      ),
      _Attr(l.compareLabelPricePerSqm, (h) {
        final p = (h['price'] as num?) ?? 0;
        final a = (h['area'] as num?) ?? 0;
        return a > 0 ? _fmtVnd(p / a) : '—';
      }),
      _Attr(l.compareLabelLegal, (h) => _legal(h['legal_status'] as String?)),
      _Attr(
        l.compareLabelBedrooms,
        (h) => '${(h['bedrooms'] as num?)?.toInt() ?? 0}',
      ),
      _Attr(
        l.compareLabelBathrooms,
        (h) => '${(h['bathrooms'] as num?)?.toInt() ?? 0}',
      ),
      _Attr(
        l.compareLabelLocation,
        (h) =>
            '${h['district'] ?? ''}${h['district'] != null ? ', ' : ''}${h['city'] ?? ''}',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(HD.paperSunken),
          columns: [
            DataColumn(label: Text(l.compareCriteria)),
            for (final h in _houses)
              DataColumn(
                label: SizedBox(
                  width: 130,
                  child: Text(
                    (h['title'] as String?) ?? l.compareHouseFallback,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
          rows: [
            for (final attr in rows)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      attr.label,
                      style: const TextStyle(
                        color: HD.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final h in _houses)
                    DataCell(SizedBox(width: 130, child: Text(attr.value(h)))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Attr {
  const _Attr(this.label, this.value);
  final String label;
  final String Function(Map<String, dynamic>) value;
}
