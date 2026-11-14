import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../core/design/fit_components.dart';
import '../../core/design/fit_theme.dart';
import '../../core/design/fit_tokens.dart';
import 'workout_session_demo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Lab — a sandbox for the new FitLife design system.
//
// Uses sample data only: no providers, no API calls. Reachable from the side
// menu in debug builds. Delete `lib/features/design_lab/` and the drawer entry
// to remove it completely.
// ─────────────────────────────────────────────────────────────────────────────

class DesignLabScreen extends StatefulWidget {
  const DesignLabScreen({super.key});

  @override
  State<DesignLabScreen> createState() => _DesignLabScreenState();
}

class _DesignLabScreenState extends State<DesignLabScreen> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    final colors = _dark ? FitColors.dark : FitColors.light;
    return FitScope(
      colors: colors,
      child: Builder(
        builder: (context) {
          final c = context.fit;
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('مختبر التصميم'),
                actions: [
                  Icon(_dark ? FLucideIcons.moon : FLucideIcons.sun, size: 18, color: c.mutedForeground),
                  const SizedBox(width: FitSpace.sm),
                  FSwitch(value: _dark, onChange: (v) => setState(() => _dark = v)),
                  const SizedBox(width: FitSpace.lg),
                ],
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'المكوّنات'),
                    Tab(text: 'تمارين اليوم'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  _ComponentsTab(),
                  WorkoutSessionDemo(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComponentsTab extends StatefulWidget {
  const _ComponentsTab();

  @override
  State<_ComponentsTab> createState() => _ComponentsTabState();
}

class _ComponentsTabState extends State<_ComponentsTab> {
  double _weight = 42.5;
  double _reps = 10;
  bool _reminders = true;
  bool _setDone = false;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    const gap = SizedBox(height: FitSpace.xxxl);

    return ListView(
      padding: const EdgeInsets.fromLTRB(FitSpace.page, FitSpace.xl, FitSpace.page, FitSpace.xxxl * 2),
      children: [
        const FAlert(
          title: Text('صفحة تجريبية'),
          subtitle: Text('بيانات تجريبية فقط — لا يتم إرسال أي شيء للخادم.'),
        ),
        gap,

        // ── Colours ───────────────────────────────────────────────
        const FitSectionHeader(title: 'الألوان', subtitle: 'كل لون له دور — لا ألوان ثابتة داخل الشاشات'),
        Wrap(
          spacing: FitSpace.sm,
          runSpacing: FitSpace.sm,
          children: [
            _Swatch('primary', c.primary, c.onPrimary),
            _Swatch('brand', c.brand, c.foreground),
            _Swatch('brandSoft', c.brandSoft, c.foreground),
            _Swatch('background', c.background, c.foreground),
            _Swatch('surface', c.surface, c.foreground),
            _Swatch('surfaceAlt', c.surfaceAlt, c.foreground),
            _Swatch('border', c.border, c.foreground),
            _Swatch('foreground', c.foreground, c.background),
            _Swatch('muted', c.mutedForeground, c.background),
            _Swatch('success', c.success, c.surface),
            _Swatch('warning', c.warning, c.surface),
            _Swatch('danger', c.danger, c.surface),
          ],
        ),
        gap,

        // ── Typography ────────────────────────────────────────────
        const FitSectionHeader(title: 'الخطوط', subtitle: 'Tajawal — 8 أحجام فقط'),
        FitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('٧٣.٥ كجم', style: FitType.number.copyWith(color: c.foreground)),
              Text('عنوان رئيسي', style: FitType.display.copyWith(color: c.foreground)),
              Text('عنوان الصفحة', style: FitType.title.copyWith(color: c.foreground)),
              Text('عنوان قسم', style: FitType.heading.copyWith(color: c.foreground)),
              Text('نص أساسي لقراءة مريحة في التطبيق.', style: FitType.body.copyWith(color: c.foreground)),
              Text('نص أساسي عريض', style: FitType.bodyStrong.copyWith(color: c.foreground)),
              Text('تسمية · Label', style: FitType.label.copyWith(color: c.mutedForeground)),
              Text('ملاحظة صغيرة · Caption', style: FitType.caption.copyWith(color: c.mutedForeground)),
            ],
          ),
        ),
        gap,

        // ── Buttons ───────────────────────────────────────────────
        const FitSectionHeader(title: 'الأزرار', subtitle: 'Forui FButton بألوان FitLife'),
        FButton(
          onPress: () {},
          prefix: const Icon(FLucideIcons.play),
          child: const Text('ابدأ التمرين'),
        ),
        const SizedBox(height: FitSpace.sm),
        Row(
          children: [
            Expanded(
              child: FButton(
                variant: FButtonVariant.secondary,
                onPress: () {},
                child: const Text('ثانوي'),
              ),
            ),
            const SizedBox(width: FitSpace.sm),
            Expanded(
              child: FButton(
                variant: FButtonVariant.outline,
                onPress: () {},
                child: const Text('محدد'),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitSpace.sm),
        Row(
          children: [
            Expanded(
              child: FButton(
                variant: FButtonVariant.ghost,
                onPress: () {},
                prefix: const Icon(FLucideIcons.plus),
                child: const Text('إضافة'),
              ),
            ),
            const SizedBox(width: FitSpace.sm),
            Expanded(
              child: FButton(
                variant: FButtonVariant.destructive,
                onPress: () {},
                child: const Text('حذف'),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitSpace.sm),
        Row(
          children: [
            FButton(
              size: FButtonSizeVariant.sm,
              mainAxisSize: MainAxisSize.min,
              onPress: () {},
              child: const Text('صغير'),
            ),
            const SizedBox(width: FitSpace.sm),
            FButton(
              onPress: null,
              mainAxisSize: MainAxisSize.min,
              child: const Text('معطّل'),
            ),
            const Spacer(),
            FButton.icon(onPress: () {}, child: const Icon(FLucideIcons.history)),
            const SizedBox(width: FitSpace.sm),
            FButton.icon(onPress: () {}, child: const Icon(FLucideIcons.ellipsis)),
          ],
        ),
        gap,

        // ── Badges ────────────────────────────────────────────────
        const FitSectionHeader(title: 'الشارات'),
        const Wrap(
          spacing: FitSpace.sm,
          runSpacing: FitSpace.sm,
          children: [
            FitBadge(label: 'نشط', tone: FitTone.brand),
            FitBadge(label: 'مكتمل', tone: FitTone.success, icon: FLucideIcons.check),
            FitBadge(label: 'قيد الانتظار', tone: FitTone.warning),
            FitBadge(label: 'منتهي', tone: FitTone.danger),
            FitBadge(label: 'جديد', tone: FitTone.info),
            FitBadge(label: 'مؤرشف'),
          ],
        ),
        gap,

        // ── Stat tiles ────────────────────────────────────────────
        const FitSectionHeader(title: 'بطاقات الإحصائيات'),
        const Row(
          children: [
            Expanded(
              child: FitStatTile(
                icon: FLucideIcons.scale,
                label: 'الوزن الحالي',
                value: '73',
                unit: 'كجم',
                delta: '-1.2',
              ),
            ),
            SizedBox(width: FitSpace.md),
            Expanded(
              child: FitStatTile(
                icon: FLucideIcons.flame,
                label: 'سلسلة الأيام',
                value: '12',
                unit: 'يوم',
                tone: FitTone.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: FitSpace.md),
        FitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('هدف الوزن', style: FitType.bodyStrong.copyWith(color: c.foreground)),
                  const Spacer(),
                  Text('73 / 75 كجم', style: FitType.label.copyWith(color: c.mutedForeground)),
                ],
              ),
              const SizedBox(height: FitSpace.md),
              const FDeterminateProgress(value: 0.62),
              const SizedBox(height: FitSpace.sm),
              Text('باقي 2 كجم للوصول لهدفك', style: FitType.caption.copyWith(color: c.mutedForeground)),
            ],
          ),
        ),
        gap,

        // ── Inputs ────────────────────────────────────────────────
        const FitSectionHeader(title: 'عناصر الإدخال', subtitle: 'اضغط مطولاً على − أو + للتكرار السريع'),
        FitCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('الوزن (كجم)', style: FitType.body.copyWith(color: c.foreground))),
                  FitStepper(value: _weight, step: 2.5, decimals: 1, onChanged: (v) => setState(() => _weight = v)),
                ],
              ),
              const SizedBox(height: FitSpace.md),
              Row(
                children: [
                  Expanded(child: Text('العدّات', style: FitType.body.copyWith(color: c.foreground))),
                  FitStepper(value: _reps, onChanged: (v) => setState(() => _reps = v)),
                ],
              ),
              const SizedBox(height: FitSpace.md),
              FSwitch(
                label: const Text('تذكير بموعد التمرين'),
                value: _reminders,
                onChange: (v) => setState(() => _reminders = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: FitSpace.md),
        FitCard(
          padding: const EdgeInsets.all(FitSpace.sm),
          child: Column(
            children: [
              const FitSetHeader(),
              const SizedBox(height: FitSpace.xs),
              FitSetRow(
                index: 0,
                weight: _weight,
                reps: _reps.round(),
                done: _setDone,
                onWeightChanged: (v) => setState(() => _weight = v),
                onRepsChanged: (v) => setState(() => _reps = v.toDouble()),
                onToggleDone: () => setState(() => _setDone = !_setDone),
              ),
            ],
          ),
        ),
        gap,

        // ── Empty state ───────────────────────────────────────────
        const FitSectionHeader(title: 'الحالة الفارغة'),
        FitCard(
          child: FitEmptyState(
            icon: FLucideIcons.utensils,
            title: 'لا توجد وجبات اليوم',
            message: 'لم يتم تخصيص خطة غذائية لك بعد. تواصل مع أخصائي التغذية.',
            action: FButton(
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: () {},
              prefix: const Icon(FLucideIcons.rotateCcw),
              child: const Text('تحديث'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, this.onColor);

  final String name;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    return Container(
      width: 104,
      height: 64,
      padding: const EdgeInsets.all(FitSpace.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: FitRadius.smAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(name, style: FitType.label.copyWith(color: onColor, fontWeight: FontWeight.w700)),
          Text(hex, style: FitType.caption.copyWith(color: onColor.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
