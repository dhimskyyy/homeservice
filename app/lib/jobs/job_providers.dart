import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../core/supabase_client.dart';
import '../shared/models/job_models.dart';
import 'job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return JobRepository(client: client);
  } catch (_) {
    return JobRepository(client: null);
  }
});

final customerJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getCustomerJobs(user.id);
});

final openJobsForTukangProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final user = ref.watch(authProvider).user;
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getOpenJobs(excludeProviderId: user?.id);
});

final tukangJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getTukangJobs(user.id, onlyActive: true);
});

final tukangAllJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getTukangJobs(user.id, onlyActive: false);
});

final jobDetailProvider = FutureProvider.autoDispose.family<Job?, String>((ref, jobId) async {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getJobDetail(jobId);
});

final jobApplicationsProvider = FutureProvider.autoDispose.family<List<JobApplication>, String>((ref, jobId) async {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getJobApplications(jobId);
});

final hasRespondedProvider = FutureProvider.autoDispose.family<bool, String>((ref, jobId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return false;
  final repo = ref.watch(jobRepositoryProvider);
  return repo.hasResponded(jobId: jobId, providerId: user.id);
});
