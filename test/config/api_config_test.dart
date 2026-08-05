import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/config/api_config.dart';

void main() {
  group('ApiConfig.normalizeBaseUrl', () {
    test('ค่าปกติผ่านไปเหมือนเดิม', () {
      expect(
        ApiConfig.normalizeBaseUrl('https://luilaykhao.com/api/v1'),
        'https://luilaykhao.com/api/v1',
      );
      expect(
        ApiConfig.normalizeBaseUrl('http://localhost:8000/api/v1'),
        'http://localhost:8000/api/v1',
      );
    });

    test('ตัด / ท้าย เพื่อไม่ให้ path กลายเป็น //', () {
      expect(
        ApiConfig.normalizeBaseUrl('https://luilaykhao.com/api/v1//'),
        'https://luilaykhao.com/api/v1',
      );
    });

    // เคสจริงจาก build 1.12.0+41: คำสั่ง build หลายบรรทัดโดนกลืน `\` ท้ายบรรทัด
    // ทั้งก้อนที่เหลือเลยไหลเข้ามาอยู่ในค่าเดียว
    test('ตัดเศษคำสั่ง build ที่หลุดเข้ามาในค่า', () {
      expect(
        ApiConfig.normalizeBaseUrl(
          'https://luilaykhao.com/api/v1 --dart-define=REVERB_APP_KEY=traildive-key '
          '--dart-define=REVERB_HOST=luilaykhao.com --dart-define=REVERB_PORT=443',
        ),
        'https://luilaykhao.com/api/v1',
      );
    });

    test('ค่าที่ใช้ไม่ได้ถอยไปใช้ production แทนที่จะทำให้แอปเป็นก้อนว่าง', () {
      expect(
        ApiConfig.normalizeBaseUrl(''),
        'https://luilaykhao.com/api/v1',
      );
      expect(
        ApiConfig.normalizeBaseUrl('   '),
        'https://luilaykhao.com/api/v1',
      );
      expect(
        ApiConfig.normalizeBaseUrl('luilaykhao.com/api/v1'),
        'https://luilaykhao.com/api/v1',
      );
      expect(
        ApiConfig.normalizeBaseUrl('ftp://luilaykhao.com/api/v1'),
        'https://luilaykhao.com/api/v1',
      );
    });
  });
}
