import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/progress/personal_record.dart';
import '../../../core/services/progress_service.dart';

// State notifier for personal records list.
class PersonalRecordsNotifier
  extends StateNotifier<AsyncValue<List<PersonalRecord>>> {
  final ProgressService _service;

  PersonalRecordsNotifier(this._service) : super(const AsyncValue.loading()) {
    // Load initial data on creation.
    fetch();
  }

  // Fetch personal records from the API.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.fetchPersonalRecords();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Explicit refresh alias.
  Future<void> refresh() => fetch();
}

// Provider for personal records list state.
final personalRecordsProvider = StateNotifierProvider<PersonalRecordsNotifier,
    AsyncValue<List<PersonalRecord>>>((ref) {
  ref.watch(currentUserIdProvider);
  return PersonalRecordsNotifier(ProgressService());
});
