import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class StoreLocationResult {
  final double latitude;
  final double longitude;
  final String address;
  final String pincode;
  final String area;
  final String city;

  StoreLocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.pincode,
    required this.area,
    required this.city,
  });
}

class LocationService {
  LocationService._();

  // Default coordinate (Chennai Central / Tamil Nadu Commercial hub)
  static const LatLng defaultLocation = LatLng(13.0827, 80.2707);

  /// Requests permission and fetches high accuracy current device GPS location
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location service disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permissions are permanently denied');
        return null;
      }

      // Try last known first for immediate response
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] Error fetching GPS position: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to human-readable address and postal code
  static Future<StoreLocationResult> reverseGeocode(double lat, double lng) async {
    String address = '';
    String pincode = '';
    String area = '';
    String city = '';

    // 1. Try native platform geocoding
    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final name = p.name?.trim() ?? '';
        final street = p.street?.trim() ?? '';
        final subLoc = p.subLocality?.trim() ?? '';
        final loc = p.locality?.trim() ?? '';
        final postal = p.postalCode?.trim() ?? '';

        area = subLoc.isNotEmpty ? subLoc : loc;
        city = loc.isNotEmpty ? loc : (p.administrativeArea ?? '');
        pincode = postal;

        final parts = <String>[];
        if (name.isNotEmpty && !parts.contains(name)) parts.add(name);
        if (street.isNotEmpty && street != name && !parts.contains(street)) parts.add(street);
        if (subLoc.isNotEmpty && !parts.contains(subLoc)) parts.add(subLoc);
        if (loc.isNotEmpty && !parts.contains(loc)) parts.add(loc);

        if (parts.isNotEmpty) {
          address = parts.join(', ');
          return StoreLocationResult(
            latitude: lat,
            longitude: lng,
            address: address,
            pincode: pincode,
            area: area,
            city: city,
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Native geocoding fallback: $e');
    }

    // 2. OpenStreetMap Nominatim HTTP Fallback (Works on Windows desktop & everywhere)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {'User-Agent': 'GoGovernmentStoreApp/1.0'}).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          pincode = addr['postcode']?.toString() ?? '';
          area = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? '';
          city = addr['city'] ?? addr['town'] ?? addr['county'] ?? addr['state'] ?? '';
          address = data['display_name'] ?? '$lat, $lng';

          return StoreLocationResult(
            latitude: lat,
            longitude: lng,
            address: address,
            pincode: pincode,
            area: area,
            city: city,
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Nominatim reverse geocode error: $e');
    }

    return StoreLocationResult(
      latitude: lat,
      longitude: lng,
      address: 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
      pincode: pincode,
      area: area,
      city: city,
    );
  }

  /// Search for places/localities by keyword using OpenStreetMap Nominatim
  static Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&addressdetails=1&limit=8&countrycodes=in',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GoGovernmentStoreApp/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) {
          final displayName = item['display_name']?.toString() ?? '';
          final parts = displayName.split(',');
          final title = parts.isNotEmpty ? parts.first.trim() : displayName;
          final subtitle = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
          final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;

          return PlaceSearchResult(
            title: title,
            subtitle: subtitle,
            latitude: lat,
            longitude: lon,
          );
        }).where((p) => p.latitude != 0.0 && p.longitude != 0.0).toList();
      }
    } catch (e) {
      debugPrint('[LocationService] Search places error: $e');
    }
    return [];
  }
}

class PlaceSearchResult {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  PlaceSearchResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });
}

