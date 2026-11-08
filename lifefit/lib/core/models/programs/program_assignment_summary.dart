import '../../utils/json_parse.dart';
/// List item from `GET /api/client/programs` → `data[]` (ProgramAssignmentResource).
class ProgramAssignmentSummary {
  final int id;
  final int programId;
  final String programName;
  final String? programDescription;
  final int? programDurationWeeks;
  final String trainerName;
  final String? trainerImage;
  final DateTime? startDate;
  final String? status;
  final String? notes;
  final DateTime? assignedAt;

  const ProgramAssignmentSummary({
    required this.id,
    required this.programId,
    required this.programName,
    this.programDescription,
    this.programDurationWeeks,
    required this.trainerName,
    this.trainerImage,
    this.startDate,
    this.status,
    this.notes,
    this.assignedAt,
  });

  factory ProgramAssignmentSummary.fromJson(Map<String, dynamic> json) {
    return ProgramAssignmentSummary(
      id: asInt(json['id']) ?? 0,
      programId: asInt(json['program_id']) ?? 0,
      programName: (json['program_name'] ?? '').toString(),
      programDescription: json['program_description']?.toString(),
      programDurationWeeks: asInt(json['program_duration_weeks']),
      trainerName: (json['trainer_name'] ?? '').toString(),
      trainerImage: json['trainer_image']?.toString(),
      startDate: _parseDate(json['start_date']),
      status: json['status']?.toString(),
      notes: json['notes']?.toString(),
      assignedAt: _parseDate(json['assigned_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
