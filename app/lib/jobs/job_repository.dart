import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/models/job_models.dart';

class JobRepository {
  final SupabaseClient? client;

  JobRepository({this.client});

  Future<Job> createJob({
    required String customerId,
    required String categoryId,
    required String title,
    required String description,
    required double lat,
    required double lng,
  }) async {
    final c = client;
    if (c == null) {
      throw Exception('Supabase client tidak diinisialisasi');
    }

    final res = await c
        .from('jobs')
        .insert({
          'customer_id': customerId,
          'category_id': categoryId,
          'title': title,
          'description': description,
          'lat': lat,
          'lng': lng,
          'status': 'open',
        })
        .select('*, service_categories(name)')
        .single();

    return Job.fromJson(res);
  }

  Future<List<Job>> getCustomerJobs(String customerId) async {
    final c = client;
    if (c == null) return [];

    final data = await c
        .from('jobs')
        .select('*, service_categories(name)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (data as List).map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Job>> getOpenJobs() async {
    final c = client;
    if (c == null) return [];

    final data = await c
        .from('jobs')
        .select('*, service_categories(name)')
        .eq('status', 'open')
        .order('created_at', ascending: false);

    return (data as List).map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Job?> getJobDetail(String jobId) async {
    final c = client;
    if (c == null) return null;

    final data = await c
        .from('jobs')
        .select('*, service_categories(name)')
        .eq('id', jobId)
        .maybeSingle();

    if (data == null) return null;
    return Job.fromJson(data);
  }

  Future<List<JobApplication>> getJobApplications(String jobId) async {
    final c = client;
    if (c == null) return [];

    final data = await c
        .from('job_applications')
        .select('*, profiles:provider_id(full_name, tukang_profiles(bio, rating_avg, payment_methods))')
        .eq('job_id', jobId)
        .order('created_at', ascending: true);

    return (data as List).map((item) {
      return JobApplication.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  Future<void> respondToJob({
    required String jobId,
    required String providerId,
  }) async {
    final c = client;
    if (c == null) return;

    await c.from('job_applications').insert({
      'job_id': jobId,
      'provider_id': providerId,
      'status': 'responded',
    });
  }

  Future<bool> hasResponded({
    required String jobId,
    required String providerId,
  }) async {
    final c = client;
    if (c == null) return false;

    final data = await c
        .from('job_applications')
        .select('id')
        .eq('job_id', jobId)
        .eq('provider_id', providerId)
        .maybeSingle();

    return data != null;
  }

  Future<void> lockProvider({
    required String jobId,
    required String providerId,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    await c.from('jobs').update({
      'status': 'locked',
      'selected_provider_id': providerId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  Future<void> startJob(String jobId) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    await c.from('jobs').update({
      'status': 'in_progress',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  Future<void> completeJob(String jobId) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    await c.from('jobs').update({
      'status': 'done',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  Future<void> approvePayment({
    required String agreementId,
    required String jobId,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    // 1. Update status nota menjadi 'paid'
    await c.from('price_agreements').update({
      'status': 'paid',
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', agreementId);

    // 2. Update status job menjadi 'paid' (transisi done -> paid di-guard trigger jobs_status_guard)
    await c.from('jobs').update({
      'status': 'paid',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  Future<void> cancelJob(String jobId) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    await c.from('jobs').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', jobId);
  }

  Future<void> deleteJob(String jobId) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    await c.from('jobs').delete().eq('id', jobId);
  }
}
