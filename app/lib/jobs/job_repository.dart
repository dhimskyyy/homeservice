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
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    final data = await c
        .from('jobs')
        .select('*, service_categories(name)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(100);

    return (data as List).map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Job>> getOpenJobs({String? excludeProviderId}) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    List<String> appliedJobIds = [];
    if (excludeProviderId != null) {
      final apps = await c
          .from('job_applications')
          .select('job_id')
          .eq('provider_id', excludeProviderId);
      appliedJobIds = (apps as List).map((a) => a['job_id'].toString()).toList();
    }

    var query = c
        .from('jobs')
        .select('*, service_categories(name)')
        .eq('status', 'open');

    final data = await query.order('created_at', ascending: false).limit(50);
    var jobs = (data as List).map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();

    // Saring agar job yang sudah di-respond tukang tidak muncul lagi di feed sekitar
    if (appliedJobIds.isNotEmpty) {
      jobs = jobs.where((j) => !appliedJobIds.contains(j.id)).toList();
    }

    return jobs;
  }

  Future<List<Job>> getTukangJobs(String providerId, {bool onlyActive = true}) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    // 1. Ambil job ID yang pernah di-apply tukang ini
    final apps = await c
        .from('job_applications')
        .select('job_id, status')
        .eq('provider_id', providerId);

    final appliedJobIds = (apps as List)
        .map((a) => a['job_id'].toString())
        .toList();

    List<dynamic> data;
    if (appliedJobIds.isEmpty) {
      data = await c
          .from('jobs')
          .select('*, service_categories(name)')
          .eq('selected_provider_id', providerId)
          .order('created_at', ascending: false)
          .limit(100);
    } else {
      data = await c
          .from('jobs')
          .select('*, service_categories(name)')
          .or('selected_provider_id.eq.$providerId,id.in.(${appliedJobIds.join(",")})')
          .order('created_at', ascending: false)
          .limit(100);
    }

    var jobs = data.map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();

    if (onlyActive) {
      // Hanya tampilkan pekerjaan yang aktif (open, locked, in_progress)
      // Pekerjaan yang sudah selesai (done, paid, cancelled) tidak ditampilkan di pekerjaan aktif
      jobs = jobs.where((j) =>
          j.status == JobStatus.open ||
          j.status == JobStatus.locked ||
          j.status == JobStatus.inProgress
      ).toList();
    }

    return jobs;
  }

  Future<Job?> getJobDetail(String jobId) async {
    final c = client;
    if (c == null) return null;

    final data = await c
        .from('jobs')
        .select('*, service_categories(name), customer_profile:customer_id(full_name), provider_profile:selected_provider_id(full_name, tukang_profiles(rating_avg))')
        .eq('id', jobId)
        .maybeSingle();

    if (data == null) return null;
    return Job.fromJson(data);
  }

  Future<List<JobApplication>> getJobApplications(String jobId) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

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

    // RPC atomic: nota pending->paid + job done->paid dalam 1 transaksi
    await c.rpc('approve_payment_provider', params: {
      'p_agreement_id': agreementId,
    });
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
