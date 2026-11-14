import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/models/workout/today_schedule.dart';
import 'workout_session.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Keeps one [WorkoutSession] per scheduled workout while the client trains.
//
// Ticked sets are only sent to the API when the client finishes the workout,
// so they are kept as a local draft (per user, today only) in secure storage:
// leaving the screen, pulling to refresh or the app being closed at the gym
// doesn't lose them. A successful save clears the draft.
//
// The state is just a counter that changes whenever a session changes;
// screens watch it and read the session with [WorkoutSessionsNotifier.of].
// ─────────────────────────────────────────────────────────────────────────────

class WorkoutSessionsNotifier extends StateNotifier<int> {
  WorkoutSessionsNotifier(this._userId) : super(0) {
    _load();
  }

  final int? _userId;
  static const _storage = FlutterSecureStorage();

  final Map<int, WorkoutSession> _sessions = {};
  Map<String, dynamic> _drafts = {};
  bool _loaded = false;
  Timer? _saveTimer;

  String get _key => 'workout_drafts_v1_${_userId ?? 0}';

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final all = (jsonDecode(raw) as Map).cast<String, dynamic>();
        // Drafts belong to today's schedules only.
        all.removeWhere((_, v) => v is! Map || v['day'] != _today());
        _drafts = all;
      }
    } catch (e) {
      debugPrint('WorkoutSessions: could not read drafts — $e');
    }
    _loaded = true;
    if (!mounted) return;
    // Sessions created before the drafts were read are rebuilt with them.
    final withDrafts = _sessions.keys.where((id) => _drafts.containsKey('$id')).toList();
    for (final id in withDrafts) {
      final s = _sessions[id]!;
      if (!s.dirty) _sessions[id] = WorkoutSession.build(s.schedule, draft: _draftFor(id));
    }
    if (withDrafts.isNotEmpty) state++;
  }

  Map<String, dynamic>? _draftFor(int scheduleId) {
    final d = _drafts['$scheduleId'];
    return d is Map ? d.cast<String, dynamic>() : null;
  }

  /// The session for [schedule]. Rebuilt when the API sends new data for it
  /// (unsaved changes are carried over). Safe to call during build.
  WorkoutSession of(TodaySchedule schedule) {
    final current = _sessions[schedule.scheduleId];
    if (current != null && identical(current.schedule, schedule)) return current;

    final draft = current != null && current.dirty ? _withDay(current.toDraft()) : _draftFor(schedule.scheduleId);
    return _sessions[schedule.scheduleId] = WorkoutSession.build(schedule, draft: draft);
  }

  /// Whether the draft for a schedule has been read yet (avoids flashing an
  /// empty state on cold start).
  bool get ready => _loaded;

  /// Call after changing a session.
  void changed(WorkoutSession session) {
    session.dirty = true;
    _drafts['${session.scheduleId}'] = _withDay(session.toDraft());
    _scheduleSave();
    state++;
  }

  /// After the API saved the session: drop the draft; the next [of] call
  /// rebuilds it from the saved log.
  void saved(int scheduleId) {
    _drafts.remove('$scheduleId');
    _sessions.remove(scheduleId);
    _scheduleSave();
    state++;
  }

  /// Throws away unsaved changes for a schedule.
  void discard(int scheduleId) => saved(scheduleId);

  Map<String, dynamic> _withDay(Map<String, dynamic> d) => {...d, 'day': _today()};

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _persist);
  }

  Future<void> _persist() async {
    try {
      if (_drafts.isEmpty) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: jsonEncode(_drafts));
      }
    } catch (e) {
      debugPrint('WorkoutSessions: could not save drafts — $e');
    }
  }

  @override
  void dispose() {
    // Flush a pending write.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _persist();
    }
    super.dispose();
  }
}

/// Per-user: switching accounts starts fresh.
final workoutSessionsProvider = StateNotifierProvider<WorkoutSessionsNotifier, int>((ref) {
  return WorkoutSessionsNotifier(ref.watch(currentUserIdProvider));
});
