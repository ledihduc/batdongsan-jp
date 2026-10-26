/// Revenue source model — mirrors backend SourceResponse schema.
///
/// ALWAYS use [displayName] in UI lists; [name] is for internal/debug only
/// as it may contain the archive suffix "__archived_{id}".
class RevenueSourceModel {
  final int id;
  final int hostId;
  final String name;
  final String displayName;
  final String colorHex;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RevenueSourceModel({
    required this.id,
    required this.hostId,
    required this.name,
    required this.displayName,
    required this.colorHex,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RevenueSourceModel.fromJson(Map<String, dynamic> json) {
    return RevenueSourceModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      name: json['name'] as String? ?? '',
      // display_name is stripped of archive suffix by the backend (Pydantic)
      // Fall back to name if backend is pre-Phase-03 (defensive)
      displayName:
          json['display_name'] as String? ?? json['name'] as String? ?? '',
      colorHex: json['color_hex'] as String? ?? '#9E9E9E',
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'host_id': hostId,
    'name': name,
    'display_name': displayName,
    'color_hex': colorHex,
    'is_archived': isArchived,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
