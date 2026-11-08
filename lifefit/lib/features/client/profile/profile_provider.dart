import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/profile_web/client_profile_bundle.dart';
import '../../../core/services/profile_web_service.dart';

// ─── Client Profile Provider ──────────────────────────────────────────────────
// Used by: ProfileScreen (read), ProfileEditSheet (write via update).
// Bundle = user + profile fields + current body stats.

/// Manages [ClientProfileBundle] from GET/PUT /api/client/profile.
class ClientProfileNotifier
  extends StateNotifier<AsyncValue<ClientProfileBundle>> {
  final ProfileService _service;

  ClientProfileNotifier(this._service) : super(const AsyncValue.loading()) {
    fetch();
  }

  /// Initial load and manual refresh.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final bundle = await _service.fetchProfile();
      state = AsyncValue.data(bundle);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => fetch();

  /// PUT partial body; replaces state with the server response.
  Future<void> update(Map<String, dynamic> body) async {
    final bundle = await _service.updateProfile(body);
    state = AsyncValue.data(bundle);
  }
}

/// Watched by [ProfileScreen]; updated by [ProfileEditSheet._save].
final clientProfileProvider = StateNotifierProvider<ClientProfileNotifier,
    AsyncValue<ClientProfileBundle>>((ref) {
  ref.watch(currentUserIdProvider);
  return ClientProfileNotifier(ProfileService());
});
