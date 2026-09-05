import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/models/job_models.dart';

class ReviewRepository {
  final SupabaseClient? client;

  ReviewRepository({this.client});

  Future<Review?> getJobReview(String jobId) async {
    final c = client;
    if (c == null) return null;

    final data = await c
        .from('reviews')
        .select('*, profiles:customer_id(full_name)')
        .eq('job_id', jobId)
        .maybeSingle();

    if (data == null) return null;
    return Review.fromJson(data);
  }

  Future<List<Review>> getProviderReviews(String providerId) async {
    final c = client;
    if (c == null) return [];

    final data = await c
        .from('reviews')
        .select('*, profiles:customer_id(full_name)')
        .eq('provider_id', providerId)
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List).map((r) => Review.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Review> createReview({
    required String jobId,
    required String customerId,
    required String providerId,
    required int rating,
    String? comment,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    final data = await c
        .from('reviews')
        .insert({
          'job_id': jobId,
          'customer_id': customerId,
          'provider_id': providerId,
          'rating': rating,
          'comment': comment?.trim().isNotEmpty == true ? comment!.trim() : null,
        })
        .select('*, profiles:customer_id(full_name)')
        .single();

    return Review.fromJson(data);
  }
}

class ComplaintRepository {
  final SupabaseClient? client;

  ComplaintRepository({this.client});

  Future<Complaint?> getJobComplaint(String jobId) async {
    final c = client;
    if (c == null) return null;

    final data = await c
        .from('complaints')
        .select()
        .eq('job_id', jobId)
        .maybeSingle();

    if (data == null) return null;
    return Complaint.fromJson(data);
  }

  Future<Complaint> createComplaint({
    required String jobId,
    required String customerId,
    required String providerId,
    required String reason,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    final data = await c
        .from('complaints')
        .insert({
          'job_id': jobId,
          'customer_id': customerId,
          'provider_id': providerId,
          'reason': reason.trim(),
          'status': 'open',
        })
        .select()
        .single();

    return Complaint.fromJson(data);
  }
}
