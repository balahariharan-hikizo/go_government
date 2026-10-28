import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_government/config/ola_config.dart';
import 'package:go_government/network/ola_maps_service.dart';
import 'package:go_government/service/location_service.dart';

void main() {
  group('OlaConfig Tests', () {
    test('Credentials validation works correctly', () {
      expect(OlaConfig.hasValidMapsKey, isTrue);
      expect(OlaConfig.hasValidOAuth, isTrue);
      expect(OlaConfig.olaMapsBaseUrl, equals('https://api.olamaps.io'));
    });
  });

  group('OlaMapsService Unit Tests', () {
    test('autocompletePlaces gracefully returns empty list when query is too short', () async {
      final emptyResult = await OlaMapsService.autocompletePlaces('a');
      expect(emptyResult, isEmpty);
    });


    test('geocodeAddress gracefully returns null without API key', () async {
      final result = await OlaMapsService.geocodeAddress('Indiranagar Bangalore');
      expect(result, isNull);
    });

    test('OlaAddressResult formats addressLine accurately', () {
      const address = OlaAddressResult(
        formattedAddress: '12, 100ft Road, Indiranagar, Bengaluru, 560038',
        houseNumber: '12',
        street: '100ft Road',
        subLocality: 'Indiranagar',
        locality: 'Bengaluru',
        postalCode: '560038',
        latitude: 12.9716,
        longitude: 77.5946,
      );
      expect(address.addressLine, contains('12'));
      expect(address.addressLine, contains('100ft Road'));
      expect(address.addressLine, contains('Indiranagar'));
    });

    test('OlaRouteResult and OlaRouteStep contain polyline and maneuvers', () {
      const step1 = OlaRouteStep(
        instruction: 'Turn left onto 100ft Road',
        maneuver: 'turn-left',
        distanceMeters: 450,
        durationSeconds: 120,
        readableDistance: '450 m',
      );
      const step2 = OlaRouteStep(
        instruction: 'Destination is on your right',
        maneuver: 'arrive',
        distanceMeters: 0,
        durationSeconds: 0,
        readableDistance: '0 m',
      );

      final route = OlaRouteResult(
        polylinePoints: const [
          LatLng(12.9716, 77.5946),
          LatLng(12.9750, 77.5990),
        ],
        distanceMeters: 450,
        durationSeconds: 120,
        readableDistance: '450 m',
        readableDuration: '2 mins',
        steps: const [step1, step2],
      );

      expect(route.polylinePoints.length, equals(2));
      expect(route.steps.length, equals(2));
      expect(route.steps.first.maneuver, equals('turn-left'));
      expect(route.steps.last.maneuver, equals('arrive'));
    });
  });

  group('Live Ola Maps OAuth Integration Tests', () {
    test('getAccessToken retrieves a valid JWT access token', () async {
      final token = await OlaMapsService.getAccessToken();
      expect(token, isNotNull);
      expect(token!.length, greaterThan(20));
    });

    test('reverseGeocode returns live address in Bengaluru', () async {
      final result = await OlaMapsService.reverseGeocode(12.9716, 77.5946);
      expect(result, isNotNull);
      expect(result!.formattedAddress, isNotEmpty);
      expect(result.locality, equals('Bengaluru'));
    });

    test('fetchRealNearbyFacilities returns real places without mock names', () async {
      final results = await LocationService.fetchRealNearbyFacilities(
        keyword: 'bus stop',
        center: const LatLng(12.9314, 77.6164),
        fallbackCategory: 'Bus Stop',
      );
      expect(results, isNotEmpty);
      expect(results.first['title'], isNot(contains('City Transit')));
      expect(results.first['title'], isNot(contains('Central Junction')));
    });
  });
}
