import '../../utils/json_parse.dart';
/// One progress photo from `GET /api/client/photos` grouped payload or POST response `data`.
class ProgressPhoto {
  final int id;
  final int clientId;
  final DateTime? date;
  final String photoUrl;
  final String photoType;
  final String? notes;

  const ProgressPhoto({
    required this.id,
    required this.clientId,
    this.date,
    required this.photoUrl,
    required this.photoType,
    this.notes,
  });

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    return ProgressPhoto(
      id: asInt(json['id']) ?? 0,
      clientId: asInt(json['client_id']) ?? 0,
      date: _parseDate(json['date']),
      photoUrl: (json['photo_url'] ?? '').toString(),
      photoType: (json['photo_type'] ?? '').toString(),
      notes: json['notes']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
