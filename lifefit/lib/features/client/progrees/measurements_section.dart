import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/models/progress/body_measurement.dart';
import 'add_measurement_sheet.dart';
import 'goals_provider.dart';
import 'measurements_provider.dart';
import 'weight_progress_chart.dart';

const Color _kPrimary =  AppColors.primary;
const Color _kDark = Color(0xFF1E293B);

/// Body measurements history, latest metrics, weight chart vs goal target.
class MeasurementsSection extends ConsumerWidget {
  const MeasurementsSection({super.key});

  static List<BodyMeasurement> _sortAsc(List<BodyMeasurement> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final da = a.date;
      final db = b.date;
      if (da == null && db == null) return a.id.compareTo(b.id);
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return copy;
  }

  static BodyMeasurement? _latest(List<BodyMeasurement> list) {
    if (list.isEmpty) return null;
    final sorted = [...list];
    sorted.sort((a, b) {
      final da = a.date;
      final db = b.date;
      if (da == null && db == null) return b.id.compareTo(a.id);
      if (da == null) return 1;
      if (db == null) return -1;
      final c = db.compareTo(da);
      if (c != 0) return c;
      return b.id.compareTo(a.id);
    });
    return sorted.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(measurementsProvider);
    final goalsAsync = ref.watch(goalsProvider);

    final targetWeight = goalsAsync.maybeWhen(
      data: (g) => g.isNotEmpty ? g.first.targetWeight : null,
      orElse: () => null,
    );

    // Main section content by provider state.
    return async.when(
      loading: () => _loadingCard(),
      error: (e, _) => _errorCard(e.toString(), ref),
      data: (list) {
        if (list.isEmpty) {
          return _emptyState(context, ref);
        }
        final asc = _sortAsc(list);
        final latest = _latest(list);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Header row: action + title.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Add measurement action.
                TextButton.icon(
                  onPressed: () => showAddMeasurementSheet(context),
                  icon: const Icon(Icons.add_circle_outline, color: _kPrimary, size: 22),
                  label: const Text(
                    'قياس جديد',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _kPrimary,
                    ),
                  ),
                ),
                // Section title.
                const Text(
                  'قياسات الجسم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ===================================================Measurement cards.
            _metricGrid(latest),
            const SizedBox(height: 18),
            // ===================================================Weight chart card.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Chart title.
                  const Text(
                    'تطور الوزن',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kDark,
                    ),
                  ),
                  if (targetWeight != null) ...[
                    const SizedBox(height: 4),
                    // Target line hint.
                    Text(
                      'خط أفقي = هدف الوزن من أهدافك (${targetWeight.toStringAsFixed(1)} كجم)',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Weight progress chart widget.
                  WeightProgressChart(
                    sortedAsc: asc,
                    targetWeightKg: targetWeight,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Latest measurement cards.
  Widget _metricGrid(BodyMeasurement? m) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: [
        // Current weight card.
        _miniCard('الوزن الحالي', _fmt(m?.weightKg), 'كجم'),
        // Body fat card.
        _miniCard('نسبة الدهون', _fmt(m?.bodyFatPct), '%'),
        // Muscle mass card.
        _miniCard('كتلة العضلات', _fmt(m?.muscleMassKg), 'كجم'),
        // Waist circumference card.
        _miniCard('محيط الخصر', _fmt(m?.waistCm), 'سم'),
      ],
    );
  }

  // Single metric mini card.
  Widget _miniCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Metric label.
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          // Metric value + unit.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: _kPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double? v) {
    if (v == null) return '—';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  // Loading state card.
  Widget _loadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5),
        ),
      ),
    );
  }

  // Error state card with retry.
  Widget _errorCard(String msg, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error message.
          Text(
            msg,
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
          ),
          const SizedBox(height: 10),
          // Retry button.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.read(measurementsProvider.notifier).refresh(),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      ),
    );
  }

  // Empty state card with CTA.
  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Empty state title.
          const Text(
            'قياسات الجسم',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 8),
          // Empty state description.
          Text(
            'لا توجد قياسات بعد. سجّل أول قياس لمتابعة وزنك ومقاييسك.',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          // Primary CTA.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showAddMeasurementSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'إضافة قياس',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
