import 'body_measurement.dart';
import '../../utils/json_parse.dart';

/// Laravel `LengthAwarePaginator` JSON shape.
class PaginatedMeasurements {
  final int currentPage;
  final int lastPage;
  final int total;
  final List<BodyMeasurement> data;

  const PaginatedMeasurements({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.data,
  });

  factory PaginatedMeasurements.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => BodyMeasurement.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <BodyMeasurement>[];

    return PaginatedMeasurements(
      currentPage: asInt(json['current_page']) ?? 1,
      lastPage: asInt(json['last_page']) ?? 1,
      total: asInt(json['total']) ?? list.length,
      data: list,
    );
  }
}
