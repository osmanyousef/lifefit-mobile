import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'fit_tokens.dart';

/// Builds Forui + Material themes from the same [FitColors] tokens, so Forui
/// widgets, Material widgets and our own components always agree.
abstract final class FitTheme {
  static FColors foruiColors(FitColors c) => FColors(
        brightness: c.brightness,
        systemOverlayStyle:
            c.brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        barrier: const Color(0x66000000),
        background: c.background,
        foreground: c.foreground,
        primary: c.primary,
        primaryForeground: c.onPrimary,
        secondary: c.surfaceAlt,
        secondaryForeground: c.foreground,
        muted: c.surfaceAlt,
        mutedForeground: c.mutedForeground,
        destructive: c.danger,
        destructiveForeground: const Color(0xFFFFFFFF),
        error: c.danger,
        errorForeground: const Color(0xFFFFFFFF),
        card: c.surface,
        border: c.border,
      );

  /// Forui theme (touch sizing, Tajawal).
  static FThemeData forui(FitColors c) {
    final colors = foruiColors(c);
    final typeface = FTypeface.inherit(colors: colors, touch: true, fontFamily: FitType.family);
    return FThemeData(
      colors: colors,
      touch: true,
      debugLabel: 'FitLife ${c.brightness.name}',
      typography: FTypography(display: typeface, body: typeface),
    );
  }

  /// Material theme carrying [FitColors] as an extension (read via `context.fit`).
  static ThemeData material(FitColors c) {
    final scheme = ColorScheme.fromSeed(seedColor: c.brand, brightness: c.brightness).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      surface: c.surface,
      onSurface: c.foreground,
      error: c.danger,
      outline: c.border,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      fontFamily: FitType.family,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      dividerColor: c.border,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displaySmall: FitType.display.copyWith(color: c.foreground),
        titleLarge: FitType.title.copyWith(color: c.foreground),
        titleMedium: FitType.heading.copyWith(color: c.foreground),
        bodyLarge: FitType.body.copyWith(color: c.foreground),
        bodyMedium: FitType.body.copyWith(color: c.foreground),
        labelLarge: FitType.label.copyWith(color: c.foreground),
        bodySmall: FitType.caption.copyWith(color: c.mutedForeground),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: FitType.heading.copyWith(color: c.foreground),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(FitRadius.lg)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.foreground,
        unselectedLabelColor: c.mutedForeground,
        indicatorColor: c.brand,
        labelStyle: FitType.bodyStrong,
        unselectedLabelStyle: FitType.body,
        dividerColor: c.border,
      ),
      extensions: [c],
    );
  }
}

/// Wraps a subtree in the FitLife design system (Material + Forui, RTL).
///
/// Used by the Design Lab today; later it can wrap the whole app.
class FitScope extends StatelessWidget {
  const FitScope({super.key, required this.colors, required this.child, this.textDirection = TextDirection.rtl});

  final FitColors colors;
  final TextDirection textDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitTheme.material(colors),
      child: FTheme(
        data: FitTheme.forui(colors),
        textDirection: textDirection,
        child: Directionality(textDirection: textDirection, child: child),
      ),
    );
  }
}
