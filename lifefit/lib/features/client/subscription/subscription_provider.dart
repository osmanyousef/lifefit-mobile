import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';

import '../../../core/models/subscription/expert_model.dart';
import '../../../core/models/subscription/my_subscription_model.dart';
import '../../../core/services/subscription_service.dart';

// ─── Experts Provider ─────────────────────────────────────────────────────────
// Used by: TrainersScreen → TrainersExpertCard
// Fetches trainers/nutritionists with per-expert subscription status.

/// Holds the list of available experts (trainers + nutritionists).
class ExpertsNotifier
    extends StateNotifier<AsyncValue<List<ExpertModel>>> {
  final SubscriptionService _service;

  ExpertsNotifier(this._service) : super(const AsyncValue.loading()) {
    fetch();
  }

  /// Loads experts from API; transitions loading → data or error.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _service.fetchExperts());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Re-fetch — called after successful payment or pull-to-refresh.
  Future<void> refresh() => fetch();
}

/// Watched by [TrainersScreen]; refreshed via [ExpertsNotifier.refresh].
final expertsProvider = StateNotifierProvider<
    ExpertsNotifier, AsyncValue<List<ExpertModel>>>(
  (ref) {
    ref.watch(currentUserIdProvider);
    return ExpertsNotifier(SubscriptionService());
  },
);

// ─── My Subscriptions Provider ────────────────────────────────────────────────
// Used by: MySubscriptionsScreen
// Fetches current/past subscriptions; reload via ref.invalidate.

/// Client subscription history — List<MySubscription>.
final mySubscriptionsProvider =
    FutureProvider.autoDispose<List<MySubscription>>((ref) {
  ref.watch(currentUserIdProvider);
  return SubscriptionService().fetchMySubscriptions();
});
