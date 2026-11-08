import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import 'client_home_state.dart';

final clientHomeProvider =
    StateNotifierProvider<ClientHomeNotifier, ClientHomeState>(
  (ref) {
    ref.watch(currentUserIdProvider);
    return ClientHomeNotifier();
  },
);

class ClientHomeNotifier extends StateNotifier<ClientHomeState> {
  ClientHomeNotifier() : super(const ClientHomeState());

  void changeTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  Future<void> loadHomeData() async {
    state = state.copyWith(isLoading: true);

    // لاحقاً: API calls (Dashboard, workouts, meals...)
    await Future.delayed(const Duration(seconds: 1));

    state = state.copyWith(isLoading: false);
  }
}
