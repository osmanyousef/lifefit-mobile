/// Shared duration conversion between UI (minutes) and backend (seconds).
///
/// The API stores durations as seconds (`target_duration_seconds`,
/// `actual_duration_seconds`, `rest_seconds`). Users enter and see minutes.
abstract final class WorkoutDurationUtils {
  WorkoutDurationUtils._();

  /// Converts backend seconds to whole minutes for display and text fields.
  static int? secondsToMinutes(int? seconds) {
    if (seconds == null) return null;
    return (seconds / 60).round();
  }

  /// Converts user-entered minutes to seconds for API payloads.
  static int? minutesToSeconds(int? minutes) {
    if (minutes == null) return null;
    return minutes * 60;
  }

  /// Parses a minutes input field and returns seconds for the backend.
  /// When empty, returns [fallbackSeconds] unchanged (already in seconds).
  static int? minutesInputToSeconds(String text, int? fallbackSeconds) {
    if (text.trim().isEmpty) return fallbackSeconds;
    final minutes = int.tryParse(text.trim());
    if (minutes == null) return fallbackSeconds;
    return minutesToSeconds(minutes);
  }

  /// Arabic label from seconds, e.g. "5 دقيقة" or "1.5 دقيقة".
  static String formatMinutesFromSeconds(int? seconds) {
    if (seconds == null) return '—';
    final minutes = seconds / 60;
    if (minutes == minutes.roundToDouble()) {
      return '${minutes.round()} دقيقة';
    }
    return '${minutes.toStringAsFixed(1)} دقيقة';
  }

  /// Arabic label from whole minutes, e.g. "5 دقيقة".
  static String formatMinutes(int? minutes) {
    if (minutes == null) return '—';
    return '$minutes دقيقة';
  }
}
