import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/design/fit_components.dart';
import '../../../core/design/fit_media.dart';
import '../../../core/design/fit_theme.dart';
import '../../../core/design/fit_tokens.dart';
import '../../../core/models/workout/today_schedule.dart';
import '../subscription/subscription_provider.dart';
import '../subscription/trainers_screen.dart';
import 'session/workout_session.dart';
import 'session/workout_sessions_provider.dart';
import 'workout_provider.dart';
import 'workout_session_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Workouts tab — today's scheduled workouts (first layer of the workout flow).
//
//   Today (this screen)  →  Workout session (WorkoutSessionScreen)  →  Sets
//
// Data: `GET client/today` through [todaySchedulesProvider] (unchanged).
// A day can hold several workouts; each one is a card with its cover picture
// (the workout's `image_url`, else its first exercise picture), what's inside
// and how far along it is. Tapping it opens the session.
// ─────────────────────────────────────────────────────────────────────────────

const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String _todayLabel() {
  final d = DateTime.now();
  return '${_weekdays[d.weekday - 1]}، ${d.day} ${_months[d.month - 1]}';
}

String _sessionsLabel(int n) => switch (n) {
      1 => 'جلسة واحدة',
      2 => 'جلستان',
      _ => '$n جلسات',
    };

/// Arabic label for the workout `type`.
String workoutTypeLabel(String? type) => switch (type) {
      'strength' => 'قوة',
      'cardio' => 'كارديو',
      'hypertrophy' => 'تضخيم',
      'other' => 'متنوع',
      _ => 'تمرين',
    };

/// Arabic label for the workout `difficulty`.
String? workoutDifficultyLabel(String? difficulty) => switch (difficulty) {
      'beginner' => 'مبتدئ',
      'intermediate' => 'متوسط',
      'advanced' => 'متقدم',
      _ => null,
    };

/// Cover picture: the workout's own image, else its first exercise picture.
String? workoutCover(TodaySchedule s) {
  final own = s.workout.imageUrl;
  if (own != null && own.trim().isNotEmpty) return own;
  for (final e in s.workout.exercises) {
    if (e.imageUrl != null && e.imageUrl!.trim().isNotEmpty) return e.imageUrl;
  }
  return null;
}

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(todaySchedulesProvider);
    final expertsAsync = ref.watch(expertsProvider);

    final hasTrainerSubscription = expertsAsync.maybeWhen(
      data: (experts) => experts.any((e) => e.role == 'trainer' && e.isSubscribed),
      orElse: () => null,
    );
    // Only show the "no subscription" screen when there is also nothing scheduled
    // today — if the API returned workouts, the client clearly has access to them.
    final hasNoWorkoutsToday = schedulesAsync.maybeWhen(
      data: (schedules) => schedules.isEmpty,
      orElse: () => false,
    );
    Future<void> refresh() => ref.read(todaySchedulesProvider.notifier).refresh();

    return FitScope(
      colors: FitColors.light,
      child: Builder(
        builder: (context) {
          final c = context.fit;
          final Widget body;
          if (hasTrainerSubscription == false && hasNoWorkoutsToday) {
            body = _CenteredScroll(
              onRefresh: refresh,
              child: FitEmptyState(
                icon: FLucideIcons.badgeCheck,
                title: 'ليس لديك اشتراك',
                message: 'لا يوجد اشتراك نشط مع أي مدرب.\nاشترك مع مدرب للحصول على تمارينك اليومية.',
                action: FButton(
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrainersScreen()),
                  ),
                  prefix: const Icon(FLucideIcons.search),
                  child: const Text('تصفح المدربين'),
                ),
              ),
            );
          } else {
            body = schedulesAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: c.toneFg(FitTone.brand))),
              error: (error, _) => _CenteredScroll(
                onRefresh: refresh,
                child: FitEmptyState(
                  icon: FLucideIcons.wifiOff,
                  title: 'تعذّر تحميل تمارين اليوم',
                  message: error.toString().replaceFirst('Exception: ', ''),
                  action: FButton(
                    mainAxisSize: MainAxisSize.min,
                    onPress: refresh,
                    prefix: const Icon(FLucideIcons.rotateCcw),
                    child: const Text('إعادة المحاولة'),
                  ),
                ),
              ),
              data: (schedules) => schedules.isEmpty
                  ? _CenteredScroll(
                      onRefresh: refresh,
                      child: FitEmptyState(
                        icon: FLucideIcons.moon,
                        title: 'يوم راحة مستحق!',
                        message: 'لا توجد تمارين مجدولة لليوم.\nراجع مدربك للحصول على تمارين جديدة.',
                        action: FButton(
                          variant: FButtonVariant.outline,
                          mainAxisSize: MainAxisSize.min,
                          onPress: refresh,
                          prefix: const Icon(FLucideIcons.rotateCcw),
                          child: const Text('تحديث'),
                        ),
                      ),
                    )
                  : _TodayList(schedules: schedules, onRefresh: refresh),
            );
          }
          return Scaffold(backgroundColor: c.background, body: body);
        },
      ),
    );
  }
}

/// Empty / error states that still support pull-to-refresh.
class _CenteredScroll extends StatelessWidget {
  const _CenteredScroll({required this.child, required this.onRefresh});

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.fit.toneFg(FitTone.brand),
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _TodayList extends ConsumerWidget {
  const _TodayList({required this.schedules, required this.onRefresh});

  final List<TodaySchedule> schedules;
  final Future<void> Function() onRefresh;

  void _open(BuildContext context, TodaySchedule s, int number) {
    // The session opens as a new page, so it needs the design-system scope again.
    final colors = context.fit;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FitScope(
          colors: colors,
          child: WorkoutSessionScreen(scheduleId: s.scheduleId, number: number),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(workoutSessionsProvider);
    final sessions = ref.read(workoutSessionsProvider.notifier);
    final c = context.fit;
    final all = [for (final s in schedules) sessions.of(s)];
    final totalSets = all.fold(0, (a, s) => a + s.totalSets);
    final doneSets = all.fold(0, (a, s) => a + s.doneSets);
    final totalExercises = all.fold(0, (a, s) => a + s.exercises.length);
    final doneExercises = all.fold(0, (a, s) => a + s.doneExercises);
    final savedCount = all.where((s) => s.saved && !s.dirty).length;

    return RefreshIndicator(
      color: c.toneFg(FitTone.brand),
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(FitSpace.page, FitSpace.lg, FitSpace.page, FitSpace.xxxl),
        children: [
          Text(_todayLabel(), style: FitType.label.copyWith(color: c.mutedForeground)),
          Text('تمارين اليوم', style: FitType.display.copyWith(color: c.foreground)),
          const SizedBox(height: FitSpace.lg),
          _DayHero(
            progress: totalSets == 0 ? 0 : doneSets / totalSets,
            doneSets: doneSets,
            totalSets: totalSets,
            doneExercises: doneExercises,
            totalExercises: totalExercises,
            allSaved: savedCount == all.length,
          ),
          const SizedBox(height: FitSpace.xxl),
          FitSectionHeader(
            title: 'جلسات اليوم',
            subtitle: '${_sessionsLabel(schedules.length)} · $totalExercises تمريناً',
            trailing: FitBadge(
              label: '$savedCount/${schedules.length}',
              tone: savedCount == schedules.length ? FitTone.success : FitTone.neutral,
            ),
          ),
          for (var i = 0; i < schedules.length; i++) ...[
            _WorkoutCard(
              schedule: schedules[i],
              session: all[i],
              number: i + 1,
              onOpen: () => _open(context, schedules[i], i + 1),
            ),
            const SizedBox(height: FitSpace.lg),
          ],
        ],
      ),
    );
  }
}

// ── Day progress hero ────────────────────────────────────────────────────────

class _DayHero extends StatelessWidget {
  const _DayHero({
    required this.progress,
    required this.doneSets,
    required this.totalSets,
    required this.doneExercises,
    required this.totalExercises,
    required this.allSaved,
  });

  final double progress;
  final int doneSets;
  final int totalSets;
  final int doneExercises;
  final int totalExercises;
  final bool allSaved;

  String get _headline {
    if (allSaved) return 'أنجزت تمارين اليوم';
    if (doneSets == 0) return 'جاهز؟ لنبدأ تمرين اليوم';
    if (progress >= 0.5) return 'أحسنت، تجاوزت نصف الطريق';
    return 'بداية قوية، واصل';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final on = c.onHero;
    final percent = (progress * 100).round();

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
            PositionedDirectional(top: -46, end: -34, child: _Blob(size: 150, color: on.withValues(alpha: 0.08))),
            PositionedDirectional(bottom: -60, end: 60, child: _Blob(size: 120, color: on.withValues(alpha: 0.06))),
            Padding(
              padding: const EdgeInsets.all(FitSpace.lg),
              child: Row(
                children: [
                  FitRing(
                    value: progress,
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
                            _HeroPill(label: '$doneExercises/$totalExercises تمرين', color: on),
                            _HeroPill(label: '$doneSets/$totalSets مجموعة', color: on),
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
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
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
  const _WorkoutCard({required this.schedule, required this.session, required this.number, required this.onOpen});

  final TodaySchedule schedule;
  final WorkoutSession session;
  final int number;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final w = schedule.workout;
    final s = session;
    final saved = s.saved && !s.dirty;
    final difficulty = workoutDifficultyLabel(w.difficulty);

    final String cta;
    final IconData ctaIcon;
    if (saved) {
      cta = 'عرض الجلسة';
      ctaIcon = FLucideIcons.listChecks;
    } else if (s.dirty && s.doneSets > 0) {
      cta = 'متابعة الجلسة';
      ctaIcon = FLucideIcons.play;
    } else {
      cta = 'ابدأ الجلسة';
      ctaIcon = FLucideIcons.play;
    }

    return FitCard(
      padding: EdgeInsets.zero,
      onTap: onOpen,
      borderColor: saved ? c.success.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 156,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(tag: 'workout-cover-${schedule.scheduleId}', child: WorkoutCover(schedule: schedule)),
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
                  child: PhotoPill(label: 'الجلسة $number · ${workoutTypeLabel(w.type)}'),
                ),
                PositionedDirectional(top: FitSpace.md, end: FitSpace.md, child: _StatusPill(schedule: schedule, session: s)),
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
                      if (w.description != null && w.description!.trim().isNotEmpty)
                        Text(
                          w.description!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitType.label.copyWith(color: kOnPhoto.withValues(alpha: 0.85)),
                        ),
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
                    Expanded(
                      child: Wrap(
                        spacing: FitSpace.lg,
                        runSpacing: FitSpace.xs,
                        children: [
                          _Meta(icon: FLucideIcons.dumbbell, label: '${w.exercises.length} تمارين'),
                          _Meta(icon: FLucideIcons.listChecks, label: '${s.totalSets} مجموعة'),
                          if ((w.estimatedDuration ?? 0) > 0)
                            _Meta(icon: FLucideIcons.clock, label: '${w.estimatedDuration} د'),
                          if (difficulty != null) _Meta(icon: FLucideIcons.gauge, label: difficulty),
                        ],
                      ),
                    ),
                    const SizedBox(width: FitSpace.sm),
                    _ThumbStack(pictures: [for (final e in w.exercises) e.imageUrl]),
                  ],
                ),
                const SizedBox(height: FitSpace.lg),
                Row(
                  children: [
                    Expanded(child: FitProgressBar(value: s.progress, color: saved ? c.success : null)),
                    const SizedBox(width: FitSpace.md),
                    Text(
                      '${s.doneSets}/${s.totalSets}',
                      style: FitType.label.copyWith(color: c.mutedForeground, fontFeatures: FitType.number.fontFeatures),
                    ),
                  ],
                ),
                const SizedBox(height: FitSpace.lg),
                FButton(
                  variant: saved ? FButtonVariant.outline : FButtonVariant.primary,
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

/// Workout cover picture, or a branded placeholder when there is none.
class WorkoutCover extends StatelessWidget {
  const WorkoutCover({super.key, required this.schedule});

  final TodaySchedule schedule;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final url = workoutCover(schedule);
    if (url != null) return FitPicture(url);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: c.heroGradient,
        ),
      ),
      child: Align(
        alignment: const AlignmentDirectional(0.7, -0.3),
        child: Icon(FLucideIcons.dumbbell, size: 64, color: c.onHero.withValues(alpha: 0.25)),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.schedule, required this.session});

  final TodaySchedule schedule;
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final s = session;
    if (s.dirty && s.doneSets > 0) {
      return PhotoPill(label: 'غير محفوظة · ${(s.progress * 100).round()}%', icon: FLucideIcons.flame);
    }
    if (s.saved) {
      return PhotoPill(
        label: schedule.workoutLog?.trainerReviewed == true ? 'راجعها المدرب' : 'مكتملة',
        icon: FLucideIcons.check,
        color: c.success,
      );
    }
    if (schedule.isMissed) return PhotoPill(label: 'فائتة', color: c.danger);
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

  final List<String?> pictures;

  static const double _size = 30;
  static const double _step = 20;
  static const int _max = 4;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    if (pictures.isEmpty) return const SizedBox.shrink();
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
