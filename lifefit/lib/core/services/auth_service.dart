import 'package:dio/dio.dart';
import '../auth/token_storage.dart';
import '../models/user.dart';
import 'base_service.dart';

/// Authentication: login, register, session check, and logout.
/// Persists the Sanctum token via [TokenStorage] on successful auth.
class AuthService extends BaseService {
  /// GET `/api/user` — current Sanctum user (Bearer token).
  Future<User> fetchCurrentUser() async {
    try {
      final response = await dio.get('user');
      if (response.statusCode == 200 && response.data is Map) {
        return User.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw Exception('تعذر التحقق من الجلسة');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await TokenStorage.deleteToken();
      }
      final msg = e.response?.data is Map
          ? e.response?.data['message']?.toString()
          : null;
      throw Exception(msg ?? e.message ?? 'تعذر التحقق من الجلسة');
    }
  }

  /// Revokes token on server (best-effort) and clears local storage.
  Future<void> logout() async {
    try {
      await dio.post('logout');
    } catch (_) {}
    await TokenStorage.deleteToken();
  }

  /// POST `/api/login` — saves `access_token` or `token` from the response.
  Future<Response> login(String email, String password) async {
    final response = await dio.post(
      "login",
      data: {"email": email, "password": password},
    );

    final token = response.data['access_token'] ?? response.data['token'];
    if (token != null) {
      await TokenStorage.saveToken(token);
    }

    return response;
  }

  /// POST `/api/register` — saves token and triggers OTP email on the server.
  /// The token is required for the subsequent `/api/email/verify` call.
  Future<Response> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await dio.post(
      "register",
      data: {
        "name": name,
        "email": email,
        "password": password,
        "password_confirmation": password,
        "role": role,
      },
    );

    final token = response.data['access_token'] ?? response.data['token'];
    if (token != null) {
      await TokenStorage.saveToken(token);
    }

    return response;
  }

  /// POST `/api/forgot-password` — sends a 6-digit OTP to [email].
  Future<String> forgotPassword(String email) async {
    try {
      final response = await dio.post(
        'forgot-password',
        data: {'email': email},
      );
      final data = response.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'تم إرسال رمز التحقق إلى بريدك الإلكتروني.';
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'فشل إرسال رمز التحقق'));
    }
  }

  /// POST `/api/email/verify` — verifies the 6-digit OTP sent after registration.
  ///
  /// Requires Bearer auth (token saved during [register]).
  /// Body: `{ "otp": "123456" }`
  Future<String> verifyEmail(String otp) async {
    try {
      final response = await dio.post(
        'email/verify',
        data: {'otp': otp},
      );
      final data = response.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'تم التحقق من البريد الإلكتروني بنجاح!';
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'فشل التحقق من رمز OTP'));
    }
  }

  /// POST `/api/email/resend` — resends the email verification OTP.
  ///
  /// Requires Bearer auth. Throttled to 6 requests per minute on the server.
  Future<String> resendVerificationEmail() async {
    try {
      final response = await dio.post('email/resend');
      final data = response.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني.';
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'فشل إعادة إرسال رمز التحقق'));
    }
  }

  /// POST `/api/reset-password` — verifies OTP and sets a new password.
  Future<String> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await dio.post(
        'reset-password',
        data: {
          'email': email,
          'otp': otp,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      final data = response.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'تم تغيير كلمة المرور بنجاح! يمكنك الآن تسجيل الدخول.';
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'فشل إعادة تعيين كلمة المرور'));
    }
  }

  String _messageFromDio(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      if (data['debug'] != null) return data['debug'].toString();
    }
    return fallback;
  }
}
