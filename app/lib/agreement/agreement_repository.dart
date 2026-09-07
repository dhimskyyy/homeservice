import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/models/job_models.dart';
import '../shared/models/user_profile.dart';

class AgreementRepository {
  final SupabaseClient? client;

  AgreementRepository({this.client});

  Future<List<PriceAgreement>> getAgreements(String jobId) async {
    final c = client;
    if (c == null) return [];

    final data = await c
        .from('price_agreements')
        .select('*, profiles:provider_id(full_name)')
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    return (data as List).map((a) => PriceAgreement.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<PriceAgreement> createAgreement({
    required String jobId,
    required String customerId,
    required String providerId,
    required int amount,
    required PaymentMethod paymentMethod,
  }) async {
    final c = client;
    if (c == null) {
      throw Exception('Supabase client tidak diinisialisasi');
    }

    final data = await c
        .from('price_agreements')
        .insert({
          'job_id': jobId,
          'customer_id': customerId,
          'provider_id': providerId,
          'amount': amount,
          'payment_method': paymentMethod.toDbValue(),
          'status': 'pending',
          'voided': false,
        })
        .select('*, profiles:provider_id(full_name)')
        .single();

    return PriceAgreement.fromJson(data);
  }

  Future<String> uploadPaymentProof({
    required String agreementId,
    required String jobId,
    required String fileName,
    required dynamic bytes,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase client tidak diinisialisasi');

    final path = '$jobId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await c.storage.from('payments').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = c.storage.from('payments').getPublicUrl(path);

    await c.from('price_agreements').update({
      'payment_proof_url': publicUrl,
    }).eq('id', agreementId);

    return publicUrl;
  }

  RealtimeChannel? subscribeToAgreements({
    required String jobId,
    required void Function() onUpdate,
  }) {
    final c = client;
    if (c == null) return null;

    final channel = c.channel('public:price_agreements:job=$jobId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'price_agreements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'job_id',
            value: jobId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();

    return channel;
  }
}
