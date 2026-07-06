import 'package:flutter/material.dart';
import '../../../../core/ui/app_colors.dart';
import '../../../../core/ui/widgets/app_network_image.dart';
import '../../../../core/models/nutrition/meal_schedule.dart';

/// Displays one scheduled meal; callbacks delegate actions to parent screen.
/// Receives [MealSchedule] only — no direct provider access.
class MealCard extends StatelessWidget {
  final MealSchedule schedule;
  final VoidCallback onLog;
  final VoidCallback onSkip;
  final VoidCallback onTap;

  const MealCard({
    super.key,
    required this.schedule,
    required this.onLog,
    required this.onSkip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meal = schedule.meal;
    if (meal == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: schedule.isEaten
                ? AppColors.primary.withOpacity(0.4)
                : schedule.isSkipped
                    ? Colors.grey.withOpacity(0.3)
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
              // Shows checkmark if eaten, X if skipped, or plate icon
              _StatusIcon(schedule: schedule),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      meal.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: schedule.isSkipped
                            ? Colors.grey
                            : AppColors.textPrimary,
                        decoration: schedule.isSkipped
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    // Quick view of meal macros
                    _MacroChips(schedule: schedule),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MealImage(imageUrl: meal.imageUrl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular status indicator for the meal.
class _StatusIcon extends StatelessWidget {
  final MealSchedule schedule;
  const _StatusIcon({required this.schedule});

  @override
  Widget build(BuildContext context) {
    if (schedule.isEaten) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
      );
    }
    if (schedule.isSkipped) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 22),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF3ABEF9).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.restaurant_outlined, color: Color(0xFF3ABEF9), size: 20),
    );
  }
}

/// Displays calories and main macros for the meal.
class _MacroChips extends StatelessWidget {
  final MealSchedule schedule;
  const _MacroChips({required this.schedule});

  String _macroLabel(double? actual, double target, {required bool eaten}) {
    if (eaten) {
      return actual != null ? actual.toStringAsFixed(0) : '—';
    }
    return target.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final eaten = schedule.isEaten;
    final cal = _macroLabel(schedule.actualCalories, schedule.targetCalories, eaten: eaten);
    final prot = _macroLabel(schedule.actualProtein, schedule.targetProtein, eaten: eaten);
    final carbs = _macroLabel(schedule.actualCarbs, schedule.targetCarbs, eaten: eaten);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      textDirection: TextDirection.rtl,
      children: [
        _Chip(
          label: '$cal سعرة',
          color: AppColors.primary,
          icon: Icons.local_fire_department,
        ),
        _Chip(
          label: 'ب ${prot}غ',
          color: const Color(0xFF3ABEF9),
        ),
        _Chip(
          label: 'ك ${carbs}غ',
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 2),
          ],
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MealImage extends StatelessWidget {
  final String? imageUrl;
  const _MealImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AppNetworkImage(
          url: imageUrl,
          width: 58,
          height: 58,
          placeholder: _placeholder(),
          errorWidget: _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.restaurant, color: AppColors.primary, size: 28),
    );
  }
}
