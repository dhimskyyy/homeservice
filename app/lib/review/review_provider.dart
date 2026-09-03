import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase_client.dart';
import '../shared/models/job_models.dart';
import 'review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return ReviewRepository(client: client);
  } catch (_) {
    return ReviewRepository(client: null);
  }
});

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return ComplaintRepository(client: client);
  } catch (_) {
    return ComplaintRepository(client: null);
  }
});

final jobReviewProvider = FutureProvider.autoDispose.family<Review?, String>((ref, jobId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getJobReview(jobId);
});

final jobComplaintProvider = FutureProvider.autoDispose.family<Complaint?, String>((ref, jobId) async {
  final repo = ref.watch(complaintRepositoryProvider);
  return repo.getJobComplaint(jobId);
});
