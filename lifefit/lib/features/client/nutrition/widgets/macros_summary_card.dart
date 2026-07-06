import 'package:flutter/material.dart';
import '../../../../core/ui/app_colors.dart';
import '../../../../core/models/nutrition/today_meals_response.dart';

/// Daily totals from [TodayMealsResponse] — calories bar + macro rings.
/// Pure display widget; parent passes aggregated [data].
class MacrosSummaryCard extends StatelessWidget {
  final TodayMealsResponse data;

  const MacrosSummaryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final calProgress = data.totalTargetCalories > 0
        ? (data.totalConsumedCalories / data.totalTargetCalories).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        // Main calorie progress card
        _CaloriesCard(
          consumed: data.totalConsumedCalories,
          target: data.totalTargetCalories,
          progress: calProgress.toDouble(),
        ),
        const SizedBox(height: 12),
        // Macro breakdown row
        Row(
          children: [
            Expanded(
              child: _MacroBar(
                label: 'بروتين',
                consumed: data.totalConsumedProtein,
                target: data.totalTargetProtein,
                unit: 'غ',
                color: const Color(0xFF3ABEF9),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroBar(
                label: 'كارب',
                consumed: data.totalConsumedCarbs,
                target: data.totalTargetCarbs,
                unit: 'غ',
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroBar(
                label: 'دهون',
                consumed: data.totalConsumedFat,
                target: data.totalTargetFat,
                unit: 'غ',
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The top card showing calorie progress with a circular or linear indicator.
class _CaloriesCard extends StatelessWidget {
  final double consumed;
  final double target;
  final double progress;

  const _CaloriesCard({
    required this.consumed,
    required this.target,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 18,
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
              const Icon(Icons.local_fire_department, color: Colors.white, size: 34),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'السعرات المأكولة',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${consumed.toStringAsFixed(0)} سعرة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.white.withOpacity(0.25),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الهدف: ${target.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
              Text(
                'مُستهلك: ${consumed.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular progress for one macro (protein / carbs / fat).
class _MacroBar extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final String unit;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: color.withOpacity(0.12),
                ),
              ),
              Icon(Icons.circle, size: 6, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${consumed.toStringAsFixed(0)}$unit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            'من ${target.toStringAsFixed(0)}$unit',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
