import 'dart:convert';

/// An SOS emergency alert raised by a traveler during a trip.
class SosAlert {
  final int id;
  final int scheduleId;
  final String userName;
  final String? message;
  final String? photoUrl;
  final String? contactPhone;
  final double? latitude;
  final double? longitude;
  final String status;

  /// True when the signed-in user is the one who raised this alert — they get
  /// a "close my case" action instead of a siren.
  final bool isMine;
  final DateTime? createdAt;

  /// เบอร์ฉุกเฉินของประเทศที่รอบนี้ไปอยู่ [ป้าย => เบอร์] — ว่างสำหรับทริปในประเทศ
  ///
  /// SOS เรียกทีมงานของเราได้ แต่เรียกรถพยาบาลของประเทศนั้นแทนลูกค้าไม่ได้
  /// หน้าจอที่เปิดอยู่ตอนเกิดเหตุจึงต้องมีเบอร์นั้นให้กดโทรด้วย
  final Map<String, String> emergencyNumbers;

  const SosAlert({
    required this.id,
    required this.scheduleId,
    required this.userName,
    this.message,
    this.photoUrl,
    this.contactPhone,
    this.latitude,
    this.longitude,
    this.status = 'active',
    this.isMine = false,
    this.createdAt,
    this.emergencyNumbers = const {},
  });

  bool get hasLocation => latitude != null && longitude != null;

  bool get isActive => status == 'active';

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    return SosAlert(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      scheduleId: int.tryParse(json['schedule_id']?.toString() ?? '') ?? 0,
      userName: json['user_name']?.toString() ?? '',
      message: _nullableString(json['message']),
      photoUrl: _nullableString(json['photo_url']),
      contactPhone: _nullableString(json['contact_phone']),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'active',
      isMine: json['is_mine'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      emergencyNumbers: _numbersFrom(json['emergency_numbers']),
    );
  }

  /// Builds an alert from an FCM `sos_alert` data payload (all values are strings).
  factory SosAlert.fromNotificationData(Map<String, dynamic> data) {
    return SosAlert(
      id: int.tryParse(data['sos_id']?.toString() ?? '') ?? 0,
      scheduleId: int.tryParse(data['schedule_id']?.toString() ?? '') ?? 0,
      userName: data['sos_user_name']?.toString() ?? '',
      message: _nullableString(data['sos_message']),
      photoUrl: _nullableString(data['photo_url']),
      contactPhone: _nullableString(data['contact_phone']),
      latitude: double.tryParse(data['latitude']?.toString() ?? ''),
      longitude: double.tryParse(data['longitude']?.toString() ?? ''),
      // FCM ส่งได้แต่สตริง เบอร์ฉุกเฉินจึงมาเป็น JSON ก้อนเดียว
      emergencyNumbers: _numbersFrom(data['emergency_numbers']),
    );
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// รับได้ทั้ง Map (จาก REST) และสตริง JSON (จาก FCM data message)
  static Map<String, String> _numbersFrom(dynamic value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): entry.value.toString(),
      };
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || !text.startsWith('{')) return const {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries)
            entry.key.toString(): entry.value.toString(),
        };
      }
    } catch (_) {}
    return const {};
  }
}
