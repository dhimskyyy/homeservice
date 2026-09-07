import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class FcmService {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM Init Error (diabaikan jika tanpa konfigurasi native): $e');
    }
  }

  static Future<void> registerDeviceToken(String userId, SupabaseClient client) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final deviceType = Platform.isIOS ? 'ios' : 'android';

      await client.from('user_fcm_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'device_type': deviceType,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );

      // Dengarkan jika ada refresh token
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await client.from('user_fcm_tokens').upsert(
            {
              'user_id': userId,
              'token': newToken,
              'device_type': deviceType,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id,token',
          );
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  static Future<void> removeDeviceToken(String userId, SupabaseClient client) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
    } catch (_) {}
  }
}
