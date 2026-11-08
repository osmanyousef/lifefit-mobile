import 'exercise.dart';
import '../../utils/json_parse.dart';

/// Workout template with ordered [exercises] and optional pivot prescriptions.
class Workout {
  final int id;
  final String name;
  final String? description;
  final int? estimatedDuration;
  final String? difficulty;
  final String? type;
  final List<Exercise> exercises;

  const Workout({
    required this.id,
    required this.name,
    this.description,
    this.estimatedDuration,
    this.difficulty,
    this.type,
    this.exercises = const [],
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    final exercisesJson = json['exercises'];
    final exercises = exercisesJson is List
        ? exercisesJson
            .whereType<Map>()
            .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Exercise>[];

    return Workout(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      estimatedDuration: asInt(json['estimated_duration']),
      difficulty: json['difficulty']?.toString(),
      type: json['type']?.toString(),
      exercises: exercises,
    );
  }
}
