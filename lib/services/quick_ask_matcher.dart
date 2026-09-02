/// จับว่าข้อความในห้องแชทกำลังถามเรื่องอะไร เพื่อยกคำตอบขึ้นมาให้เองทันที
///
/// ห้องแชททริปตอบคำถามเดิม ๆ ห้าข้อซ้ำทุกรอบ (กำหนดการ / ขึ้นรถกี่โมง /
/// จุดรับที่ไหน / รถคันไหน / โทรหาใคร) ซึ่งแอปมีคำตอบครบอยู่แล้วในชีตคำถามด่วน
/// แต่ลูกค้าพิมพ์ถามเพราะไม่รู้ว่ามีปุ่ม ตัวจับนี้อ่านข้อความแล้วบอกว่าเข้าข้อไหน
/// แอปจะได้ยื่นคำตอบให้ตั้งแต่ยังพิมพ์ไม่จบ
///
/// **จับพลาดแล้วไม่เสียหาย** เพราะปลายทางคือชีตที่ตอบครบทั้งห้าข้ออยู่แล้ว
/// เพียงแต่ไฮไลต์ข้อที่เดาไว้ — เดาผิดคือผู้ใช้เห็นคำตอบข้ออื่นด้วย ไม่ใช่เห็นผิด
/// และคำตอบนี้ขึ้นเฉพาะบนเครื่องคนถาม ไม่ได้โพสต์ลงห้อง เดาผิดจึงไม่กวนใคร
enum QuickAskTopic { itinerary, time, place, vehicle, contact }

class QuickAskMatcher {
  /// คำที่พบแล้วมั่นใจได้เลยว่าถามข้อนั้น
  static const Map<QuickAskTopic, List<String>> _strong = {
    QuickAskTopic.itinerary: [
      'กำหนดการ',
      'ตารางเวลา',
      'ตารางทริป',
      'ตารางเดินทาง',
      'แผนการเดินทาง',
      'โปรแกรมทริป',
      'โปรแกรมเดินทาง',
      'itinerary',
    ],
    QuickAskTopic.place: [
      'จุดรับ',
      'จุดนัด',
      'จุดขึ้นรถ',
      'ขึ้นรถที่ไหน',
      'รอที่ไหน',
      'นัดเจอที่ไหน',
      'เจอกันที่ไหน',
      'ไปขึ้นรถตรงไหน',
    ],
    QuickAskTopic.time: [
      'ขึ้นรถกี่โมง',
      'รถออกกี่โมง',
      'ออกรถกี่โมง',
      'ออกเดินทางกี่โมง',
      'นัดกี่โมง',
      'เจอกันกี่โมง',
      'ถึงจุดรับกี่โมง',
    ],
    QuickAskTopic.vehicle: [
      'ทะเบียนรถ',
      'ทะเบียนอะไร',
      'รถคันไหน',
      'รถทะเบียน',
      'รถสีอะไร',
      'นั่งรถอะไร',
    ],
    QuickAskTopic.contact: [
      'เบอร์โทร',
      'เบอร์ติดต่อ',
      'เบอร์คนขับ',
      'เบอร์สตาฟ',
      'ติดต่อใคร',
      'โทรหาใคร',
      'โทรเบอร์ไหน',
    ],
  };

  /// คำกว้างเกินกว่าจะเชื่อลอย ๆ — ต้องมีรูปประโยคคำถามประกอบด้วย
  /// ("ตามโปรแกรมเดิมนะครับ" ไม่ใช่คำถาม แต่ "โปรแกรมเป็นยังไงบ้าง" ใช่)
  static const Map<QuickAskTopic, List<String>> _weak = {
    QuickAskTopic.itinerary: [
      'ตาราง',
      'โปรแกรม',
      'แพลน',
      'ทำอะไรบ้าง',
      'ไปไหนบ้าง',
      'เที่ยวไหนบ้าง',
      'ไปที่ไหนบ้าง',
    ],
    QuickAskTopic.time: ['กี่โมง'],
    QuickAskTopic.vehicle: ['ทะเบียน'],
    QuickAskTopic.contact: ['เบอร์'],
  };

  /// เครื่องหมายว่ากำลังถาม ไม่ใช่กำลังเล่า
  static const List<String> _questionMarks = [
    '?',
    '？',
    'ไหม',
    'มั้ย',
    'มัย',
    'หรอ',
    'เหรอ',
    'อะไร',
    'ยังไง',
    'อย่างไร',
    'บ้าง',
    'กี่',
    'ที่ไหน',
    'ตรงไหน',
    'เมื่อไหร่',
    'เมื่อไร',
    'ขอทราบ',
    'สอบถาม',
    'ขอถาม',
    'ใครทราบ',
  ];

  /// ลำดับการตรวจ — ข้อที่คำเฉพาะเจาะจงกว่ามาก่อน เพื่อให้ "รถออกกี่โมง"
  /// ไม่ถูกกลืนโดยคำกว้างของข้ออื่น
  static const List<QuickAskTopic> _order = [
    QuickAskTopic.itinerary,
    QuickAskTopic.place,
    QuickAskTopic.time,
    QuickAskTopic.vehicle,
    QuickAskTopic.contact,
  ];

  /// ข้อความนี้ถามเรื่องอะไร — null คือไม่เข้าข้อไหนเลย (ปล่อยผ่าน)
  static QuickAskTopic? match(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return null;

    for (final topic in _order) {
      if (_containsAny(normalized, _strong[topic])) return topic;
    }

    if (!_looksLikeQuestion(normalized)) return null;

    for (final topic in _order) {
      if (_containsAny(normalized, _weak[topic])) return topic;
    }

    return null;
  }

  /// ตัดช่องว่างทิ้งทั้งหมด เพราะคนไทยพิมพ์เว้นวรรคกลางคำได้ตามใจ
  /// ("กำหนด การ" ต้องเจอเหมือน "กำหนดการ")
  static String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static bool _looksLikeQuestion(String normalized) =>
      _questionMarks.any(normalized.contains);

  static bool _containsAny(String normalized, List<String>? needles) =>
      needles != null && needles.any(normalized.contains);
}

/// คำตอบหนึ่งบรรทัดของแต่ละข้อ สำหรับแถบคำตอบอัตโนมัติเหนือช่องพิมพ์
///
/// อ่านจาก payload เดียวกับชีตคำถามด่วน (GET chat/trip-info) และยึดหลักเดียวกับ
/// TripFactsService ฝั่งเซิร์ฟเวอร์: สิ่งที่ยังไม่รู้ต้องบอกว่า "ทีมงานจะยืนยัน
/// ให้ก่อนเดินทาง" ไม่ใช่เงียบหายไป — ความไม่รู้ที่อธิบายได้หยุดคำถามได้พอกัน
class QuickAskAnswer {
  /// null = ยังไม่มีข้อมูล (ยังโหลดไม่เสร็จ) ให้ผู้เรียกแสดงคำชวนกดแทน
  static String? line(QuickAskTopic topic, Map<String, dynamic>? info) {
    if (info == null) return null;

    final pickup = _map(info['pickup']);

    switch (topic) {
      case QuickAskTopic.itinerary:
        final itinerary = _map(info['itinerary']);
        if (itinerary == null) return 'ทีมงานจะลงกำหนดการให้ก่อนเดินทางครับ';

        final total = int.tryParse('${itinerary['total']}') ?? 0;

        return 'กำหนดการของรอบนี้ $total รายการ';
      case QuickAskTopic.time:
        final time = _text(pickup?['time']);

        return time == null
            ? 'ทีมงานจะยืนยันเวลาขึ้นรถให้ก่อนเดินทางครับ'
            : 'ขึ้นรถ $time น.';
      case QuickAskTopic.place:
        return _text(pickup?['location']) ??
            _text(pickup?['label']) ??
            'ทีมงานจะยืนยันจุดรับให้ก่อนเดินทางครับ';
      case QuickAskTopic.vehicle:
        final plate = _text(_map(info['vehicle'])?['license_plate']);

        return plate == null
            ? 'ทีมงานจะยืนยันรถและทะเบียนให้ก่อนเดินทางครับ'
            : 'ทะเบียน $plate';
      case QuickAskTopic.contact:
        final driver = _text(_map(info['driver'])?['phone']);
        if (driver != null) return 'คนขับ $driver';

        final staff = (info['staff'] as List? ?? const [])
            .whereType<Map>()
            .map((member) => _text(member['phone']))
            .whereType<String>();

        return staff.isEmpty
            ? 'ทีมงานจะแจ้งเบอร์ติดต่อให้ก่อนเดินทางครับ'
            : 'สตาฟประจำรอบ ${staff.first}';
    }
  }

  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }
}
