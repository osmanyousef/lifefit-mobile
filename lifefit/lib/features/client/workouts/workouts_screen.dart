import 'package:flutter/material.dart';
import '../../../core/ui/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/workout/today_schedule.dart';
import '../../../core/models/workout/exercise.dart';
import '../subscription/subscription_provider.dart';
import '../subscription/trainers_screen.dart';
import 'workout_provider.dart';
import 'workout_detail_screen.dart';
import 'exercise_thumbnail.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Workouts module — today's scheduled workouts and exercise list.
// ─────────────────────────────────────────────────────────────────────────────

const Color _primary = AppColors.primary;
const Color _bg = AppColors.background;

/// Home tab screen listing all workouts scheduled for today.
///
/// Flow:
/// 1. Watches [todaySchedulesProvider] for async load / error / data states.
/// 2. Shows summary progress, then one section per [TodaySchedule].
/// 3. Tapping an exercise opens [WorkoutDetailScreen].
///
/// Empty state: no schedules → rest-day view with refresh.
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(todaySchedulesProvider);
    final expertsAsync = ref.watch(expertsProvider);

    final hasTrainerSubscription = expertsAsync.maybeWhen(
      data: (experts) =>
          experts.any((e) => e.role == 'trainer' && e.isSubscribed),
      orElse: () => null,
    );
    // Only show the "no subscription" screen when there is also nothing scheduled
    // today — if the API returned workouts, the client clearly has access to them.
    final hasNoWorkoutsToday = schedulesAsync.maybeWhen(
      data: (schedules) => schedules.isEmpty,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: _bg,
      body: hasTrainerSubscription == false && hasNoWorkoutsToday
          ? _NoSubscriptionView(
              onBrowseTrainers: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrainersScreen()),
              ),
            )
          : schedulesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _primary),
              ),
              error: (error, _) => _ErrorView(
                message: error.toString().replaceFirst('Exception: ', ''),
                onRetry: () =>
                    ref.read(todaySchedulesProvider.notifier).refresh(),
              ),
              data: (schedules) {
                if (schedules.isEmpty) {
                  return _RestDayView(
                    onRefresh: () =>
                        ref.read(todaySchedulesProvider.notifier).refresh(),
                  );
                }
                return _WorkoutsList(
                  schedules: schedules,
                  onRefresh: () =>
                      ref.read(todaySchedulesProvider.notifier).refresh(),
                );
              },
            ),
    );
  }
}

/// Scrollable list of today's workout sections with pull-to-refresh.
class _WorkoutsList extends StatelessWidget {
  final List<TodaySchedule> schedules;
  final Future<void> Function() onRefresh;

  const _WorkoutsList({
    required this.schedules,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE، d MMMM', 'ar').format(DateTime.now());

    // Aggregate completion across all schedules for the summary card.
    var totalExercises = 0;
    var doneExercises = 0;
    for (final s in schedules) {
      final w = s.workout;
      totalExercises += w.exercises.length;
      final ids = <int>{};
      if (s.workoutLog != null) {
        for (final log in s.workoutLog!.exerciseLogs) {
          ids.add(log.exerciseId);
        }
      }
      doneExercises += w.exercises.where((e) => ids.contains(e.id)).length;
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Screen title.
                  const Text(
                    'تمارين اليوم',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Date label formatted for the user.
                      Text(
                        today,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      if (schedules.length > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${schedules.length} جلسات',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Overview of weekly or daily progress.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: _WorkoutsSummaryCard(
                done: doneExercises,
                total: totalExercises,
                schedules: schedules,
              ),
            ),
          ),

          // Detailed list of workout sections for today.
          for (final schedule in schedules) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: _WorkoutSectionHeader(schedule: schedule),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final exercise = schedule.workout.exercises[i];
                    final loggedIds = <int>{};
                    if (schedule.workoutLog != null) {
                      for (final log in schedule.workoutLog!.exerciseLogs) {
                        loggedIds.add(log.exerciseId);
                      }
                    }
                    final isDone = loggedIds.contains(exercise.id);
                    return _WorkoutExerciseCard(
                      schedule: schedule,
                      exercise: exercise,
                      isDone: isDone,
                    );
                  },
                  childCount: schedule.workout.exercises.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

/// Gradient card showing today's exercise completion progress.
class _WorkoutsSummaryCard extends StatelessWidget {
  final int done;
  final int total;
  final List<TodaySchedule> schedules;

  const _WorkoutsSummaryCard({
    required this.done,
    required this.total,
    required this.schedules,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? done / total : 0.0;
    final completedWorkouts = schedules.where((s) => s.isCompleted).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.fitness_center, color: Colors.white, size: 36),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Summary label.
                  Text(
                    'التمارين المنجزة',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Summary value.
                  Text(
                    '$done/$total تمرين',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Session count.
              Text(
                'جلسات اليوم: ${schedules.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              // Completed count.
              Text(
                'مكتمل: $completedWorkouts',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section title for one workout within today's list (name + done/total).
class _WorkoutSectionHeader extends StatelessWidget {
  final TodaySchedule schedule;

  const _WorkoutSectionHeader({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final workout = schedule.workout;
    final exercises = workout.exercises;
    final loggedIds = <int>{};
    if (schedule.workoutLog != null) {
      for (final log in schedule.workoutLog!.exerciseLogs) {
        loggedIds.add(log.exerciseId);
      }
    }
    final done = exercises.where((e) => loggedIds.contains(e.id)).length;
    final total = exercises.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Per-workout completion count.
        Text(
          '$done/$total',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            workout.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          schedule.isCompleted ? Icons.check_circle_outline : Icons.fitness_center,
          size: 18,
          color: _primary,
        ),
      ],
    );
  }
}

/// Tappable row for a single exercise — navigates to [WorkoutDetailScreen].
class _WorkoutExerciseCard extends StatelessWidget {
  final TodaySchedule schedule;
  final Exercise exercise;
  final bool isDone;

  const _WorkoutExerciseCard({
    required this.schedule,
    required this.exercise,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final pivot = exercise.pivot;
    // Tap to open detail screen.
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutDetailScreen(
            schedule: schedule,
            exercise: exercise,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDone
                ? _primary.withOpacity(0.4)
                : Colors.grey.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ExerciseStatusIcon(isDone: isDone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDone
                          ? 'مكتمل — يمكنك فتح التفاصيل أو إلغاء الإكمال'
                          : 'اضغط لعرض التفاصيل والتسجيل',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDone
                            ? _primary
                            : Colors.grey,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    if (pivot != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
                          _chip(
                              '${pivot.sets} جولات',
                              const Color(0xFF3ABEF9).withOpacity(0.1),
                              const Color(0xFF3ABEF9)),
                          if (!pivot.isTimeBased)
                            _chip(
                                '${pivot.reps} عدة',
                                const Color(0xFFF59E0B).withOpacity(0.12),
                                const Color(0xFFF59E0B)),
                          _chip(
                            pivot.targetIntensityText,
                            const Color(0xFF10B981).withOpacity(0.12),
                            const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExerciseThumbnail(
                imageUrl: exercise.imageUrl,
                dimmed: isDone,
                size: 58,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    // Small prescription badge (sets, reps, intensity).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Circular icon indicating whether the exercise has been logged.
class _ExerciseStatusIcon extends StatelessWidget {
  final bool isDone;

  const _ExerciseStatusIcon({required this.isDone});

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle,
          color: _primary,
          size: 22,
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF3ABEF9).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.fitness_center,
        color: Color(0xFF3ABEF9),
        size: 20,
      ),
    );
  }
}

/// Shown when the client has no active subscription with a trainer.
class _NoSubscriptionView extends StatelessWidget {
  final VoidCallback onBrowseTrainers;

  const _NoSubscriptionView({required this.onBrowseTrainers});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_membership_outlined,
                size: 60,
                color: _primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ليس لديك اشتراك',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'لا يوجد اشتراك نشط مع أي مدرب.\nاشترك مع مدرب للحصول على تمارينك اليومية.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onBrowseTrainers,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.search),
              label: const Text(
                'تصفح المدربين',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when [todaySchedulesProvider] returns an empty list.
class _RestDayView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _RestDayView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fitness_center,
                size: 60,
                color: _primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'يوم راحة مستحق!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'لا توجد تمارين مجدولة لليوم.\nراجع مدربك للحصول على تمارين جديدة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'تحديث',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when [todaySchedulesProvider] is in error state.
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'تعذّر التحميل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
