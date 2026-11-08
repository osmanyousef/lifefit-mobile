import 'meal_schedule.dart';
import '../../utils/json_parse.dart';

/// Root payload for today's nutrition dashboard; totals are computed client-side.
class TodayMealsResponse {
  final List<MealSchedule> meals;
  final String? planName;
  final int? intakeLogId;
  final String? intakeLogStatus;

  const TodayMealsResponse({
    required this.meals,
    this.planName,
    this.intakeLogId,
    this.intakeLogStatus,
  });

  double get totalTargetCalories =>
      meals.fold(0, (sum, m) => sum + m.targetCalories);

  /// Sum of backend-reported actual macros for eaten meals only.
  double get totalConsumedCalories => meals
      .where((m) => m.isEaten)
      .fold(0, (sum, m) => sum + (m.actualCalories ?? 0));

  double get totalTargetProtein =>
      meals.fold(0, (sum, m) => sum + m.targetProtein);

  double get totalConsumedProtein => meals
      .where((m) => m.isEaten)
      .fold(0, (sum, m) => sum + (m.actualProtein ?? 0));

  double get totalTargetCarbs =>
      meals.fold(0, (sum, m) => sum + m.targetCarbs);

  double get totalConsumedCarbs => meals
      .where((m) => m.isEaten)
      .fold(0, (sum, m) => sum + (m.actualCarbs ?? 0));

  double get totalTargetFat =>
      meals.fold(0, (sum, m) => sum + m.targetFat);

  double get totalConsumedFat => meals
      .where((m) => m.isEaten)
      .fold(0, (sum, m) => sum + (m.actualFat ?? 0));

  factory TodayMealsResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'];
    final meals = dataList is List
        ? dataList
            .whereType<Map>()
            .map((e) => MealSchedule.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MealSchedule>[];

    final intakeLog = json['intake_log'];
    return TodayMealsResponse(
      meals: meals,
      planName: json['plan_name']?.toString(),
      intakeLogId: intakeLog is Map ? asInt(intakeLog['id']) : null,
      intakeLogStatus: intakeLog is Map ? intakeLog['status']?.toString() : null,
    );
  }

  /// Immutable replace-one-meal helper for local state after logging intake.
  TodayMealsResponse withUpdatedMeal(MealSchedule updated) {
    return TodayMealsResponse(
      meals: meals.map((m) => m.scheduleId == updated.scheduleId ? updated : m).toList(),
      planName: planName,
      intakeLogId: intakeLogId,
      intakeLogStatus: intakeLogStatus,
    );
  }
}
