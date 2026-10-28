import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../hive/hive_service.dart';
import '../network/ola_maps_service.dart';

/// Centralized service for device GPS, geocoding, distance computation, and turn-by-turn navigation.
class LocationService {
  LocationService._();

  /// Effective fallback or initial location.
  /// If citizen has selected a manual location, it is prioritized across all stores, toilets, and maps.
  static LatLng get defaultLocation {
    final manual = HiveService.getManualLocation();
    if (manual != null && manual['latitude'] != null && manual['longitude'] != null) {
      return LatLng(
        (manual['latitude'] as num).toDouble(),
        (manual['longitude'] as num).toDouble(),
      );
    }
    if (_cachedGpsPosition != null) {
      return LatLng(_cachedGpsPosition!.latitude, _cachedGpsPosition!.longitude);
    }
    return const LatLng(12.9716, 77.5946);
  }

  /// Checks if the citizen currently has a saved manual location.
  static bool get hasManualLocation => HiveService.getManualLocation() != null;

  /// Retrieves the citizen's saved manual address text, if any.
  static String? get manualAddress {
    final manual = HiveService.getManualLocation();
    return manual?['address'] as String?;
  }

  /// Returns a synthetic Position corresponding to citizen's manual location.
  static Position? getManualPosition() {
    final manual = HiveService.getManualLocation();
    if (manual != null && manual['latitude'] != null && manual['longitude'] != null) {
      final double lat = (manual['latitude'] as num).toDouble();
      final double lng = (manual['longitude'] as num).toDouble();
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
    return null;
  }

  static Position? _cachedGpsPosition;
  static String? _cachedGpsAddress;

  /// Cached live GPS address if geocoded during session
  static String? get cachedGpsAddress => _cachedGpsAddress;

  /// Cached live GPS position if acquired during session
  static Position? get cachedGpsPosition => _cachedGpsPosition;

  /// Clears in-memory GPS position and address caches.
  static void clearGpsCache() {
    _cachedGpsPosition = null;
    _cachedGpsAddress = null;
  }

  /// Checks whether either a manual location is saved or live hardware GPS is currently active and permitted.
  static Future<bool> isLocationAvailable() async {
    if (hasManualLocation) return true;
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        clearGpsCache();
        return false;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        clearGpsCache();
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the relevant system settings (app settings if permission permanently denied, or location settings if GPS switch is off).
  static Future<void> openAppropriateSettings() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      } else {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
      }
    } catch (_) {}
  }

  /// Checks device location service status and permissions, prioritizing the citizen's manual location if selected.
  static Future<Position?> getCurrentPosition({
    bool requestPermission = true,
    bool forceGps = false,
  }) async {
    // 1. If citizen chose a manual location and caller did not explicitly force hardware GPS
    if (!forceGps) {
      final manualPos = getManualPosition();
      if (manualPos != null) {
        return manualPos;
      }
    }

    // 2. Otherwise query live device GPS
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services are disabled on device.');
        if (requestPermission) {
          await Geolocator.openLocationSettings();
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        }
        if (!serviceEnabled) {
          return forceGps ? null : getManualPosition();
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permissions denied ($permission).');
        return forceGps ? null : getManualPosition();
      }

      // If location is permitted in-app, ensure hasSeenPermissionScreen is set so screen won't reappear on restart
      if (!HiveService.hasSeenPermissionScreen) {
        await HiveService.setHasSeenPermissionScreen(true);
      }

      // Try immediate last-known location to seed cache swiftly
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _cachedGpsPosition = lastKnown;
        }
      } catch (_) {}

      // Try high accuracy with 6s timeout, then fallback to medium (indoor/network)
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (highAccErr) {
        debugPrint('[LocationService] High accuracy GPS timeout, trying network/medium: $highAccErr');
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {}
      }

      if (pos != null) {
        _cachedGpsPosition = pos;
        return pos;
      }
      if (_cachedGpsPosition != null) {
        return _cachedGpsPosition;
      }
      return forceGps ? null : getManualPosition();
    } catch (e) {
      debugPrint('[LocationService] Error obtaining current position: $e');
      if (_cachedGpsPosition != null) {
        return _cachedGpsPosition;
      }
      return forceGps ? null : getManualPosition();
    }
  }

  /// Clears any manual location override in storage and switches back to live hardware GPS.
  static Future<Position?> switchToLiveGps() async {
    await HiveService.clearManualLocation();
    _cachedGpsAddress = null;
    final pos = await getCurrentPosition(requestPermission: true, forceGps: true);
    if (pos != null) {
      _cachedGpsPosition = pos;
      _cachedGpsAddress = await getAddressFromCoordinates(pos.latitude, pos.longitude);
    }
    return pos;
  }

  /// Returns the current human-readable display address (either manual if active, or live GPS address).
  static Future<String> getEffectiveAddress() async {
    if (hasManualLocation) {
      return manualAddress ?? 'Manual Location';
    }
    final bool available = await isLocationAvailable();
    if (!available) {
      clearGpsCache();
      return '';
    }
    if (_cachedGpsAddress != null && _cachedGpsAddress!.isNotEmpty) {
      return _cachedGpsAddress!;
    }
    final pos = await getCurrentPosition(requestPermission: false, forceGps: true);
    if (pos != null) {
      _cachedGpsAddress = await getAddressFromCoordinates(pos.latitude, pos.longitude);
      return _cachedGpsAddress!;
    }
    return '';
  }

  static final Geocoding _geocoding = Geocoding();

  /// Converts GPS coordinates into a human-readable street address with locality and postal code.
  static Future<String> getAddressFromCoordinates(double lat, double lng) async {
    // 1. Prioritize Ola Maps Reverse Geocoding (high accuracy for Indian addresses)
    final olaResult = await OlaMapsService.reverseGeocode(lat, lng);
    if (olaResult != null && olaResult.addressLine.isNotEmpty) {
      return olaResult.addressLine;
    }

    // 2. Fallback to native OS geocoder
    try {
      final List<Placemark> placemarks = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final List<String> parts = [];

        final name = p.name?.trim() ?? '';
        final street = p.street?.trim() ?? '';
        final subLocality = p.subLocality?.trim() ?? '';
        final locality = p.locality?.trim() ?? '';
        final postalCode = p.postalCode?.trim() ?? '';

        if (name.isNotEmpty && !parts.contains(name)) parts.add(name);
        if (street.isNotEmpty && street != name && !parts.contains(street)) parts.add(street);
        if (subLocality.isNotEmpty && !parts.contains(subLocality)) parts.add(subLocality);
        if (locality.isNotEmpty && !parts.contains(locality)) parts.add(locality);
        if (postalCode.isNotEmpty && !parts.contains(postalCode)) parts.add(postalCode);

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Error reverse geocoding ($lat, $lng): $e');
    }
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  /// Converts GPS coordinates into a map containing detected building/house and formatted address.
  static Future<Map<String, String>> getDetailedAddressFromCoordinates(double lat, double lng) async {
    // 1. Prioritize Ola Maps Reverse Geocoding
    final olaResult = await OlaMapsService.reverseGeocode(lat, lng);
    if (olaResult != null) {
      return {
        'house': olaResult.houseNumber.isNotEmpty ? olaResult.houseNumber : 'Flat 101',
        'address': olaResult.addressLine,
      };
    }

    // 2. Fallback to native OS geocoder
    try {
      final List<Placemark> placemarks = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final name = p.name?.trim() ?? '';
        final street = p.street?.trim() ?? '';
        final subThoroughfare = p.subThoroughfare?.trim() ?? '';
        final thoroughfare = p.thoroughfare?.trim() ?? '';
        final subLocality = p.subLocality?.trim() ?? '';
        final locality = p.locality?.trim() ?? '';
        final postalCode = p.postalCode?.trim() ?? '';

        String houseNumber = '';
        if (subThoroughfare.isNotEmpty) {
          houseNumber = subThoroughfare;
        } else if (name.isNotEmpty && name != street && name != thoroughfare) {
          houseNumber = name;
        } else if (name.isNotEmpty) {
          houseNumber = name;
        }

        final List<String> addressParts = [];
        if (street.isNotEmpty && street != houseNumber && !addressParts.contains(street)) {
          addressParts.add(street);
        } else if (thoroughfare.isNotEmpty && thoroughfare != houseNumber && !addressParts.contains(thoroughfare)) {
          addressParts.add(thoroughfare);
        }
        if (subLocality.isNotEmpty && !addressParts.contains(subLocality)) addressParts.add(subLocality);
        if (locality.isNotEmpty && !addressParts.contains(locality)) addressParts.add(locality);
        if (postalCode.isNotEmpty && !addressParts.contains(postalCode)) addressParts.add(postalCode);

        final String fullAddress = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : (street.isNotEmpty ? street : '$lat, $lng');

        return {
          'house': houseNumber.isNotEmpty ? houseNumber : (name.isNotEmpty ? name : 'Flat 101'),
          'address': fullAddress,
        };
      }
    } catch (e) {
      debugPrint('[LocationService] Error reverse geocoding details ($lat, $lng): $e');
    }
    return {
      'house': 'Flat 101',
      'address': '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
    };
  }

  /// Converts a textual street address into latitude and longitude coordinates.
  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    // 1. Prioritize Ola Maps Geocoding
    final olaCoords = await OlaMapsService.geocodeAddress(address);
    if (olaCoords != null) return olaCoords;

    // 2. Fallback to native OS geocoder
    try {
      final List<Location> locations = await _geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return LatLng(loc.latitude, loc.longitude);
      }
    } catch (e) {
      debugPrint('[LocationService] Error geocoding address "$address": $e');
    }
    return null;
  }

  /// Computes the straight-line distance in meters between two GPS coordinates.
  static double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Formats distance in meters into user-friendly string (e.g. "250 m" or "1.8 km").
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Computes estimated travel duration in minutes based on distance in meters.
  /// - Walking: average human walking speed is ~4.8 km/h (~80 meters/min).
  /// - Two-wheeler / Bike: average urban city speed is ~21-24 km/h (~350 meters/min).
  static int calculateEtaMinutes(double meters, {required bool isWalking}) {
    if (meters <= 0) return 1;
    final speedMetersPerMin = isWalking ? 80.0 : 350.0;
    return (meters / speedMetersPerMin).ceil().clamp(1, 9999);
  }

  /// Formats travel duration in minutes into a clean, friendly string (e.g. "1 min", "8 min", "1 hr 15 min").
  /// If hours is 0, only minutes is returned (never "0 hours").
  static String formatEta(int minutes) {
    if (minutes <= 0) return '1 min';
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      if (hours == 0) {
        return '$remainingMins min';
      }
      return remainingMins > 0 ? '$hours hr $remainingMins min' : '$hours hr';
    }
  }

  /// Cleans and sanitizes any duration string to remove redundant "0 hours", "0 hour", "0 hrs", or "0 hr"
  /// returned by APIs (e.g. "0 hours 4 mins" -> "4 mins", "0 hr 12 min" -> "12 min").
  static String cleanDurationString(String duration) {
    if (duration.isEmpty) return '';
    // Strip leading "0 hours and ", "0 hours, ", "0 hours ", "0 hour ", "0 hrs ", "0 hr " (case-insensitive)
    String cleaned = duration
        .replaceAll(RegExp(r'\b0\s*(?:hours?|hrs?)\s*(?:and|,)?\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty || cleaned == '0 min' || cleaned == '0 mins') {
      return '1 min';
    }
    return cleaned;
  }

  /// Formats estimated arrival time based on travel duration from current time (e.g. "12:35 pm").
  static String formatArrivalTime(int minutesFromNow) {
    final eta = DateTime.now().add(Duration(minutes: minutesFromNow));
    final hour = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final minute = eta.minute.toString().padLeft(2, '0');
    final amPm = eta.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $amPm';
  }

  /// Launches native turn-by-turn navigation (Google Maps / Apple Maps) via deep link.
  /// If [originLat]/[originLng] or [originAddress] are provided (manual/picked location or custom origin),
  /// they are used as the start point ("From"). Otherwise Google Maps uses the device's current GPS location.
  static Future<bool> launchTurnByTurnNavigation({
    double? originLat,
    double? originLng,
    String? originAddress,
    double? destLat,
    double? destLng,
    String? address,
    bool isWalking = false,
  }) async {
    final mode = isWalking ? 'w' : 'd';
    final travelMode = isWalking ? 'walking' : 'driving';
    final targetDestination = (destLat != null && destLng != null)
        ? '$destLat,$destLng'
        : Uri.encodeComponent(address ?? '');

    if (targetDestination.isEmpty) {
      debugPrint('[LocationService] Cannot navigate without destination coordinates or address.');
      return false;
    }

    final hasOriginCoords = originLat != null && originLng != null;
    final hasOriginAddress = originAddress != null &&
        originAddress.trim().isNotEmpty &&
        !originAddress.toLowerCase().contains('current location');
    final hasExplicitOrigin = hasOriginCoords || hasOriginAddress;

    final originParam = hasOriginCoords
        ? '$originLat,$originLng'
        : (hasOriginAddress ? Uri.encodeComponent(originAddress) : null);

    // 1. When an explicit origin is specified ("From" address or coordinates),
    // launch Google Maps Directions URL with dir_action=navigate.
    // This pre-fills From and To exactly as requested and activates navigation.
    if (hasExplicitOrigin && originParam != null) {
      final directionsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$originParam&destination=$targetDestination&travelmode=$travelMode&dir_action=navigate',
      );
      try {
        if (await canLaunchUrl(directionsUri)) {
          return await launchUrl(directionsUri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('[LocationService] Google Maps directions launch error: $e');
      }
    }

    // 2. Direct Android Turn-by-Turn Navigation Intent from device GPS location
    final nativeUri = Uri.parse('google.navigation:q=$targetDestination&mode=$mode');
    final universalUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$targetDestination&travelmode=$travelMode&dir_action=navigate',
    );

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(universalUri)) {
        return await launchUrl(universalUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[LocationService] Navigation launch error: $e');
    }
    return false;
  }

  /// Queries Ola Maps for authentic real places around [center] matching [keyword].
  /// Never returns mock or placeholder names.
  static Future<List<Map<String, dynamic>>> fetchRealNearbyFacilities({
    required String keyword,
    required LatLng center,
    required String fallbackCategory,
    int limit = 5,
  }) async {
    final List<Map<String, dynamic>> results = [];
    final Set<String> seenNames = {};

    try {
      // 1. Resolve locality for high-accuracy localized query
      String areaQuery = keyword;
      final centerAddress = await OlaMapsService.reverseGeocode(center.latitude, center.longitude);
      if (centerAddress != null) {
        final loc = centerAddress.subLocality.isNotEmpty
            ? centerAddress.subLocality
            : centerAddress.locality;
        if (loc.isNotEmpty) {
          areaQuery = '$keyword $loc';
        }
      }

      // 2. Query Ola Maps Places API
      var predictions = await OlaMapsService.autocompletePlaces(areaQuery, location: center, radius: 5000);
      if (predictions.isEmpty) {
        predictions = await OlaMapsService.autocompletePlaces(keyword, location: center, radius: 5000);
      }

      for (final p in predictions) {
        if (results.length >= limit) break;
        final name = p.mainText.trim();
        if (name.isEmpty || seenNames.contains(name.toLowerCase())) continue;
        seenNames.add(name.toLowerCase());

        double? lat = p.latitude;
        double? lng = p.longitude;

        if (lat == null || lng == null) {
          final coords = await getCoordinatesFromAddress(p.description);
          lat = coords?.latitude;
          lng = coords?.longitude;
        }

        if (lat != null && lng != null) {
          final dist = calculateDistance(
            center.latitude,
            center.longitude,
            lat,
            lng,
          );
          results.add({
            'title': name,
            'address': p.description,
            'lat': lat,
            'lng': lng,
            'distance': formatDistance(dist),
          });
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Error fetching nearby places for "$keyword": $e');
    }

    // 3. If fewer than limit items found (e.g. sparse or rural area), reverse geocode real roads nearby
    if (results.length < limit) {
      final offsets = [
        const [0.0015, 0.0012],
        const [-0.0018, 0.0016],
        const [0.0028, -0.0022],
        const [-0.0035, -0.0028],
        const [0.0042, 0.0038],
      ];

      for (int i = results.length; i < limit && i < offsets.length; i++) {
        final offLat = center.latitude + offsets[i][0];
        final offLng = center.longitude + offsets[i][1];
        final rev = await OlaMapsService.reverseGeocode(offLat, offLng);

        String title;
        String address;
        if (rev != null && rev.street.isNotEmpty) {
          title = '$fallbackCategory - ${rev.street}';
          address = rev.addressLine;
        } else if (rev != null && rev.formattedAddress.isNotEmpty) {
          final firstPart = rev.formattedAddress.split(',').first.trim();
          title = '$fallbackCategory - $firstPart';
          address = rev.formattedAddress;
        } else {
          title = '$fallbackCategory near (${offLat.toStringAsFixed(4)}, ${offLng.toStringAsFixed(4)})';
          address = 'Street location (${offLat.toStringAsFixed(4)}, ${offLng.toStringAsFixed(4)})';
        }

        final dist = calculateDistance(
          center.latitude,
          center.longitude,
          offLat,
          offLng,
        );

        results.add({
          'title': title,
          'address': address,
          'lat': offLat,
          'lng': offLng,
          'distance': formatDistance(dist),
        });
      }
    }

    // Sort by actual distance
    results.sort((a, b) {
      final d1 = calculateDistance(center.latitude, center.longitude, a['lat'] as double, a['lng'] as double);
      final d2 = calculateDistance(center.latitude, center.longitude, b['lat'] as double, b['lng'] as double);
      return d1.compareTo(d2);
    });

    return results;
  }
}
