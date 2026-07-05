import 'package:flutter/material.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/widgets/app_network_image.dart';

/// Square exercise image used in list rows on [WorkoutsScreen].
///
/// When [dimmed] is true, a semi-transparent overlay with a check icon
/// indicates the exercise has been logged for today.
class ExerciseThumbnail extends StatelessWidget {
  final String? imageUrl;

  /// Applies a dark overlay + check icon when the exercise is completed.
  final bool dimmed;

  /// Width and height of the square thumbnail.
  final double size;

  const ExerciseThumbnail({
    super.key,
    required this.imageUrl,
    this.dimmed = false,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url.isNotEmpty)
              AppNetworkImage(
                url: url,
                fit: BoxFit.cover,
                placeholder: _placeholder(),
                errorWidget: _placeholder(),
              )
            else
              _placeholder(),
            if (dimmed)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Icon(Icons.done_all, color: Colors.white, size: 26),
              ),
          ],
        ),
      ),
    );
  }

  /// Fallback when no image URL is available or loading fails.
  Widget _placeholder() => ColoredBox(
        color: const Color(0xFFF0F0F0),
        child: Icon(Icons.fitness_center, color: Colors.grey[500], size: 28),
      );
}
