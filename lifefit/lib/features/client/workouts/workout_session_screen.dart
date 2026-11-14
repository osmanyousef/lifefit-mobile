import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/design/fit_components.dart';
import '../../../core/design/fit_media.dart';
import '../../../core/design/fit_theme.dart';
import '../../../core/design/fit_tokens.dart';
import '../../../core/models/workout/today_schedule.dart';
import 'session/workout_session.dart';
import 'session/workout_sessions_provider.dart';
import 'workout_provider.dart';
import 'workouts_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// One scheduled workout: cover header → collapsible exercise cards → sets table.
//
// • Tap an exercise to open / close it. Finishing one opens the next.
// • The table adapts to the trainer's prescription:
//     #  · الهدف · [الوزن | % من 1RM | RPE] · [العدّات | المدة] · ✓
//   Every set starts with the target, so most sets are one tap on ✓.
//   Tap a value to change it (big steppers + an optional note).
// • The round ✓ on the header marks the whole exercise done at once.
// • The exercise picture (or the small play icon under the table) opens the
//   video / picture, description and trainer notes — only when wanted.
// • Ticked sets are kept as a local draft; "إنهاء الجلسة" sends them all in one
//   `POST client/workout-logs` (see workout_session.dart for the payload).
// • No timers anywhere.
// ─────────────────────────────────────────────────────────────────────────────

const double _headerHeight = 232;

String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key, required this.scheduleId, required this.number});

  final int scheduleId;

  /// 1-based position of this workout in today's list.
  final int number;

  @override
  ConsumerState<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  final Set<String> _open = {};
  bool _openedFirst = false;

  WorkoutSessionsNotifier get _sessions => ref.read(workoutSessionsProvider.notifier);

  // ── Actions ──────────────────────────────────────────────────────
  void _changed(WorkoutSession session, VoidCallback fn) {
    setState(fn);
    _sessions.changed(session);
  }

  /// When an exercise becomes complete: close it and open the next unfinished one.
  void _afterChange(WorkoutSession session, ExerciseSession ex, {required bool wasComplete}) {
    if (wasComplete || !ex.complete) return;
    HapticFeedback.heavyImpact();
    _open.remove(ex.key);
    final all = session.exercises;
    final i = all.indexOf(ex);
    ExerciseSession? next;
    for (var j = i + 1; j < all.length; j++) {
      if (!all[j].complete) {
        next = all[j];
        break;
      }
    }
    next ??= all.where((e) => !e.complete).firstOrNull;
    if (next != null) _open.add(next.key);
  }

  void _toggleOpen(ExerciseSession ex) => setState(() => _open.contains(ex.key) ? _open.remove(ex.key) : _open.add(ex.key));

  void _toggleSet(WorkoutSession session, ExerciseSession ex, SetEntry set) {
    final was = ex.complete;
    _changed(session, () {
      set.done = !set.done;
      _afterChange(session, ex, wasComplete: was);
    });
  }

  void _toggleAll(WorkoutSession session, ExerciseSession ex) {
    final was = ex.complete;
    HapticFeedback.mediumImpact();
    _changed(session, () {
      final target = !was;
      for (final s in ex.sets) {
        s.done = target;
      }
      if (!target) _open.add(ex.key);
      _afterChange(session, ex, wasComplete: was);
    });
  }

  void _addSet(WorkoutSession session, ExerciseSession ex) => _changed(session, () {
        final last = ex.sets.isNotEmpty ? ex.sets.last : null;
        final next = last != null ? (last.copy()..done = false..note = null) : SetEntry.fromPlan(ex.plan);
        ex.sets.add(next);
      });

  void _removeSet(WorkoutSession session, ExerciseSession ex, int index) => _changed(session, () {
        ex.sets.removeAt(index);
      });

  Future<void> _confirmDiscard(WorkoutSession session) async {
    final c = context.fit;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => FitScope(
        colors: c,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text('تجاهل التغييرات؟', style: FitType.heading.copyWith(color: c.foreground)),
          content: Text(
            session.saved
                ? 'سيعود التسجيل كما هو محفوظ.'
                : 'سيتم مسح كل المجموعات التي سجلتها في هذه الجلسة.',
            style: FitType.body.copyWith(color: c.mutedForeground),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: c.danger),
              child: const Text('تجاهل'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(_open.clear);
      _openedFirst = false;
      _sessions.discard(session.scheduleId);
    }
  }

  // ── Sheets ───────────────────────────────────────────────────────
  void _editSet(WorkoutSession session, ExerciseSession ex, int index) {
    final c = context.fit;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      shape: fitSheetShape,
      builder: (_) => FitScope(
        colors: c,
        child: _SetEditSheet(
          exercise: ex,
          index: index,
          onChanged: () => _changed(session, () {}),
          onSaveAndDone: () {
            final set = ex.sets[index];
            if (!set.done) _toggleSet(session, ex, set);
          },
          onRemove: ex.sets.length > 1 ? () => _removeSet(session, ex, index) : null,
        ),
      ),
    );
  }

  void _showGuide(ExerciseSession ex) {
    final e = ex.exercise;
    final p = ex.plan;
    final rest = p.restSeconds;
    showExerciseGuideSheet(
      context,
      colors: context.fit,
      title: e.name,
      subtitle: e.muscles,
      pictures: [if (e.imageUrl != null) e.imageUrl!],
      videoUrl: e.videoUrl,
      description: e.description,
      tips: [if (p.notes != null && p.notes!.trim().isNotEmpty) p.notes!.trim()],
      facts: [
        GuideFact(FLucideIcons.listChecks, p.summary),
        if (rest != null && rest > 0)
          GuideFact(FLucideIcons.timer, 'راحة ${rest >= 60 && rest % 60 == 0 ? '${rest ~/ 60} د' : '$rest ث'}'),
        if (p.tempo != null && p.tempo!.trim().isNotEmpty) GuideFact(FLucideIcons.repeat, 'الإيقاع ${ltr(p.tempo!.trim())}'),
        if (e.category != null && e.category!.trim().isNotEmpty) GuideFact(FLucideIcons.dumbbell, e.category!.trim()),
      ],
    );
  }

  void _finish(WorkoutSession session) {
    final c = context.fit;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      shape: fitSheetShape,
      builder: (_) => FitScope(
        colors: c,
        child: _FinishSheet(
          session: session,
          onSubmit: () {
            final logs = session.toExerciseLogs();
            if (kDebugMode) {
              debugPrint('[WorkoutSession] POST client/workout-logs schedule=${session.scheduleId} '
                  'sets=${logs.length} ${jsonEncode([for (final l in logs) l.toJson()])}');
            }
            return ref.read(todaySchedulesProvider.notifier).submitWorkoutLog(
                  scheduleId: session.scheduleId,
                  exerciseLogs: logs,
                  actualDurationMinutes: session.durationMinutes,
                  notes: session.notes?.trim(),
                );
          },
          onChanged: () => _sessions.changed(session),
        ),
      ),
    ).then((saved) {
      if (saved != true || !mounted) return;
      _sessions.saved(session.scheduleId);
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).maybePop();
      messenger?.showSnackBar(const SnackBar(content: Text('تم حفظ الجلسة، أحسنت!')));
    });
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final schedules = ref.watch(todaySchedulesProvider).valueOrNull;
    ref.watch(workoutSessionsProvider);

    TodaySchedule? schedule;
    for (final s in schedules ?? const <TodaySchedule>[]) {
      if (s.scheduleId == widget.scheduleId) schedule = s;
    }
    if (schedule == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(),
        body: Center(
          child: FitEmptyState(
            icon: FLucideIcons.dumbbell,
            title: 'هذه الجلسة غير متاحة الآن',
            message: 'اسحب للتحديث في صفحة التمارين.',
          ),
        ),
      );
    }

    final session = _sessions.of(schedule);
    if (!_openedFirst) {
      _openedFirst = true;
      final first = session.exercises.where((e) => !e.complete).firstOrNull;
      if (first != null && !session.saved) _open.add(first.key);
    }
    final topPad = MediaQuery.paddingOf(context).top;
    var number = 0;

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _CoverHeader(
                schedule: schedule,
                number: widget.number,
                topPad: topPad,
                onDiscard: session.dirty ? () => _confirmDiscard(session) : null,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(FitSpace.page, FitSpace.lg, FitSpace.page, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (session.saved && !session.dirty) ...[
                      _SavedBanner(reviewed: schedule.workoutLog?.trainerReviewed == true),
                      const SizedBox(height: FitSpace.md),
                    ],
                    _SummaryStrip(session: session),
                    const SizedBox(height: FitSpace.xl),
                    FitSectionHeader(
                      title: 'التمارين',
                      subtitle: '${session.exercises.length} تمارين · ${session.totalSets} مجموعة',
                      trailing: FitBadge(
                        label: '${session.doneExercises}/${session.exercises.length}',
                        tone: session.complete ? FitTone.success : FitTone.neutral,
                      ),
                    ),
                    if (session.exercises.isEmpty)
                      const FitEmptyState(
                        icon: FLucideIcons.dumbbell,
                        title: 'لا توجد تمارين في هذه الجلسة',
                        message: 'تواصل مع مدربك.',
                      ),
                    for (final ex in session.exercises) ...[
                      _ExerciseCard(
                        number: ++number,
                        exercise: ex,
                        open: _open.contains(ex.key),
                        onToggleOpen: () => _toggleOpen(ex),
                        onToggleAll: () => _toggleAll(session, ex),
                        onToggleSet: (s) => _toggleSet(session, ex, s),
                        onEditSet: (i) => _editSet(session, ex, i),
                        onAddSet: () => _addSet(session, ex),
                        onGuide: () => _showGuide(ex),
                      ),
                      const SizedBox(height: FitSpace.md),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // Finish / save button pinned to the bottom.
          Positioned(
            left: FitSpace.page,
            right: FitSpace.page,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: FitSpace.lg),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: FitRadius.mdAll,
                  boxShadow: [BoxShadow(color: c.background, blurRadius: 16, spreadRadius: 8)],
                ),
                child: _BottomAction(session: session, onFinish: () => _finish(session)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.session, required this.onFinish});

  final WorkoutSession session;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (s.saved && !s.dirty) {
      return FButton(
        variant: FButtonVariant.outline,
        onPress: null,
        prefix: const Icon(FLucideIcons.check),
        child: const Text('الجلسة محفوظة'),
      );
    }
    if (s.saved) {
      return FButton(
        onPress: s.doneSets == 0 ? null : onFinish,
        prefix: const Icon(FLucideIcons.check),
        child: Text(s.doneSets == 0 ? 'سجّل مجموعة واحدة على الأقل' : 'حفظ التعديلات'),
      );
    }
    return FButton(
      variant: s.complete ? FButtonVariant.primary : FButtonVariant.outline,
      onPress: s.doneSets == 0 ? null : onFinish,
      prefix: const Icon(FLucideIcons.flag),
      child: Text(s.complete ? 'إنهاء الجلسة' : 'إنهاء الجلسة (${s.doneSets}/${s.totalSets})'),
    );
  }
}

// ── Cover header (collapses into a plain app bar) ────────────────────────────

class _CoverHeader extends StatelessWidget {
  const _CoverHeader({required this.schedule, required this.number, required this.topPad, this.onDiscard});

  final TodaySchedule schedule;
  final int number;
  final double topPad;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final w = schedule.workout;
    final difficulty = workoutDifficultyLabel(w.difficulty);
    final info = [
      '${w.exercises.length} تمارين',
      if ((w.estimatedDuration ?? 0) > 0) '${w.estimatedDuration} د',
      if (difficulty != null) difficulty,
    ].join(' · ');

    return SliverAppBar(
      pinned: true,
      expandedHeight: _headerHeight,
      automaticallyImplyLeading: false,
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: FitSpace.md),
        child: Center(child: _RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context))),
      ),
      actions: [
        if (onDiscard != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: FitSpace.md),
            child: _RoundButton(icon: FLucideIcons.undo2, onTap: onDiscard!, tooltip: 'تجاهل التغييرات'),
          ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final minHeight = kToolbarHeight + topPad;
          // 1 = fully open, 0 = collapsed into the toolbar.
          final t = ((constraints.maxHeight - minHeight) / (_headerHeight - kToolbarHeight)).clamp(0.0, 1.0).toDouble();
          final coverOpacity = ((t - 0.2) / 0.8).clamp(0.0, 1.0).toDouble();
          final titleOpacity = (1 - t * 2.5).clamp(0.0, 1.0).toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: coverOpacity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(tag: 'workout-cover-${schedule.scheduleId}', child: WorkoutCover(schedule: schedule)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66000000), Color(0x0D000000), Color(0xD9000000)],
                          stops: [0, 0.4, 1],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: FitSpace.page,
                      end: FitSpace.page,
                      bottom: FitSpace.lg,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PhotoPill(label: 'الجلسة $number'),
                              const SizedBox(width: FitSpace.sm),
                              PhotoPill(label: workoutTypeLabel(w.type), icon: FLucideIcons.flame),
                            ],
                          ),
                          const SizedBox(height: FitSpace.sm),
                          Text(
                            w.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FitType.display.copyWith(color: kOnPhoto),
                          ),
                          Text(info, style: FitType.label.copyWith(color: kOnPhoto.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Title shown once the cover has collapsed.
              PositionedDirectional(
                top: topPad,
                start: 64,
                end: 64,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: titleOpacity,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        w.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FitType.heading.copyWith(color: c.foreground),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Opacity(opacity: titleOpacity, child: Divider(height: 1, thickness: 1, color: c.border)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final button = Material(
      color: c.surface.withValues(alpha: 0.92),
      shape: CircleBorder(side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: c.foreground)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

// ── Summary + banner ─────────────────────────────────────────────────────────

class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.reviewed});

  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Container(
      padding: const EdgeInsets.all(FitSpace.md),
      decoration: BoxDecoration(color: c.successSoft, borderRadius: FitRadius.mdAll),
      child: Row(
        children: [
          Icon(FLucideIcons.badgeCheck, color: c.success, size: 22),
          const SizedBox(width: FitSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewed ? 'محفوظة وراجعها مدربك' : 'تم حفظ هذه الجلسة',
                  style: FitType.bodyStrong.copyWith(color: c.foreground),
                ),
                Text(
                  'يمكنك تعديل أي مجموعة ثم حفظ التعديلات.',
                  style: FitType.caption.copyWith(color: c.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final s = session;
    final hasVolume = s.exercises.any((e) => e.plan.load == LoadKind.weight && e.plan.amount == AmountKind.reps);
    final description = s.schedule.workout.description?.trim();
    return FitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description != null && description.isNotEmpty) ...[
            Text(description, style: FitType.body.copyWith(color: c.mutedForeground)),
            const SizedBox(height: FitSpace.md),
          ],
          Row(
            children: [
              _MiniStat(value: '${s.doneExercises}/${s.exercises.length}', label: 'التمارين'),
              _MiniStat(value: '${s.doneSets}/${s.totalSets}', label: 'المجموعات'),
              if (hasVolume)
                _MiniStat(value: '${s.volume.round()}', label: 'الحجم (كجم)')
              else
                _MiniStat(value: '${(s.progress * 100).round()}%', label: 'الإنجاز'),
            ],
          ),
          const SizedBox(height: FitSpace.md),
          FitProgressBar(value: s.progress, color: s.complete ? c.success : null),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ltr(value), style: FitType.number.copyWith(fontSize: 22, color: c.foreground)),
          Text(label, style: FitType.caption.copyWith(color: c.mutedForeground)),
        ],
      ),
    );
  }
}

// ── Collapsible exercise card ────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.number,
    required this.exercise,
    required this.open,
    required this.onToggleOpen,
    required this.onToggleAll,
    required this.onToggleSet,
    required this.onEditSet,
    required this.onAddSet,
    required this.onGuide,
  });

  final int number;
  final ExerciseSession exercise;
  final bool open;
  final VoidCallback onToggleOpen;
  final VoidCallback onToggleAll;
  final ValueChanged<SetEntry> onToggleSet;
  final ValueChanged<int> onEditSet;
  final VoidCallback onAddSet;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final ex = exercise;
    final e = ex.exercise;
    final hasVideo = e.videoUrl != null && e.videoUrl!.trim().isNotEmpty;
    final trainerNote = ex.plan.notes?.trim();
    final border = ex.complete
        ? c.success.withValues(alpha: 0.5)
        : (open ? c.toneFg(FitTone.brand).withValues(alpha: 0.45) : null);

    return FitCard(
      padding: EdgeInsets.zero,
      borderColor: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — always visible, tap to open / close.
          InkWell(
            onTap: onToggleOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(FitSpace.md, FitSpace.md, FitSpace.sm, FitSpace.md),
              child: Row(
                children: [
                  _Thumb(number: number, exercise: ex, hasVideo: hasVideo, onTap: onGuide),
                  const SizedBox(width: FitSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitType.bodyStrong.copyWith(
                            color: ex.complete ? c.mutedForeground : c.foreground,
                            decoration: ex.complete ? TextDecoration.lineThrough : null,
                            decorationColor: c.mutedForeground,
                          ),
                        ),
                        if (e.muscles != null && e.muscles!.trim().isNotEmpty)
                          Text(
                            e.muscles!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FitType.caption.copyWith(color: c.mutedForeground),
                          ),
                        const SizedBox(height: FitSpace.xs + 2),
                        Row(
                          children: [
                            Flexible(
                              child: FitBadge(label: ex.plan.summary, tone: ex.complete ? FitTone.success : FitTone.brand),
                            ),
                            const SizedBox(width: FitSpace.sm),
                            _SetDots(total: ex.sets.length, done: ex.doneCount),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: FitSpace.sm),
                  _CheckAllButton(done: ex.complete, onTap: onToggleAll),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Padding(
                      padding: const EdgeInsets.all(FitSpace.xs),
                      child: Icon(FLucideIcons.chevronDown, size: 20, color: c.mutedForeground),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body — opens / closes with animation.
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, thickness: 1, color: c.border),
                      if (trainerNote != null && trainerNote.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(FitSpace.md, FitSpace.sm, FitSpace.md, 0),
                          child: InkWell(
                            onTap: onGuide,
                            borderRadius: FitRadius.smAll,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: FitSpace.sm, vertical: FitSpace.xs + 2),
                              decoration: BoxDecoration(color: c.brandSoft, borderRadius: FitRadius.smAll),
                              child: Row(
                                children: [
                                  Icon(FLucideIcons.messageSquare, size: 14, color: c.toneFg(FitTone.brand)),
                                  const SizedBox(width: FitSpace.sm),
                                  Expanded(
                                    child: Text(
                                      trainerNote,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: FitType.caption.copyWith(color: c.foreground),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: FitSpace.sm),
                        child: _TableHeader(plan: ex.plan),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: FitSpace.sm),
                        child: Column(
                          children: [
                            for (var i = 0; i < ex.sets.length; i++)
                              _SetTableRow(
                                index: i,
                                exercise: ex,
                                set: ex.sets[i],
                                onEdit: () => onEditSet(i),
                                onToggle: () => onToggleSet(ex.sets[i]),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(FitSpace.sm, FitSpace.xs, FitSpace.sm, FitSpace.sm),
                        child: Row(
                          children: [
                            FButton(
                              variant: FButtonVariant.ghost,
                              size: FButtonSizeVariant.sm,
                              mainAxisSize: MainAxisSize.min,
                              onPress: onAddSet,
                              prefix: const Icon(FLucideIcons.plus),
                              child: const Text('إضافة مجموعة'),
                            ),
                            const Spacer(),
                            // Small way into the video / picture, for when it's needed.
                            FButton.icon(
                              variant: FButtonVariant.ghost,
                              size: FButtonSizeVariant.sm,
                              onPress: onGuide,
                              child: Icon(hasVideo ? FLucideIcons.circlePlay : FLucideIcons.info),
                            ),
                            const SizedBox(width: FitSpace.xs),
                            FButton(
                              variant: ex.complete ? FButtonVariant.outline : FButtonVariant.secondary,
                              size: FButtonSizeVariant.sm,
                              mainAxisSize: MainAxisSize.min,
                              onPress: onToggleAll,
                              prefix: const Icon(FLucideIcons.listChecks),
                              child: Text(ex.complete ? 'إلغاء الكل' : 'تمّ الكل'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Exercise picture with its number; turns green with a ✓ when done.
/// Tapping it opens the video / picture (the badge in the corner hints at it).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.number, required this.exercise, required this.hasVideo, required this.onTap});

  final int number;
  final ExerciseSession exercise;
  final bool hasVideo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final ex = exercise;
    return ClipRRect(
      borderRadius: FitRadius.smAll,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FitPicture(ex.exercise.imageUrl),
            AnimatedOpacity(
              opacity: ex.complete ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: ColoredBox(
                color: c.success.withValues(alpha: 0.82),
                child: const Icon(FLucideIcons.check, size: 26, color: kOnPhoto),
              ),
            ),
            if (!ex.complete)
              PositionedDirectional(
                top: 4,
                start: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: kPhotoScrim, shape: BoxShape.circle),
                  child: Text(
                    '$number',
                    style: FitType.caption.copyWith(color: kOnPhoto, fontWeight: FontWeight.w800, fontSize: 10, height: 1),
                  ),
                ),
              ),
            PositionedDirectional(
              bottom: 4,
              end: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: hasVideo ? c.primary : kPhotoScrim,
                  shape: BoxShape.circle,
                  border: Border.all(color: kOnPhoto, width: 1.5),
                ),
                child: Icon(
                  hasVideo ? FLucideIcons.play : FLucideIcons.info,
                  size: 10,
                  color: hasVideo ? c.onPrimary : kOnPhoto,
                ),
              ),
            ),
            Positioned.fill(
              child: Material(color: Colors.transparent, child: InkWell(onTap: onTap)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small progress pills, one per set.
class _SetDots extends StatelessWidget {
  const _SetDots({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total && i < 6; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsetsDirectional.only(end: 3),
            width: 10,
            height: 4,
            decoration: BoxDecoration(
              color: i < done ? c.success : c.border,
              borderRadius: FitRadius.pillAll,
            ),
          ),
        const SizedBox(width: FitSpace.xxs),
        Text(ltr('$done/$total'), style: FitType.caption.copyWith(color: c.mutedForeground, fontSize: 11)),
      ],
    );
  }
}

/// Round ✓ that marks the whole exercise done (or undone).
class _CheckAllButton extends StatelessWidget {
  const _CheckAllButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? c.success : Colors.transparent,
          border: Border.all(color: done ? c.success : c.border, width: 2),
        ),
        child: Icon(FLucideIcons.check, size: 18, color: done ? c.surface : c.mutedForeground),
      ),
    );
  }
}

// ── Sets table ───────────────────────────────────────────────────────────────

const _colSet = 34.0;
const _colDone = 44.0;

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.plan});

  final ExercisePlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final style = FitType.caption.copyWith(color: c.mutedForeground, fontWeight: FontWeight.w700);
    Widget cell(String t, int flex) => Expanded(flex: flex, child: Text(t, textAlign: TextAlign.center, style: style));
    final load = plan.loadLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FitSpace.xs, vertical: FitSpace.sm),
      child: Row(
        children: [
          SizedBox(width: _colSet, child: Text('#', textAlign: TextAlign.center, style: style)),
          cell('الهدف', 4),
          if (load != null) ...[
            cell(load, 4),
            const SizedBox(width: FitSpace.xs),
          ],
          cell(plan.amountLabel, load != null ? 3 : 4),
          SizedBox(width: _colDone, child: Icon(FLucideIcons.check, size: 14, color: c.mutedForeground)),
        ],
      ),
    );
  }
}

class _SetTableRow extends StatelessWidget {
  const _SetTableRow({
    required this.index,
    required this.exercise,
    required this.set,
    required this.onEdit,
    required this.onToggle,
  });

  final int index;
  final ExerciseSession exercise;
  final SetEntry set;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  bool get _isExtra => index >= exercise.plan.targetSets;

  /// Above target → success, below → warning, equal / unknown → normal text.
  Color _valueColor(FitColors c, num? actual, num? target) {
    if (_isExtra || actual == null || target == null) return c.foreground;
    if (actual > target) return c.success;
    if (actual < target) return c.warning;
    return c.foreground;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final p = exercise.plan;
    final done = set.done;
    final hasNote = set.note != null && set.note!.trim().isNotEmpty;

    String loadValue() => switch (p.load) {
          LoadKind.weight => set.weight == null ? '—' : _num(set.weight!),
          LoadKind.percentage => set.percentage == null ? '—' : '${set.percentage}%',
          LoadKind.rpe => set.rpe == null ? '—' : '${set.rpe}',
          LoadKind.none => '',
        };
    Color loadColor() => switch (p.load) {
          LoadKind.weight => _valueColor(c, set.weight, p.targetWeight),
          LoadKind.percentage => _valueColor(c, set.percentage, p.targetPercentage),
          _ => c.foreground,
        };
    final byReps = p.amount == AmountKind.reps;
    final amountValue = byReps ? (set.reps?.toString() ?? '—') : p.durationNumber(set.durationSeconds);
    final amountColor = byReps
        ? _valueColor(c, set.reps, p.targetReps)
        : _valueColor(c, set.durationSeconds, p.targetDurationSeconds);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: FitSpace.xs),
      padding: const EdgeInsets.symmetric(horizontal: FitSpace.xs, vertical: FitSpace.xs),
      decoration: BoxDecoration(
        color: done ? c.successSoft : Colors.transparent,
        borderRadius: FitRadius.smAll,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _colSet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: FitType.bodyStrong.copyWith(color: done ? c.success : c.mutedForeground),
                ),
                if (hasNote) Icon(FLucideIcons.stickyNote, size: 11, color: c.mutedForeground),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _isExtra ? 'إضافية' : p.targetCell,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FitType.label.copyWith(color: c.mutedForeground, fontFeatures: FitType.number.fontFeatures),
            ),
          ),
          if (p.load != LoadKind.none) ...[
            Expanded(
              flex: 4,
              child: _ValueCell(text: loadValue(), color: done ? c.success : loadColor(), done: done, onTap: onEdit),
            ),
            const SizedBox(width: FitSpace.xs),
          ],
          Expanded(
            flex: p.load != LoadKind.none ? 3 : 4,
            child: _ValueCell(text: amountValue, color: done ? c.success : amountColor, done: done, onTap: onEdit),
          ),
          SizedBox(width: _colDone, child: Center(child: _SetDoneButton(done: done, onTap: onToggle))),
        ],
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.text, required this.color, required this.done, required this.onTap});

  final String text;
  final Color color;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Material(
      color: done ? Colors.transparent : c.surfaceAlt,
      borderRadius: FitRadius.smAll,
      child: InkWell(
        borderRadius: FitRadius.smAll,
        onTap: onTap,
        child: SizedBox(
          height: 38,
          child: Center(
            child: Text(
              text,
              style: FitType.bodyStrong.copyWith(color: color, fontFeatures: FitType.number.fontFeatures),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetDoneButton extends StatelessWidget {
  const _SetDoneButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Material(
      color: done ? c.success : c.surfaceAlt,
      borderRadius: FitRadius.smAll,
      child: InkWell(
        borderRadius: FitRadius.smAll,
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(FLucideIcons.check, size: 18, color: done ? c.surface : c.mutedForeground),
        ),
      ),
    );
  }
}

// ── Edit one set ─────────────────────────────────────────────────────────────

class _SetEditSheet extends StatefulWidget {
  const _SetEditSheet({
    required this.exercise,
    required this.index,
    required this.onChanged,
    required this.onSaveAndDone,
    this.onRemove,
  });

  final ExerciseSession exercise;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onSaveAndDone;
  final VoidCallback? onRemove;

  @override
  State<_SetEditSheet> createState() => _SetEditSheetState();
}

class _SetEditSheetState extends State<_SetEditSheet> {
  late final TextEditingController _note;

  SetEntry get _set => widget.exercise.sets[widget.index];
  ExercisePlan get _plan => widget.exercise.plan;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: _set.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  void _saveNote() {
    final text = _note.text.trim();
    final value = text.isEmpty ? null : text;
    if (value != _set.note) _update(() => _set.note = value);
  }

  Widget _loadStepper() {
    final s = _set;
    return switch (_plan.load) {
      LoadKind.weight => _SheetStepperRow(
          label: 'الوزن',
          unit: 'كجم',
          child: FitStepper(
            value: s.weight ?? _plan.targetWeight ?? 0,
            step: 2.5,
            max: 999,
            decimals: 1,
            onChanged: (v) => _update(() => s.weight = v),
          ),
        ),
      LoadKind.percentage => _SheetStepperRow(
          label: 'النسبة',
          unit: '% من 1RM',
          child: FitStepper(
            value: (s.percentage ?? _plan.targetPercentage ?? 70).toDouble(),
            step: 5,
            max: 200,
            onChanged: (v) => _update(() => s.percentage = v.round()),
          ),
        ),
      LoadKind.rpe => _SheetStepperRow(
          label: 'الجهد',
          unit: 'RPE 1-10',
          child: FitStepper(
            value: (s.rpe ?? _plan.targetRpe ?? 7).toDouble(),
            min: 1,
            max: 10,
            onChanged: (v) => _update(() => s.rpe = v.round()),
          ),
        ),
      LoadKind.none => const SizedBox.shrink(),
    };
  }

  Widget _amountStepper() {
    final s = _set;
    if (_plan.amount == AmountKind.reps) {
      return _SheetStepperRow(
        label: 'العدّات',
        child: FitStepper(
          value: (s.reps ?? _plan.targetReps ?? 0).toDouble(),
          max: 100,
          onChanged: (v) => _update(() => s.reps = v.round()),
        ),
      );
    }
    final seconds = s.durationSeconds ?? _plan.targetDurationSeconds ?? 60;
    if (_plan.durationInMinutes) {
      return _SheetStepperRow(
        label: 'المدة',
        unit: 'دقيقة',
        child: FitStepper(
          value: (seconds / 60).roundToDouble(),
          max: 300,
          onChanged: (v) => _update(() => s.durationSeconds = (v * 60).round()),
        ),
      );
    }
    return _SheetStepperRow(
      label: 'المدة',
      unit: 'ثانية',
      child: FitStepper(
        value: seconds.toDouble(),
        step: 5,
        max: 3600,
        onChanged: (v) => _update(() => s.durationSeconds = v.round()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final ex = widget.exercise;
    final isExtra = widget.index >= _plan.targetSets;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(FitSpace.page, 0, FitSpace.page, FitSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.exercise.name, style: FitType.heading.copyWith(color: c.foreground)),
                        Text(
                          isExtra
                              ? 'المجموعة ${widget.index + 1} · إضافية'
                              : 'المجموعة ${widget.index + 1} · الهدف ${_plan.targetCell}',
                          style: FitType.label.copyWith(color: c.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onRemove != null)
                    FButton.icon(
                      variant: FButtonVariant.ghost,
                      onPress: () {
                        Navigator.pop(context);
                        widget.onRemove!();
                      },
                      child: Icon(FLucideIcons.trash2, color: c.danger),
                    ),
                ],
              ),
              const SizedBox(height: FitSpace.lg),
              if (_plan.load != LoadKind.none) ...[
                _loadStepper(),
                const SizedBox(height: FitSpace.md),
              ],
              _amountStepper(),
              const SizedBox(height: FitSpace.md),
              TextField(
                controller: _note,
                onChanged: (_) => _saveNote(),
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.done,
                style: FitType.body.copyWith(color: c.foreground),
                decoration: InputDecoration(
                  hintText: 'ملاحظة على المجموعة (اختياري)',
                  hintStyle: FitType.body.copyWith(color: c.mutedForeground),
                  prefixIcon: Icon(FLucideIcons.stickyNote, size: 18, color: c.mutedForeground),
                  filled: true,
                  fillColor: c.surfaceAlt,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: FitRadius.mdAll, borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: FitSpace.xl),
              FButton(
                onPress: () {
                  _saveNote();
                  Navigator.pop(context);
                  widget.onSaveAndDone();
                },
                prefix: const Icon(FLucideIcons.check),
                child: Text(_set.done ? 'حفظ' : 'حفظ وتمّت المجموعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetStepperRow extends StatelessWidget {
  const _SheetStepperRow({required this.label, required this.child, this.unit});

  final String label;
  final String? unit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FitSpace.md, vertical: FitSpace.sm),
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: FitRadius.mdAll),
      child: Row(
        children: [
          Text(label, style: FitType.bodyStrong.copyWith(color: c.foreground)),
          if (unit != null) ...[
            const SizedBox(width: FitSpace.xs),
            Text(unit!, style: FitType.caption.copyWith(color: c.mutedForeground)),
          ],
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

// ── Finish / save ────────────────────────────────────────────────────────────

class _FinishSheet extends StatefulWidget {
  const _FinishSheet({required this.session, required this.onSubmit, required this.onChanged});

  final WorkoutSession session;

  /// Sends the log; throws on failure.
  final Future<void> Function() onSubmit;
  final VoidCallback onChanged;

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  late final TextEditingController _notes;
  bool _saving = false;
  String? _error;

  WorkoutSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: _s.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final s = _s;
    final remaining = s.totalSets - s.doneSets;
    final estimated = s.schedule.workout.estimatedDuration;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(FitSpace.page, 0, FitSpace.page, FitSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FitIconChip(icon: FLucideIcons.trophy, tone: FitTone.warning, size: 64),
              const SizedBox(height: FitSpace.lg),
              Text(
                s.saved ? 'حفظ التعديلات' : (s.complete ? 'أحسنت! أنهيت الجلسة' : 'إنهاء الجلسة؟'),
                style: FitType.title.copyWith(color: c.foreground),
              ),
              const SizedBox(height: FitSpace.xs),
              Text(
                remaining > 0
                    ? 'بقيت $remaining مجموعة غير مسجّلة — ستُحفظ المجموعات المنجزة فقط'
                    : 'هذا ملخص ${s.schedule.workout.name}',
                textAlign: TextAlign.center,
                style: FitType.body.copyWith(color: c.mutedForeground),
              ),
              const SizedBox(height: FitSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: FitStatTile(
                      icon: FLucideIcons.dumbbell,
                      label: 'التمارين',
                      value: ltr('${s.startedExercises}/${s.exercises.length}'),
                    ),
                  ),
                  const SizedBox(width: FitSpace.sm),
                  Expanded(
                    child: FitStatTile(
                      icon: FLucideIcons.listChecks,
                      label: 'المجموعات',
                      value: ltr('${s.doneSets}/${s.totalSets}'),
                      tone: FitTone.success,
                    ),
                  ),
                ],
              ),
              if (s.volume > 0) ...[
                const SizedBox(height: FitSpace.sm),
                FitStatTile(
                  icon: FLucideIcons.flame,
                  label: 'إجمالي الحجم (الوزن × العدّات)',
                  value: s.volume.round().toString(),
                  unit: 'كجم',
                  tone: FitTone.info,
                ),
              ],
              const SizedBox(height: FitSpace.lg),
              // Optional: how long it took (there is no timer in the app).
              if (s.durationMinutes == null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FButton(
                    variant: FButtonVariant.ghost,
                    size: FButtonSizeVariant.sm,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () {
                      setState(() => s.durationMinutes = (estimated ?? 45).clamp(1, 600));
                      widget.onChanged();
                    },
                    prefix: const Icon(FLucideIcons.clock),
                    child: const Text('إضافة مدة الجلسة (اختياري)'),
                  ),
                )
              else
                _SheetStepperRow(
                  label: 'مدة الجلسة',
                  unit: 'دقيقة',
                  child: FitStepper(
                    value: s.durationMinutes!.toDouble(),
                    step: 5,
                    min: 1,
                    max: 600,
                    onChanged: (v) {
                      setState(() => s.durationMinutes = v.round());
                      widget.onChanged();
                    },
                  ),
                ),
              const SizedBox(height: FitSpace.md),
              TextField(
                controller: _notes,
                onChanged: (v) {
                  s.notes = v.trim().isEmpty ? null : v;
                  widget.onChanged();
                },
                maxLines: 3,
                minLines: 1,
                style: FitType.body.copyWith(color: c.foreground),
                decoration: InputDecoration(
                  hintText: 'ملاحظات للمدرب (اختياري)',
                  hintStyle: FitType.body.copyWith(color: c.mutedForeground),
                  prefixIcon: Icon(FLucideIcons.messageSquare, size: 18, color: c.mutedForeground),
                  filled: true,
                  fillColor: c.surfaceAlt,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: FitRadius.mdAll, borderSide: BorderSide.none),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: FitSpace.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(FitSpace.md),
                  decoration: BoxDecoration(color: c.dangerSoft, borderRadius: FitRadius.mdAll),
                  child: Text(
                    'تعذّر الحفظ، حاول مجدداً.\n$_error',
                    style: FitType.caption.copyWith(color: c.danger),
                  ),
                ),
              ],
              const SizedBox(height: FitSpace.xl),
              SizedBox(
                width: double.infinity,
                child: FButton(
                  onPress: _saving ? null : _save,
                  prefix: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
                        )
                      : const Icon(FLucideIcons.check),
                  child: Text(_saving ? 'جارٍ الحفظ…' : (s.saved ? 'حفظ التعديلات' : 'حفظ الجلسة')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
