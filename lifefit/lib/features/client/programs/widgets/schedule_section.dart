import 'package:flutter/material.dart';
import '../../../../core/ui/app_colors.dart';
import '../../../../core/models/programs/client_program_detail.dart';
import '../../../../core/ui/widgets/app_network_image.dart';

/// Collapsible section for a specific workout schedule in the program.
class ScheduleSection extends StatelessWidget {
  final ProgramScheduleEntry entry;

  const ScheduleSection({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final w = entry.workout;
    final dayPart = entry.dayOfWeek != null ? 'يوم ${entry.dayOfWeek}' : '';
    final weekPart =
        entry.weekNumber != null ? 'أسبوع ${entry.weekNumber}' : null;
    final subtitle =
        [if (weekPart != null) weekPart, if (dayPart.isNotEmpty) dayPart]
            .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          // Material ancestor so the tile's ink/background isn't hidden by the white Container.
          child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            iconColor: AppColors.primary,
            collapsedIconColor: Colors.grey[400],
            title: Row(
              children: [
                // Display exercise count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${w.exercises.length} تمارين',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      w.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        textAlign: TextAlign.right,
                      ),
                  ],
                ),
              ],
            ),
            children: [
              if (w.description != null && w.description!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    w.description!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              if (w.exercises.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('لا توجد تمارين مضافة.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                )
              else
                ...w.exercises.map(
                  (e) => _ExerciseRow(exercise: e),
                ),
            ],
          )
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ProgramExerciseRow exercise;

  const _ExerciseRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExerciseImage(url: exercise.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  exercise.name,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                if (exercise.muscleGroup != null &&
                    exercise.muscleGroup!.isNotEmpty)
                  Text(
                    exercise.muscleGroup!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.right,
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  textDirection: TextDirection.rtl,
                  children: [
                    if (exercise.sets != null)
                      _MetaChip('${exercise.sets} مجموعات', const Color(0xFF3ABEF9)),
                    if (exercise.reps != null)
                      _MetaChip('${exercise.reps} تكرار', const Color(0xFFF59E0B)),
                    if (exercise.durationMinutes != null)
                      _MetaChip('${exercise.durationMinutes} دقيقة', const Color(0xFF10B981)),
                    if (exercise.restSeconds != null)
                      _MetaChip('راحة ${exercise.restSeconds} ث', const Color(0xFFEF4444)),
                  ],
                ),
                if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    exercise.notes!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _ExerciseImage extends StatelessWidget {
  final String? url;
  const _ExerciseImage({required this.url});

  @override
  Widget build(BuildContext context) {
    const size = 66.0;
    if (resolveAppImageUrl(url) != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AppNetworkImage(
          url: url,
          width: size,
          height: size,
          errorWidget: _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.sports_gymnastics,
          color: AppColors.primary, size: 28),
    );
  }
}
