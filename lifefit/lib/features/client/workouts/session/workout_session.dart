import '../../../../core/models/workout/exercise.dart';
import '../../../../core/models/workout/exercise_log.dart';
import '../../../../core/models/workout/exercise_pivot.dart';
import '../../../../core/models/workout/today_schedule.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Workout session — the client's in-progress logging for one scheduled workout.
//
// Built from what `GET client/today` returns (workout → exercises → pivot
// prescription, plus any saved `workout_log`), changed locally while the
// client trains, and turned back into the exact `exercise_logs` payload that
// `POST client/workout-logs` expects.
//
// How the backend saves (WorkoutLogService::storeLog):
//   • every POST REPLACES all exercise logs of the schedule, so the payload
//     always contains every logged set of every exercise in the workout;
//   • every POST marks the schedule completed and notifies the trainer, so the
//     app posts once, when the client finishes (or saves an edit).
//
// Prescription shapes (workout_exercises pivot):
//   set_type        reps | time          → what each set counts
//   intensity_type  weight | percentage | rpe | time (legacy: duration, no load)
// ─────────────────────────────────────────────────────────────────────────────

/// What a set counts.
enum AmountKind { reps, duration }

/// How heavy a set is.
enum LoadKind { weight, percentage, rpe, none }

String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// Keeps a numeric expression left-to-right inside Arabic text (60 × 10).
String ltr(String s) => '⁦$s⁩';

/// The trainer's prescription for one exercise, normalised for the UI.
class ExercisePlan {
  const ExercisePlan({
    required this.amount,
    required this.load,
    required this.intensityType,
    required this.targetSets,
    this.repsText,
    this.targetReps,
    this.targetWeight,
    this.targetPercentage,
    this.targetRpe,
    this.targetDurationSeconds,
    this.durationInMinutes = false,
    this.restSeconds,
    this.tempo,
    this.notes,
  });

  factory ExercisePlan.from(ExercisePivot? pivot) {
    final p = pivot;
    final intensity = p?.effectiveIntensityType ?? 'weight';
    final amount = (p?.isDurationSet ?? false) ? AmountKind.duration : AmountKind.reps;

    final LoadKind load;
    switch (intensity) {
      case 'percentage':
        load = LoadKind.percentage;
      case 'rpe':
        load = LoadKind.rpe;
      case 'time':
        load = LoadKind.none;
      default:
        // Weight with no target weight = body-weight exercise.
        load = (p?.targetWeight ?? 0) > 0 ? LoadKind.weight : LoadKind.none;
    }

    final duration = p?.targetDurationSeconds;
    // Show minutes for whole-minute targets (or the legacy cardio type with no
    // target, which the old screen entered in minutes); seconds otherwise.
    final inMinutes = duration != null ? duration >= 60 && duration % 60 == 0 : intensity == 'time';

    return ExercisePlan(
      amount: amount,
      load: load,
      intensityType: intensity,
      targetSets: (p?.sets ?? 1).clamp(1, 20),
      repsText: amount == AmountKind.reps ? p?.reps.trim() : null,
      targetReps: amount == AmountKind.reps ? _firstInt(p?.reps) : null,
      targetWeight: p?.targetWeight,
      targetPercentage: p?.targetPercentage,
      targetRpe: p?.rpeTarget,
      targetDurationSeconds: amount == AmountKind.duration ? duration : null,
      durationInMinutes: inMinutes,
      restSeconds: p?.restSeconds,
      tempo: p?.tempo,
      notes: p?.notes,
    );
  }

  final AmountKind amount;
  final LoadKind load;

  /// Sent as `intensity_type` on every set.
  final String intensityType;
  final int targetSets;

  /// Reps exactly as the trainer wrote them ("10", "8-12", "AMRAP").
  final String? repsText;

  /// First number of [repsText] — what the old screen used as `target_reps`.
  final int? targetReps;
  final double? targetWeight;
  final int? targetPercentage;
  final int? targetRpe;
  final int? targetDurationSeconds;
  final bool durationInMinutes;
  final int? restSeconds;
  final String? tempo;
  final String? notes;

  /// Weight-type prescription with no weight (push-ups, pull-ups…).
  bool get isBodyweight => intensityType == 'weight' && load == LoadKind.none;

  static int? _firstInt(String? text) {
    if (text == null) return null;
    final m = RegExp(r'(\d+)').firstMatch(text);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  // ── Display helpers ────────────────────────────────────────────────

  String get durationUnit => durationInMinutes ? 'د' : 'ث';

  /// Seconds → number in the display unit.
  num durationValue(int seconds) => durationInMinutes ? seconds / 60 : seconds;

  /// Number only, in the display unit ("1.5", "45", "—").
  String durationNumber(int? seconds) {
    if (seconds == null) return '—';
    final v = durationValue(seconds);
    return v is double ? _num(v) : '$v';
  }

  String durationText(int? seconds) => seconds == null ? '—' : '${durationNumber(seconds)} $durationUnit';

  String loadText({double? weight, int? percentage, int? rpe}) => switch (load) {
        LoadKind.weight => weight == null ? '—' : '${_num(weight)} كجم',
        LoadKind.percentage => percentage == null ? '—' : '$percentage%',
        LoadKind.rpe => rpe == null ? '—' : 'RPE $rpe',
        LoadKind.none => isBodyweight ? 'وزن الجسم' : '',
      };

  /// Short summary for the exercise header, e.g. "4×10 · 60 كجم".
  String get summary {
    final count = amount == AmountKind.duration
        ? '${ltr('$targetSets×${durationNumber(targetDurationSeconds)}')} $durationUnit'
        : ltr('$targetSets×${repsText?.isNotEmpty == true ? repsText : '—'}');
    final l = loadText(weight: targetWeight, percentage: targetPercentage, rpe: targetRpe);
    return l.isEmpty ? count : '$count · $l';
  }

  /// Target shown in each table row.
  String get targetCell {
    final count = amount == AmountKind.duration
        ? durationText(targetDurationSeconds)
        : (repsText?.isNotEmpty == true ? repsText! : '—');
    final value = switch (load) {
      LoadKind.weight => targetWeight == null ? null : _num(targetWeight!),
      LoadKind.percentage => targetPercentage == null ? null : '$targetPercentage%',
      LoadKind.rpe => targetRpe == null ? null : '@$targetRpe',
      LoadKind.none => null,
    };
    return value == null ? count : ltr('$value × $count');
  }

  /// Column title for the load column (null when there is none).
  String? get loadLabel => switch (load) {
        LoadKind.weight => 'الوزن (كجم)',
        LoadKind.percentage => '% من 1RM',
        LoadKind.rpe => 'RPE',
        LoadKind.none => null,
      };

  String get amountLabel => amount == AmountKind.duration ? 'المدة ($durationUnit)' : 'العدّات';
}

/// One set the client logs.
class SetEntry {
  SetEntry({this.reps, this.weight, this.percentage, this.rpe, this.durationSeconds, this.note, this.done = false});

  /// Pre-filled with the trainer's target, so most sets are one tap.
  factory SetEntry.fromPlan(ExercisePlan plan) => SetEntry(
        reps: plan.targetReps,
        weight: plan.load == LoadKind.weight ? plan.targetWeight : null,
        percentage: plan.load == LoadKind.percentage ? plan.targetPercentage : null,
        rpe: plan.load == LoadKind.rpe ? plan.targetRpe : null,
        durationSeconds: plan.targetDurationSeconds,
      );

  /// A set the server already has (shown as done).
  factory SetEntry.fromLog(ExerciseLog log, ExercisePlan plan) => SetEntry(
        reps: log.actualReps ?? log.targetReps ?? plan.targetReps,
        weight: log.actualWeight ?? log.targetWeight ?? (plan.load == LoadKind.weight ? plan.targetWeight : null),
        percentage: log.actualPercentage ?? log.targetPercentage ?? plan.targetPercentage,
        rpe: log.rpe ?? log.rpeTarget ?? plan.targetRpe,
        durationSeconds: log.actualDurationSeconds ?? log.targetDurationSeconds ?? plan.targetDurationSeconds,
        note: log.notes,
        done: true,
      );

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
        reps: (j['r'] as num?)?.toInt(),
        weight: (j['w'] as num?)?.toDouble(),
        percentage: (j['p'] as num?)?.toInt(),
        rpe: (j['e'] as num?)?.toInt(),
        durationSeconds: (j['d'] as num?)?.toInt(),
        note: j['n'] as String?,
        done: j['x'] == true,
      );

  int? reps;
  double? weight;
  int? percentage;
  int? rpe;
  int? durationSeconds;
  String? note;
  bool done;

  SetEntry copy() => SetEntry(
        reps: reps,
        weight: weight,
        percentage: percentage,
        rpe: rpe,
        durationSeconds: durationSeconds,
        note: note,
        done: done,
      );

  Map<String, dynamic> toJson() => {
        if (reps != null) 'r': reps,
        if (weight != null) 'w': weight,
        if (percentage != null) 'p': percentage,
        if (rpe != null) 'e': rpe,
        if (durationSeconds != null) 'd': durationSeconds,
        if (note != null && note!.isNotEmpty) 'n': note,
        if (done) 'x': true,
      };
}

/// One exercise of the session with its sets.
class ExerciseSession {
  ExerciseSession({required this.exercise, required this.key, required this.plan, required this.sets});

  final Exercise exercise;

  /// Identifies the exercise inside the workout ("12", or "12#2" when the
  /// trainer added the same exercise twice).
  final String key;
  final ExercisePlan plan;
  final List<SetEntry> sets;

  int get doneCount => sets.where((s) => s.done).length;
  bool get complete => sets.isNotEmpty && doneCount == sets.length;

  /// Weight × reps of done sets (weight exercises only).
  double get volume => plan.load == LoadKind.weight && plan.amount == AmountKind.reps
      ? sets.where((s) => s.done).fold(0.0, (a, s) => a + (s.weight ?? 0) * (s.reps ?? 0))
      : 0;
}

/// The client's logging for one scheduled workout.
class WorkoutSession {
  WorkoutSession._({
    required this.schedule,
    required this.exercises,
    this.notes,
    this.durationMinutes,
    this.dirty = false,
  });

  /// Builds the session from the API data and, when present, an unsaved draft
  /// (the draft wins for every exercise it contains).
  factory WorkoutSession.build(TodaySchedule schedule, {Map<String, dynamic>? draft}) {
    final draftSets = (draft?['ex'] as Map?)?.cast<String, dynamic>() ?? const {};
    final logsByExercise = <int, List<ExerciseLog>>{};
    for (final log in schedule.workoutLog?.exerciseLogs ?? const <ExerciseLog>[]) {
      logsByExercise.putIfAbsent(log.exerciseId, () => []).add(log);
    }

    final seen = <int, int>{};
    final exercises = <ExerciseSession>[];
    for (final ex in schedule.workout.exercises) {
      final occurrence = seen[ex.id] = (seen[ex.id] ?? 0) + 1;
      final key = occurrence == 1 ? '${ex.id}' : '${ex.id}#$occurrence';
      final plan = ExercisePlan.from(ex.pivot);

      List<SetEntry> sets;
      final fromDraft = draftSets[key];
      if (fromDraft is List && fromDraft.isNotEmpty) {
        sets = [for (final s in fromDraft.whereType<Map>()) SetEntry.fromJson(s.cast<String, dynamic>())];
      } else {
        sets = List.generate(plan.targetSets, (_) => SetEntry.fromPlan(plan));
        // Saved sets go back to their set number (logs only belong to the
        // first occurrence of an exercise).
        if (occurrence == 1) {
          for (final log in logsByExercise[ex.id] ?? const <ExerciseLog>[]) {
            final i = log.setNumber - 1;
            if (i < 0 || i > 60) continue;
            while (sets.length <= i) {
              sets.add(SetEntry.fromPlan(plan));
            }
            sets[i] = SetEntry.fromLog(log, plan);
          }
        }
      }
      exercises.add(ExerciseSession(exercise: ex, key: key, plan: plan, sets: sets));
    }

    return WorkoutSession._(
      schedule: schedule,
      exercises: exercises,
      notes: draft != null ? draft['notes'] as String? : schedule.workoutLog?.notes,
      durationMinutes: draft != null
          ? (draft['min'] as num?)?.toInt()
          : schedule.workoutLog?.actualDurationMinutes,
      dirty: draft != null,
    );
  }

  /// The API data this session was built from.
  final TodaySchedule schedule;
  final List<ExerciseSession> exercises;

  /// Session notes (`workout_logs.notes`).
  String? notes;

  /// How long the session took, only when the client enters it
  /// (`actual_duration_minutes`; no timers in the app).
  int? durationMinutes;

  /// Has changes the server doesn't have yet.
  bool dirty;

  int get scheduleId => schedule.scheduleId;

  /// The server already has a log for this workout.
  bool get saved => schedule.workoutLog != null;

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);
  int get doneSets => exercises.fold(0, (a, e) => a + e.doneCount);
  int get doneExercises => exercises.where((e) => e.complete).length;
  int get startedExercises => exercises.where((e) => e.doneCount > 0).length;
  double get volume => exercises.fold(0.0, (a, e) => a + e.volume);
  double get progress => totalSets == 0 ? 0 : doneSets / totalSets;
  bool get complete => totalSets > 0 && doneSets == totalSets;

  /// Unsaved draft for local storage.
  Map<String, dynamic> toDraft() => {
        'ex': {for (final e in exercises) e.key: [for (final s in e.sets) s.toJson()]},
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (durationMinutes != null) 'min': durationMinutes,
      };

  /// The `exercise_logs` payload: every done set of every exercise, numbered
  /// by its position (set 3 stays set 3 even if set 2 was skipped).
  List<ExerciseLog> toExerciseLogs() {
    final logs = <ExerciseLog>[];
    final usedNumbers = <int, int>{};
    for (final e in exercises) {
      // A repeated exercise continues the numbering of the first one.
      final offset = usedNumbers[e.exercise.id] ?? 0;
      for (var i = 0; i < e.sets.length; i++) {
        final s = e.sets[i];
        if (!s.done) continue;
        logs.add(_toLog(e, s, offset + i + 1));
      }
      usedNumbers[e.exercise.id] = offset + e.sets.length;
    }
    return logs;
  }

  /// Same fields the old logging screen sent for each intensity type, plus the
  /// duration fields for "time" sets of weight / % / RPE exercises.
  static ExerciseLog _toLog(ExerciseSession e, SetEntry s, int setNumber) {
    final p = e.plan;
    final byReps = p.amount == AmountKind.reps;
    final note = s.note?.trim();
    return ExerciseLog(
      exerciseId: e.exercise.id,
      setNumber: setNumber.clamp(1, 255),
      intensityType: p.intensityType,
      targetReps: byReps ? p.targetReps : null,
      actualReps: byReps ? s.reps?.clamp(0, 255) : null,
      targetDurationSeconds: byReps ? null : p.targetDurationSeconds,
      actualDurationSeconds: byReps ? null : s.durationSeconds,
      targetWeight: p.intensityType == 'weight' ? p.targetWeight : null,
      actualWeight: p.load == LoadKind.weight ? s.weight : null,
      targetPercentage: p.load == LoadKind.percentage ? p.targetPercentage : null,
      actualPercentage: p.load == LoadKind.percentage ? s.percentage?.clamp(0, 200) : null,
      rpeTarget: p.load == LoadKind.rpe ? p.targetRpe : null,
      rpe: p.load == LoadKind.rpe ? s.rpe?.clamp(1, 10) : null,
      notes: note == null || note.isEmpty ? null : note,
    );
  }
}
