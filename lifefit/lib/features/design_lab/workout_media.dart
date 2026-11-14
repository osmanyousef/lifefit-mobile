import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Already installed as part of webview_flutter; only used for the autoplay setting.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/design/fit_theme.dart';
import '../../core/design/fit_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Media + small visual pieces used by the workout demo:
// pictures, the two-frame exercise "motion", the in-app YouTube
// player, progress bar / ring and the pills drawn on top of pictures.
// ─────────────────────────────────────────────────────────────────────────────

/// Text / icons drawn on top of photos are always white on a dark scrim.
const kOnPhoto = Color(0xFFFFFFFF);
const kPhotoScrim = Color(0x73000000);

const fitSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(FitRadius.lg)),
);

/// Picture that fades in, with a soft placeholder while loading or when it
/// can't be loaded. [source] is an asset path or an http(s) URL (the real
/// screens pass the URL from the API). Must be placed in a sized box.
class FitPicture extends StatelessWidget {
  const FitPicture(this.source, {super.key, this.fit = BoxFit.cover, this.icon = FLucideIcons.dumbbell});

  final String source;
  final BoxFit fit;
  final IconData icon;

  /// Pictures already reported as failing, so each one is logged once.
  static final Set<String> _reported = {};

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    Widget placeholder() => ColoredBox(
          color: c.surfaceAlt,
          child: Center(child: Icon(icon, size: 22, color: c.mutedForeground.withValues(alpha: 0.55))),
        );

    final ImageProvider provider;
    if (source.startsWith('http')) {
      provider = NetworkImage(source);
    } else {
      provider = AssetImage(source);
    }

    return Image(
      image: provider,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            placeholder(),
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              child: child,
            ),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (_reported.add(source)) debugPrint('FitPicture: could not load $source — $error');
        return placeholder();
      },
    );
  }
}

/// Shows the start and end position of an exercise, cross-fading between the
/// two pictures so the movement is readable at a glance.
class ExerciseMotion extends StatefulWidget {
  const ExerciseMotion({super.key, required this.first, required this.second});

  final String first;
  final String second;

  @override
  State<ExerciseMotion> createState() => _ExerciseMotionState();
}

class _ExerciseMotionState extends State<ExerciseMotion> {
  Timer? _ticker;
  bool _showSecond = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (mounted) setState(() => _showSecond = !_showSecond);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dot(bool on) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: on ? 14 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: kOnPhoto.withValues(alpha: on ? 1 : 0.55),
            borderRadius: FitRadius.pillAll,
          ),
        );

    return Stack(
      fit: StackFit.expand,
      children: [
        FitPicture(widget.first),
        AnimatedOpacity(
          opacity: _showSecond ? 1 : 0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
          child: FitPicture(widget.second),
        ),
        PositionedDirectional(
          top: FitSpace.sm,
          end: FitSpace.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(color: kPhotoScrim, borderRadius: FitRadius.pillAll),
            child: Row(mainAxisSize: MainAxisSize.min, children: [dot(!_showSecond), dot(_showSecond)]),
          ),
        ),
      ],
    );
  }
}

/// Small dark pill for labels on top of pictures.
class PhotoPill extends StatelessWidget {
  const PhotoPill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;

  /// Background; defaults to a dark translucent scrim.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color ?? kPhotoScrim, borderRadius: FitRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: kOnPhoto),
            const SizedBox(width: FitSpace.xs),
          ],
          Text(label, style: FitType.caption.copyWith(color: kOnPhoto, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar that animates to its value.
class FitProgressBar extends StatelessWidget {
  const FitProgressBar({super.key, required this.value, this.color, this.trackColor, this.height = 6});

  final double value;
  final Color? color;
  final Color? trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: FitRadius.pillAll,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: trackColor ?? c.surfaceAlt),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: v,
                child: ColoredBox(color: color ?? c.toneFg(FitTone.brand)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular progress ring with something in the middle.
class FitRing extends StatelessWidget {
  const FitRing({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
    this.size = 84,
    this.stroke = 9,
    this.child,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, v, inner) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(value: v, color: color, trackColor: trackColor, stroke: stroke),
          child: Center(child: inner),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.trackColor, required this.stroke});

  final double value;
  final Color color;
  final Color trackColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);
    if (value <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor || old.stroke != stroke;
}

// ── YouTube ──────────────────────────────────────────────────────────────────

/// Plays a YouTube video inside the app (WebView with the official embed player).
class YoutubeEmbed extends StatefulWidget {
  const YoutubeEmbed({super.key, required this.videoId});

  final String videoId;

  @override
  State<YoutubeEmbed> createState() => _YoutubeEmbedState();
}

class _YoutubeEmbedState extends State<YoutubeEmbed> {
  /// YouTube only plays embeds that identify who embeds them: the page that
  /// hosts the player needs an https origin (the app id is the usual choice).
  static const _origin = 'https://com.example.lifefit';

  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Only the player frame matters (not icons, ads or trackers).
            final url = error.url ?? '';
            debugPrint('YoutubeEmbed: ${error.errorCode} ${error.description} ($url)');
            if (url.contains('/embed/') && mounted) setState(() => _failed = true);
          },
          onNavigationRequest: (request) {
            // Links out of the player (e.g. "Watch on YouTube") open outside the app.
            final url = request.url;
            if (request.isMainFrame && url.startsWith('http') && !url.startsWith(_origin)) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      // Lets the video start right away instead of needing a second tap.
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    _load();
  }

  void _load() => _controller.loadHtmlString(_html(widget.videoId), baseUrl: _origin);

  void _retry() {
    setState(() {
      _failed = false;
      _loading = true;
    });
    _load();
  }

  static String _html(String id) => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<link rel="icon" href="data:,">
<style>
  html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
  iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
</style>
</head>
<body>
<iframe
  src="https://www.youtube.com/embed/$id?playsinline=1&autoplay=1&rel=0&modestbranding=1"
  referrerpolicy="strict-origin-when-cross-origin"
  allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
  allowfullscreen></iframe>
</body>
</html>
''';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF000000)),
        WebViewWidget(controller: _controller),
        if (_failed)
          ColoredBox(
            color: const Color(0xFF000000),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 28, color: kOnPhoto),
                const SizedBox(height: FitSpace.sm),
                Text(
                  'تعذّر تشغيل الفيديو',
                  style: FitType.bodyStrong.copyWith(color: kOnPhoto),
                ),
                Text(
                  'تحقق من اتصال الإنترنت ثم حاول مجدداً',
                  style: FitType.caption.copyWith(color: kOnPhoto.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: FitSpace.sm),
                TextButton(
                  onPressed: _retry,
                  style: TextButton.styleFrom(foregroundColor: kOnPhoto),
                  child: Text('إعادة المحاولة', style: FitType.label.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )
        else if (_loading)
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: kOnPhoto),
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet that explains an exercise: the video (or, when there is no
/// video, the two moving pictures), the trainer's tips and a link to open the
/// video in the YouTube app. Opened on demand, so logging stays uncluttered.
Future<void> showExerciseGuideSheet(
  BuildContext context, {
  required FitColors colors,
  required String title,
  required String subtitle,
  required List<String> pictures,
  String? videoId,
  List<String> tips = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: colors.surface,
    shape: fitSheetShape,
    builder: (_) => FitScope(
      colors: colors,
      child: _GuideSheet(title: title, subtitle: subtitle, pictures: pictures, videoId: videoId, tips: tips),
    ),
  );
}

class _GuideSheet extends StatelessWidget {
  const _GuideSheet({
    required this.title,
    required this.subtitle,
    required this.pictures,
    required this.videoId,
    required this.tips,
  });

  final String title;
  final String subtitle;

  /// Start and end position.
  final List<String> pictures;
  final String? videoId;
  final List<String> tips;

  Future<void> _openInYoutube() async {
    await launchUrl(
      Uri.parse('https://www.youtube.com/watch?v=$videoId'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fit;
    final id = videoId;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(FitSpace.page, 0, FitSpace.page, FitSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: FitType.title.copyWith(color: c.foreground)),
            Text(subtitle, style: FitType.label.copyWith(color: c.mutedForeground)),
            const SizedBox(height: FitSpace.md),
            ClipRRect(
              borderRadius: FitRadius.mdAll,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: id != null
                    ? YoutubeEmbed(videoId: id)
                    : ExerciseMotion(first: pictures.first, second: pictures.last),
              ),
            ),
            if (tips.isNotEmpty) ...[
              const SizedBox(height: FitSpace.lg),
              Text('ملاحظات المدرب', style: FitType.bodyStrong.copyWith(color: c.foreground)),
              const SizedBox(height: FitSpace.sm),
              for (final tip in tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: FitSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(FLucideIcons.check, size: 16, color: c.toneFg(FitTone.brand)),
                      ),
                      const SizedBox(width: FitSpace.sm),
                      Expanded(child: Text(tip, style: FitType.body.copyWith(color: c.foreground))),
                    ],
                  ),
                ),
            ],
            if (id != null) ...[
              const SizedBox(height: FitSpace.sm),
              FButton(
                variant: FButtonVariant.outline,
                onPress: _openInYoutube,
                prefix: const Icon(Icons.open_in_new_rounded),
                child: const Text('فتح في يوتيوب'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
