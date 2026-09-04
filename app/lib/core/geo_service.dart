import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'theme.dart';

class GeoService {
  static Future<LatLng?> getCurrentDeviceLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  static Future<String> getAddressFromCoordinates(double lat, double lng) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'BeresApp/1.0 (contact: info@beres.id)');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final address = json['address'] as Map<String, dynamic>?;

        if (address != null) {
          final village = address['village'] ??
              address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['hamlet'];

          final district = address['subdistrict'] ??
              address['city_district'] ??
              address['municipality'] ??
              address['county'];

          final city = address['city'] ??
              address['regency'] ??
              address['town'] ??
              address['state_district'];

          final parts = <String>[];
          if (village != null) parts.add(village.toString());
          if (district != null) parts.add('Kec. ${district.toString()}');
          if (city != null) parts.add(city.toString());

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      }
    } catch (_) {
    } finally {
      client.close();
    }

    return 'Area ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  static Future<bool> ensureTukangGpsEnabled(BuildContext context) async {
    // 1. Cek apakah perangkat menyalakan layanan GPS
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off, color: AppColors.error),
              SizedBox(width: 8),
              Text('Aktifkan GPS Anda'),
            ],
          ),
          content: const Text(
            'Sebagai mitra tukang, Anda wajib mengaktifkan GPS perangkat agar customer dapat memantau lokasi dan pergerakan layanan Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.of(ctx).pop();
                Geolocator.openLocationSettings();
              },
              child: const Text('Buka Pengaturan GPS'),
            ),
          ],
        ),
      );
      return false;
    }

    // 2. Cek izin akses lokasi
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin GPS lokasi ditolak. Tukang wajib mengizinkan GPS untuk mengambil order.'),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Izin Lokasi Ditolak Permanen'),
          content: const Text(
            'Aplikasi membutuhkan izin akses GPS lokasi. Silakan aktifkan izin lokasi di Pengaturan Aplikasi HP Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Geolocator.openAppSettings();
              },
              child: const Text('Buka Pengaturan Aplikasi'),
            ),
          ],
        ),
      );
      return false;
    }

    return true;
  }
}
