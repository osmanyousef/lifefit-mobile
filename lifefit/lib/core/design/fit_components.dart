import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'fit_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FitLife shared components. Built only from tokens (fit_tokens.dart) and
// Forui primitives — no hard-coded colours, sizes or radii.
// ─────────────────────────────────────────────────────────────────────────────

/// Surface container with the standard radius, border and padding.
class FitCard extends StatelessWidget {
  const FitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FitSpace.lg),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: FitRadius.mdAll,
        side: BorderSide(color: borderColor ?? c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Section title with an optional trailing action.
class FitSectionHeader extends StatelessWidget {
  const FitSectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FitType.heading.copyWith(color: c.foreground)),
                if (subtitle != null)
                  Text(subtitle!, style: FitType.caption.copyWith(color: c.mutedForeground)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small rounded label in a semantic tone.
class FitBadge extends StatelessWidget {
  const FitBadge({super.key, required this.label, this.tone = FitTone.neutral, this.icon});

  final String label;
  final FitTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final fg = c.toneFg(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FitSpace.sm, vertical: FitSpace.xxs + 1),
      decoration: BoxDecoration(color: c.toneBg(tone), borderRadius: FitRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: FitSpace.xs),
          ],
          Text(label, style: FitType.label.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Rounded square holding an icon in a soft tone.
class FitIconChip extends StatelessWidget {
  const FitIconChip({super.key, required this.icon, this.tone = FitTone.brand, this.size = 40});

  final IconData icon;
  final FitTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.toneBg(tone), borderRadius: FitRadius.smAll),
      child: Icon(icon, size: size * 0.5, color: c.toneFg(tone)),
    );
  }
}

/// Stat card: icon, big value with unit, label, optional delta badge.
class FitStatTile extends StatelessWidget {
  const FitStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.tone = FitTone.brand,
    this.delta,
    this.deltaTone = FitTone.success,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final FitTone tone;
  final String? delta;
  final FitTone deltaTone;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return FitCard(
      padding: const EdgeInsets.all(FitSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FitIconChip(icon: icon, tone: tone, size: 34),
              const Spacer(),
              if (delta != null) FitBadge(label: delta!, tone: deltaTone),
            ],
          ),
          const SizedBox(height: FitSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: FitType.number.copyWith(fontSize: 26, color: c.foreground)),
              if (unit != null) ...[
                const SizedBox(width: FitSpace.xs),
                Text(unit!, style: FitType.label.copyWith(color: c.mutedForeground)),
              ],
            ],
          ),
          const SizedBox(height: FitSpace.xxs),
          Text(label, style: FitType.caption.copyWith(color: c.mutedForeground)),
        ],
      ),
    );
  }
}

/// − value + control with large tap targets. Hold a button to repeat.
class FitStepper extends StatefulWidget {
  const FitStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 9999,
    this.decimals = 0,
    this.compact = false,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final bool compact;
  final bool enabled;

  @override
  State<FitStepper> createState() => _FitStepperState();
}

class _FitStepperState extends State<FitStepper> {
  Timer? _repeat;

  void _bump(int dir) {
    final next = (widget.value + dir * widget.step).clamp(widget.min, widget.max).toDouble();
    if (next != widget.value) {
      HapticFeedback.selectionClick();
      widget.onChanged(next);
    }
  }

  void _startRepeat(int dir) {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) => _bump(dir));
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  String get _text {
    final v = widget.value;
    if (widget.decimals == 0 || v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(widget.decimals);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final btn = widget.compact ? 30.0 : 40.0;
    final valueWidth = widget.compact ? 42.0 : 56.0;

    Widget button(IconData icon, int dir) => GestureDetector(
          onLongPressStart: widget.enabled ? (_) => _startRepeat(dir) : null,
          onLongPressEnd: (_) => _stopRepeat(),
          child: Material(
            color: c.surfaceAlt,
            borderRadius: FitRadius.smAll,
            child: InkWell(
              borderRadius: FitRadius.smAll,
              onTap: widget.enabled ? () => _bump(dir) : null,
              child: SizedBox(
                width: btn,
                height: btn,
                child: Icon(icon, size: widget.compact ? 16 : 18, color: widget.enabled ? c.foreground : c.mutedForeground),
              ),
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(FLucideIcons.minus, -1),
        SizedBox(
          width: valueWidth,
          child: Text(
            _text,
            textAlign: TextAlign.center,
            style: (widget.compact ? FitType.bodyStrong : FitType.heading).copyWith(
              color: c.foreground,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        button(FLucideIcons.plus, 1),
      ],
    );
  }
}

/// One set in a workout session: number · weight · reps · done.
class FitSetRow extends StatelessWidget {
  const FitSetRow({
    super.key,
    required this.index,
    required this.weight,
    required this.reps,
    required this.done,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggleDone,
    this.weightStep = 2.5,
  });

  final int index;
  final double weight;
  final int reps;
  final bool done;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onToggleDone;
  final double weightStep;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: FitSpace.sm, vertical: FitSpace.xs + 2),
      decoration: BoxDecoration(
        color: done ? c.successSoft : Colors.transparent,
        borderRadius: FitRadius.smAll,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: FitType.bodyStrong.copyWith(color: done ? c.success : c.mutedForeground),
            ),
          ),
          const Spacer(),
          FitStepper(
            value: weight,
            step: weightStep,
            decimals: 1,
            compact: true,
            onChanged: onWeightChanged,
          ),
          const Spacer(),
          FitStepper(
            value: reps.toDouble(),
            compact: true,
            max: 100,
            onChanged: (v) => onRepsChanged(v.round()),
          ),
          const Spacer(),
          _DoneButton(done: done, onTap: onToggleDone),
        ],
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.done, required this.onTap});

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
          width: 40,
          height: 40,
          child: Icon(FLucideIcons.check, size: 20, color: done ? c.surface : c.mutedForeground),
        ),
      ),
    );
  }
}

/// Column labels shown above a group of [FitSetRow]s.
class FitSetHeader extends StatelessWidget {
  const FitSetHeader({super.key, this.weightLabel = 'الوزن (كجم)', this.repsLabel = 'العدّات'});

  final String weightLabel;
  final String repsLabel;

  @override
  Widget build(BuildContext context) {
    final style = FitType.caption.copyWith(color: context.fit.mutedForeground, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FitSpace.sm),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text('#', textAlign: TextAlign.center, style: style)),
          const Spacer(),
          SizedBox(width: 102, child: Text(weightLabel, textAlign: TextAlign.center, style: style)),
          const Spacer(),
          SizedBox(width: 102, child: Text(repsLabel, textAlign: TextAlign.center, style: style)),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Floating rest-timer bar: countdown, progress, +15s and skip.
class FitRestTimerBar extends StatelessWidget {
  const FitRestTimerBar({
    super.key,
    required this.remaining,
    required this.total,
    required this.onAdd,
    required this.onSkip,
    this.nextLabel,
  });

  final Duration remaining;
  final Duration total;
  final VoidCallback onAdd;
  final VoidCallback onSkip;
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final secs = remaining.inSeconds;
    final text = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    final progress = total.inSeconds == 0 ? 0.0 : 1 - remaining.inSeconds / total.inSeconds;

    return Material(
      color: c.inverseSurface,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: FitRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: Colors.transparent,
            color: c.brand,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(FitSpace.lg, FitSpace.md, FitSpace.md, FitSpace.md),
            child: Row(
              children: [
                Icon(FLucideIcons.timer, color: c.brand, size: 22),
                const SizedBox(width: FitSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('راحة', style: FitType.caption.copyWith(color: c.onInverseSurface.withValues(alpha: 0.7))),
                      Text(text, style: FitType.number.copyWith(fontSize: 24, color: c.onInverseSurface)),
                      if (nextLabel != null)
                        Text(
                          'التالي: $nextLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FitType.caption.copyWith(color: c.onInverseSurface.withValues(alpha: 0.7)),
                        ),
                    ],
                  ),
                ),
                _BarButton(label: '+15ث', onTap: onAdd),
                const SizedBox(width: FitSpace.sm),
                _BarButton(label: 'تخطي', onTap: onSkip, filled: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Material(
      color: filled ? c.brand : c.onInverseSurface.withValues(alpha: 0.12),
      borderRadius: FitRadius.pillAll,
      child: InkWell(
        borderRadius: FitRadius.pillAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FitSpace.lg, vertical: FitSpace.sm + 2),
          child: Text(
            label,
            style: FitType.label.copyWith(
              fontWeight: FontWeight.w700,
              color: filled ? c.inverseSurface : c.onInverseSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Friendly empty / no-data state with an optional action.
class FitEmptyState extends StatelessWidget {
  const FitEmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FitSpace.xxl, horizontal: FitSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FitIconChip(icon: icon, size: 56),
          const SizedBox(height: FitSpace.lg),
          Text(title, textAlign: TextAlign.center, style: FitType.heading.copyWith(color: c.foreground)),
          if (message != null) ...[
            const SizedBox(height: FitSpace.xs),
            Text(message!, textAlign: TextAlign.center, style: FitType.body.copyWith(color: c.mutedForeground)),
          ],
          if (action != null) ...[
            const SizedBox(height: FitSpace.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

