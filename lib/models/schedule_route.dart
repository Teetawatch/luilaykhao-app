import 'package:latlong2/latlong.dart';

/// จุดจอดหนึ่งจุดบนเส้นทางเดินรถของรอบ (จุดรับ หรือปลายทางทริป)
class RouteStop {
  final String type; // pickup | destination
  final int? id;
  final String name;
  final String regionLabel;
  final String pickupTime;
  final LatLng? point;
  final bool completed;

  const RouteStop({
    required this.type,
    required this.id,
    required this.name,
    required this.regionLabel,
    required this.pickupTime,
    required this.point,
    required this.completed,
  });

  bool get isDestination => type == 'destination';

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse(json['latitude']?.toString() ?? '');
    final lng = double.tryParse(json['longitude']?.toString() ?? '');
    return RouteStop(
      type: json['type']?.toString() ?? 'pickup',
      id: int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      regionLabel: json['region_label']?.toString() ?? '',
      pickupTime: json['pickup_time']?.toString() ?? '',
      point: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      completed: json['completed'] == true,
    );
  }
}

/// เส้นทางเดินรถทั้งรอบ: จุดจอดเรียงลำดับ + polyline ตามถนนจริงจาก backend
class ScheduleRouteData {
  final List<RouteStop> stops;
  final List<LatLng> polyline;
  final int distanceMeters;
  final int durationSeconds;

  const ScheduleRouteData({
    required this.stops,
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  bool get isEmpty => stops.isEmpty;

  /// พิกัดของจุดจอดที่ปักหมุดได้ (ใช้ fit กล้อง/ลากเส้นตรง fallback)
  List<LatLng> get stopPoints =>
      stops.where((s) => s.point != null).map((s) => s.point!).toList();

  factory ScheduleRouteData.fromJson(Map<String, dynamic> json) {
    final stops = (json['stops'] is List ? json['stops'] as List : const [])
        .whereType<Map>()
        .map((s) => RouteStop.fromJson(Map<String, dynamic>.from(s)))
        .toList();
    return ScheduleRouteData(
      stops: stops,
      polyline: decodeGooglePolyline(json['polyline']?.toString() ?? ''),
      distanceMeters: int.tryParse(json['distance']?.toString() ?? '') ?? 0,
      durationSeconds: int.tryParse(json['duration']?.toString() ?? '') ?? 0,
    );
  }
}

/// ถอดรหัส Google encoded polyline → รายการพิกัด
List<LatLng> decodeGooglePolyline(String encoded) {
  if (encoded.isEmpty) return const [];
  final points = <LatLng>[];
  int index = 0, lat = 0, lng = 0;

  while (index < encoded.length) {
    int shift = 0, result = 0, b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
