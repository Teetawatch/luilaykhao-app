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
  final DateTime? createdAt;

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
    this.createdAt,
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
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
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
    );
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
