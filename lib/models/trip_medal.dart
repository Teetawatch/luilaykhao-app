import 'package:flutter/material.dart';

/// หน้าตาเหรียญของทริปหนึ่ง — เซิร์ฟเวอร์ (MedalDesign.php) เป็นคนตัดสิน
/// ค่าตั้งต้นทั้งหมดแล้ว แอปแค่วาดตาม
@immutable
class MedalDesign {
  /// ชื่อที่พิมพ์บนดวงเหรียญ
  final String name;

  /// ชื่อ Material Symbols เช่น "hiking" — ดู [medalIconFor]
  final String icon;

  final Color color;

  /// ภาพเหรียญที่แอดมินออกแบบเอง — มีแล้วใช้แทนเหรียญแม่แบบทั้งดวง
  final String? imageUrl;

  const MedalDesign({
    required this.name,
    required this.icon,
    required this.color,
    this.imageUrl,
  });

  bool get isCustom => imageUrl != null && imageUrl!.isNotEmpty;

  factory MedalDesign.fromJson(Map<String, dynamic> json) {
    final image = '${json['image_url'] ?? ''}'.trim();

    return MedalDesign(
      name: '${json['name'] ?? ''}'.trim(),
      icon: '${json['icon'] ?? ''}'.trim(),
      color: parseMedalColor(json['color']),
      imageUrl: image.isEmpty ? null : image,
    );
  }
}

/// "#7C4A2D" → Color; รหัสเสีย/ว่างได้เขียวป่า (สีตั้งต้นของเซิร์ฟเวอร์)
Color parseMedalColor(Object? raw) {
  final hex = '${raw ?? ''}'.trim().replaceFirst('#', '');

  if (hex.length == 6) {
    final value = int.tryParse(hex, radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }

  return const Color(0xFF15803D);
}

/// รูปร่างเส้นทางของเหรียญ — ย่อลงกรอบสี่เหลี่ยมจัตุรัส 0–1 มาจากเซิร์ฟเวอร์แล้ว
/// (MedalRouteService) ไม่มีพิกัดจริง ผู้วาดแค่คูณขนาดกล่อง
@immutable
class MedalRoute {
  /// "recorded" = แทร็ก GPS ที่เดินจริง, "planned" = เส้นทางของทริป
  final String source;
  final List<Offset> points;

  /// ความสูง (ม.) เรียงตามระยะทาง — null เมื่อแทร็กไม่มีข้อมูลความสูง
  final List<int>? elevations;

  const MedalRoute({
    required this.source,
    required this.points,
    required this.elevations,
  });

  bool get isRecorded => source == 'recorded';

  /// null เมื่อข้อมูลวาดไม่ได้ (จุดไม่พอ) — ผู้เรียกจะได้ไม่ต้องเช็คซ้ำ
  static MedalRoute? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final points = <Offset>[];
    for (final p in raw['points'] is List ? raw['points'] as List : const []) {
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
        points.add(
          Offset(
            (p[0] as num).toDouble().clamp(0.0, 1.0),
            (p[1] as num).toDouble().clamp(0.0, 1.0),
          ),
        );
      }
    }

    if (points.length < 2) return null;

    final rawEle = raw['elevations'];
    final elevations = rawEle is List
        ? [
            for (final e in rawEle)
              if (e is num) e.round(),
          ]
        : null;

    return MedalRoute(
      source: '${raw['source'] ?? 'planned'}',
      points: points,
      elevations: elevations != null && elevations.length >= 2
          ? elevations
          : null,
    );
  }
}

/// ตัวเลขที่เดินจริงจาก GPS ของเจ้าของเหรียญ
@immutable
class MedalPersonal {
  final double distanceKm;
  final int elevationGainM;
  final int movingSeconds;
  final double? avgSpeedKmh;
  final int? maxElevationM;

  const MedalPersonal({
    required this.distanceKm,
    required this.elevationGainM,
    required this.movingSeconds,
    required this.avgSpeedKmh,
    required this.maxElevationM,
  });

  static MedalPersonal? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final distance = double.tryParse('${raw['distance_km'] ?? ''}');
    if (distance == null || distance <= 0) return null;

    return MedalPersonal(
      distanceKm: distance,
      elevationGainM: int.tryParse('${raw['elevation_gain_m'] ?? 0}') ?? 0,
      movingSeconds: int.tryParse('${raw['moving_seconds'] ?? 0}') ?? 0,
      avgSpeedKmh: double.tryParse('${raw['avg_speed_kmh'] ?? ''}'),
      maxElevationM: int.tryParse('${raw['max_elevation_m'] ?? ''}'),
    );
  }
}

/// เวลาเดิน "2 ชม. 15 น." / "45 น." — null เมื่อไม่มีเวลา
String? formatMovingTime(int seconds) {
  if (seconds < 60) return null;

  final minutes = seconds ~/ 60;
  final h = minutes ~/ 60;
  final m = minutes % 60;

  if (h == 0) return '$m น.';
  return m == 0 ? '$h ชม.' : '$h ชม. $m น.';
}

/// เวลาเดินแบบสั้นสำหรับตัวเลขใหญ่บนการ์ด "5:30 ชม." / "45 น." (แบบ Strava
/// "5h 30m") — แบบยาวกว้างเกินช่องเมื่อวางสามตัวเลขเรียงกัน
String? formatMovingTimeShort(int seconds) {
  if (seconds < 60) return null;

  final minutes = seconds ~/ 60;
  final h = minutes ~/ 60;
  final m = minutes % 60;

  if (h == 0) return '$m น.';
  return '$h:${m.toString().padLeft(2, '0')} ชม.';
}

/// ป้ายสถิติส่วนตัวสูงสุด (ตรงกับคีย์ที่ MedalRouteService::records() คืน)
String medalRecordLabel(String key) => switch (key) {
  'distance' => 'เดินไกลที่สุดของฉัน',
  'climb' => 'ไต่สะสมมากที่สุดของฉัน',
  'altitude' => 'ขึ้นสูงที่สุดของฉัน',
  _ => 'สถิติใหม่ของฉัน',
};

/// เหรียญพิชิตหนึ่งเหรียญในตู้ของผู้ใช้ (GET /me/medals)
@immutable
class TripMedal {
  final int id;
  final bool seen;
  final String? bookingRef;
  final int finisherNo;
  final String finisherLabel;

  /// วันสุดท้ายของทริป = วันที่พิชิต
  final DateTime? earnedOn;
  final String earnedLabel;

  /// ช่วงวันเดินทาง ("2 – 5 กันยายน 2569") — จัดรูปมาจากเซิร์ฟเวอร์แล้ว
  final String dateLabel;
  final String holderName;
  final MedalDesign design;

  final int tripId;
  final String tripTitle;
  final String tripSlug;
  final String location;
  final String? countryFlag;
  final String? countryName;
  final double? distanceKm;
  final int? elevationGainM;
  final int? durationDays;
  final String? coverImage;

  /// ไปทริปนี้เป็นครั้งที่เท่าไร / รวมกี่ครั้ง
  final int attempt;
  final int attemptsOfTrip;

  /// ลิงก์สาธารณะ /m/{token} — ติดไปกับคำบรรยายตอนแชร์
  final String shareUrl;

  /// รูปร่างเส้นทาง — null เมื่อไม่ได้บันทึก GPS และทริปก็ไม่มีไฟล์ GPX
  final MedalRoute? route;

  /// ตัวเลขที่เดินจริง — null เมื่อไม่ได้บันทึก GPS ในรอบนั้น
  final MedalPersonal? personal;

  /// สถิติส่วนตัวสูงสุดที่เหรียญนี้ถือ: distance / climb / altitude
  final List<String> records;

  const TripMedal({
    required this.id,
    required this.seen,
    required this.bookingRef,
    required this.finisherNo,
    required this.finisherLabel,
    required this.earnedOn,
    required this.earnedLabel,
    required this.dateLabel,
    required this.holderName,
    required this.design,
    required this.tripId,
    required this.tripTitle,
    required this.tripSlug,
    required this.location,
    required this.countryFlag,
    required this.countryName,
    required this.distanceKm,
    required this.elevationGainM,
    required this.durationDays,
    required this.coverImage,
    required this.attempt,
    required this.attemptsOfTrip,
    required this.shareUrl,
    this.route,
    this.personal,
    this.records = const [],
  });

  /// ปี พ.ศ. ของวันที่พิชิต — ใช้กับตัวอักษรที่วิ่งรอบขอบเหรียญ
  int? get buddhistYear {
    final on = earnedOn;
    return on == null ? null : on.year + 543;
  }

  /// บรรทัดสถานที่ใต้ชื่อเหรียญ — ทริปต่างประเทศใช้ธง+ชื่อประเทศแทนจังหวัด
  String get placeLabel {
    final flag = countryFlag;
    final country = countryName;

    if (flag != null &&
        flag.isNotEmpty &&
        country != null &&
        country.isNotEmpty) {
      return '$flag $country';
    }

    return location;
  }

  TripMedal markSeen() => TripMedal(
    id: id,
    seen: true,
    bookingRef: bookingRef,
    finisherNo: finisherNo,
    finisherLabel: finisherLabel,
    earnedOn: earnedOn,
    earnedLabel: earnedLabel,
    dateLabel: dateLabel,
    holderName: holderName,
    design: design,
    tripId: tripId,
    tripTitle: tripTitle,
    tripSlug: tripSlug,
    location: location,
    countryFlag: countryFlag,
    countryName: countryName,
    distanceKm: distanceKm,
    elevationGainM: elevationGainM,
    durationDays: durationDays,
    coverImage: coverImage,
    attempt: attempt,
    attemptsOfTrip: attemptsOfTrip,
    shareUrl: shareUrl,
    route: route,
    personal: personal,
    records: records,
  );

  factory TripMedal.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'] is Map
        ? Map<String, dynamic>.from(json['trip'] as Map)
        : const <String, dynamic>{};
    final design = json['design'] is Map
        ? Map<String, dynamic>.from(json['design'] as Map)
        : const <String, dynamic>{};

    String text(Object? v) => v == null ? '' : '$v'.trim();
    String? optional(Object? v) {
      final t = text(v);
      return t.isEmpty ? null : t;
    }

    final finisherNo = int.tryParse(text(json['finisher_no'])) ?? 0;
    final dateLabel = text(json['date_label']);

    return TripMedal(
      id: int.tryParse(text(json['id'])) ?? 0,
      seen: json['seen'] == true,
      bookingRef: optional(json['booking_ref']),
      finisherNo: finisherNo,
      finisherLabel:
          optional(json['finisher_label']) ?? 'Finisher #$finisherNo',
      earnedOn: DateTime.tryParse(text(json['earned_on'])),
      earnedLabel: text(json['earned_label']),
      dateLabel: dateLabel == '-' ? '' : dateLabel,
      holderName: optional(json['holder_name']) ?? 'นักเดินทาง',
      design: MedalDesign.fromJson(design),
      tripId: int.tryParse(text(trip['id'])) ?? 0,
      tripTitle: text(trip['title']),
      tripSlug: text(trip['slug']),
      location: text(trip['location']),
      countryFlag: optional(trip['country_flag']),
      countryName: optional(trip['country_name']),
      distanceKm: double.tryParse(text(trip['distance_km'])),
      elevationGainM: int.tryParse(text(trip['elevation_gain_m'])),
      durationDays: int.tryParse(text(trip['duration_days'])),
      coverImage: optional(trip['cover_image']),
      attempt: int.tryParse(text(json['attempt'])) ?? 1,
      attemptsOfTrip: int.tryParse(text(json['attempts_of_trip'])) ?? 1,
      shareUrl: text(json['share_url']),
      route: MedalRoute.fromJson(json['route']),
      personal: MedalPersonal.fromJson(json['personal']),
      records: [
        for (final r in json['records'] is List ? json['records'] as List : [])
          if (r is String && r.isNotEmpty) r,
      ],
    );
  }
}

/// ตู้เหรียญทั้งตู้
@immutable
class MedalCabinet {
  final List<TripMedal> medals;
  final int tripsCount;

  const MedalCabinet({required this.medals, required this.tripsCount});

  static const empty = MedalCabinet(medals: [], tripsCount: 0);

  List<TripMedal> get unseen => medals.where((m) => !m.seen).toList();

  factory MedalCabinet.fromJson(Map<String, dynamic> json) {
    final list = json['medals'] is List ? json['medals'] as List : const [];

    return MedalCabinet(
      medals: [
        for (final item in list)
          if (item is Map) TripMedal.fromJson(Map<String, dynamic>.from(item)),
      ],
      tripsCount: int.tryParse('${json['trips_count'] ?? 0}') ?? 0,
    );
  }

  MedalCabinet markAllSeen() => MedalCabinet(
    medals: [for (final m in medals) m.seen ? m : m.markSeen()],
    tripsCount: tripsCount,
  );
}
