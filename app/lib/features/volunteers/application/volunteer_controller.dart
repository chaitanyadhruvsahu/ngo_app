import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/volunteers/data/volunteer.dart';
import 'package:ngo_app/features/volunteers/data/volunteer_repository.dart';

final volunteerRepositoryProvider =
    Provider((ref) => VolunteerRepository(ref.watch(apiClientProvider)));

final volunteerControllerProvider =
    StateNotifierProvider<VolunteerController, AsyncValue<List<Volunteer>>>((ref) {
  final controller = VolunteerController(ref.watch(volunteerRepositoryProvider));
  controller.load();
  return controller;
});

class VolunteerController extends StateNotifier<AsyncValue<List<Volunteer>>> {
  VolunteerController(this._repository) : super(const AsyncValue.loading());

  final VolunteerRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repository.getMyVolunteers());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _repository.create(data);
    await load();
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _repository.update(id, data);
    await load();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await load();
  }
}
