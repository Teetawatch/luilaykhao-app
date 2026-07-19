import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:luilaykhao_app/models/schedule_route.dart';

void main() {
  group('decodeGooglePolyline', () {
    test('decodes the Google reference example', () {
      final points = decodeGooglePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points, hasLength(3));
      expect(points.first.latitude, closeTo(38.5, 0.001));
      expect(points.first.longitude, closeTo(-120.2, 0.001));
      expect(points.last.latitude, closeTo(43.252, 0.001));
      expect(points.last.longitude, closeTo(-126.453, 0.001));
    });

    test('empty string decodes to empty list', () {
      expect(decodeGooglePolyline(''), isEmpty);
    });
  });

  group('ScheduleRouteData.fromJson', () {
    test('parses stops, polyline and totals', () {
      final data = ScheduleRouteData.fromJson({
        'stops': [
          {
            'type': 'pickup',
            'id': 11,
            'name': 'BTS หมอชิต',
            'region_label': 'กรุงเทพฯ',
            'pickup_time': '21:00',
            'latitude': 13.8023,
            'longitude': 100.5536,
            'completed': true,
          },
          {
            'type': 'pickup',
            'id': 12,
            'name': 'จุดไม่มีพิกัด',
            'region_label': null,
            'pickup_time': null,
            'latitude': null,
            'longitude': null,
            'completed': false,
          },
          {
            'type': 'destination',
            'id': null,
            'name': 'เชียงราย',
            'latitude': 19.839,
            'longitude': 100.443,
          },
        ],
        'polyline': '_p~iF~ps|U_ulLnnqC',
        'distance': 530000,
        'duration': 23400,
      });

      expect(data.isEmpty, isFalse);
      expect(data.stops, hasLength(3));
      expect(data.stops[0].id, 11);
      expect(data.stops[0].completed, isTrue);
      expect(data.stops[0].point, const LatLng(13.8023, 100.5536));
      expect(data.stops[1].point, isNull);
      expect(data.stops[2].isDestination, isTrue);
      // จุดที่ไม่มีพิกัดต้องไม่ติดมาใน stopPoints (ใช้ fit กล้อง/เส้นตรง fallback)
      expect(data.stopPoints, hasLength(2));
      expect(data.polyline, hasLength(2));
      expect(data.distanceMeters, 530000);
      expect(data.durationSeconds, 23400);
    });

    test('missing fields fall back safely', () {
      final data = ScheduleRouteData.fromJson(const {});
      expect(data.isEmpty, isTrue);
      expect(data.polyline, isEmpty);
      expect(data.distanceMeters, 0);
      expect(data.durationSeconds, 0);
    });
  });
}
