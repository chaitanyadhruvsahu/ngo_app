import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngo_app/core/providers.dart';
import 'package:ngo_app/features/jobs/data/jobs_repository.dart';
import 'package:ngo_app/features/jobs/services/job_capture.dart';

final workRevisionProvider = StateProvider<int>((ref) => 0);
final jobsRepositoryProvider = Provider<JobsRepository>(
    (ref) => JobsRepository(ref.watch(apiClientProvider), onChanged: () {
      ref.read(workRevisionProvider.notifier).state++;
    }));
final jobCaptureProvider = Provider<JobCapture>((ref) => JobCapture());
