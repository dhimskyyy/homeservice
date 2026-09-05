import 'dart:typed_data';
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

  Future<String> uploadAvatar({
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await c.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return c.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> becomeTukang({
    required String bio,
    required List<String> serviceTypeIds,
    required List<PaymentMethod> paymentMethods,
    Map<String, dynamic> paymentDetails = const {},
  }) async {
    final c = client;
    if (c == null) return;
    await c.rpc(
      'become_tukang',
      params: {
        'p_bio': bio,
        'p_service_type_ids': serviceTypeIds,
        'p_payment_methods': paymentMethods.map((m) => m.toDbValue()).toList(),
        'p_payment_details': paymentDetails,
      },
    );
  }

  Future<void> updateTukangPayments({
    required String profileId,
    required List<PaymentMethod> paymentMethods,
    required Map<String, dynamic> paymentDetails,
  }) async {
    final c = client;
    if (c == null) return;
    await c.from('tukang_profiles').update({
      'payment_methods': paymentMethods.map((m) => m.toDbValue()).toList(),
      'payment_details': paymentDetails,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('profile_id', profileId);
  }

  Future<void> updateTukangServices({
    required String profileId,
    required int serviceRadiusKm,
    required List<String> serviceTypeIds,
  }) async {
    final c = client;
    if (c == null) return;
    await c.from('tukang_profiles').update({
      'service_radius_km': serviceRadiusKm.clamp(0, 100),
      'service_type_ids': serviceTypeIds,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('profile_id', profileId);
  }
}
