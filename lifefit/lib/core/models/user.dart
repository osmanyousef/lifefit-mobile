/// User model from GET /api/user and login/register responses.
class User {
  final int id;
  final String email;
  final String name;
  /// 'client' | 'trainer' | 'nutritionist' | 'admin'
  final String role;

  final String? phone;
  final String? avatar;    // Relative storage path (avatars/...)
  final String? avatarUrl; // Full display URL from the API
  final String? bio;

  final DateTime? emailVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.avatar,
    this.avatarUrl,
    this.bio,
    this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isEmailVerified => emailVerifiedAt != null;

  /// Only [role] == `client` may use the client mobile app.
  bool get canUseClientApp => role == 'client';

  /// Prefer this in UI over [avatar].
  String? get displayAvatarUrl {
    final url = _normalizeAvatarUrl(avatarUrl);
    if (url != null) return url;
    final fallback = _normalizeAvatarUrl(avatar);
    if (fallback != null) return fallback;
    return null;
  }

  static String? _normalizeAvatarUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final embeddedHttpIndex = raw.lastIndexOf('http://');
    final embeddedHttpsIndex = raw.lastIndexOf('https://');
    final embeddedIndex = embeddedHttpsIndex > embeddedHttpIndex
        ? embeddedHttpsIndex
        : embeddedHttpIndex;

    if (embeddedIndex > 0) {
      return raw.substring(embeddedIndex);
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return null;
  }

  //copy with is used to create a new instance of the user with the updated values
  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? avatarUrl,
    DateTime? emailVerifiedAt,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.parse(json['email_verified_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'].toString())
          : null,
    );
  }
}
