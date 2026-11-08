/// Tolerant JSON readers for API payloads.
///
/// Laravel often sends numbers as strings (`decimal` casts → "72.50"), booleans
/// as 1/0, and nullable dates. A strict `json['x'] as num` throws on any of
/// those and takes the whole list down with it, so models read fields through
/// these helpers instead.

/// int from int / double / "12" / "12.0"; null for anything else.
int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final s = v.trim();
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }
  return null;
}

/// double from num / "72.5"; null for anything else.
double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// true for `true`, 1, "1", "true" (case-insensitive); false otherwise.
bool asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true';
  }
  return false;
}

/// Non-empty string or null.
String? asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// DateTime from an ISO string (or DateTime); null when missing or unparseable.
DateTime? asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
