import '../../utils/json_parse.dart';
/// Root of `GET /api/client/programs/{id}` → `data`.
class ClientProgramDetail {
  final int id;
  final ProgramDetailBlock program;
  final TrainerDetailBlock trainer;
  final DateTime? startDate;
  final String? status;
  final String? notes;
  final List<ProgramScheduleEntry> schedules;

  const ClientProgramDetail({
    required this.id,
    required this.program,
    required this.trainer,
    this.startDate,
    this.status,
    this.notes,
    required this.schedules,
  });

  factory ClientProgramDetail.fromJson(Map<String, dynamic> json) {
    final schedRaw = json['schedules'];
    final schedules = schedRaw is List
        ? schedRaw
            .whereType<Map>()
            .map((e) => ProgramScheduleEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ProgramScheduleEntry>[];

    return ClientProgramDetail(
      id: asInt(json['id']) ?? 0,
      program: ProgramDetailBlock.fromJson(
        Map<String, dynamic>.from(json['program'] as Map? ?? {}),
      ),
      trainer: TrainerDetailBlock.fromJson(
        Map<String, dynamic>.from(json['trainer'] as Map? ?? {}),
      ),
      startDate: _parseDate(json['start_date']),
      status: json['status']?.toString(),
      notes: json['notes']?.toString(),
      schedules: schedules,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}

class ProgramDetailBlock {
  final int id;
  final String name;
  final String? description;
  final int? durationWeeks;
  final String? difficultyLevel;

  const ProgramDetailBlock({
    required this.id,
    required this.name,
    this.description,
    this.durationWeeks,
    this.difficultyLevel,
  });

  factory ProgramDetailBlock.fromJson(Map<String, dynamic> json) {
    return ProgramDetailBlock(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      durationWeeks: asInt(json['duration_weeks']),
      difficultyLevel: json['difficulty_level']?.toString(),
    );
  }
}

class TrainerDetailBlock {
  final int id;
  final String name;
  final String? profileImage;

  const TrainerDetailBlock({
    required this.id,
    required this.name,
    this.profileImage,
  });

  factory TrainerDetailBlock.fromJson(Map<String, dynamic> json) {
    return TrainerDetailBlock(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      profileImage: json['profile_image']?.toString(),
    );
  }
}

/// One week/day slot in the program calendar with its [workout].
class ProgramScheduleEntry {
  final int id;
  final int? dayOfWeek;
  final int? weekNumber;
  final ScheduleWorkout workout;

  const ProgramScheduleEntry({
    required this.id,
    this.dayOfWeek,
    this.weekNumber,
    required this.workout,
  });

  factory ProgramScheduleEntry.fromJson(Map<String, dynamic> json) {
    final w = json['workout'];
    return ProgramScheduleEntry(
      id: asInt(json['id']) ?? 0,
      dayOfWeek: asInt(json['day_of_week']),
      weekNumber: asInt(json['week_number']),
      workout: w is Map
          ? ScheduleWorkout.fromJson(Map<String, dynamic>.from(w))
          : const ScheduleWorkout(id: 0, name: '—', exercises: []),
    );
  }
}

class ScheduleWorkout {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<ProgramExerciseRow> exercises;

  const ScheduleWorkout({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.exercises,
  });

  factory ScheduleWorkout.fromJson(Map<String, dynamic> json) {
    final exRaw = json['exercises'];
    final exercises = exRaw is List
        ? exRaw
            .whereType<Map>()
            .map((e) => ProgramExerciseRow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ProgramExerciseRow>[];

    return ScheduleWorkout(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      exercises: exercises,
    );
  }
}

/// Flattened exercise row in program detail (not the shared [Exercise] workout model).
class ProgramExerciseRow {
  final int id;
  final String name;
  final String? muscleGroup;
  final String? equipment;
  final String? imageUrl;
  final String? videoUrl;
  final int? sets;
  /// Kept as text: trainers enter ranges like "8-12".
  final String? reps;
  final int? durationMinutes;
  final int? restSeconds;
  final String? notes;

  const ProgramExerciseRow({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.equipment,
    this.imageUrl,
    this.videoUrl,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.restSeconds,
    this.notes,
  });

  factory ProgramExerciseRow.fromJson(Map<String, dynamic> json) {
    return ProgramExerciseRow(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      muscleGroup: json['muscle_group']?.toString(),
      equipment: json['equipment']?.toString(),
      imageUrl: json['image_url']?.toString(),
      videoUrl: json['video_url']?.toString(),
      sets: _toInt(json['sets']),
      reps: asString(json['reps']),
      durationMinutes: _toInt(json['duration_minutes']),
      restSeconds: _toInt(json['rest_seconds']),
      notes: json['notes']?.toString(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
