/// สถานะการ์ด "วันเดินทาง" หนึ่งใบ ตามที่เซิร์ฟเวอร์บอกมา
///
/// ข้อความทุกบรรทัดในนี้ถูกเขียนมาแล้วจากฝั่ง Laravel (`TripActivityService`)
/// โดยตั้งใจ — แอปไม่แต่งประโยคเอง ไม่คิด ETA เอง ไม่ตัดสินขั้นเอง ถ้าทำ วันหนึ่ง
/// iOS กับ Android จะบอกเวลารถถึงไม่ตรงกัน ซึ่งแย่กว่าไม่บอกเลย
class TripActivityState {
  final String stage;
  final String headline;
  final String detail;
  final int? etaMinutes;
  final double progress;
  final String? pickupName;
  final String? vehicleLabel;
  final String? departsAt;
  final String? tripTitle;
  final String bookingRef;
  final int scheduleId;

  const TripActivityState({
    required this.stage,
    required this.headline,
    required this.detail,
    required this.progress,
    required this.bookingRef,
    required this.scheduleId,
    this.etaMinutes,
    this.pickupName,
    this.vehicleLabel,
    this.departsAt,
    this.tripTitle,
  });

  static TripActivityState? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final stage = json['stage']?.toString() ?? '';
    if (stage.isEmpty) return null;

    return TripActivityState(
      stage: stage,
      headline: json['headline']?.toString() ?? 'ทริปของคุณ',
      detail: json['detail']?.toString() ?? '',
      etaMinutes: int.tryParse('${json['eta_minutes']}'),
      progress: double.tryParse('${json['progress']}') ?? 0,
      pickupName: json['pickup_name']?.toString(),
      vehicleLabel: json['vehicle_label']?.toString(),
      departsAt: json['departs_at']?.toString(),
      tripTitle: json['trip_title']?.toString(),
      bookingRef: json['booking_ref']?.toString() ?? '',
      scheduleId: int.tryParse('${json['schedule_id']}') ?? 0,
    );
  }

  /// รูปแบบที่ ActivityKit ฝั่ง Swift รอรับ (camelCase) — ต้องตรงกับ
  /// `TripActivityAttributes.ContentState` เป๊ะ ๆ ไม่งั้นถอดรหัสไม่ผ่านเงียบ ๆ
  Map<String, dynamic> toContentState() => {
    'stage': stage,
    'headline': headline,
    'detail': detail,
    'etaMinutes': etaMinutes,
    'progress': progress,
    'pickupName': pickupName,
    'vehicleLabel': vehicleLabel,
    'departsAt': departsAt,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  /// เปอร์เซ็นต์สำหรับแถบความคืบหน้าของ Android
  int get progressPercent => (progress.clamp(0, 1) * 100).round();
}
