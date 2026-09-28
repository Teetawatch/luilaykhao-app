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
  });

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
