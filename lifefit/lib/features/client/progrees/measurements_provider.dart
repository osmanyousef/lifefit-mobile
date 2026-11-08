import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/progress/body_measurement.dart';
import '../../../core/services/progress_service.dart';

// State notifier for body measurements history.
class MeasurementsNotifier extends StateNotifier<AsyncValue<List<BodyMeasurement>>> {
  final ProgressService _service;

  MeasurementsNotifier(this._service) : super(const AsyncValue.loading()) {
    // Load initial data on creation.
    fetch();
  }

  // Fetch all measurements from the API.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.fetchAllMeasurements();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Explicit refresh alias.
  Future<void> refresh() => fetch();

  // Submit a new measurement and refresh state.
  Future<BodyMeasurement> submit(Map<String, dynamic> body) async {
    final created = await _service.storeMeasurement(body);
    await fetch();
    return created;
  }
}

// Provider for measurements list state.
final measurementsProvider =
    StateNotifierProvider<MeasurementsNotifier, AsyncValue<List<BodyMeasurement>>>(
  (ref) {
    ref.watch(currentUserIdProvider);
    return MeasurementsNotifier(ProgressService());
  },
);
