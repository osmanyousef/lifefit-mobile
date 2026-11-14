import '../../utils/workout_duration_utils.dart';

/// Laravel `workout_exercise` pivot: prescription for one exercise inside a workout.
class ExercisePivot {
  final int sets;
  final String reps;

  /// `reps` (count repetitions) or `time` (hold / run for a duration).
  final String? setType;
  final double? targetWeight;
  final String? intensityType;
  final int? targetPercentage;
  final int? targetDurationSeconds;
  final int? rpeTarget;
  final int? restSeconds;
  final String? tempo;
  final String? notes;
  final int? order;

  const ExercisePivot({
    required this.sets,
    required this.reps,
    this.setType,
    this.targetWeight,
    this.intensityType,
    this.targetPercentage,
    this.targetDurationSeconds,
    this.rpeTarget,
    this.restSeconds,
    this.tempo,
    this.notes,
    this.order,
  });

  factory ExercisePivot.fromJson(Map<String, dynamic> json) {
    return ExercisePivot(
      sets: _toInt(json['sets']) ?? 0,
      reps: (json['reps'] ?? '0').toString(),
      setType: json['set_type']?.toString(),
      targetWeight: _toDouble(json['target_weight']),
      intensityType: json['intensity_type']?.toString(),
      targetPercentage: _toInt(json['target_percentage']),
      targetDurationSeconds: _toInt(json['target_duration_seconds']),
      rpeTarget: _toInt(json['rpe_target']),
      restSeconds: _toInt(json['rest_seconds']),
      tempo: json['tempo']?.toString(),
      notes: json['notes']?.toString(),
      order: _toInt(json['order']),
    );
  }

  Map<String, dynamic> toJson() => {
        'sets': sets,
        'reps': reps,
        'set_type': setType,
        'target_weight': targetWeight,
        'intensity_type': intensityType,
        'target_percentage': targetPercentage,
        'target_duration_seconds': targetDurationSeconds,
        'rpe_target': rpeTarget,
        'rest_seconds': restSeconds,
        'tempo': tempo,
        'notes': notes,
        'order': order,
      };

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Defaults to `'weight'` when the API omits [intensityType].
  String get effectiveIntensityType {
    final type = intensityType?.trim().toLowerCase();
    if (type == null || type.isEmpty) return 'weight';
    return type;
  }

  bool get isWeightBased => effectiveIntensityType == 'weight';
  bool get isPercentageBased => effectiveIntensityType == 'percentage';
  bool get isRpeBased => effectiveIntensityType == 'rpe';
  bool get isTimeBased => effectiveIntensityType == 'time';

  /// Each set is measured by duration instead of reps — either the trainer
  /// picked set type "time" (e.g. a weighted plank) or the legacy "time"
  /// intensity type.
  bool get isDurationSet => setType?.trim().toLowerCase() == 'time' || isTimeBased;

  String get intensityTypeLabel {
    switch (effectiveIntensityType) {
      case 'percentage':
        return 'نسبة من 1RM';
      case 'rpe':
        return 'مستوى الجهد';
      case 'time':
        return 'المدة';
      default:
        return 'الوزن';
    }
  }

  String get targetIntensityText {
    switch (effectiveIntensityType) {
      case 'percentage':
        return targetPercentage != null ? '$targetPercentage%' : '—';
      case 'rpe':
        return rpeTarget != null ? 'RPE $rpeTarget' : '—';
      case 'time':
        return WorkoutDurationUtils.formatMinutesFromSeconds(
          targetDurationSeconds,
        );
      default:
        return formatWeight(targetWeight);
    }
  }

  static String formatWeight(double? weight) {
    if (weight == null || weight == 0) return 'بوزن الجسم';
    final fixed = weight % 1 == 0 ? 0 : 1;
    return '${weight.toStringAsFixed(fixed)} كجم';
  }
}
