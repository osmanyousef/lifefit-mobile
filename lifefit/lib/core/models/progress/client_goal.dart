import '../../utils/json_parse.dart';
/// One row from `GET /api/client/goals` → `data[]`.
class ClientGoal {
  final int id;
  final int clientId;
  final double? targetWeight;
  final double? targetBodyFat;
  final DateTime? startDate;
  final DateTime? targetDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClientGoal({
    required this.id,
    required this.clientId,
    this.targetWeight,
    this.targetBodyFat,
    this.startDate,
    this.targetDate,
    this.createdAt,
    this.updatedAt,
  });

  factory ClientGoal.fromJson(Map<String, dynamic> json) {
    return ClientGoal(
      id: asInt(json['id']) ?? 0,
      clientId: asInt(json['client_id']) ?? 0,
      targetWeight: _toDouble(json['target_weight']),
      targetBodyFat: _toDouble(json['target_body_fat']),
      startDate: _parseDate(json['start_date']),
      targetDate: _parseDate(json['target_date']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  /// Body for `PUT /api/client/goals/{id}` (partial updates allowed by backend).
  Map<String, dynamic> toUpdateBody({
    double? targetWeight,
    double? targetBodyFat,
    DateTime? startDate,
    DateTime? targetDate,
  }) {
    return {
      if (targetWeight != null) 'target_weight': targetWeight,
      if (targetBodyFat != null) 'target_body_fat': targetBodyFat,
      if (startDate != null) 'start_date': _dateOnly(startDate),
      if (targetDate != null) 'target_date': _dateOnly(targetDate),
    };
  }

  static String _dateOnly(DateTime d) => formatDateForApi(d);

  /// `Y-m-d` for Laravel `date` rule.
  static String formatDateForApi(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
