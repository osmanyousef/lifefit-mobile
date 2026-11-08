import '../../utils/json_parse.dart';
/// One row from Laravel paginated `GET /api/client/measurements` → `data[]`.
class BodyMeasurement {
  final int id;
  final int clientId;
  final DateTime? date;
  final double? weightKg;
  final double? bodyFatPct;
  final double? muscleMassKg;
  final double? waistCm;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BodyMeasurement({
    required this.id,
    required this.clientId,
    this.date,
    this.weightKg,
    this.bodyFatPct,
    this.muscleMassKg,
    this.waistCm,
    this.createdAt,
    this.updatedAt,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      id: asInt(json['id']) ?? 0,
      clientId: asInt(json['client_id']) ?? 0,
      date: _parseDate(json['date']),
      weightKg: _toDouble(json['weight_kg']),
      bodyFatPct: _toDouble(json['body_fat_pct']),
      muscleMassKg: _toDouble(json['muscle_mass_kg']),
      waistCm: _toDouble(json['waist_cm']),
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
}
