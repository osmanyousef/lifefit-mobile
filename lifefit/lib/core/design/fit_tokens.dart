import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FitLife design tokens — the single place to change how the app looks.
//
// Screens never hard-code a colour, size or radius: they read these tokens
// (through `context.fit` for colours). Change a value here and every screen
// that uses the design system follows.
// ─────────────────────────────────────────────────────────────────────────────

/// Spacing scale on a 4-pt grid.
abstract final class FitSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal padding for page content.
  static const double page = 16;
}

/// Corner radii. Three sizes only, so shapes stay consistent.
abstract final class FitRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Type scale (Tajawal). Colours are applied by the theme / at use site.
abstract final class FitType {
  static const String family = 'Tajawal';

  static const _tabular = [FontFeature.tabularFigures()];

  /// Big numbers: timers, weights, stats.
  static const number = TextStyle(
    fontFamily: family,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.1,
    fontFeatures: _tabular,
  );
  static const display = TextStyle(fontFamily: family, fontSize: 28, fontWeight: FontWeight.w800, height: 1.25);
  static const title = TextStyle(fontFamily: family, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static const heading = TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w700, height: 1.35);
  static const body = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w400, height: 1.5);
  static const bodyStrong = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w700, height: 1.5);
  static const label = TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);
  static const caption = TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);
}

/// Semantic tone used by badges, icon chips and stat tiles.
enum FitTone { neutral, brand, success, warning, danger, info }

/// Colour roles for one brightness. Read with `context.fit`.
@immutable
class FitColors extends ThemeExtension<FitColors> {
  const FitColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.foreground,
    required this.mutedForeground,
    required this.primary,
    required this.onPrimary,
    required this.brand,
    required this.brandSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.inverseSurface,
    required this.onInverseSurface,
  });

  final Brightness brightness;

  /// Page background.
  final Color background;

  /// Cards, sheets, inputs.
  final Color surface;

  /// Subtle fills: stepper buttons, chips, table headers.
  final Color surfaceAlt;
  final Color border;

  /// Main text.
  final Color foreground;

  /// Secondary text, captions, icons at rest.
  final Color mutedForeground;

  /// Filled buttons and key actions (contrast-safe with [onPrimary]).
  final Color primary;
  final Color onPrimary;

  /// The bright FitLife teal for accents: progress, highlights, icons.
  final Color brand;
  final Color brandSoft;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  /// High-emphasis floating bars (e.g. the rest timer).
  final Color inverseSurface;
  final Color onInverseSurface;

  static const light = FitColors(
    brightness: Brightness.light,
    background: Color(0xFFF5F7F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF2F2),
    border: Color(0xFFE2E8E8),
    foreground: Color(0xFF0F172A),
    mutedForeground: Color(0xFF5F6E80),
    primary: Color(0xFF0B7F72),
    onPrimary: Color(0xFFFFFFFF),
    brand: Color(0xFF19BDAA),
    brandSoft: Color(0xFFDDF6F2),
    success: Color(0xFF15803D),
    successSoft: Color(0xFFDCFCE7),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFEE2E2),
    info: Color(0xFF2563EB),
    infoSoft: Color(0xFFDBEAFE),
    inverseSurface: Color(0xFF0F172A),
    onInverseSurface: Color(0xFFF8FAFC),
  );

  static const dark = FitColors(
    brightness: Brightness.dark,
    background: Color(0xFF0B1214),
    surface: Color(0xFF121B1E),
    surfaceAlt: Color(0xFF1A2629),
    border: Color(0xFF243134),
    foreground: Color(0xFFE6EDEE),
    mutedForeground: Color(0xFF8FA3A8),
    primary: Color(0xFF2DD4BF),
    onPrimary: Color(0xFF042F2A),
    brand: Color(0xFF2DD4BF),
    brandSoft: Color(0xFF123A36),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF12321F),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2C0B),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF3B1515),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0xFF13284A),
    inverseSurface: Color(0xFFE6EDEE),
    onInverseSurface: Color(0xFF0B1214),
  );

  /// Strong colour for a tone (text / icon).
  Color toneFg(FitTone tone) => switch (tone) {
        FitTone.neutral => mutedForeground,
        FitTone.brand => brightness == Brightness.light ? primary : brand,
        FitTone.success => success,
        FitTone.warning => warning,
        FitTone.danger => danger,
        FitTone.info => info,
      };

  /// Soft background for a tone.
  Color toneBg(FitTone tone) => switch (tone) {
        FitTone.neutral => surfaceAlt,
        FitTone.brand => brandSoft,
        FitTone.success => successSoft,
        FitTone.warning => warningSoft,
        FitTone.danger => dangerSoft,
        FitTone.info => infoSoft,
      };

  @override
  FitColors copyWith({Color? primary, Color? onPrimary, Color? brand, Color? brandSoft}) => FitColors(
        brightness: brightness,
        background: background,
        surface: surface,
        surfaceAlt: surfaceAlt,
        border: border,
        foreground: foreground,
        mutedForeground: mutedForeground,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        brand: brand ?? this.brand,
        brandSoft: brandSoft ?? this.brandSoft,
        success: success,
        successSoft: successSoft,
        warning: warning,
        warningSoft: warningSoft,
        danger: danger,
        dangerSoft: dangerSoft,
        info: info,
        infoSoft: infoSoft,
        inverseSurface: inverseSurface,
        onInverseSurface: onInverseSurface,
      );

  @override
  FitColors lerp(ThemeExtension<FitColors>? other, double t) {
    if (other is! FitColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FitColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      foreground: l(foreground, other.foreground),
      mutedForeground: l(mutedForeground, other.mutedForeground),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      brand: l(brand, other.brand),
      brandSoft: l(brandSoft, other.brandSoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      inverseSurface: l(inverseSurface, other.inverseSurface),
      onInverseSurface: l(onInverseSurface, other.onInverseSurface),
    );
  }
}

/// `context.fit` → the active [FitColors].
extension FitThemeContext on BuildContext {
  FitColors get fit => Theme.of(this).extension<FitColors>() ?? FitColors.light;
}
