import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../../core/design/fit_components.dart';
import '../../core/design/fit_theme.dart';
import '../../core/design/fit_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Workout session — proposed new logging flow (sample data, no API).
//
// One screen for the whole workout: every set is pre-filled with the
// trainer's target, so most sets are a single tap on ✓. Ticking a set starts
// the rest timer automatically. In the real screen, saving will send the same
// `POST client/workout-logs` payload the app sends today.
// ─────────────────────────────────────────────────────────────────────────────

class _DemoSet {
  _DemoSet(this.weight, this.reps);
  double weight;
  int reps;
  bool done = false;
}

class _DemoExercise {
  _DemoExercise({
    required this.name,
    required this.muscles,
    required this.targetSets,
    required this.targetReps,
    required this.targetWeight,
    required this.restSeconds,
  }) : sets = List.generate(targetSets, (_) => _DemoSet(targetWeight, targetReps));

  final String name;
  final String muscles;
  final int targetSets;
  final int targetReps;
  final double targetWeight;
  final int restSeconds;
  final List<_DemoSet> sets;

  int get doneCount => sets.where((s) => s.done).length;
  bool get complete => doneCount == sets.length;
}

class WorkoutSessionDemo extends StatefulWidget {
  const WorkoutSessionDemo({super.key});

  @override
  State<WorkoutSessionDemo> createState() => _WorkoutSessionDemoState();
}

class _WorkoutSessionDemoState extends State<WorkoutSessionDemo> with AutomaticKeepAliveClientMixin {
  late List<_DemoExercise> _exercises;

  bool _started = false;
  Timer? _clock;
  Duration _elapsed = Duration.zero;

  Timer? _restTimer;
  Duration _restTotal = Duration.zero;
  Duration _restLeft = Duration.zero;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _exercises = _sampleWorkout();
  }

  List<_DemoExercise> _sampleWorkout() => [
        _DemoExercise(name: 'ضغط البنش بالبار', muscles: 'صدر · ترايسبس', targetSets: 4, targetReps: 10, targetWeight: 40, restSeconds: 90),
        _DemoExercise(name: 'سكوات', muscles: 'أرجل · مؤخرة', targetSets: 4, targetReps: 8, targetWeight: 60, restSeconds: 120),
        _DemoExercise(name: 'سحب أمامي', muscles: 'ظهر · بايسبس', targetSets: 3, targetReps: 12, targetWeight: 35, restSeconds: 60),
        _DemoExercise(name: 'رفع جانبي بالدمبل', muscles: 'أكتاف', targetSets: 3, targetReps: 15, targetWeight: 8, restSeconds: 45),
      ];

  @override
  void dispose() {
    _clock?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // ── Derived stats ────────────────────────────────────────────────
  int get _totalSets => _exercises.fold(0, (a, e) => a + e.sets.length);
  int get _doneSets => _exercises.fold(0, (a, e) => a + e.doneCount);
  double get _volume => _exercises.fold(
        0.0,
        (a, e) => a + e.sets.where((s) => s.done).fold(0.0, (b, s) => b + s.weight * s.reps),
      );

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Actions ──────────────────────────────────────────────────────
  void _start() {
    setState(() => _started = true);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed += const Duration(seconds: 1)));
  }

  void _toggleSet(_DemoExercise ex, _DemoSet set) {
    if (!_started) _start();
    setState(() => set.done = !set.done);
    if (set.done) {
      _startRest(Duration(seconds: ex.restSeconds));
    }
  }

  void _startRest(Duration d) {
    _restTimer?.cancel();
    setState(() {
      _restTotal = d;
      _restLeft = d;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restLeft.inSeconds <= 1) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _restLeft = Duration.zero);
      } else {
        setState(() => _restLeft -= const Duration(seconds: 1));
      }
    });
  }

  void _addRest() => setState(() {
        _restLeft += const Duration(seconds: 15);
        _restTotal += const Duration(seconds: 15);
      });

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restLeft = Duration.zero);
  }

  void _reset() {
    _clock?.cancel();
    _restTimer?.cancel();
    setState(() {
      _exercises = _sampleWorkout();
      _started = false;
      _elapsed = Duration.zero;
      _restLeft = Duration.zero;
    });
  }

  String? get _nextLabel {
    for (final e in _exercises) {
      final i = e.sets.indexWhere((s) => !s.done);
      if (i != -1) return '${e.name} · المجموعة ${i + 1}';
    }
    return null;
  }

  void _showInfo(_DemoExercise ex) {
    final c = context.fit;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      // Sheets open above this page, so they need the design-system scope again.
      builder: (_) => FitScope(
        colors: c,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(FitSpace.page, 0, FitSpace.page, FitSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ex.name, style: FitType.title.copyWith(color: c.foreground)),
              Text(ex.muscles, style: FitType.label.copyWith(color: c.mutedForeground)),
              const SizedBox(height: FitSpace.lg),
              Container(
                height: 160,
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: FitRadius.mdAll),
                alignment: Alignment.center,
                child: Icon(FLucideIcons.circlePlay, size: 44, color: c.mutedForeground),
              ),
              const SizedBox(height: FitSpace.lg),
              Text(
                'الفيديو وطريقة الأداء وملاحظات المدرب تظهر هنا، بدون مغادرة شاشة التمرين.',
                style: FitType.body.copyWith(color: c.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finish() {
    _clock?.cancel();
    _restTimer?.cancel();
    final c = context.fit;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      builder: (sheetContext) => FitScope(
        colors: c,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(FitSpace.page, 0, FitSpace.page, FitSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FitIconChip(icon: FLucideIcons.trophy, tone: FitTone.warning, size: 64),
              const SizedBox(height: FitSpace.lg),
              Text('أحسنت! أنهيت التمرين', style: FitType.title.copyWith(color: c.foreground)),
              const SizedBox(height: FitSpace.xs),
              Text('هذا ملخص جلستك', style: FitType.body.copyWith(color: c.mutedForeground)),
              const SizedBox(height: FitSpace.xl),
              Row(
                children: [
                  Expanded(child: FitStatTile(icon: FLucideIcons.timer, label: 'المدة', value: _fmt(_elapsed))),
                  const SizedBox(width: FitSpace.sm),
                  Expanded(
                    child: FitStatTile(
                      icon: FLucideIcons.listChecks,
                      label: 'المجموعات',
                      value: '$_doneSets/$_totalSets',
                      tone: FitTone.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FitSpace.sm),
              FitStatTile(
                icon: FLucideIcons.dumbbell,
                label: 'إجمالي الحجم (الوزن × العدّات)',
                value: _volume.round().toString(),
                unit: 'كجم',
                tone: FitTone.info,
              ),
              const SizedBox(height: FitSpace.xl),
              FButton(
                onPress: () => Navigator.pop(sheetContext),
                prefix: const Icon(FLucideIcons.check),
                child: const Text('حفظ التمرين'),
              ),
              const SizedBox(height: FitSpace.sm),
              Text(
                'في التطبيق الحقيقي: نفس طلب POST client/workout-logs الحالي',
                textAlign: TextAlign.center,
                style: FitType.caption.copyWith(color: c.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.fit;
    final resting = _restLeft > Duration.zero;
    final allDone = _doneSets == _totalSets;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(FitSpace.page, FitSpace.lg, FitSpace.page, resting ? 170 : 110),
          children: [
            _SessionHeader(
              elapsed: _fmt(_elapsed),
              started: _started,
              doneSets: _doneSets,
              totalSets: _totalSets,
              volume: _volume,
              onStart: _start,
              onReset: _reset,
            ),
            const SizedBox(height: FitSpace.lg),
            for (final ex in _exercises) ...[
              _ExerciseBlock(
                exercise: ex,
                onInfo: () => _showInfo(ex),
                onToggle: (s) => _toggleSet(ex, s),
                onChanged: () => setState(() {}),
                onAddSet: () => setState(() {
                  final last = ex.sets.isNotEmpty ? ex.sets.last : null;
                  ex.sets.add(_DemoSet(last?.weight ?? ex.targetWeight, last?.reps ?? ex.targetReps));
                }),
              ),
              const SizedBox(height: FitSpace.md),
            ],
          ],
        ),

        // Bottom area: rest timer (when resting) + finish button.
        Positioned(
          left: FitSpace.page,
          right: FitSpace.page,
          bottom: FitSpace.lg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => SizeTransition(sizeFactor: anim, child: FadeTransition(opacity: anim, child: child)),
                child: resting
                    ? Padding(
                        key: const ValueKey('rest'),
                        padding: const EdgeInsets.only(bottom: FitSpace.sm),
                        child: FitRestTimerBar(
                          remaining: _restLeft,
                          total: _restTotal,
                          onAdd: _addRest,
                          onSkip: _skipRest,
                          nextLabel: _nextLabel,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: FitRadius.mdAll,
                  boxShadow: [BoxShadow(color: c.background, blurRadius: 16, spreadRadius: 8)],
                ),
                child: FButton(
                  variant: allDone ? FButtonVariant.primary : FButtonVariant.outline,
                  onPress: _doneSets == 0 ? null : _finish,
                  prefix: const Icon(FLucideIcons.flag),
                  child: Text(allDone ? 'إنهاء التمرين' : 'إنهاء التمرين ($_doneSets/$_totalSets)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.elapsed,
    required this.started,
    required this.doneSets,
    required this.totalSets,
    required this.volume,
    required this.onStart,
    required this.onReset,
  });

  final String elapsed;
  final bool started;
  final int doneSets;
  final int totalSets;
  final double volume;
  final VoidCallback onStart;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return FitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تمرين اليوم', style: FitType.caption.copyWith(color: c.mutedForeground)),
                    Text('Full Body', style: FitType.title.copyWith(color: c.foreground)),
                  ],
                ),
              ),
              FButton.icon(onPress: onReset, child: const Icon(FLucideIcons.rotateCcw)),
            ],
          ),
          const SizedBox(height: FitSpace.lg),
          Row(
            children: [
              _HeaderStat(label: 'الوقت', value: elapsed),
              _HeaderStat(label: 'المجموعات', value: '$doneSets/$totalSets'),
              _HeaderStat(label: 'الحجم', value: '${volume.round()}'),
            ],
          ),
          const SizedBox(height: FitSpace.md),
          FDeterminateProgress(value: totalSets == 0 ? 0 : doneSets / totalSets),
          if (!started) ...[
            const SizedBox(height: FitSpace.lg),
            FButton(onPress: onStart, prefix: const Icon(FLucideIcons.play), child: const Text('ابدأ التمرين')),
          ],
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: FitType.number.copyWith(fontSize: 22, color: c.foreground)),
          Text(label, style: FitType.caption.copyWith(color: c.mutedForeground)),
        ],
      ),
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.exercise,
    required this.onInfo,
    required this.onToggle,
    required this.onChanged,
    required this.onAddSet,
  });

  final _DemoExercise exercise;
  final VoidCallback onInfo;
  final ValueChanged<_DemoSet> onToggle;
  final VoidCallback onChanged;
  final VoidCallback onAddSet;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final ex = exercise;
    return FitCard(
      padding: const EdgeInsets.fromLTRB(FitSpace.sm, FitSpace.md, FitSpace.sm, FitSpace.xs),
      borderColor: ex.complete ? c.success.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FitSpace.sm),
            child: Row(
              children: [
                FitIconChip(
                  icon: ex.complete ? FLucideIcons.check : FLucideIcons.dumbbell,
                  tone: ex.complete ? FitTone.success : FitTone.brand,
                ),
                const SizedBox(width: FitSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name, style: FitType.bodyStrong.copyWith(color: c.foreground)),
                      Text(
                        '${ex.muscles} · الهدف ${ex.targetSets}×${ex.targetReps}',
                        style: FitType.caption.copyWith(color: c.mutedForeground),
                      ),
                    ],
                  ),
                ),
                FitBadge(
                  label: '${ex.doneCount}/${ex.sets.length}',
                  tone: ex.complete ? FitTone.success : FitTone.neutral,
                ),
                const SizedBox(width: FitSpace.xs),
                FButton.icon(
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  onPress: onInfo,
                  child: const Icon(FLucideIcons.info),
                ),
              ],
            ),
          ),
          const SizedBox(height: FitSpace.md),
          const FitSetHeader(),
          const SizedBox(height: FitSpace.xs),
          for (var i = 0; i < ex.sets.length; i++)
            FitSetRow(
              index: i,
              weight: ex.sets[i].weight,
              reps: ex.sets[i].reps,
              done: ex.sets[i].done,
              onWeightChanged: (v) {
                ex.sets[i].weight = v;
                onChanged();
              },
              onRepsChanged: (v) {
                ex.sets[i].reps = v;
                onChanged();
              },
              onToggleDone: () => onToggle(ex.sets[i]),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FButton(
              variant: FButtonVariant.ghost,
              size: FButtonSizeVariant.sm,
              mainAxisSize: MainAxisSize.min,
              onPress: onAddSet,
              prefix: const Icon(FLucideIcons.plus),
              child: const Text('إضافة مجموعة'),
            ),
          ),
        ],
      ),
    );
  }
}
