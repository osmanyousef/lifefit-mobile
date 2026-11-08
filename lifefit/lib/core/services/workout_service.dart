import 'package:dio/dio.dart';
import 'base_service.dart';
import '../models/workout/today_schedule.dart';
import '../models/workout/workout.dart';
import '../models/workout/workout_log.dart';
import '../models/workout/exercise_log.dart';
import '../utils/json_parse.dart';

/// Web client workouts: `GET /client/today`, `POST /client/workout-logs`.
class WorkoutService extends BaseService {
  /// GET `/api/client/today` — today's scheduled workouts with status.
  Future<List<TodaySchedule>> fetchTodaySchedules() async {
    try {
      final response = await dio.get('client/today');

      if (response.statusCode == 200) {
        final dataList = response.data['data'];
        if (dataList is List) {
          return dataList
              .whereType<Map>()
              .map((e) =>
                  TodaySchedule.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      if (e.response != null) {
        final dataList = e.response?.data['data'];
        if (dataList is List && dataList.isEmpty) return [];
      }
      throw Exception('Failed to fetch today schedules: ${e.message}');
    }
  }

  /// POST `/api/client/workout-logs` — saves exercise sets and marks schedule complete.
  Future<TodaySchedule> saveWorkoutLog({
    required int scheduleId,
    required List<ExerciseLog> exerciseLogs,
    int? actualDurationMinutes,
    String? notes,
  }) async {
    final body = {
      'schedule_id': scheduleId,
      'exercise_logs': exerciseLogs.map((l) => l.toJson()).toList(),
      if (actualDurationMinutes != null)
        'actual_duration_minutes': actualDurationMinutes,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    try {
      final response = await dio.post('client/workout-logs', data: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        if (data is Map<String, dynamic>) {
          return _scheduleResourceToTodaySchedule(data);
        }
      }
      throw Exception('Unexpected response: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to save workout log: $msg');
    }
  }

  /// Maps the Laravel schedule resource shape to [TodaySchedule].
  TodaySchedule _scheduleResourceToTodaySchedule(Map<String, dynamic> json) {
    WorkoutLog? log;
    final logJson = json['log'];
    if (logJson is Map<String, dynamic>) {
      log = WorkoutLog.fromJson(logJson);
    }

    return TodaySchedule(
      scheduleId: asInt(json['id']) ?? 0,
      status: (json['status'] ?? 'completed').toString(),
      workout: json['workout'] is Map<String, dynamic>
          ? Workout.fromJson(json['workout'] as Map<String, dynamic>)
          : const Workout(id: 0, name: ''),
      workoutLog: log,
    );
  }
}
