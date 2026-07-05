import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';
import 'token_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Global auth state. Watch via `ref.watch(authProvider)`; mutate via `ref.read(authProvider.notifier)`.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Handles login/register/logout and session restore. Token persistence lives in [TokenStorage].
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _auth = AuthService();

  AuthNotifier() : super(const AuthState());

  /// Call once on app start: restores [User] when a token exists in [TokenStorage].
  Future<void> restoreSession() async {
    if (!state.isInitializing) return;

    try {
      final hasToken = await TokenStorage.hasToken();
      if (!hasToken) {
        state = state.copyWith(isInitializing: false);
        return;
      }

      final user = await _auth.fetchCurrentUser();
      state = state.copyWith(user: user, isInitializing: false, isLoading: false);
    } catch (_) {
      // Stale or invalid token — clear storage so the user is sent to login.
      await TokenStorage.deleteToken();
      state = state.copyWith(
        isInitializing: false,
        isLoading: false,
        clearUser: true,
      );
    }
  }

  /// Clears API token and resets state; does not set [AuthState.isInitializing] back to true.
  Future<void> logout() async {
    await _auth.logout();
    state = const AuthState(isInitializing: false, isLoading: false);
  }

  /// Keeps drawer/app bar in sync after account settings change.
  void updateUser(User user) {
    state = state.copyWith(user: user);
  }

  /// Clears the last API/auth error shown on login or register screens.
  void clearErrorMessage() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  /// Sets a client-side validation error (e.g. incomplete OTP before submit).
  void setErrorMessage(String message) {
    state = state.copyWith(errorMessage: message);
  }

  /// On success, [AuthService] stores the token; this notifier only updates [User].
  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _auth.login(email, password);
      final user = User.fromJson(response.data['user']);

      state = state.copyWith(
        user: user,
        isLoading: false,
        isInitializing: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _toUserMessage(e));
    }
  }

  /// Creates the account and stores the Bearer token.
  /// The backend sends an OTP email; the UI should then show the OTP step
  /// before navigating to [AppEntry].
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _auth.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      final user = User.fromJson(response.data['user']);

      state = state.copyWith(
        user: user,
        isLoading: false,
        isInitializing: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _toUserMessage(e));
    }
  }

  /// Verifies the email OTP after registration.
  ///
  /// Requires a valid token (saved during [register]). On success, re-fetches
  /// the user so [User.emailVerifiedAt] is up to date. Returns `true` on success.
  Future<bool> verifyEmail({required String otp}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _auth.verifyEmail(otp);
      // Refresh user profile — email_verified_at is set on the server.
      final user = await _auth.fetchCurrentUser();

      state = state.copyWith(
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Requests a new verification OTP for the currently authenticated user.
  /// Returns the backend success message, or `null` on failure.
  Future<String?> resendVerificationEmail() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final message = await _auth.resendVerificationEmail();
      state = state.copyWith(isLoading: false);
      return message;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  /// Maps [DioException] to Arabic user-facing strings for login/register screens.
  String _toUserMessage(DioException e) {
    if (e.response != null) {
      final status = e.response!.statusCode;
      final data = e.response!.data;

      if (status == 401) {
        return "البريد الإلكتروني أو كلمة المرور غير صحيحة";
      }

      if (status == 422 && data is Map && data['message'] != null) {
        return data['message'];
      }

      return "خطأ من السيرفر $status";
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "انتهت مهلة الاتصال";
    }

    if (e.type == DioExceptionType.connectionError) {
      return "تحقق من اتصال الإنترنت";
    }

    return "حدث خطأ غير متوقع";
  }
}
