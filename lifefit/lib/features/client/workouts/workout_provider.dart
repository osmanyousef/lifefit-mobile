import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/workout/today_schedule.dart';
import '../../../core/models/workout/exercise_log.dart';
import '../../../core/services/workout_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// workout_provider — Riverpod state for today's workout schedules.
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches, caches, and updates today's workout schedules.
///
/// Consumed by [WorkoutsScreen], [WorkoutDetailScreen], and [WorkoutLogScreen]
/// via [todaySchedulesProvider].
class TodaySchedulesNotifier
    extends StateNotifier<AsyncValue<List<TodaySchedule>>> {
  final WorkoutService _service;

  TodaySchedulesNotifier(this._service) : super(const AsyncValue.loading()) {
    fetch();
  }

  /// GET today's schedules — called on provider init and pull-to-refresh.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final schedules = await _service.fetchTodaySchedules();
      state = AsyncValue.data(schedules);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Alias for [fetch] — used by RefreshIndicator and retry buttons.
  Future<void> refresh() => fetch();

  /// POST exercise logs for one schedule and patch local state.
  ///
  /// Returns `true` on success. Merges [exerciseLogs] server-side; the
  /// response may omit nested exercises, so we preserve [TodaySchedule.workout]
  /// from the cached item and only update status + workoutLog.
  Future<bool> saveWorkoutLog({
    required int scheduleId,
    required List<ExerciseLog> exerciseLogs,
    int? actualDurationMinutes,
    String? notes,
  }) async {
    try {
      await submitWorkoutLog(
        scheduleId: scheduleId,
        exerciseLogs: exerciseLogs,
        actualDurationMinutes: actualDurationMinutes,
        notes: notes,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Same as [saveWorkoutLog] but throws the API error, so the screen can
  /// show what went wrong. Same request, same local state update.
  Future<void> submitWorkoutLog({
    required int scheduleId,
    required List<ExerciseLog> exerciseLogs,
    int? actualDurationMinutes,
    String? notes,
  }) async {
    final updated = await _service.saveWorkoutLog(
      scheduleId: scheduleId,
      exerciseLogs: exerciseLogs,
      actualDurationMinutes: actualDurationMinutes,
      notes: notes,
    );

    state.whenData((schedules) {
      final newList = schedules.map((s) {
        if (s.scheduleId != updated.scheduleId) return s;
        // API response lacks workout.exercises — keep the cached workout tree.
        return TodaySchedule(
          scheduleId: s.scheduleId,
          status: updated.status,
          workout: s.workout,
          workoutLog: updated.workoutLog,
        );
      }).toList();
      state = AsyncValue.data(newList);
    });
  }
}

/// Global provider — watch with `ref.watch(todaySchedulesProvider)`.
final todaySchedulesProvider = StateNotifierProvider<TodaySchedulesNotifier,
    AsyncValue<List<TodaySchedule>>>((ref) {
  ref.watch(currentUserIdProvider);
  return TodaySchedulesNotifier(WorkoutService());
});
