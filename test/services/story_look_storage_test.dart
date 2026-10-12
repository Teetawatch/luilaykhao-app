import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/story_look_storage.dart';
import 'package:luilaykhao_app/widgets/trip_story_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ยังไม่เคยเลือกอะไร ได้การ์ดหน้าตาตั้งต้น', () async {
    final look = await StoryLookStorage.instance.read();

    expect(look.style, StoryStyle.classic);
    expect(look.photoOpacity, kStoryPhotoOpacityDefault);
  });

  test('จำสไตล์กับความโปร่งใสที่เลือกไว้ข้ามการแชร์', () async {
    await StoryLookStorage.instance.write(
      const StoryLook(style: StoryStyle.mono, photoOpacity: 0.8),
    );

    final look = await StoryLookStorage.instance.read();

    expect(look.style, StoryStyle.mono);
    expect(look.photoOpacity, 0.8);
  });

  test('ค่าที่เพี้ยนไม่ทำให้เปิดหน้าแชร์ไม่ได้', () async {
    SharedPreferences.setMockInitialValues({
      'story_look_v1': '{"style":"สไตล์ที่ไม่มี","photo_opacity":"เยอะ"}',
    });

    final look = await StoryLookStorage.instance.read();

    expect(look.style, StoryStyle.classic);
    expect(look.photoOpacity, kStoryPhotoOpacityDefault);
  });

  test('ความโปร่งใสที่หลุดช่วง 0–1 ถูกดึงกลับเข้าช่วง', () async {
    SharedPreferences.setMockInitialValues({
      'story_look_v1': '{"style":"poster","photo_opacity":4.2}',
    });

    final look = await StoryLookStorage.instance.read();

    expect(look.style, StoryStyle.poster);
    expect(look.photoOpacity, 1.0);
  });

  test('จำชิ้นส่วนที่ซ่อน รูปแบบวันที่ และการแนบลิงก์', () async {
    await StoryLookStorage.instance.write(
      const StoryLook(
        style: StoryStyle.poster,
        photoOpacity: 0.5,
        parts: StoryCardParts(logo: false, date: false),
        dateFormat: StoryDateFormat.month,
        includeLink: false,
      ),
    );

    final look = await StoryLookStorage.instance.read();

    expect(look.parts, const StoryCardParts(logo: false, date: false));
    expect(look.dateFormat, StoryDateFormat.month);
    expect(look.includeLink, isFalse);
  });

  test('ค่าที่บันทึกจากรุ่นก่อน (ไม่มีช่องใหม่) ยังเปิดทุกอย่างเหมือนเดิม', () async {
    SharedPreferences.setMockInitialValues({
      'story_look_v1': '{"style":"mono","photo_opacity":0.7}',
    });

    final look = await StoryLookStorage.instance.read();

    expect(look.style, StoryStyle.mono);
    expect(look.parts, StoryCardParts.all);
    expect(look.dateFormat, StoryDateFormat.full);
    expect(look.includeLink, isTrue);
  });
}
