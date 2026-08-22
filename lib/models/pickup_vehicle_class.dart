/// ประเภทรถรับ-ส่งที่วิ่งจากจุดรับต่างภูมิภาคมายังจุดขึ้นรถจุดแรก
///
/// เป็นไกด์ให้ลูกค้าเห็นว่าค่าจุดรับที่จ่ายเพิ่มได้รถแบบไหน ไม่ใช่คำสัญญาว่ารถ
/// คันไหนจะมารับ — ตอนเลือกจุดรับยังไม่รู้ว่าจุดนั้นจะมีคนรวมกี่คน
class PickupVehicleClass {
  final int id;
  final String label;
  final int minPax;

  /// null = "ขึ้นไปไม่จำกัด" (เช่น รถตู้ 6 ท่านขึ้นไป)
  final int? maxPax;

  /// ข้อความช่วงจำนวนคนที่ backend ประกอบมาให้แล้ว — แอปแค่วาด
  final String paxLabel;
  final String? imageUrl;
  final String? note;

  const PickupVehicleClass({
    required this.id,
    required this.label,
    required this.minPax,
    required this.maxPax,
    required this.paxLabel,
    required this.imageUrl,
    required this.note,
  });

  bool covers(int pax) =>
      pax >= minPax && (maxPax == null || pax <= maxPax!);

  factory PickupVehicleClass.fromJson(Map<String, dynamic> json) {
    final rawImage = json['image_url']?.toString();
    final rawNote = json['note']?.toString();
    return PickupVehicleClass(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      label: json['label']?.toString() ?? '',
      minPax: int.tryParse(json['min_pax']?.toString() ?? '') ?? 1,
      maxPax: int.tryParse(json['max_pax']?.toString() ?? ''),
      paxLabel: json['pax_label']?.toString() ?? '',
      imageUrl: (rawImage != null && rawImage.isNotEmpty) ? rawImage : null,
      note: (rawNote != null && rawNote.isNotEmpty) ? rawNote : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'min_pax': minPax,
        'max_pax': maxPax,
        'pax_label': paxLabel,
        'image_url': imageUrl,
        'note': note,
      };

  static List<PickupVehicleClass> listFrom(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PickupVehicleClass.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
