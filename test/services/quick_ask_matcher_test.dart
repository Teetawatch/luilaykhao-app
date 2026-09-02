import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/quick_ask_matcher.dart';

/// สิ่งที่ต้องถูกคือ *อะไรถึงจะนับว่ากำลังถาม* — เดาหัวข้อผิดยังพอรับได้เพราะ
/// ชีตปลายทางตอบครบทั้งห้าข้อ แต่เด้งใส่บทสนทนาปกติคือรบกวนเปล่า ๆ
void main() {
  group('จับคำถามที่แอปตอบเองได้', () {
    test('คำเฉพาะเจาะจงจับได้โดยไม่ต้องมีรูปคำถาม', () {
      expect(QuickAskMatcher.match('กำหนดการ'), QuickAskTopic.itinerary);
      expect(
        QuickAskMatcher.match('ขอกำหนดการรอบนี้หน่อยครับ'),
        QuickAskTopic.itinerary,
      );
      expect(QuickAskMatcher.match('จุดรับอยู่ตรงไหนคะ'), QuickAskTopic.place);
      expect(QuickAskMatcher.match('ขึ้นรถกี่โมงครับ'), QuickAskTopic.time);
      expect(
        QuickAskMatcher.match('ทะเบียนรถคันไหนครับ'),
        QuickAskTopic.vehicle,
      );
      expect(
        QuickAskMatcher.match('ขอเบอร์คนขับหน่อยครับ'),
        QuickAskTopic.contact,
      );
    });

    test('เว้นวรรคกลางคำก็ยังจับได้', () {
      expect(
        QuickAskMatcher.match('ขอ กำหนด การ หน่อย'),
        QuickAskTopic.itinerary,
      );
      expect(QuickAskMatcher.match('ขึ้น รถ กี่ โมง'), QuickAskTopic.time);
    });

    test('ภาษาอังกฤษและตัวพิมพ์ใหญ่ก็จับได้', () {
      expect(QuickAskMatcher.match('Itinerary?'), QuickAskTopic.itinerary);
    });

    test('คำกว้างต้องมาคู่กับรูปคำถามเท่านั้น', () {
      // เล่า ไม่ได้ถาม
      expect(QuickAskMatcher.match('ไปตามโปรแกรมเดิมนะครับ'), isNull);
      expect(QuickAskMatcher.match('เดี๋ยวผมส่งตารางให้'), isNull);

      // ถามจริง
      expect(
        QuickAskMatcher.match('โปรแกรมวันแรกเป็นยังไงบ้างครับ'),
        QuickAskTopic.itinerary,
      );
      expect(
        QuickAskMatcher.match('วันนี้ไปไหนบ้างครับ'),
        QuickAskTopic.itinerary,
      );
      expect(QuickAskMatcher.match('นัดกันกี่โมงครับ'), QuickAskTopic.time);
    });

    test('บทสนทนาปกติต้องไม่ถูกเด้ง', () {
      const chatter = [
        'สวัสดีครับทุกคน',
        'ตื่นเต้นมากเลย แล้วเจอกันนะครับ',
        'ฝนตกหนักเลยวันนี้',
        'ขอบคุณครับพี่',
        'ใครเอาถุงมือไปเผื่อบ้างครับ',
        'ถ่ายรูปสวยมากเลยครับ',
        '',
        '   ',
      ];

      for (final text in chatter) {
        expect(
          QuickAskMatcher.match(text),
          isNull,
          reason: 'ไม่ควรเด้งกับข้อความ "$text"',
        );
      }
    });

    test('ถามหลายเรื่องพร้อมกัน หยิบข้อที่เฉพาะเจาะจงตามลำดับที่ตั้งไว้', () {
      // มีทั้ง "กำหนดการ" และ "กี่โมง" — กำหนดการมาก่อนตามลำดับตรวจ
      expect(
        QuickAskMatcher.match('กำหนดการวันแรกเริ่มกี่โมงครับ'),
        QuickAskTopic.itinerary,
      );
    });
  });

  group('คำตอบหนึ่งบรรทัดบนแถบ', () {
    const info = {
      'pickup': {'location': 'ปั๊ม ปตท. วิภาวดี', 'time': '19:30'},
      'vehicle': {'license_plate': 'ฮก 1234 กรุงเทพมหานคร'},
      'driver': {'name': 'สมชาย', 'phone': '0812345678'},
      'staff': [
        {'name': 'ต้น', 'phone': '0899999999'},
      ],
      'itinerary': {'source': 'schedule', 'total': 9, 'items': []},
    };

    test('ยังไม่มีข้อมูลคืน null ให้แถบไปแสดงคำชวนกดแทน', () {
      expect(QuickAskAnswer.line(QuickAskTopic.itinerary, null), isNull);
    });

    test('ตอบจากข้อมูลจริงของรอบ', () {
      expect(
        QuickAskAnswer.line(QuickAskTopic.itinerary, info),
        'กำหนดการของรอบนี้ 9 รายการ',
      );
      expect(QuickAskAnswer.line(QuickAskTopic.time, info), 'ขึ้นรถ 19:30 น.');
      expect(
        QuickAskAnswer.line(QuickAskTopic.place, info),
        'ปั๊ม ปตท. วิภาวดี',
      );
      expect(
        QuickAskAnswer.line(QuickAskTopic.vehicle, info),
        'ทะเบียน ฮก 1234 กรุงเทพมหานคร',
      );
      expect(
        QuickAskAnswer.line(QuickAskTopic.contact, info),
        'คนขับ 0812345678',
      );
    });

    test('สิ่งที่ยังไม่รู้ต้องบอกว่ารอทีมงานยืนยัน ไม่ใช่เงียบหาย', () {
      const empty = <String, dynamic>{'staff': []};

      for (final topic in QuickAskTopic.values) {
        final line = QuickAskAnswer.line(topic, empty);
        expect(line, isNotNull);
        expect(
          line,
          contains('ทีมงาน'),
          reason: 'ข้อ $topic ต้องอธิบายว่ายังไม่รู้เพราะอะไร',
        );
      }
    });

    test('ไม่มีเบอร์คนขับก็ยกเบอร์สตาฟมาแทน', () {
      const noDriver = {
        'staff': [
          {'name': 'ต้น', 'phone': '0899999999'},
        ],
      };

      expect(
        QuickAskAnswer.line(QuickAskTopic.contact, noDriver),
        'สตาฟประจำรอบ 0899999999',
      );
    });
  });
}
