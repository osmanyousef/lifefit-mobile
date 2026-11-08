import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/user.dart';
import '../../../core/services/user_service.dart';
import '../profile/profile_provider.dart';

// ─── Account Settings Provider ──────────────────────────────────────────────
// Used by: SettingsScreen (read), account_edit_sheet & change_password_sheet (write).
// Syncs authProvider (drawer/app bar) and clientProfileProvider after name updates.

/// Manages account data from GET/PUT `/api/user` and related endpoints.
class AccountSettingsNotifier extends StateNotifier<AsyncValue<User>> {
  final UserService _service;
  final Ref _ref;

  AccountSettingsNotifier(this._service, this._ref)
      : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.fetchUser();
      state = AsyncValue.data(user);
      _syncAuth(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => fetch();

  /// PUT /api/user — updates name, email, and phone together.
  Future<void> update({
    String? name,
    String? email,
    String? phone,
  }) async {
    final user = await _service.updateUser(
      name: name,
      email: email,
      phone: phone,
    );
    state = AsyncValue.data(user);
    _syncAuth(user);
    _refreshProfile();
  }

  /// POST /api/avatar — response returns avatar_url only; merge into current User.
  Future<void> uploadAvatar({
    required List<int> bytes,
    required String fileName,
  }) async {
    final avatarUrl = await _service.updateAvatar(
      bytes: bytes,
      fileName: fileName,
    );
    final current = state.value;
    if (current != null) {
      final updated = current.copyWith(avatarUrl: avatarUrl);
      state = AsyncValue.data(updated);
      _syncAuth(updated);
    } else {
      await fetch();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    await _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmation: confirmation,
    );
  }

  /// Updates drawer and app bar without re-login.
  void _syncAuth(User user) {
    _ref.read(authProvider.notifier).updateUser(user);
  }

  /// Refreshes fitness profile because the name is shown there too.
  void _refreshProfile() {
    final profile = _ref.read(clientProfileProvider);
    if (profile.hasValue) {
      _ref.read(clientProfileProvider.notifier).refresh();
    }
  }
}

final accountSettingsProvider =
    StateNotifierProvider<AccountSettingsNotifier, AsyncValue<User>>((ref) {
  ref.watch(currentUserIdProvider);
  return AccountSettingsNotifier(UserService(), ref);
});
