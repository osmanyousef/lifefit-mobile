import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../core/design/fit_components.dart';
import '../../core/design/fit_theme.dart';
import '../../core/design/fit_tokens.dart';
import 'workout_demo_data.dart';
import 'workout_detail_demo.dart';
import 'workout_media.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Today's workouts — the first layer of the new workout flow (sample data).
//
//   Today (this screen)  →  Workout (workout_detail_demo.dart)  →  Exercise  →  Sets
//
// A day can hold more than one workout (e.g. "Full Day" and "Full Cardio &
// Core"). Each one is a card with its cover picture, what's inside and how far
// along it is; tapping it opens the workout.
// ─────────────────────────────────────────────────────────────────────────────

const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String _sessionsLabel(int n) => switch (n) {
      1 => 'جلسة واحدة',
      2 => 'جلستان',
      _ => '$n جلسات',
    };

String _todayLabel() {
  final d = DateTime.now();
  return '${_weekdays[d.weekday - 1]}، ${d.day} ${_months[d.month - 1]}';
}

class WorkoutSessionDemo extends StatefulWidget {
  const WorkoutSessionDemo({super.key});

  @override
  State<WorkoutSessionDemo> createState() => _WorkoutSessionDemoState();
}

class _WorkoutSessionDemoState extends State<WorkoutSessionDemo> with AutomaticKeepAliveClientMixin {
  final DemoDay _day = DemoDay();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _day.dispose();
    super.dispose();
  }

  void _openWorkout(DemoWorkout workout, int number) {
    // The workout opens as a new page, so it needs the design-system scope again.
    final colors = context.fit;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FitScope(
          colors: colors,
          child: WorkoutDetailDemo(day: _day, workout: workout, number: number),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.fit;

    return ListenableBuilder(
      listenable: _day,
      builder: (context, _) {
        final workouts = _day.workouts;
        return ListView(
          padding: const EdgeInsets.fromLTRB(FitSpace.page, FitSpace.lg, FitSpace.page, FitSpace.xxxl),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_todayLabel(), style: FitType.label.copyWith(color: c.mutedForeground)),
                      Text('تمارين اليوم', style: FitType.display.copyWith(color: c.foreground)),
                    ],
                  ),
                ),
                FButton.icon(onPress: _day.reset, child: const Icon(FLucideIcons.rotateCcw)),
              ],
            ),
            const SizedBox(height: FitSpace.lg),
            _DayHero(day: _day),
            const SizedBox(height: FitSpace.xxl),
            FitSectionHeader(
              title: 'جلسات اليوم',
              subtitle: '${_sessionsLabel(workouts.length)} · ${_day.totalExercises} تمريناً',
              trailing: FitBadge(
                label: '${_day.doneWorkouts}/${workouts.length}',
                tone: _day.doneWorkouts == workouts.length ? FitTone.success : FitTone.neutral,
              ),
            ),
            for (var i = 0; i < workouts.length; i++) ...[
              _WorkoutCard(
                workout: workouts[i],
                number: i + 1,
                onOpen: () => _openWorkout(workouts[i], i + 1),
              ),
              const SizedBox(height: FitSpace.lg),
            ],
          ],
        );
      },
    );
  }
}

// ── Day progress hero ────────────────────────────────────────────────────────

class _DayHero extends StatelessWidget {
  const _DayHero({required this.day});

  final DemoDay day;

  String get _headline {
    if (day.doneSets == 0) return 'جاهز؟ لنبدأ تمرين اليوم';
    if (day.doneSets == day.totalSets) return 'أنجزت كل تمارين اليوم';
    if (day.progress >= 0.5) return 'أحسنت، تجاوزت نصف الطريق';
    return 'بداية قوية، واصل';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final on = c.onHero;
    final percent = (day.progress * 100).round();

    return ClipRRect(
      borderRadius: FitRadius.lgAll,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: c.heroGradient,
          ),
        ),
        child: Stack(
          children: [
            // Soft decorative circles, like the ones on the login screen.
            PositionedDirectional(
              top: -46,
              end: -34,
              child: _Blob(size: 150, color: on.withValues(alpha: 0.08)),
            ),
            PositionedDirectional(
              bottom: -60,
              end: 60,
              child: _Blob(size: 120, color: on.withValues(alpha: 0.06)),
            ),
            Padding(
              padding: const EdgeInsets.all(FitSpace.lg),
              child: Row(
                children: [
                  FitRing(
                    value: day.progress,
                    size: 88,
                    stroke: 9,
                    color: on,
                    trackColor: on.withValues(alpha: 0.22),
                    child: Text('$percent%', style: FitType.number.copyWith(fontSize: 22, color: on)),
                  ),
                  const SizedBox(width: FitSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تقدّم اليوم', style: FitType.label.copyWith(color: on.withValues(alpha: 0.8))),
                        Text(_headline, style: FitType.heading.copyWith(color: on)),
                        const SizedBox(height: FitSpace.md),
                        Wrap(
                          spacing: FitSpace.sm,
                          runSpacing: FitSpace.sm,
                          children: [
                            _HeroPill(label: '${day.doneExercises}/${day.totalExercises} تمرين', color: on),
                            _HeroPill(label: '${day.doneSets}/${day.totalSets} مجموعة', color: on),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: FitRadius.pillAll),
      child: Text(label, style: FitType.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Workout card ─────────────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout, required this.number, required this.onOpen});

  final DemoWorkout workout;
  final int number;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final w = workout;
    final finished = w.saved || w.complete;

    final String cta;
    final IconData ctaIcon;
    if (finished) {
      cta = 'عرض الجلسة';
      ctaIcon = FLucideIcons.listChecks;
    } else if (w.started) {
      cta = 'متابعة الجلسة';
      ctaIcon = FLucideIcons.play;
    } else {
      cta = 'ابدأ الجلسة';
      ctaIcon = FLucideIcons.play;
    }

    return FitCard(
      padding: EdgeInsets.zero,
      onTap: onOpen,
      borderColor: finished ? c.success.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover picture with the name on top.
          SizedBox(
            height: 156,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(tag: 'workout-cover-${w.id}', child: FitPicture(w.cover)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33000000), Color(0x0D000000), Color(0xD9000000)],
                      stops: [0, 0.4, 1],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: FitSpace.md,
                  start: FitSpace.md,
                  child: PhotoPill(label: 'الجلسة $number · ${w.kind}'),
                ),
                PositionedDirectional(
                  top: FitSpace.md,
                  end: FitSpace.md,
                  child: _StatusPill(workout: w),
                ),
                PositionedDirectional(
                  start: FitSpace.lg,
                  end: FitSpace.lg,
                  bottom: FitSpace.md,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FitType.title.copyWith(color: kOnPhoto),
                      ),
                      Text(w.subtitle, style: FitType.label.copyWith(color: kOnPhoto.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(FitSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Meta(icon: FLucideIcons.dumbbell, label: '${w.exercises.length} تمارين'),
                    const SizedBox(width: FitSpace.lg),
                    _Meta(icon: FLucideIcons.listChecks, label: '${w.totalSets} مجموعة'),
                    const Spacer(),
                    _ThumbStack(pictures: [for (final e in w.exercises) e.thumb]),
                  ],
                ),
                const SizedBox(height: FitSpace.md),
                // What's inside: one chip per muscle group.
                Wrap(
                  spacing: FitSpace.sm,
                  runSpacing: FitSpace.sm,
                  children: [
                    for (final s in w.sections)
                      FitBadge(
                        label: '${s.title} · ${s.doneExercises}/${s.exercises.length}',
                        tone: s.complete ? FitTone.success : FitTone.neutral,
                        icon: s.complete ? FLucideIcons.check : null,
                      ),
                  ],
                ),
                const SizedBox(height: FitSpace.lg),
                Row(
                  children: [
                    Expanded(child: FitProgressBar(value: w.progress, color: finished ? c.success : null)),
                    const SizedBox(width: FitSpace.md),
                    Text(
                      '${w.doneSets}/${w.totalSets}',
                      style: FitType.label.copyWith(color: c.mutedForeground, fontFeatures: FitType.number.fontFeatures),
                    ),
                  ],
                ),
                const SizedBox(height: FitSpace.lg),
                FButton(
                  variant: finished ? FButtonVariant.outline : FButtonVariant.primary,
                  onPress: onOpen,
                  prefix: Icon(ctaIcon),
                  child: Text(cta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.workout});

  final DemoWorkout workout;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final w = workout;
    if (w.saved || w.complete) {
      return PhotoPill(label: 'مكتملة', icon: FLucideIcons.check, color: c.success);
    }
    if (w.started) {
      return PhotoPill(label: 'جارية · ${(w.progress * 100).round()}%', icon: FLucideIcons.flame);
    }
    return const PhotoPill(label: 'لم تبدأ');
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c.toneFg(FitTone.brand)),
        const SizedBox(width: FitSpace.xs + 2),
        Text(label, style: FitType.label.copyWith(color: c.foreground, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Overlapping round exercise pictures, with "+n" when there are more.
class _ThumbStack extends StatelessWidget {
  const _ThumbStack({required this.pictures});

  final List<String> pictures;

  static const double _size = 30;
  static const double _step = 20;
  static const int _max = 4;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final shown = pictures.take(_max).toList();
    final extra = pictures.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);

    Widget circle(Widget child) => Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surfaceAlt,
            border: Border.all(color: c.surface, width: 2),
          ),
          child: ClipOval(child: child),
        );

    return SizedBox(
      width: _size + (count - 1) * _step,
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(start: i * _step, child: circle(FitPicture(shown[i]))),
          if (extra > 0)
            PositionedDirectional(
              start: shown.length * _step,
              child: circle(
                Center(
                  child: Text(
                    ltr('+$extra'),
                    style: FitType.caption.copyWith(color: c.foreground, fontWeight: FontWeight.w800, fontSize: 10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
