import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../../core/design/fit_components.dart';
import '../../core/design/fit_theme.dart';
import '../../core/design/fit_tokens.dart';
import 'workout_demo_data.dart';
import 'workout_media.dart';

// ─────────────────────────────────────────────────────────────────────────────
// One workout (جلسة): cover header → muscle-group sections → collapsible
// exercise cards → sets table.
//
// • Tap an exercise to open / close it. Finishing one opens the next.
// • Open card goes straight to logging:
//   #  · الهدف · الوزن · العدّات · ✓   (cardio shows a duration instead).
// • The video stays out of the way: tap the exercise picture (or the small
//   play button under the table) to open it in a sheet, only when wanted.
// • The round ✓ on the header marks the whole exercise done at once.
// • No timers anywhere.
//
// In the real screen, saving sends the same `POST client/workout-logs`
// payload the app sends today.
// ─────────────────────────────────────────────────────────────────────────────

const double _headerHeight = 232;

class WorkoutDetailDemo extends StatefulWidget {
  const WorkoutDetailDemo({super.key, required this.day, required this.workout, required this.number});

  final DemoDay day;
  final DemoWorkout workout;

  /// 1-based position of this workout in the day.
  final int number;

  @override
  State<WorkoutDetailDemo> createState() => _WorkoutDetailDemoState();
}

class _WorkoutDetailDemoState extends State<WorkoutDetailDemo> {
  final Set<DemoExercise> _open = {};

  DemoWorkout get _w => widget.workout;

  @override
  void initState() {
    super.initState();
    final pending = _w.exercises.where((e) => !e.complete);
    if (pending.isNotEmpty) _open.add(pending.first);
  }

  // ── Actions ──────────────────────────────────────────────────────
  void _changed(VoidCallback fn) {
    setState(fn);
    widget.day.touch();
  }

  /// When an exercise becomes complete: close it and open the next unfinished one.
  void _afterChange(DemoExercise ex, {required bool wasComplete}) {
    if (wasComplete || !ex.complete) return;
    HapticFeedback.heavyImpact();
    _open.remove(ex);
    final all = _w.exercises;
    final i = all.indexOf(ex);
    DemoExercise? next;
    for (var j = i + 1; j < all.length; j++) {
      if (!all[j].complete) {
        next = all[j];
        break;
      }
    }
    next ??= all.where((e) => !e.complete).firstOrNull;
    if (next != null) _open.add(next);
  }

  void _toggleOpen(DemoExercise ex) => setState(() => _open.contains(ex) ? _open.remove(ex) : _open.add(ex));

  void _toggleSet(DemoExercise ex, DemoSet set) {
    final was = ex.complete;
    _changed(() {
      set.done = !set.done;
      _afterChange(ex, wasComplete: was);
    });
  }

  void _toggleAll(DemoExercise ex) {
    final was = ex.complete;
    HapticFeedback.mediumImpact();
    _changed(() {
      final target = !was;
      for (final s in ex.sets) {
        s.done = target;
      }
      if (!target) _open.add(ex);
      _afterChange(ex, wasComplete: was);
    });
  }

  void _addSet(DemoExercise ex) => _changed(() {
        final last = ex.sets.isNotEmpty ? ex.sets.last : null;
        ex.sets.add(DemoSet(last?.weight ?? ex.targetWeight, last?.amount ?? ex.targetAmount));
      });

  // ── Sheets ───────────────────────────────────────────────────────
  void _editSet(DemoExercise ex, int setIndex) {
    final set = ex.sets[setIndex];
    final c = context.fit;
    final maxAmount = switch (ex.unit) {
      DemoUnit.reps => 100.0,
      DemoUnit.seconds => 600.0,
      DemoUnit.minutes => 180.0,
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.surface,
      shape: fitSheetShape,
      builder: (sheetContext) => FitScope(
        colors: c,
        child: StatefulBuilder(
          builder: (context, setSheet) {
            void update(VoidCallback fn) {
              setSheet(fn);
              _changed(() {});
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(FitSpace.page, 0, FitSpace.page, FitSpace.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(ex.name, style: FitType.heading.copyWith(color: c.foreground)),
                    Text(
                      'المجموعة ${setIndex + 1} · الهدف ${ex.targetCell}',
                      style: FitType.label.copyWith(color: c.mutedForeground),
                    ),
                    const SizedBox(height: FitSpace.lg),
                    if (ex.usesWeight) ...[
                      _SheetStepperRow(
                        label: 'الوزن',
                        unit: 'كجم',
                        child: FitStepper(
                          value: set.weight,
                          step: 2.5,
                          decimals: 1,
                          onChanged: (v) => update(() => set.weight = v),
                        ),
                      ),
                      const SizedBox(height: FitSpace.md),
                    ],
                    _SheetStepperRow(
                      label: ex.amountName,
                      unit: ex.amountUnitName.isEmpty ? null : ex.amountUnitName,
                      child: FitStepper(
                        value: set.amount.toDouble(),
                        step: ex.amountStep.toDouble(),
                        max: maxAmount,
                        onChanged: (v) => update(() => set.amount = v.round()),
                      ),
                    ),
                    const SizedBox(height: FitSpace.xl),
                    FButton(
                      onPress: () {
                        Navigator.pop(sheetContext);
                        if (!set.done) _toggleSet(ex, set);
                      },
                      prefix: const Icon(FLucideIcons.check),
                      child: Text(set.done ? 'حفظ' : 'حفظ وتمّت المجموعة'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// How to do the exercise: video (or pictures) + tips. Only on request.
  void _showGuide(DemoExercise ex) {
    showExerciseGuideSheet(
      context,
      colors: context.fit,
      title: ex.name,
      subtitle: ex.muscles,
      pictures: [ex.image(0), ex.image(1)],
      videoId: ex.videoId,
      tips: ex.tips,
    );
  }

  void _finish() {
    final c = context.fit;
    final w = _w;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      shape: fitSheetShape,
      builder: (sheetContext) => FitScope(
        colors: c,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(FitSpace.page, 0, FitSpace.page, FitSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FitIconChip(icon: FLucideIcons.trophy, tone: FitTone.warning, size: 64),
                const SizedBox(height: FitSpace.lg),
                Text(
                  w.complete ? 'أحسنت! أنهيت الجلسة' : 'إنهاء الجلسة؟',
                  style: FitType.title.copyWith(color: c.foreground),
                ),
                const SizedBox(height: FitSpace.xs),
                Text(
                  w.complete ? 'هذا ملخص ${w.name}' : 'بقيت ${w.totalSets - w.doneSets} مجموعة لم تُسجَّل',
                  style: FitType.body.copyWith(color: c.mutedForeground),
                ),
                const SizedBox(height: FitSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: FitStatTile(
                        icon: FLucideIcons.dumbbell,
                        label: 'التمارين',
                        value: '${w.doneExercises}/${w.exercises.length}',
                      ),
                    ),
                    const SizedBox(width: FitSpace.sm),
                    Expanded(
                      child: FitStatTile(
                        icon: FLucideIcons.listChecks,
                        label: 'المجموعات',
                        value: '${w.doneSets}/${w.totalSets}',
                        tone: FitTone.success,
                      ),
                    ),
                  ],
                ),
                if (w.volume > 0) ...[
                  const SizedBox(height: FitSpace.sm),
                  FitStatTile(
                    icon: FLucideIcons.flame,
                    label: 'إجمالي الحجم (الوزن × العدّات)',
                    value: w.volume.round().toString(),
                    unit: 'كجم',
                    tone: FitTone.info,
                  ),
                ],
                const SizedBox(height: FitSpace.xl),
                FButton(
                  onPress: () {
                    w.saved = true;
                    widget.day.touch();
                    Navigator.pop(sheetContext);
                    Navigator.pop(context);
                  },
                  prefix: const Icon(FLucideIcons.check),
                  child: const Text('حفظ الجلسة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final w = _w;
    final topPad = MediaQuery.paddingOf(context).top;
    var number = 0;

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _CoverHeader(workout: w, number: widget.number, topPad: topPad),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(FitSpace.page, FitSpace.lg, FitSpace.page, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SummaryStrip(workout: w),
                    for (final section in w.sections) ...[
                      const SizedBox(height: FitSpace.xl),
                      _SectionHeader(section: section),
                      const SizedBox(height: FitSpace.md),
                      for (final ex in section.exercises) ...[
                        _ExerciseCard(
                          number: ++number,
                          exercise: ex,
                          open: _open.contains(ex),
                          onToggleOpen: () => _toggleOpen(ex),
                          onToggleAll: () => _toggleAll(ex),
                          onToggleSet: (s) => _toggleSet(ex, s),
                          onEditSet: (i) => _editSet(ex, i),
                          onAddSet: () => _addSet(ex),
                          onGuide: () => _showGuide(ex),
                        ),
                        const SizedBox(height: FitSpace.md),
                      ],
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // Finish button pinned to the bottom.
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
                child: FButton(
                  variant: w.complete ? FButtonVariant.primary : FButtonVariant.outline,
                  onPress: w.doneSets == 0 ? null : _finish,
                  prefix: const Icon(FLucideIcons.flag),
                  child: Text(w.complete ? 'إنهاء الجلسة' : 'إنهاء الجلسة (${w.doneSets}/${w.totalSets})'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cover header (collapses into a plain app bar) ────────────────────────────

class _CoverHeader extends StatelessWidget {
  const _CoverHeader({required this.workout, required this.number, required this.topPad});

  final DemoWorkout workout;
  final int number;
  final double topPad;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final w = workout;

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
        child: Center(
          child: _RoundButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.maybePop(context),
          ),
        ),
      ),
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
                    Hero(tag: 'workout-cover-${w.id}', child: FitPicture(w.cover)),
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
                              PhotoPill(label: w.kind, icon: FLucideIcons.flame),
                            ],
                          ),
                          const SizedBox(height: FitSpace.sm),
                          Text(
                            w.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FitType.display.copyWith(color: kOnPhoto),
                          ),
                          Text(
                            '${w.subtitle} · ${w.exercises.length} تمارين · ${w.totalSets} مجموعة',
                            style: FitType.label.copyWith(color: kOnPhoto.withValues(alpha: 0.85)),
                          ),
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
                end: FitSpace.page,
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
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Material(
      color: c.surface.withValues(alpha: 0.92),
      shape: CircleBorder(side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: c.foreground)),
      ),
    );
  }
}

// ── Summary + section header ─────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.workout});

  final DemoWorkout workout;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final w = workout;
    final hasWeights = w.exercises.any((e) => e.usesWeight);
    return FitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _MiniStat(value: '${w.doneExercises}/${w.exercises.length}', label: 'التمارين'),
              _MiniStat(value: '${w.doneSets}/${w.totalSets}', label: 'المجموعات'),
              if (hasWeights)
                _MiniStat(value: '${w.volume.round()}', label: 'الحجم (كجم)')
              else
                _MiniStat(value: '${(w.progress * 100).round()}%', label: 'الإنجاز'),
            ],
          ),
          const SizedBox(height: FitSpace.md),
          FitProgressBar(value: w.progress, color: w.complete ? c.success : null),
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
          Text(value, style: FitType.number.copyWith(fontSize: 22, color: c.foreground)),
          Text(label, style: FitType.caption.copyWith(color: c.mutedForeground)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final DemoSection section;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final s = section;
    return Row(
      children: [
        FitIconChip(icon: s.icon, tone: s.complete ? FitTone.success : s.tone, size: 36),
        const SizedBox(width: FitSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.title, style: FitType.heading.copyWith(color: c.foreground)),
              Text('${s.exercises.length} تمارين', style: FitType.caption.copyWith(color: c.mutedForeground)),
            ],
          ),
        ),
        FitBadge(
          label: '${s.doneExercises}/${s.exercises.length}',
          tone: s.complete ? FitTone.success : FitTone.neutral,
          icon: s.complete ? FLucideIcons.check : null,
        ),
      ],
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
  final DemoExercise exercise;
  final bool open;
  final VoidCallback onToggleOpen;
  final VoidCallback onToggleAll;
  final ValueChanged<DemoSet> onToggleSet;
  final ValueChanged<int> onEditSet;
  final VoidCallback onAddSet;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final ex = exercise;
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
                  _Thumb(number: number, exercise: ex, onTap: onGuide),
                  const SizedBox(width: FitSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitType.bodyStrong.copyWith(
                            color: ex.complete ? c.mutedForeground : c.foreground,
                            decoration: ex.complete ? TextDecoration.lineThrough : null,
                            decorationColor: c.mutedForeground,
                          ),
                        ),
                        Text(
                          ex.muscles,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitType.caption.copyWith(color: c.mutedForeground),
                        ),
                        const SizedBox(height: FitSpace.xs + 2),
                        Row(
                          children: [
                            FitBadge(label: ex.targetSummary, tone: ex.complete ? FitTone.success : FitTone.brand),
                            const SizedBox(width: FitSpace.sm),
                            Flexible(child: _SetDots(total: ex.sets.length, done: ex.doneCount)),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: FitSpace.sm),
                        child: _TableHeader(exercise: ex),
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
                            // Small way into the video / pictures, for when it's needed.
                            FButton.icon(
                              variant: FButtonVariant.ghost,
                              size: FButtonSizeVariant.sm,
                              onPress: onGuide,
                              child: Icon(ex.hasVideo ? FLucideIcons.circlePlay : FLucideIcons.image),
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
/// Tapping it opens the video / pictures (the badge in the corner hints at it).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.number, required this.exercise, required this.onTap});

  final int number;
  final DemoExercise exercise;
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
            FitPicture(ex.thumb),
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
                  color: ex.hasVideo ? c.primary : kPhotoScrim,
                  shape: BoxShape.circle,
                  border: Border.all(color: kOnPhoto, width: 1.5),
                ),
                child: Icon(
                  ex.hasVideo ? FLucideIcons.play : FLucideIcons.image,
                  size: 10,
                  color: ex.hasVideo ? c.onPrimary : kOnPhoto,
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
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
            width: 12,
            height: 4,
            decoration: BoxDecoration(
              color: i < done ? c.success : c.border,
              borderRadius: FitRadius.pillAll,
            ),
          ),
        const SizedBox(width: FitSpace.xxs),
        Text('$done/$total', style: FitType.caption.copyWith(color: c.mutedForeground, fontSize: 11)),
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
  const _TableHeader({required this.exercise});

  final DemoExercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final ex = exercise;
    final style = FitType.caption.copyWith(color: c.mutedForeground, fontWeight: FontWeight.w700);
    Widget cell(String t, int flex) => Expanded(flex: flex, child: Text(t, textAlign: TextAlign.center, style: style));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FitSpace.xs, vertical: FitSpace.sm),
      child: Row(
        children: [
          SizedBox(width: _colSet, child: Text('#', textAlign: TextAlign.center, style: style)),
          cell('الهدف', 4),
          if (ex.usesWeight) ...[
            cell('الوزن (كجم)', 4),
            const SizedBox(width: FitSpace.xs),
          ],
          cell(ex.amountLabel, ex.usesWeight ? 3 : 4),
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
  final DemoExercise exercise;
  final DemoSet set;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  bool get _isExtra => index >= exercise.targetSets;

  /// Above target → success, below → warning, equal → normal text.
  Color _valueColor(FitColors c, num actual, num target) {
    if (_isExtra) return c.foreground;
    if (actual > target) return c.success;
    if (actual < target) return c.warning;
    return c.foreground;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final ex = exercise;
    final done = set.done;

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
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: FitType.bodyStrong.copyWith(color: done ? c.success : c.mutedForeground),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _isExtra ? 'إضافية' : ex.targetCell,
              textAlign: TextAlign.center,
              style: FitType.label.copyWith(color: c.mutedForeground, fontFeatures: FitType.number.fontFeatures),
            ),
          ),
          if (ex.usesWeight) ...[
            Expanded(
              flex: 4,
              child: _ValueCell(
                text: fmtKg(set.weight),
                color: done ? c.success : _valueColor(c, set.weight, ex.targetWeight),
                done: done,
                onTap: onEdit,
              ),
            ),
            const SizedBox(width: FitSpace.xs),
          ],
          Expanded(
            flex: ex.usesWeight ? 3 : 4,
            child: _ValueCell(
              text: '${set.amount}',
              color: done ? c.success : _valueColor(c, set.amount, ex.targetAmount),
              done: done,
              onTap: onEdit,
            ),
          ),
          SizedBox(
            width: _colDone,
            child: Center(child: _SetDoneButton(done: done, onTap: onToggle)),
          ),
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
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: FitRadius.mdAll,
      ),
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
