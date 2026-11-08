import '../../utils/json_parse.dart';
/// In-app notification: [type] selects behavior; human text lives in [payload].
class AppNotification {
  final int id;
  final int userId;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.payload,
    required this.isRead,
    this.createdAt,
  });

  /// Falls back to a type-based label when `payload.title` is missing.
  String get title {
    final t = payload['title']?.toString();
    if (t != null && t.isNotEmpty) return t;
    return _defaultTitleForType(type);
  }

  String get body {
    final m = payload['message']?.toString();
    if (m != null && m.isNotEmpty) return m;
    return payload['body']?.toString() ?? '';
  }

  AppNotification copyWith({
    int? id,
    int? userId,
    String? type,
    Map<String, dynamic>? payload,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};

    DateTime? created;
    final ca = json['created_at'];
    if (ca is String) {
      created = DateTime.tryParse(ca);
    }

    return AppNotification(
      id: _intId(json['id']),
      userId: _intId(json['user_id']),
      type: json['type']?.toString() ?? '',
      payload: payload,
      isRead: asBool(json['is_read']) || json['is_read'] == 1,
      createdAt: created,
    );
  }

  static int _intId(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String _defaultTitleForType(String type) {
    switch (type) {
      case 'program_assigned':
        return 'Program';
      case 'workout_logged':
        return 'Workout';
      case 'new_pr':
        return 'Personal record';
      default:
        return 'Notification';
    }
  }
}
