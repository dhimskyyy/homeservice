import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/models/user_profile.dart';

class ProfileRepository {
  final SupabaseClient? client;

  ProfileRepository({this.client});

  Future<UserProfile?> getProfile(String userId) async {
    final c = client;
    if (c == null) return null;
    final data = await c
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<TukangProfile?> getTukangProfile(String userId) async {
    final c = client;
    if (c == null) return null;
    final data = await c
        .from('tukang_profiles')
        .select()
        .eq('profile_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return TukangProfile.fromJson(data);
  }

  Future<List<ServiceCategory>> getServiceCategories() async {
    final c = client;
    if (c == null) return [];
    final data = await c
        .from('service_categories')
        .select()
        .order('sort_order', ascending: true);

    return (data as List)
        .map((item) => ServiceCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? avatarUrl,
    bool? isOnline,
    double? lat,
    double? lng,
  }) async {
    final c = client;
    if (c == null) return;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (isOnline != null) updates['is_online'] = isOnline;
    if (lat != null) updates['lat'] = lat;
    if (lng != null) updates['lng'] = lng;

    await c.from('profiles').update(updates).eq('id', userId);
  }

  Future<void> becomeTukang({
    required String bio,
    required List<String> serviceTypeIds,
    required List<PaymentMethod> paymentMethods,
  }) async {
    final c = client;
    if (c == null) return;
    await c.rpc(
      'become_tukang',
      params: {
        'p_bio': bio,
        'p_service_type_ids': serviceTypeIds,
        'p_payment_methods': paymentMethods.map((m) => m.toDbValue()).toList(),
      },
    );
  }
}
