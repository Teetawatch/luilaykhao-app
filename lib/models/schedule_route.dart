import 'package:latlong2/latlong.dart';

/// พิกัดที่วาดบนแผนที่ได้จริงเท่านั้น — flutter_map assert ว่าขอบเขตต้องอยู่ใน
/// ±90/±180 ถ้าหลุดกรอบ (หรือเป็น NaN/Infinity) ทั้งเลเยอร์จะพังทั้งจอ
/// ตอนเปิดแผนที่ จึงตัดพิกัดเสียทิ้งตั้งแต่ตอนอ่านข้อมูล
LatLng? mapSafePoint(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return null;
  if (!latitude.isFinite || !longitude.isFinite) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;

  return LatLng(latitude, longitude);
}

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
      point: mapSafePoint(lat, lng),
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
///
/// ทนสตริงเพี้ยน: ถ้าถูกตัดกลางคัน (หรือไม่ใช่ polyline เลย) จะคืนเท่าที่อ่านได้
/// แทนที่จะโยน error และไม่ปล่อยพิกัดหลุดโลกออกไปให้แผนที่วาด
List<LatLng> decodeGooglePolyline(String encoded) {
  if (encoded.isEmpty) return const [];
  final points = <LatLng>[];
  int index = 0, lat = 0, lng = 0;

  /// อ่านค่าถัดไปหนึ่งตัว — คืน null เมื่อสตริงหมดกลางคัน
  int? readValue() {
    int shift = 0, result = 0, b;
    do {
      if (index >= encoded.length) return null;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  while (index < encoded.length) {
    final dLat = readValue();
    final dLng = readValue();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;

    final point = mapSafePoint(lat / 1e5, lng / 1e5);
    if (point == null) break; // หลุดโลกแล้ว จุดที่เหลือก็เชื่อไม่ได้
    points.add(point);
  }
  return points;
}
