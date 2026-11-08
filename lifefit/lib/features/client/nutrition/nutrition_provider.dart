import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/nutrition/today_meals_response.dart';
import '../../../core/models/nutrition/meal_schedule.dart';
import '../../../core/services/nutrition_service.dart';

/// Central state for [NutritionScreen] and [LogMealSheet].
/// State updates after successful API responses (no local macro math).
class NutritionNotifier extends StateNotifier<AsyncValue<TodayMealsResponse>> {
  final NutritionService _service;

  NutritionNotifier(this._service) : super(const AsyncValue.loading()) {
    fetch();
  }

  /// Fetches the user's meals for today.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.fetchTodayMeals();
      state = AsyncValue.data(data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refreshes the meal data.
  Future<void> refresh() => fetch();

  /// Logs a meal as eaten; patches state from POST response only.
  Future<bool> logMeal({
    required int scheduleId,
    required int mealId,
    required String mealType,
    required double actualWeightGrams,
    required double referenceWeightG,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final result = await _service.logSingleMeal(
        logDate: today,
        scheduleId: scheduleId,
        mealId: mealId,
        mealType: mealType,
        actualWeightGrams: actualWeightGrams,
        referenceWeightG: referenceWeightG,
      );

      _updateMealState(scheduleId, (m) => m.copyWith(
            status: 'eaten',
            logged: true,
            actualWeightGrams: actualWeightGrams,
            actualCalories:
                MealSchedule.parseApiDouble(result['actual_calories']),
            actualProtein:
                MealSchedule.parseApiDouble(result['actual_protein']),
            actualCarbs: MealSchedule.parseApiDouble(result['actual_carbs']),
            actualFat: MealSchedule.parseApiDouble(result['actual_fat']),
            intakeItemId: MealSchedule.parseApiInt(result['intake_item_id']),
          ));

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Marks a meal as skipped after the server confirms.
  Future<bool> skipMeal({
    required int scheduleId,
    required int mealId,
    required String mealType,
    required double referenceWeightG,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await _service.logSingleMeal(
        logDate: today,
        scheduleId: scheduleId,
        mealId: mealId,
        mealType: mealType,
        actualWeightGrams: 0,
        referenceWeightG: referenceWeightG,
        skipped: true,
      );

      _updateMealState(
        scheduleId,
        (m) => m.copyWith(
          status: 'skipped',
          logged: false,
          clearLoggedActuals: true,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Patches one [MealSchedule] by [scheduleId] and rebuilds [TodayMealsResponse].
  void _updateMealState(
    int scheduleId,
    MealSchedule Function(MealSchedule) updater,
  ) {
    state.whenData((response) {
      final updated = response.meals.map((m) {
        return m.scheduleId == scheduleId ? updater(m) : m;
      }).toList();
      state = AsyncValue.data(TodayMealsResponse(
        meals: updated,
        planName: response.planName,
        intakeLogId: response.intakeLogId,
        intakeLogStatus: response.intakeLogStatus,
      ));
    });
  }
}

/// Watched by [NutritionScreen]; written by [LogMealSheet] via logMeal/skipMeal.
final nutritionProvider =
    StateNotifierProvider<NutritionNotifier, AsyncValue<TodayMealsResponse>>(
  (ref) {
    ref.watch(currentUserIdProvider);
    return NutritionNotifier(NutritionService());
  },
);
