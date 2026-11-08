import '../../utils/json_parse.dart';
/// Nested exercise payload from `GET /api/client/personal-records`.
class PersonalRecordExercise {
  final int id;
  final String name;
  final String? muscles;

  const PersonalRecordExercise({
    required this.id,
    required this.name,
    this.muscles,
  });

  factory PersonalRecordExercise.fromJson(Map<String, dynamic> json) {
    return PersonalRecordExercise(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      muscles: json['muscles']?.toString(),
    );
  }
}

/// One row from `data[]` in personal records API.
class PersonalRecord {
  final int id;
  final int clientId;
  final int exerciseId;
  final double? weight;
  final int? reps;
  final DateTime? recordedAt;
  final double? estimatedOneRm;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? sourceLogId;
  final PersonalRecordExercise? exercise;

  const PersonalRecord({
    required this.id,
    required this.clientId,
    required this.exerciseId,
    this.weight,
    this.reps,
    this.recordedAt,
    this.estimatedOneRm,
    this.createdAt,
    this.updatedAt,
    this.sourceLogId,
    this.exercise,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    final ex = json['exercise'];
    return PersonalRecord(
      id: asInt(json['id']) ?? 0,
      clientId: asInt(json['client_id']) ?? 0,
      exerciseId: asInt(json['exercise_id']) ?? 0,
      weight: _toDouble(json['weight']),
      reps: asInt(json['reps']),
      recordedAt: _parseDate(json['recorded_at']),
      estimatedOneRm: _toDouble(json['estimated_1rm']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      sourceLogId: asInt(json['source_log_id']),
      exercise: ex is Map<String, dynamic>
          ? PersonalRecordExercise.fromJson(ex)
          : null,
    );
  }

  /// Arabic fallback when the nested `exercise` relation was not eager-loaded.
  String get displayExerciseName => exercise?.name ?? 'تمرين #$exerciseId';

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
