import 'package:flutter_test/flutter_test.dart';
import 'package:go_government/service/location_service.dart';

void main() {
  group('LocationService tests', () {
    test('formatDistance formats meters accurately', () {
      expect(LocationService.formatDistance(50), '50 m');
      expect(LocationService.formatDistance(260.4), '260 m');
      expect(LocationService.formatDistance(999), '999 m');
      expect(LocationService.formatDistance(1000), '1.0 km');
      expect(LocationService.formatDistance(1250), '1.3 km');
      expect(LocationService.formatDistance(3140), '3.1 km');
    });

    test('defaultLocation is set to Bengaluru coordinates', () {
      expect(LocationService.defaultLocation.latitude, closeTo(12.9716, 0.001));
      expect(LocationService.defaultLocation.longitude, closeTo(77.5946, 0.001));
    });

    test('calculateDistance returns plausible geographic distance', () {
      // Distance between Bangalore Vidhana Soudha (12.9791, 77.5913) and MG Road Metro (12.9752, 77.6065)
      final meters = LocationService.calculateDistance(12.9791, 77.5913, 12.9752, 77.6065);
      expect(meters, greaterThan(1000));
      expect(meters, lessThan(3000));
    });

    test('calculateEtaMinutes computes dynamic duration for bike and walk', () {
      // 350 meters: ~1 min bike, ~5 min walk
      expect(LocationService.calculateEtaMinutes(350, isWalking: false), 1);
      expect(LocationService.calculateEtaMinutes(350, isWalking: true), 5);

      // 1400 meters: ~4 min bike, ~18 min walk
      expect(LocationService.calculateEtaMinutes(1400, isWalking: false), 4);
      expect(LocationService.calculateEtaMinutes(1400, isWalking: true), 18);

      // Edge cases
      expect(LocationService.calculateEtaMinutes(0, isWalking: false), 1);
      expect(LocationService.calculateEtaMinutes(-10, isWalking: true), 1);
    });

    test('formatEta formats minutes into friendly duration strings', () {
      expect(LocationService.formatEta(1), '1 min');
      expect(LocationService.formatEta(15), '15 min');
      expect(LocationService.formatEta(60), '1 hr');
      expect(LocationService.formatEta(75), '1 hr 15 min');
      expect(LocationService.formatEta(130), '2 hr 10 min');
    });

    test('cleanDurationString removes redundant 0 hours and keeps minutes only', () {
      expect(LocationService.cleanDurationString('0 hours 4 mins'), '4 mins');
      expect(LocationService.cleanDurationString('0 hours 1 min'), '1 min');
      expect(LocationService.cleanDurationString('0 hour 1 min'), '1 min');
      expect(LocationService.cleanDurationString('0 hrs 14 mins'), '14 mins');
      expect(LocationService.cleanDurationString('0 hr 25 min'), '25 min');
      expect(LocationService.cleanDurationString('0 hours and 12 mins'), '12 mins');
      expect(LocationService.cleanDurationString('0 hours, 12 mins'), '12 mins');
      expect(LocationService.cleanDurationString('0 hours'), '1 min');
      expect(LocationService.cleanDurationString('1 hour 15 mins'), '1 hour 15 mins');
      expect(LocationService.cleanDurationString('2 hours'), '2 hours');
    });
  });
}
