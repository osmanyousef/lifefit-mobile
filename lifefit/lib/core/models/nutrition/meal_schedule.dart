import 'meal_detail.dart';
import '../../utils/json_parse.dart';

double _d(dynamic v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;

/// One meal slot in today's plan with targets and optional intake log values.
class MealSchedule {
  final int scheduleId;
  final String mealType;
  final int mealOrder;
  final String status; // scheduled | eaten | skipped
  final MealDetail? meal;
  final double referenceWeightG;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final bool logged;
  final double? actualWeightGrams;
  final double? actualCalories;
  final double? actualProtein;
  final double? actualCarbs;
  final double? actualFat;
  final int? intakeItemId;

  const MealSchedule({
    required this.scheduleId,
    required this.mealType,
    required this.mealOrder,
    required this.status,
    this.meal,
    required this.referenceWeightG,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.logged,
    this.actualWeightGrams,
    this.actualCalories,
    this.actualProtein,
    this.actualCarbs,
    this.actualFat,
    this.intakeItemId,
  });

  bool get isEaten => status == 'eaten';
  bool get isSkipped => status == 'skipped';

  /// Parses API decimals whether encoded as num or string (e.g. Laravel `"150.00"`).
  static double? parseApiDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  static int? parseApiInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String get mealTypeLabel {
    switch (mealType) {
      case 'breakfast':
        return 'فطور';
      case 'lunch':
        return 'غداء';
      case 'dinner':
        return 'عشاء';
      case 'snack':
        return 'وجبة خفيفة';
      default:
        return mealType;
    }
  }

  factory MealSchedule.fromJson(Map<String, dynamic> json) {
    final mealJson = json['meal'];
    return MealSchedule(
      scheduleId: asInt(json['schedule_id']) ?? 0,
      mealType: (json['meal_type'] ?? 'snack').toString(),
      mealOrder: asInt(json['meal_order']) ?? 1,
      status: (json['status'] ?? 'scheduled').toString(),
      meal: mealJson is Map<String, dynamic>
          ? MealDetail.fromJson(mealJson)
          : null,
      // API may omit reference weight; 100g is the portion baseline for macro scaling.
      referenceWeightG: _d(json['reference_weight_g']) > 0 ? _d(json['reference_weight_g']) : 100,
      targetCalories: _d(json['target_calories']),
      targetProtein: _d(json['target_protein']),
      targetCarbs: _d(json['target_carbs']),
      targetFat: _d(json['target_fat']),
      logged: asBool(json['logged']),
      actualWeightGrams: parseApiDouble(json['actual_weight_grams']),
      actualCalories: parseApiDouble(json['actual_calories']),
      actualProtein: parseApiDouble(json['actual_protein']),
      actualCarbs: parseApiDouble(json['actual_carbs']),
      actualFat: parseApiDouble(json['actual_fat']),
      intakeItemId: parseApiInt(json['intake_item_id']),
    );
  }

  MealSchedule copyWith({
    String? status,
    bool? logged,
    double? actualWeightGrams,
    double? actualCalories,
    double? actualProtein,
    double? actualCarbs,
    double? actualFat,
    int? intakeItemId,
    bool clearLoggedActuals = false,
  }) {
    return MealSchedule(
      scheduleId: scheduleId,
      mealType: mealType,
      mealOrder: mealOrder,
      status: status ?? this.status,
      meal: meal,
      referenceWeightG: referenceWeightG,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      logged: logged ?? this.logged,
      actualWeightGrams:
          clearLoggedActuals ? null : (actualWeightGrams ?? this.actualWeightGrams),
      actualCalories:
          clearLoggedActuals ? null : (actualCalories ?? this.actualCalories),
      actualProtein:
          clearLoggedActuals ? null : (actualProtein ?? this.actualProtein),
      actualCarbs:
          clearLoggedActuals ? null : (actualCarbs ?? this.actualCarbs),
      actualFat: clearLoggedActuals ? null : (actualFat ?? this.actualFat),
      intakeItemId:
          clearLoggedActuals ? null : (intakeItemId ?? this.intakeItemId),
    );
  }
}
