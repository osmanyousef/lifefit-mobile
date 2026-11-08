import '../../utils/json_parse.dart';
// Model for a single service (monthly / quarterly / yearly) offered by an expert.
class ExpertServiceItem {
  final int id;
  final String title;
  final double price;
  final int maxParticipants;
  final int currentParticipants;

  const ExpertServiceItem({
    required this.id,
    required this.title,
    required this.price,
    required this.maxParticipants,
    required this.currentParticipants,
  });

  factory ExpertServiceItem.fromJson(Map<String, dynamic> json) =>
      ExpertServiceItem(
        id: asInt(json['id']) ?? 0,
        title: (json['title'] ?? '').toString(),
        price: asDouble(json['price']) ?? 0,
        maxParticipants: asInt(json['max_participants']) ?? 0,
        currentParticipants: asInt(json['current_participants']) ?? 0,
      );
}

// ─── ExpertModel ─────────────────────────────────────────────────────────────
// Maps the payload returned by GET /api/client/available-experts

class ExpertModel {
  final int id;
  final String name;
  final String email;

  /// 'trainer' | 'nutritionist'
  final String role;

  final String? avatarUrl;
  final String? bio;
  final List<String> specialties;
  final int yearsExperience;

  /// True when the authenticated client has an active subscription to this expert.
  final bool isSubscribed;

  /// Keyed by service_type: 'monthly', 'quarterly', 'yearly'.
  final Map<String, ExpertServiceItem> services;

  const ExpertModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.bio,
    required this.specialties,
    required this.yearsExperience,
    required this.isSubscribed,
    required this.services,
  });

  factory ExpertModel.fromJson(Map<String, dynamic> json) {
    // API may return `[]` (empty list) when no services exist — guard against it.
    final raw = json['services'];
    final Map<String, ExpertServiceItem> services;
    if (raw is Map<String, dynamic> && raw.isNotEmpty) {
      services = raw.map(
        (key, value) => MapEntry(
          key,
          ExpertServiceItem.fromJson(value as Map<String, dynamic>),
        ),
      );
    } else {
      services = {};
    }

    return ExpertModel(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      avatarUrl: asString(json['avatar_url']),
      bio: asString(json['bio']),
      specialties: (json['specialties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      yearsExperience: asInt(json['years_experience']) ?? 0,
      isSubscribed: asBool(json['is_subscribed']),
      services: services,
    );
  }

  /// Cheapest price across all available services. Null if no services.
  double? get lowestPrice {
    if (services.isEmpty) return null;
    return services.values.map((s) => s.price).reduce((a, b) => a < b ? a : b);
  }
}
