import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/admin/data/admin_repository.dart';
import 'package:ngo_app/features/admin/data/fellow_summary.dart';
import 'package:ngo_app/features/documents/data/document.dart';
import 'package:ngo_app/features/profile/data/fellow_profile.dart';
import 'package:ngo_app/features/volunteers/data/volunteer.dart';

final adminRepositoryProvider =
    Provider((ref) => AdminRepository(ref.watch(apiClientProvider)));

final fellowListProvider = FutureProvider<List<FellowSummary>>((ref) {
  return ref.watch(adminRepositoryProvider).getFellows();
});

final filteredFellowListProvider =
    FutureProvider.family<List<FellowSummary>, int?>((ref, block) {
  return ref.watch(adminRepositoryProvider).getFellows(block: block);
});

final fellowDetailProvider =
    FutureProvider.family<FellowProfile, String>((ref, fellowId) {
  return ref.watch(adminRepositoryProvider).getFellowDetail(fellowId);
});

final fellowDocumentsProvider =
    FutureProvider.family<List<Document>, String>((ref, fellowId) {
  return ref.watch(adminRepositoryProvider).getFellowDocuments(fellowId);
});

final fellowVolunteersProvider =
    FutureProvider.family<List<Volunteer>, String>((ref, fellowId) {
  return ref.watch(adminRepositoryProvider).getFellowVolunteers(fellowId);
});
