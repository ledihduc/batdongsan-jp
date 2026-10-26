import 'package:flutter/material.dart';

/// 6 khối chức năng dùng làm nhãn (category) cho bài đăng Cộng đồng.
/// `key` khớp CHÍNH XÁC với backend (helpers.SOCIAL_CATEGORIES) và slug
/// construction (design/build/interior). KHÔNG đổi key nếu không đổi cả backend.
class CommunityCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const CommunityCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Danh mục cố định — hardcode để tránh round-trip; đồng bộ với backend.
const List<CommunityCategory> kCommunityCategories = [
  CommunityCategory(
    key: 'rent',
    label: 'Thuê nhà',
    icon: Icons.home_outlined,
    color: Color(0xFF2E7D6B),
  ),
  CommunityCategory(
    key: 'lease',
    label: 'Cho thuê',
    icon: Icons.vpn_key_outlined,
    color: Color(0xFFB5651D),
  ),
  CommunityCategory(
    key: 'industrial',
    label: 'BĐS công nghiệp',
    icon: Icons.factory_outlined,
    color: Color(0xFF546E7A),
  ),
  CommunityCategory(
    key: 'design',
    label: 'Thiết kế',
    icon: Icons.architecture_outlined,
    color: Color(0xFF3F51B5),
  ),
  CommunityCategory(
    key: 'build',
    label: 'Xây dựng',
    icon: Icons.construction_outlined,
    color: Color(0xFFE65100),
  ),
  CommunityCategory(
    key: 'interior',
    label: 'Nội thất',
    icon: Icons.chair_outlined,
    color: Color(0xFF8D6E63),
  ),
];

/// Tra cứu category theo key; fallback về 'Cho thuê' (khớp backend) nếu lạ.
CommunityCategory communityCategoryOf(String? key) {
  for (final c in kCommunityCategories) {
    if (c.key == key) return c;
  }
  return kCommunityCategories[1]; // lease
}
