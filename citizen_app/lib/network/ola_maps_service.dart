import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/ola_config.dart';

/// Structured address model returned by Ola Maps Reverse Geocoding.
class OlaAddressResult {
  final String formattedAddress;
  final String houseNumber;
  final String street;
  final String subLocality;
  final String locality;
  final String state;
  final String postalCode;
  final double latitude;
  final double longitude;

  const OlaAddressResult({
    required this.formattedAddress,
    this.houseNumber = '',
    this.street = '',
    this.subLocality = '',
    this.locality = '',
    this.state = '',
    this.postalCode = '',
    required this.latitude,
    required this.longitude,
  });

  /// Returns a clean user-friendly address line
  String get addressLine {
    final parts = <String>[];
    if (houseNumber.isNotEmpty) parts.add(houseNumber);
    if (street.isNotEmpty && street != houseNumber) parts.add(street);
    if (subLocality.isNotEmpty && !parts.contains(subLocality)) parts.add(subLocality);
    if (locality.isNotEmpty && !parts.contains(locality)) parts.add(locality);
    if (postalCode.isNotEmpty) parts.add(postalCode);
    return parts.isNotEmpty ? parts.join(', ') : formattedAddress;
  }
}

/// Autocomplete place prediction returned by Ola Maps Places API.
class OlaPlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  const OlaPlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });

  factory OlaPlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    return OlaPlacePrediction(
      placeId: json['place_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mainText: structured?['main_text']?.toString() ?? json['description']?.toString() ?? '',
      secondaryText: structured?['secondary_text']?.toString() ?? '',
      latitude: (location?['lat'] as num?)?.toDouble(),
      longitude: (location?['lng'] as num?)?.toDouble(),
    );
  }
}

/// Turn maneuver step returned in an Ola Maps direction leg.
class OlaRouteStep {
  final String instruction;
  final String maneuver; // e.g. turn-left, turn-right, straight, uturn, roundabout, arrive
  final double distanceMeters;
  final double durationSeconds;
  final String readableDistance;
  final LatLng? startLocation;
  final LatLng? endLocation;

  const OlaRouteStep({
    required this.instruction,
    this.maneuver = 'straight',
    this.distanceMeters = 0.0,
    this.durationSeconds = 0.0,
    this.readableDistance = '',
    this.startLocation,
    this.endLocation,
  });
}

/// Directions route result returned by Ola Maps Routing API.
class OlaRouteResult {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;
  final String readableDistance;
  final String readableDuration;
  final List<OlaRouteStep> steps;

  const OlaRouteResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.readableDistance,
    required this.readableDuration,
    this.steps = const [],
  });
}

/// Service class interfacing directly with Ola Maps Web APIs with OAuth 2.0 & API Key support.
class OlaMapsService {
  OlaMapsService._();

  static final http.Client _client = http.Client();

  static String? _cachedAccessToken;
  static DateTime? _tokenExpiry;
  static Future<String?>? _pendingTokenFuture;

  /// Cleans duration strings by stripping redundant "0 hours", "0 hour", "0 hrs", or "0 hr"
  /// returned by Ola Maps API (e.g. "0 hours 4 mins" -> "4 mins", "0 hr 12 min" -> "12 min").
  static String cleanDuration(String duration) {
    if (duration.isEmpty) return '';
    String cleaned = duration
        .replaceAll(RegExp(r'\b0\s*(?:hours?|hrs?)\s*(?:and|,)?\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty || cleaned == '0 min' || cleaned == '0 mins') {
      return '1 min';
    }
    return cleaned;
  }

  /// Retrieves a valid OAuth 2.0 access token using client credentials.
  static Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
      return _cachedAccessToken;
    }

    if (!OlaConfig.hasValidOAuth) {
      return null;
    }

    if (_pendingTokenFuture != null) {
      return _pendingTokenFuture;
    }

    _pendingTokenFuture = _fetchNewToken();
    try {
      final token = await _pendingTokenFuture;
      return token;
    } finally {
      _pendingTokenFuture = null;
    }
  }

  static Future<String?> _fetchNewToken() async {
    final url = Uri.parse('${OlaConfig.olaMapsBaseUrl}/auth/v1/token');
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'client_credentials',
          'client_id': OlaConfig.clientId,
          'client_secret': OlaConfig.clientSecret,
          'scope': 'openid',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token']?.toString();
        if (token != null && token.isNotEmpty) {
          _cachedAccessToken = token;
          _tokenExpiry = DateTime.now().add(const Duration(hours: 10));
          debugPrint('[OlaMapsService] OAuth token acquired successfully.');
          return token;
        }
      } else {
        debugPrint('[OlaMapsService] OAuth token request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[OlaMapsService] Error fetching OAuth access token: $e');
    }
    return null;
  }

  /// Reverse geocodes latitude/longitude into a structured Indian address.
  static Future<OlaAddressResult?> reverseGeocode(double lat, double lng) async {
    final token = await getAccessToken();
    if (token == null && !OlaConfig.hasValidMapsKey) {
      debugPrint('[OlaMapsService] Skipped reverseGeocode: No valid Ola Maps API key or OAuth credentials configured.');
      return null;
    }

    final queryParams = <String, String>{
      'latlng': '$lat,$lng',
      if (token == null) 'api_key': OlaConfig.mapsApiKey,
    };
    final url = Uri.parse('${OlaConfig.olaMapsBaseUrl}/places/v1/reverse-geocode')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final formatted = first['formatted_address']?.toString() ?? '$lat, $lng';
          final components = first['address_components'] as List<dynamic>? ?? [];
          final placeName = first['name']?.toString() ?? '';

          String houseNum = '';
          String streetName = '';
          String subLoc = '';
          String loc = '';
          String stateName = '';
          String pin = '';

          for (final c in components) {
            if (c is Map<String, dynamic>) {
              final types = (c['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
              final name = c['long_name']?.toString() ?? '';

              if (types.contains('street_number') || types.contains('premise') || types.contains('subpremise')) {
                houseNum = name;
              } else if (types.contains('route') || types.contains('street_address')) {
                streetName = name;
              } else if (types.contains('sublocality') || types.contains('sublocality_level_1') || types.contains('neighborhood')) {
                subLoc = name;
              } else if (types.contains('locality')) {
                loc = name;
              } else if (types.contains('administrative_area_level_1')) {
                stateName = name;
              } else if (types.contains('postal_code')) {
                pin = name;
              }
            }
          }

          // If houseNum is empty, use place name as building/landmark
          if (houseNum.isEmpty && placeName.isNotEmpty && placeName != streetName) {
            houseNum = placeName;
          }

          return OlaAddressResult(
            formattedAddress: formatted,
            houseNumber: houseNum,
            street: streetName,
            subLocality: subLoc,
            locality: loc,
            state: stateName,
            postalCode: pin,
            latitude: lat,
            longitude: lng,
          );
        }
      } else {
        debugPrint('[OlaMapsService] Reverse geocode failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[OlaMapsService] Error in reverseGeocode ($lat, $lng): $e');
    }
    return null;
  }

  /// Searches for places/localities matching a query string, optionally biased to a geographical location.
  static Future<List<OlaPlacePrediction>> autocompletePlaces(
    String query, {
    LatLng? location,
    int? radius,
  }) async {
    if (query.trim().length < 3) return [];

    final token = await getAccessToken();
    if (token == null && !OlaConfig.hasValidMapsKey) {
      debugPrint('[OlaMapsService] Skipped autocomplete: No valid Ola Maps API key or OAuth credentials.');
      return [];
    }

    final queryParams = <String, String>{
      'input': query,
      if (location != null) 'location': '${location.latitude},${location.longitude}',
      if (radius != null) 'radius': radius.toString(),
      if (token == null) 'api_key': OlaConfig.mapsApiKey,
    };
    final url = Uri.parse('${OlaConfig.olaMapsBaseUrl}/places/v1/autocomplete')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = data['predictions'] as List<dynamic>?;
        if (predictions != null) {
          return predictions
              .map((p) => OlaPlacePrediction.fromJson(p as Map<String, dynamic>))
              .toList();
        }
      } else {
        debugPrint('[OlaMapsService] Autocomplete failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[OlaMapsService] Error in autocompletePlaces ("$query"): $e');
    }
    return [];
  }

  /// Converts a place name or address into latitude and longitude coordinates.
  static Future<LatLng?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;

    final token = await getAccessToken();
    if (token == null && !OlaConfig.hasValidMapsKey) {
      debugPrint('[OlaMapsService] Skipped geocodeAddress: No valid Ola Maps API key or OAuth credentials.');
      return null;
    }

    final queryParams = <String, String>{
      'address': address,
      if (token == null) 'api_key': OlaConfig.mapsApiKey,
    };
    final url = Uri.parse('${OlaConfig.olaMapsBaseUrl}/places/v1/geocode')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final geometry = first['geometry'] as Map<String, dynamic>?;
          final location = geometry?['location'] as Map<String, dynamic>?;
          final lat = (location?['lat'] as num?)?.toDouble();
          final lng = (location?['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            return LatLng(lat, lng);
          }
        }
      }
    } catch (e) {
      debugPrint('[OlaMapsService] Error in geocodeAddress ("$address"): $e');
    }
    return null;
  }

  /// Fetches road driving or walking route directions between origin and destination.
  static Future<OlaRouteResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving', // driving, walking
  }) async {
    final token = await getAccessToken();
    if (token == null && !OlaConfig.hasValidMapsKey) {
      debugPrint('[OlaMapsService] Skipped getDirections: No valid Ola Maps API key or OAuth credentials.');
      return null;
    }

    final queryParams = <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': mode,
      if (token == null) 'api_key': OlaConfig.mapsApiKey,
    };
    final url = Uri.parse('${OlaConfig.olaMapsBaseUrl}/routing/v1/directions')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      // Ola Maps Directions API requires HTTP POST
      final response = await _client.post(url, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes.first as Map<String, dynamic>;
          final legs = firstRoute['legs'] as List<dynamic>?;
          double totalDistance = 0;
          double totalDuration = 0;
          String readableDist = '';
          String readableDur = '';

          final List<OlaRouteStep> routeSteps = [];

          if (legs != null && legs.isNotEmpty) {
            final leg = legs.first as Map<String, dynamic>;
            final rawDist = leg['distance'];
            if (rawDist is num) {
              totalDistance = rawDist.toDouble();
            } else if (rawDist is Map && rawDist['value'] is num) {
              totalDistance = (rawDist['value'] as num).toDouble();
            }

            final rawDur = leg['duration'];
            if (rawDur is num) {
              totalDuration = rawDur.toDouble();
            } else if (rawDur is Map && rawDur['value'] is num) {
              totalDuration = (rawDur['value'] as num).toDouble();
            }

            readableDist = leg['readable_distance']?.toString() ?? '';
            readableDur = cleanDuration(leg['readable_duration']?.toString() ?? '');

            // Parse detailed maneuver steps if provided by Ola Maps API
            final rawSteps = leg['steps'] as List<dynamic>?;
            if (rawSteps != null) {
              for (final s in rawSteps) {
                if (s is Map<String, dynamic>) {
                  final rawInstr = s['instructions']?.toString() ??
                      s['html_instructions']?.toString() ??
                      'Continue along route';
                  final cleanInstr = rawInstr.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                  final maneuver = s['maneuver']?.toString() ?? 'straight';

                  double sDist = 0;
                  final rawStepDist = s['distance'];
                  if (rawStepDist is num) {
                    sDist = rawStepDist.toDouble();
                  } else if (rawStepDist is Map && rawStepDist['value'] is num) {
                    sDist = (rawStepDist['value'] as num).toDouble();
                  }

                  double sDur = 0;
                  final rawStepDur = s['duration'];
                  if (rawStepDur is num) {
                    sDur = rawStepDur.toDouble();
                  } else if (rawStepDur is Map && rawStepDur['value'] is num) {
                    sDur = (rawStepDur['value'] as num).toDouble();
                  }

                  final sReadableDist = s['readable_distance']?.toString() ??
                      (sDist < 1000 ? '${sDist.round()} m' : '${(sDist / 1000).toStringAsFixed(1)} km');

                  LatLng? startLoc;
                  if (s['start_location'] is Map) {
                    final lat = (s['start_location']['lat'] as num?)?.toDouble();
                    final lng = (s['start_location']['lng'] as num?)?.toDouble();
                    if (lat != null && lng != null) startLoc = LatLng(lat, lng);
                  }

                  LatLng? endLoc;
                  if (s['end_location'] is Map) {
                    final lat = (s['end_location']['lat'] as num?)?.toDouble();
                    final lng = (s['end_location']['lng'] as num?)?.toDouble();
                    if (lat != null && lng != null) endLoc = LatLng(lat, lng);
                  }

                  routeSteps.add(OlaRouteStep(
                    instruction: cleanInstr.isNotEmpty ? cleanInstr : 'Continue along road',
                    maneuver: maneuver,
                    distanceMeters: sDist,
                    durationSeconds: sDur,
                    readableDistance: sReadableDist,
                    startLocation: startLoc,
                    endLocation: endLoc,
                  ));
                }
              }
            }
          }

          // Decode overview_polyline string or extract coordinate geometry
          List<LatLng> points = [];
          final polylineStr = firstRoute['overview_polyline']?.toString();
          if (polylineStr != null && polylineStr.isNotEmpty) {
            points = decodePolyline(polylineStr);
          } else {
            final geometry = firstRoute['geometry'];
            if (geometry is Map<String, dynamic> && geometry['coordinates'] is List) {
              final coords = geometry['coordinates'] as List<dynamic>;
              for (final pair in coords) {
                if (pair is List && pair.length >= 2) {
                  final lng = (pair[0] as num).toDouble();
                  final lat = (pair[1] as num).toDouble();
                  points.add(LatLng(lat, lng));
                }
              }
            }
          }

          if (readableDist.isEmpty) {
            readableDist = totalDistance < 1000
                ? '${totalDistance.round()} m'
                : '${(totalDistance / 1000).toStringAsFixed(1)} km';
          }
          if (readableDur.isEmpty) {
            final int mins = (totalDuration / 60).round();
            if (mins < 60) {
              readableDur = '${mins <= 0 ? 1 : mins} min';
            } else {
              final hrs = mins ~/ 60;
              final rMins = mins % 60;
              readableDur = rMins > 0 ? '$hrs hr $rMins min' : '$hrs hr';
            }
          } else {
            readableDur = cleanDuration(readableDur);
          }

          // If no granular steps returned, generate initial & arrival steps
          if (routeSteps.isEmpty && points.isNotEmpty) {
            routeSteps.add(OlaRouteStep(
              instruction: 'Head toward destination along route',
              maneuver: 'straight',
              distanceMeters: totalDistance,
              durationSeconds: totalDuration,
              readableDistance: readableDist,
              startLocation: points.first,
              endLocation: points.last,
            ));
            routeSteps.add(OlaRouteStep(
              instruction: 'Destination is on your path',
              maneuver: 'arrive',
              distanceMeters: 0,
              durationSeconds: 0,
              readableDistance: '0 m',
              startLocation: points.last,
              endLocation: points.last,
            ));
          }

          return OlaRouteResult(
            polylinePoints: points,
            distanceMeters: totalDistance,
            durationSeconds: totalDuration,
            readableDistance: readableDist,
            readableDuration: readableDur,
            steps: routeSteps,
          );
        }
      } else {
        debugPrint('[OlaMapsService] Directions failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[OlaMapsService] Error in getDirections: $e');
    }
    return null;
  }

  /// Decodes an encoded polyline string into a list of LatLng coordinates.
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }
}
