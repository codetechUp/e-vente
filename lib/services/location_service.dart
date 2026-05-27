import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  /// Request permission and get the current GPS coordinates.
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) debugPrint('Location permissions are denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) debugPrint('Location permissions are permanently denied.');
        return null;
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error or timeout getting current position, falling back to last known: $e');
        }
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Perform reverse geocoding via OpenStreetMap Nominatim API to get an address string.
  /// Nominatim requires a User-Agent header to avoid 403 responses.
  static Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'GrosDiversApp/1.0 (contact@gros-divers.sn)',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      } else {
        if (kDebugMode) {
          debugPrint('Nominatim API error: ${response.statusCode} ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in reverse geocoding: $e');
    }
    return null;
  }
}
