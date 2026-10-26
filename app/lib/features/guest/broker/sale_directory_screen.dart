import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/host_public_api.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';

/// Danh bạ Sale dành cho Khách.
///
/// Sale đã được duyệt xuất hiện kể cả khi chưa đăng căn nào. Người dùng tìm
/// gần đúng theo tên hoặc nhập đúng email; backend không trả email ra client.
class SaleDirectoryScreen extends StatefulWidget {
  const SaleDirectoryScreen({super.key, this.api = const HostPublicApi()});

  final HostPublicApi api;

  @override
  State<SaleDirectoryScreen> createState() => _SaleDirectoryScreenState();
}

class _SaleDirectoryScreenState extends State<SaleDirectoryScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.sales(query: _search.text);
      if (!mounted || request != _request) return;
      setState(() => _items = page.items);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = 'Không tải được danh sách Sale. Vui lòng thử lại.',
      );
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _clear() {
    _search.clear();
    _load();
  }

  void _open(Map<String, dynamic> item) {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrokerProfileScreen(
          userId: id,
          name: item['name'] as String?,
          avatarPath: item['avatar_path'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(title: const Text('Tìm Sale')),
      body: Column(
        children: [
          _searchPanel(),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _searchPanel() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFFECEF), Color(0xFFFFF8F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border(bottom: BorderSide(color: HD.hairline)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tìm chuyên viên phù hợp', style: HD.bodyBold(size: 18)),
        const SizedBox(height: HD.s4),
        Text(
          'Tìm theo tên hoặc nhập đúng email Sale',
          style: HD.body(size: 13, color: HD.inkMuted),
        ),
        const SizedBox(height: HD.s12),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'Tên hoặc email, ví dụ sale@hotmail.com',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  )
                : IconButton(
                    tooltip: 'Xóa',
                    onPressed: _loading ? null : _clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _load(),
        ),
        const SizedBox(height: HD.s8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.manage_search_rounded),
            label: const Text('Tìm Sale'),
          ),
        ),
      ],
    ),
  );

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Message(
        icon: Icons.wifi_off_rounded,
        title: _error!,
        action: TextButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }
    if (_items.isEmpty) {
      return _Message(
        icon: Icons.person_search_rounded,
        title: _search.text.trim().isEmpty
            ? 'Chưa có Sale nào trong danh bạ'
            : 'Không tìm thấy Sale phù hợp',
        subtitle: _search.text.contains('@')
            ? 'Hãy kiểm tra lại email và nhập đầy đủ địa chỉ.'
            : 'Thử tên khác hoặc tìm bằng email Sale.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(HD.s16),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: HD.s12),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: HD.s4),
              child: Text(
                '${_items.length} Sale phù hợp',
                style: HD.bodyBold(size: 15),
              ),
            );
          }
          return _SaleCard(item: _items[index - 1], onTap: _open);
        },
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Chuyên viên Sale';
    final avatar = item['avatar_path'] as String?;
    final bio = (item['bio'] as String? ?? '').trim();
    final areas = (item['service_areas'] as List? ?? const [])
        .whereType<String>()
        .take(3)
        .toList();
    final rating = (item['rating'] as num?)?.toDouble();
    final listings = (item['listing_count'] as num?)?.toInt() ?? 0;
    final verified = item['verified'] == true;
    return Material(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      child: InkWell(
        onTap: () => onTap(item),
        borderRadius: BorderRadius.circular(HD.r12),
        child: Container(
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: HD.accentTint,
                backgroundImage: avatar != null && avatar.isNotEmpty
                    ? CachedNetworkImageProvider(_abs(avatar))
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: HD.bodyBold(size: 21, color: HD.accent),
                      )
                    : null,
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name, style: HD.bodyBold(size: 16)),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 17,
                            color: HD.positive,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bio.isEmpty ? 'Chuyên viên tư vấn bất động sản' : bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    ),
                    if (areas.isNotEmpty) ...[
                      const SizedBox(height: HD.s8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: areas
                            .map(
                              (area) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: HD.accentTint,
                                  borderRadius: BorderRadius.circular(HD.rPill),
                                ),
                                child: Text(
                                  area,
                                  style: HD.caption(color: HD.accent),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: HD.s8),
                    Row(
                      children: [
                        if (rating != null && rating > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFA000),
                            size: 16,
                          ),
                          Text(
                            ' ${rating.toStringAsFixed(1)}',
                            style: HD.caption(),
                          ),
                          const SizedBox(width: HD.s12),
                        ],
                        Icon(
                          Icons.home_work_outlined,
                          size: 15,
                          color: HD.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          listings == 0
                              ? 'Chưa có tin công khai'
                              : '$listings tin',
                          style: HD.caption(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(HD.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: HD.inkMuted),
          const SizedBox(height: HD.s12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: HD.bodyBold(size: 16),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: HD.s4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: HD.s8), action!],
        ],
      ),
    ),
  );
}

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
