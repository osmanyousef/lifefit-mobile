import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/ui/app_colors.dart';

/// External video link card shown on [WorkoutDetailScreen].
///
/// Opens [videoUrl] in the device's browser or YouTube app via
/// [launchUrl] — no in-app video player to keep the bundle light.
class ExerciseVideoCard extends StatelessWidget {
  final String videoUrl;
  final Color primary;

  const ExerciseVideoCard({
    super.key,
    required this.videoUrl,
    this.primary = AppColors.primary,
  });

  /// Parses the URL and launches it externally; shows a SnackBar on failure.
  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) {
      _showError(context, 'رابط الفيديو غير صالح');
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showError(context, 'تعذّر فتح الفيديو. تأكد من وجود متصفح أو تطبيق يوتيوب.');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_filled_rounded, color: primary, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'فيديو التمرين',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _open(context),
              icon: Icon(Icons.open_in_new_rounded, size: 18, color: primary),
              label: Text(
                'مشاهدة الفيديو',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
