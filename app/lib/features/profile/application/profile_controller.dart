import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/profile/data/block.dart';
import 'package:ngo_app/features/profile/data/fellow_profile.dart';
import 'package:ngo_app/features/profile/data/profile_repository.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(apiClientProvider)));

final blocksProvider = FutureProvider<List<Block>>((ref) {
  return ref.watch(profileRepositoryProvider).getBlocks();
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<FellowProfile>>((ref) {
  final controller = ProfileController(ref.watch(profileRepositoryProvider));
  controller.load();
  return controller;
});

class ProfileController extends StateNotifier<AsyncValue<FellowProfile>> {
  ProfileController(this._repository) : super(const AsyncValue.loading());

  final ProfileRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.getMyProfile();
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> update(Map<String, dynamic> patch) async {
    // Re-throws on failure so the calling screen can show the error inline
    // — state is only replaced once the update actually succeeds.
    final updated = await _repository.updateMyProfile(patch);
    state = AsyncValue.data(updated);
  }
}
