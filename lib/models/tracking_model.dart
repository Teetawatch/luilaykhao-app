import 'package:latlong2/latlong.dart';

enum TrackingPhase { far, nearSoon, imminent, arrived }

class VehicleTracking {
  final int vehicleId;
  final String licensePlate;
  final String? driverName;
  final String? driverPhone;
  final LatLng driverLocation;
  final LatLng? destinationPoint;
  final String? tripTitle;
  final double? heading;
  final double? speed;
  final DateTime updatedAt;

  const VehicleTracking({
    required this.vehicleId,
    required this.licensePlate,
    this.driverName,
    this.driverPhone,
    required this.driverLocation,
    this.destinationPoint,
    this.tripTitle,
    this.heading,
    this.speed,
    required this.updatedAt,
  });

  factory VehicleTracking.fromJson(
    Map<String, dynamic> json, {
    String? driverName,
    String? driverPhone,
  }) {
    return VehicleTracking(
      vehicleId: json['vehicle_id'] is int
          ? json['vehicle_id'] as int
          : int.parse(json['vehicle_id'].toString()),
      licensePlate: json['license_plate']?.toString() ?? '',
      driverName: driverName ?? json['driver_name']?.toString(),
      driverPhone: driverPhone ?? json['driver_phone']?.toString(),
      driverLocation: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      destinationPoint:
          _pointFromJson(json, 'dest_lat', 'dest_lng') ??
          _pointFromJson(json, 'destination_lat', 'destination_lng'),
      tripTitle: json['trip_title']?.toString(),
      heading: json['heading'] != null
          ? (json['heading'] as num).toDouble()
          : null,
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      updatedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class BookingInfo {
  final String bookingRef;
  final int scheduleId;
  final int vehicleId;
  final String tripTitle;
  final String departurePoint;
  final LatLng pickupPoint;
  final LatLng? destinationPoint;
  final String departureDate;
  final String status;
  final String? driverName;
  final String? driverPhone;
  final String? licensePlate;

  const BookingInfo({
    required this.bookingRef,
    required this.scheduleId,
    required this.vehicleId,
    required this.tripTitle,
    required this.departurePoint,
    required this.pickupPoint,
    this.destinationPoint,
    required this.departureDate,
    required this.status,
    this.driverName,
    this.driverPhone,
    this.licensePlate,
  });

  factory BookingInfo.fromJson(Map<String, dynamic> json) {
    return BookingInfo(
      bookingRef:
          json['booking_ref']?.toString() ?? json['id']?.toString() ?? '',
      scheduleId: json['schedule_id'] is int
          ? json['schedule_id'] as int
          : int.parse(json['schedule_id'].toString()),
      vehicleId: json['vehicle_id'] is int
          ? json['vehicle_id'] as int
          : int.parse(json['vehicle_id'].toString()),
      tripTitle: json['trip_title']?.toString() ?? '',
      departurePoint: json['departure_point']?.toString() ?? '',
      pickupPoint: LatLng(
        json['pickup_lat'] != null
            ? (json['pickup_lat'] as num).toDouble()
            : 0.0,
        json['pickup_lng'] != null
            ? (json['pickup_lng'] as num).toDouble()
            : 0.0,
      ),
      destinationPoint:
          _pointFromJson(json, 'destination_lat', 'destination_lng') ??
          _pointFromJson(json, 'dest_lat', 'dest_lng'),
      departureDate: json['departure_date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      licensePlate: json['license_plate']?.toString(),
    );
  }
}

class ETAResult {
  final Duration eta;
  final double distanceKm;
  final TrackingPhase phase;

  const ETAResult({
    required this.eta,
    required this.distanceKm,
    required this.phase,
  });

  static ETAResult compute({
    required LatLng from,
    required LatLng to,
    double? speedKmh,
  }) {
    const calc = Distance();
    final km = calc.as(LengthUnit.Kilometer, from, to);

    if (km <= 0.05) {
      return ETAResult(
        eta: Duration.zero,
        distanceKm: km,
        phase: TrackingPhase.arrived,
      );
    }

    final speed = (speedKmh == null || speedKmh < 10) ? 40.0 : speedKmh;
    final minutes = (km / speed * 60).ceil();
    final eta = Duration(minutes: minutes);

    final phase = minutes < 5
        ? TrackingPhase.imminent
        : minutes < 30
        ? TrackingPhase.nearSoon
        : TrackingPhase.far;

    return ETAResult(eta: eta, distanceKm: km, phase: phase);
  }

  String get formattedETA {
    if (eta == Duration.zero) return 'ถึงแล้ว';
    final h = eta.inHours;
    final m = eta.inMinutes.remainder(60);
    if (h > 0) return '$h ชม. $m นาที';
    return '$m นาที';
  }

  String get formattedDistance {
    if (distanceKm >= 1) return '${distanceKm.toStringAsFixed(1)} กม.';
    return '${(distanceKm * 1000).toInt()} ม.';
  }
}

LatLng? _pointFromJson(
  Map<String, dynamic> json,
  String latKey,
  String lngKey,
) {
  final lat = json[latKey];
  final lng = json[lngKey];
  if (lat == null || lng == null) return null;
  final parsedLat = num.tryParse(lat.toString());
  final parsedLng = num.tryParse(lng.toString());
  if (parsedLat == null || parsedLng == null) return null;
  if (parsedLat == 0 && parsedLng == 0) return null;
  return LatLng(parsedLat.toDouble(), parsedLng.toDouble());
}
