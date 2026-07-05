import 'package:flutter/material.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/widgets/app_network_image.dart';
import '../../../core/utils/workout_duration_utils.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/workout/today_schedule.dart';
import '../../../core/models/workout/exercise.dart';
import '../../../core/models/workout/exercise_pivot.dart';
import 'exercise_video_card.dart';
import 'workout_log_screen.dart';
import 'workout_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorkoutDetailScreen — exercise info + navigation to logging.
// ─────────────────────────────────────────────────────────────────────────────

/// Read-only exercise detail view for a single item in today's schedule.
///
/// Flow:
/// 1. Shows image, optional video, description, and pivot prescription
///    (sets, reps, intensity, rest — durations shown in minutes via
///    [WorkoutDurationUtils]).
/// 2. Watches [todaySchedulesProvider] so completion badge stays in sync.
/// 3. CTA opens [WorkoutLogScreen] to record or update set logs.
class WorkoutDetailScreen extends ConsumerWidget {
  final TodaySchedule schedule;
  final Exercise exercise;

  const WorkoutDetailScreen({
    super.key,
    required this.schedule,
    required this.exercise,
  });

  static const _primary = AppColors.primary;

  /// Returns the freshest copy of [schedule] from the provider (includes logs).
  /// Falls back to the constructor argument if not found in cache.
  TodaySchedule _liveSchedule(WidgetRef ref) {
    final list = ref.watch(todaySchedulesProvider).valueOrNull;
    if (list != null) {
      for (final s in list) {
        if (s.scheduleId == schedule.scheduleId) return s;
      }
    }
    return schedule;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current live data including logs
    final live = _liveSchedule(ref);
    final isDone = live.isExerciseLogged(exercise.id);
    final pivot = exercise.pivot;
    final videoUrl = exercise.videoUrl;
    final hasVideo = videoUrl != null && videoUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          'تفاصيل التمرين',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Media header — image display.
            _buildImage(),
            if (hasVideo) ...[
              const SizedBox(height: 16),
              // Video demonstration card.
              ExerciseVideoCard(videoUrl: videoUrl.trim(), primary: _primary),
            ],
            const SizedBox(height: 24),
            // Name of the exercise.
            Text(
              exercise.name,
              style: const TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (exercise.description != null &&
                exercise.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              // Longer description or instructions.
              Text(
                exercise.description!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, color: Colors.grey, height: 1.5),
              ),
            ],
            if (exercise.muscles != null &&
                exercise.muscles!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              // List of target muscle groups.
              Text(
                'العضلات: ${exercise.muscles}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 30),
            const Text(
              'معلومات التدريب',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (pivot != null) ...[
              // Prescription cards: reps/sets, intensity target, rest time.
              Row(children: [
                Expanded(
                    child: _detailCard('العدات', pivot.reps, Icons.repeat)),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        _detailCard('المجموعات', '${pivot.sets}', Icons.layers)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _detailCard(
                        pivot.intensityTypeLabel,
                        pivot.targetIntensityText,
                        _intensityIcon(pivot))),
                const SizedBox(width: 12),
                Expanded(
                    child: _detailCard(
                        'الراحة',
                        WorkoutDurationUtils.formatMinutesFromSeconds(
                          pivot.restSeconds ?? 60,
                        ),
                        Icons.timer)),
              ]),
            ],
            const SizedBox(height: 40),
            // Shown when at least one set log exists for this exercise.
            if (isDone)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'تم إكمال هذا التمرين — يمكنك إعادة التسجيل لتحديثه',
                    style: TextStyle(
                      fontSize: 12,
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkoutLogScreen(
                      schedule: live,
                      exercise: exercise,
                    ),
                  ),
                ),
                child: Text(
                  isDone ? 'تعديل التسجيل' : 'ابدأ تسجيل المجموعات',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = exercise.imageUrl;
    // Exercise image preview.
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 15),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: url != null && url.isNotEmpty
            ? AppNetworkImage(
                url: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 250,
                loadingColor: Colors.white,
                errorWidget: const Center(
                  child:
                      Icon(Icons.fitness_center, size: 50, color: Colors.grey),
                ),
              )
            : const Center(
                child:
                    Icon(Icons.fitness_center, size: 50, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _detailCard(String label, String value, IconData icon) {
    // Compact stat card used in the 2×2 prescription grid.
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Icon matching the pivot's intensity type (weight / % / RPE / time).
  IconData _intensityIcon(ExercisePivot pivot) {
    switch (pivot.effectiveIntensityType) {
      case 'percentage':
        return Icons.percent;
      case 'rpe':
        return Icons.speed;
      case 'time':
        return Icons.timer_outlined;
      default:
        return Icons.fitness_center;
    }
  }
}
