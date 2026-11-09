import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;

/// Dev server host/port shared by API calls and media URLs from the backend.
class ServerConfig {
  static const int port = 8000;

  /// Set your PC LAN IP when testing on a **physical** phone (same Wi‑Fi).
  /// Example: `'192.168.1.10'`. Leave null for emulator defaults.
  static const String? lanHostOverride = '192.168.1.250'; // set back to null for the emulator

  /// Reachable host from the current runtime.
  static String get host {
    final override = lanHostOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    if (kIsWeb) return '127.0.0.1';
    if (Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  static String get apiBaseUrl => 'http://$host:$port/api/';

  static String get origin => 'http://$host:$port';

  /// Parses a full image URL from the API and rewrites localhost for emulators.
  static String? resolveAppImageUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final embeddedHttpIndex = raw.lastIndexOf('http://');
    final embeddedHttpsIndex = raw.lastIndexOf('https://');
    final embeddedIndex = embeddedHttpsIndex > embeddedHttpIndex
        ? embeddedHttpsIndex
        : embeddedHttpIndex;

    String? url;
    if (embeddedIndex > 0) {
      url = raw.substring(embeddedIndex);
    } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
      url = raw;
    }

    if (url == null) return null;
    return _rewriteLocalhost(url);
  }

  /// Backend often returns `127.0.0.1` — unreachable from Android emulator/phone.
  static String _rewriteLocalhost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    final h = uri.host.toLowerCase();
    if (h != '127.0.0.1' && h != 'localhost') return url;

    final rewritten = uri.replace(host: host).toString();
    if (kDebugMode && rewritten != url) {
      debugPrint('[MediaURL] $url → $rewritten');
    }
    return rewritten;
  }
}
