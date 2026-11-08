import '../../utils/json_parse.dart';
// ─── Nested service info ──────────────────────────────────────────────────────

/// Nested `service` object inside a client subscription record.
class SubscriptionServiceInfo {
  final int id;
  final String title;

  /// 'monthly' | 'quarterly' | 'yearly'
  final String type;

  final double price;
  final String? expertName;

  const SubscriptionServiceInfo({
    required this.id,
    required this.title,
    required this.type,
    required this.price,
    this.expertName,
  });

  factory SubscriptionServiceInfo.fromJson(Map<String, dynamic> json) =>
      SubscriptionServiceInfo(
        id: asInt(json['id']) ?? 0,
        title: (json['title'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        price: asDouble(json['price']) ?? 0,
        expertName: asString(json['expert_name']),
      );
}

// ─── MySubscription ───────────────────────────────────────────────────────────
// Maps the payload returned by GET /api/client/my-subscriptions

class MySubscription {
  final int id;

  /// 'active' | 'expired' | 'cancelled'
  final String status;

  final DateTime? renewalDate;
  final SubscriptionServiceInfo? service;

  const MySubscription({
    required this.id,
    required this.status,
    this.renewalDate,
    this.service,
  });

  factory MySubscription.fromJson(Map<String, dynamic> json) => MySubscription(
        id: asInt(json['id']) ?? 0,
        status: (json['status'] ?? '').toString(),
        renewalDate: json['renewal_date'] != null
            ? DateTime.tryParse(json['renewal_date'].toString())
            : null,
        service: json['service'] is Map
            ? SubscriptionServiceInfo.fromJson(
                Map<String, dynamic>.from(json['service'] as Map))
            : null,
      );
}
