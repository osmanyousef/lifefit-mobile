import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

import '../../../core/models/programs/client_program_detail.dart';
import '../../../core/models/programs/program_assignment_summary.dart';
import '../../../core/services/client_program_service.dart';

class ClientProgramsNotifier extends StateNotifier<AsyncValue<List<ProgramAssignmentSummary>>> {
  final ClientProgramService _service;

  ClientProgramsNotifier(this._service) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.fetchPrograms();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => fetch();
}

final clientProgramsProvider =
    StateNotifierProvider<ClientProgramsNotifier, AsyncValue<List<ProgramAssignmentSummary>>>((ref) {
  ref.watch(currentUserIdProvider);
  return ClientProgramsNotifier(ClientProgramService());
});

final clientProgramDetailProvider =
    FutureProvider.autoDispose.family<ClientProgramDetail, int>((ref, assignmentId) async {
  final service = ClientProgramService();
  return service.fetchProgramDetail(assignmentId);
});
