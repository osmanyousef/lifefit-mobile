import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/progress/progress_photos_grouped.dart';
import '../../../core/services/progress_service.dart';

class ProgressPhotosNotifier extends StateNotifier<AsyncValue<List<ProgressPhotosDay>>> {
  final ProgressService _service;

  ProgressPhotosNotifier(this._service) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.fetchProgressPhotos();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => fetch();

  Future<void> uploadPhoto({
    required DateTime date,
    required XFile file,
    required String photoType,
    String? notes,
  }) async {
    final bytes = await file.readAsBytes();
    final name = file.name.trim().isNotEmpty ? file.name : 'photo.jpg';
    await _service.storeProgressPhoto(
      date: date,
      bytes: bytes,
      fileName: name,
      photoType: photoType,
      notes: notes,
    );
    await fetch();
  }

  Future<void> deletePhoto(int id) async {
    await _service.deleteProgressPhoto(id);
    await fetch();
  }
}

final progressPhotosProvider =
    StateNotifierProvider<ProgressPhotosNotifier, AsyncValue<List<ProgressPhotosDay>>>((ref) {
  ref.watch(currentUserIdProvider);
  return ProgressPhotosNotifier(ProgressService());
});
