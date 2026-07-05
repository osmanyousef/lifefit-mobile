import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/utils/workout_duration_utils.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/workout/today_schedule.dart';
import '../../../core/models/workout/exercise.dart';
import '../../../core/models/workout/exercise_log.dart';
import '../../../core/models/workout/exercise_pivot.dart';
import 'workout_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorkoutLogScreen — per-set performance logging.
// ─────────────────────────────────────────────────────────────────────────────

/// Logs actual performance for each set of an exercise.
///
/// Flow:
/// 1. Builds one [_SetFields] row per prescribed set, pre-filled from
///    existing logs or pivot targets.
/// 2. Input fields adapt to [ExercisePivot.effectiveIntensityType]:
///    `weight` | `percentage` | `rpe` | `time`.
/// 3. On save, merges this exercise's logs with others on the same schedule
///    and posts via [TodaySchedulesNotifier.saveWorkoutLog].
///
/// Duration note: users enter **minutes**; [WorkoutDurationUtils] converts
/// to seconds before sending to the API.
class WorkoutLogScreen extends ConsumerStatefulWidget {
  final TodaySchedule schedule;
  final Exercise exercise;

  const WorkoutLogScreen({
    super.key,
    required this.schedule,
    required this.exercise,
  });

  @override
  ConsumerState<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends ConsumerState<WorkoutLogScreen> {
  /// One form row per prescribed set (controllers + target values).
  late List<_SetFields> _sets;

  /// Drives which input widgets are shown — mirrors pivot intensity type.
  late String _intensityType;

  bool _isSubmitting = false;

  /// Local countdown between sets; uses seconds internally for precision.
  Timer? _restTimer;
  int _restRemaining = 60;
  bool _restRunning = false;

  static const _primary = AppColors.primary;

  Exercise get _exercise => widget.exercise;
  TodaySchedule get _schedule => widget.schedule;
  ExercisePivot? get _pivot => _exercise.pivot;

  @override
  void initState() {
    super.initState();
    final pivot = _pivot;
    _intensityType = pivot?.effectiveIntensityType ?? 'weight';
    final count = (pivot?.sets ?? 1).clamp(1, 20);

    final existingLogs = _schedule.workoutLog?.exerciseLogs
            .where((l) => l.exerciseId == _exercise.id)
            .toList() ??
        []
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

    // Pre-fill from saved logs when re-editing; otherwise use pivot targets.
    _sets = List.generate(count, (index) {
      final existing =
          index < existingLogs.length ? existingLogs[index] : null;
      return _SetFields.fromTargets(
        intensityType: _intensityType,
        pivot: pivot,
        existing: existing,
      );
    });
  }

  @override
  void dispose() {
    for (final s in _sets) {
      s.dispose();
    }
    _restTimer?.cancel();
    super.dispose();
  }

  /// Starts a local rest countdown using [ExercisePivot.restSeconds].
  void _startRestTimer() {
    _restTimer?.cancel();
    final restSec = _pivot?.restSeconds ?? 60;
    setState(() {
      _restRemaining = restSec;
      _restRunning = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restRemaining <= 1) {
        timer.cancel();
        setState(() => _restRunning = false);
      } else {
        setState(() => _restRemaining -= 1);
      }
    });
  }

  /// Reads the latest schedule from provider so we don't overwrite other exercises' logs.
  TodaySchedule _scheduleForSubmit() {
    final list = ref.read(todaySchedulesProvider).valueOrNull;
    if (list != null) {
      for (final s in list) {
        if (s.scheduleId == widget.schedule.scheduleId) return s;
      }
    }
    return widget.schedule;
  }

  /// Builds [ExerciseLog] list for this exercise and POSTs the merged schedule log.
  Future<void> _submitLog() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final schedule = _scheduleForSubmit();
      final existingFromOthers = schedule.workoutLog?.exerciseLogs
              .where((l) => l.exerciseId != _exercise.id)
              .toList() ??
          [];

      final pivot = _pivot;
      final newLogs = <ExerciseLog>[];
      for (var i = 0; i < _sets.length; i++) {
        newLogs.add(_buildExerciseLog(_sets[i], i + 1, pivot));
      }

      final exerciseLogs = [...existingFromOthers, ...newLogs];

      final success =
          await ref.read(todaySchedulesProvider.notifier).saveWorkoutLog(
                scheduleId: schedule.scheduleId,
                exerciseLogs: exerciseLogs,
              );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ سجل التمرين بنجاح')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ السجل، حاول مجدداً')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Maps form fields → [ExerciseLog] based on [_intensityType].
  ExerciseLog _buildExerciseLog(
    _SetFields set,
    int setNumber,
    ExercisePivot? pivot,
  ) {
    switch (_intensityType) {
      case 'percentage':
        return ExerciseLog(
          exerciseId: _exercise.id,
          setNumber: setNumber,
          targetReps: set.targetReps,
          actualReps: _intFrom(set.repsCtrl.text, set.targetReps),
          targetPercentage: set.targetPercentage,
          actualPercentage:
              _intFrom(set.percentageCtrl.text, set.targetPercentage),
          intensityType: 'percentage',
          notes: _notesFrom(set),
        );
      case 'rpe':
        return ExerciseLog(
          exerciseId: _exercise.id,
          setNumber: setNumber,
          targetReps: set.targetReps,
          actualReps: _intFrom(set.repsCtrl.text, set.targetReps),
          rpeTarget: set.rpeTarget,
          rpe: _intFrom(set.rpeCtrl.text, set.rpeTarget),
          intensityType: 'rpe',
          notes: _notesFrom(set),
        );
      case 'time':
        return ExerciseLog(
          exerciseId: _exercise.id,
          setNumber: setNumber,
          targetDurationSeconds: set.targetDurationSeconds,
          // User enters minutes; backend expects seconds.
          actualDurationSeconds: WorkoutDurationUtils.minutesInputToSeconds(
            set.durationCtrl.text,
            set.targetDurationSeconds,
          ),
          intensityType: 'time',
          notes: _notesFrom(set),
        );
      default:
        return ExerciseLog(
          exerciseId: _exercise.id,
          setNumber: setNumber,
          targetReps: set.targetReps,
          actualReps: _intFrom(set.repsCtrl.text, set.targetReps),
          targetWeight: set.targetWeight,
          actualWeight: _doubleFrom(set.weightCtrl.text, set.targetWeight),
          intensityType: 'weight',
          notes: _notesFrom(set),
        );
    }
  }

  String? _notesFrom(_SetFields set) {
    final text = set.notesCtrl.text.trim();
    return text.isEmpty ? null : text;
  }

  int? _intFrom(String text, int? fallback) {
    if (text.trim().isEmpty) return fallback;
    return int.tryParse(text.trim()) ?? fallback;
  }

  double? _doubleFrom(String text, double? fallback) {
    if (text.trim().isEmpty) return fallback;
    return double.tryParse(text.trim()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('تسجيل التمرين',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildRestTimer(),
            const SizedBox(height: 16),
            Text(
              _pivot?.isTimeBased == true ? 'الجولات' : 'المجموعات',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...List.generate(_sets.length, (i) => _buildSetCard(i)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submitLog,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('حفظ التسجيل',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final pivot = _pivot;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_schedule.workout.name,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.right),
          const SizedBox(height: 4),
          Text(_exercise.name,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
              textAlign: TextAlign.right),
          if (pivot != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: [
                _tag('${pivot.sets} مجموعات', Colors.blue[50]!, Colors.blue),
                if (!pivot.isTimeBased)
                  _tag('${pivot.reps} عدات', Colors.orange[50]!, Colors.orange),
                _tag(
                  '${pivot.intensityTypeLabel}: ${pivot.targetIntensityText}',
                  Colors.green[50]!,
                  Colors.green,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestTimer() {
    // Countdown display stays mm:ss for precise rest timing.
    final mm = (_restRemaining ~/ 60).toString().padLeft(2, '0');
    final ss = (_restRemaining % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مؤقت الراحة',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                  '${WorkoutDurationUtils.formatMinutesFromSeconds(_pivot?.restSeconds ?? 60)} للراحة',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$mm:$ss',
                  style: TextStyle(
                      color: _primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _restRunning ? null : _startRestTimer,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_restRunning ? 'يعمل' : 'ابدأ'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSetCard(int index) {
    final s = _sets[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المجموعة ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'الهدف: ${s.targetSummary}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildSetInputs(s),
          const SizedBox(height: 10),
          TextFormField(
            controller: s.notesCtrl,
            textAlign: TextAlign.right,
            maxLines: 1,
            decoration: _inputDeco('ملاحظات المجموعة'),
          ),
        ],
      ),
    );
  }

  /// Renders the correct input fields for the current intensity type.
  List<Widget> _buildSetInputs(_SetFields s) {
    switch (_intensityType) {
      case 'percentage':
        return [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: s.repsCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('العدات'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: s.percentageCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('النسبة %'),
              ),
            ),
          ]),
        ];
      case 'rpe':
        return [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: s.repsCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('العدات'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: s.rpeCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('RPE (1-10)'),
              ),
            ),
          ]),
        ];
      case 'time':
        return [
          TextFormField(
            controller: s.durationCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: _inputDeco('المدة (دقيقة)'),
          ),
        ];
      default:
        return [
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: s.repsCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('العدات'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: s.weightCtrl,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDeco('الوزن كجم'),
              ),
            ),
          ]),
        ];
    }
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      );

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style:
                TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
      );
}

/// Holds controllers and target values for a single set row.
///
/// Targets come from [ExercisePivot] (trainer prescription) or an existing
/// [ExerciseLog] when the user is editing a previous entry.
class _SetFields {
  final String intensityType;

  // Target values from pivot / existing log (seconds for duration).
  final int? targetReps;
  final double? targetWeight;
  final int? targetPercentage;
  final int? targetDurationSeconds;
  final int? rpeTarget;

  final TextEditingController repsCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController percentageCtrl;
  final TextEditingController durationCtrl;
  final TextEditingController rpeCtrl;
  final TextEditingController notesCtrl;

  _SetFields._({
    required this.intensityType,
    this.targetReps,
    this.targetWeight,
    this.targetPercentage,
    this.targetDurationSeconds,
    this.rpeTarget,
    required this.repsCtrl,
    required this.weightCtrl,
    required this.percentageCtrl,
    required this.durationCtrl,
    required this.rpeCtrl,
    required this.notesCtrl,
  });

  factory _SetFields.fromTargets({
    required String intensityType,
    ExercisePivot? pivot,
    ExerciseLog? existing,
  }) {
    // Time-based exercises have no rep target — only duration.
    final targetReps = intensityType == 'time'
        ? null
        : _parseFirstIntStatic(pivot?.reps ?? existing?.targetReps?.toString());
    final targetWeight = pivot?.targetWeight ?? existing?.targetWeight;
    final targetPercentage =
        pivot?.targetPercentage ?? existing?.targetPercentage;
    final targetDurationSeconds =
        pivot?.targetDurationSeconds ?? existing?.targetDurationSeconds;
    final rpeTarget = pivot?.rpeTarget ?? existing?.rpeTarget;

    return _SetFields._(
      intensityType: intensityType,
      targetReps: existing?.targetReps ?? targetReps,
      targetWeight: existing?.targetWeight ?? targetWeight,
      targetPercentage: existing?.targetPercentage ?? targetPercentage,
      targetDurationSeconds:
          existing?.targetDurationSeconds ?? targetDurationSeconds,
      rpeTarget: existing?.rpeTarget ?? rpeTarget,
      repsCtrl: TextEditingController(
        text: _textOrEmpty(existing?.actualReps ?? targetReps),
      ),
      weightCtrl: TextEditingController(
        text: _textOrEmpty(existing?.actualWeight ?? targetWeight),
      ),
      percentageCtrl: TextEditingController(
        text: _textOrEmpty(existing?.actualPercentage ?? targetPercentage),
      ),
      durationCtrl: TextEditingController(
        // Display minutes in the field; stored as seconds on the backend.
        text: _textOrEmpty(WorkoutDurationUtils.secondsToMinutes(
          existing?.actualDurationSeconds ?? targetDurationSeconds,
        )),
      ),
      rpeCtrl: TextEditingController(
        text: _textOrEmpty(existing?.rpe ?? rpeTarget),
      ),
      notesCtrl: TextEditingController(text: existing?.notes ?? ''),
    );
  }

  /// One-line target summary shown in the set card header.
  String get targetSummary {
    switch (intensityType) {
      case 'percentage':
        return '${targetReps ?? "--"} عدات | ${targetPercentage ?? "--"}%';
      case 'rpe':
        return '${targetReps ?? "--"} عدات | RPE ${rpeTarget ?? "--"}';
      case 'time':
        return WorkoutDurationUtils.formatMinutesFromSeconds(
          targetDurationSeconds,
        );
      default:
        return '${targetReps ?? "--"} | ${ExercisePivot.formatWeight(targetWeight)}';
    }
  }

  static int? _parseFirstIntStatic(String? text) {
    if (text == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  static String _textOrEmpty(num? value) {
    if (value == null) return '';
    if (value is double && value % 1 != 0) return value.toString();
    return value.toInt().toString();
  }

  void dispose() {
    repsCtrl.dispose();
    weightCtrl.dispose();
    percentageCtrl.dispose();
    durationCtrl.dispose();
    rpeCtrl.dispose();
    notesCtrl.dispose();
  }
}
