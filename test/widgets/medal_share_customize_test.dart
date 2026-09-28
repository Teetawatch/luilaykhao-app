import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/trip_medal.dart';
import 'package:luilaykhao_app/services/medal_look_storage.dart';
import 'package:luilaykhao_app/widgets/medal_share_sheet.dart';
import 'package:luilaykhao_app/widgets/medal_story_card.dart';
import 'package:luilaykhao_app/widgets/trip_story_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_medal_test.dart' show medalJson;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  final medal = TripMedal.fromJson(medalJson());
  final longMedal = TripMedal.fromJson(
    medalJson(
      overrides: {
        'design': {
          'name':
              'เดินป่าข้ามสามจังหวัด ผ่านทะเลหมอกและน้ำตกเจ็ดชั้นกลางป่าดิบชื้น',
          'icon': 'hiking',
          'color': '#15803D',
        },
        'holder_name': 'ชื่อยาวมากเป็นพิเศษ นามสกุลยาวยิ่งกว่าเดิมอีกหลายเท่า',
      },
    ),
  );

  group('MedalStoryCard', () {
    testWidgets(
      'ทุกรูปแบบ × ทุกพื้นหลัง × เหรียญใหญ่สุด ยังเป็น 360×640 ไม่ล้น',
      (tester) async {
        _useTallSurface(tester);

        for (final m in [medal, longMedal]) {
          for (final layout in MedalCardLayout.values) {
            for (final backdrop in MedalBackdrop.values) {
              for (final scale in [kMedalScaleMin, 1.0, kMedalScaleMax]) {
                await tester.pumpWidget(
                  _wrap(
                    MedalStoryCard(
                      medal: m,
                      layout: layout,
                      backdrop: backdrop,
                      medalScale: scale,
                    ),
                  ),
                );

                final reason = '${layout.name}/${backdrop.name}/$scale';
                expect(
                  tester.getSize(find.byType(MedalStoryCard)),
                  const Size(kStoryCardWidth, kStoryCardHeight),
                  reason: reason,
                );
                expect(tester.takeException(), isNull, reason: reason);
              }
            }
          }
        }
      },
    );

    testWidgets('ทุกทรงเหรียญ × เหรียญใหญ่สุด ยังเป็น 360×640 ไม่ล้น', (
      tester,
    ) async {
      _useTallSurface(tester);

      for (final shape in MedalShape.values) {
        for (final layout in MedalCardLayout.values) {
          await tester.pumpWidget(
            _wrap(
              MedalStoryCard(
                medal: longMedal,
                layout: layout,
                medalScale: kMedalScaleMax,
                shape: shape,
              ),
            ),
          );

          final reason = '${shape.name}/${layout.name}';
          expect(
            tester.getSize(find.byType(MedalStoryCard)),
            const Size(kStoryCardWidth, kStoryCardHeight),
            reason: reason,
          );
          expect(tester.takeException(), isNull, reason: reason);
        }
      }
    });

    testWidgets('ปิดชื่อ/สถิติ/ครั้งที่/โลโก้ได้ทีละอย่าง', (tester) async {
      _useTallSurface(tester);

      await tester.pumpWidget(_wrap(MedalStoryCard(medal: medal)));
      expect(find.text('ต้น'), findsOneWidget);
      expect(find.text('ระยะทาง'), findsOneWidget);
      expect(find.textContaining('กันยายน'), findsOneWidget);
      expect(
        find.textContaining('ครั้งที่ 2', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(StoryLogo), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          MedalStoryCard(
            medal: medal,
            parts: const MedalCardParts(
              holder: false,
              stats: false,
              attempt: false,
              logo: false,
              meta: false,
            ),
          ),
        ),
      );

      expect(find.text('ต้น'), findsNothing);
      expect(find.text('ระยะทาง'), findsNothing);
      // บรรทัดสถานที่·วันที่ (ชื่อทริปเองก็มีคำว่า "ลาว" จึงเช็คจากวันที่)
      expect(find.textContaining('กันยายน'), findsNothing);
      expect(
        find.textContaining('ครั้งที่ 2', findRichText: true),
        findsNothing,
      );
      expect(find.byType(StoryLogo), findsNothing);
      // ของที่อยู่เสมอ
      // บนดวงเหรียญหนึ่งที่ + ใต้เหรียญอีกหนึ่งที่
      expect(find.text('เดินป่าลาวใต้ ที่ราบสูงโบลาเวน'), findsNWidgets(2));
      expect(
        find.textContaining('FINISHER #27', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('รูปแบบเหรียญเต็มตาไม่โชว์แถวสถิติ', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(MedalStoryCard(medal: medal, layout: MedalCardLayout.hero)),
      );

      expect(find.text('ระยะทาง'), findsNothing);
      expect(find.text('ต้น'), findsOneWidget);
    });

    test('แถบความทึบ/ความเข้มอยู่ในช่วงที่ตัวอักษรยังอ่านออก', () {
      expect(medalScrimAlpha(0), closeTo(0.85, 1e-9));
      expect(medalScrimAlpha(1), closeTo(0.20, 1e-9));
      expect(medalScrimAlpha(kMedalPhotoOpacityDefault), closeTo(0.59, 1e-9));
      expect(medalScrimAlpha(5), medalScrimAlpha(1));

      const green = Color(0xFF15803D);
      final light = medalBackdropColor(green, 0);
      final dark = medalBackdropColor(green, 1);
      expect(light.computeLuminance(), greaterThan(dark.computeLuminance()));
      expect(
        medalBackdropColor(green),
        medalBackdropColor(green, kMedalToneDefault),
      );
    });
  });

  group('MedalLook', () {
    test('เก็บแล้วอ่านกลับได้ครบ', () {
      const look = MedalLook(
        backdrop: MedalBackdrop.photo,
        layout: MedalCardLayout.corner,
        photoOpacity: 0.8,
        tone: 0.2,
        medalScale: 1.2,
        parts: MedalCardParts(holder: false, logo: false),
        shape: MedalShape.hexagon,
      );

      final back = MedalLook.fromJson(look.toJson());

      expect(back.shape, MedalShape.hexagon);

      expect(back.backdrop, MedalBackdrop.photo);
      expect(back.layout, MedalCardLayout.corner);
      expect(back.photoOpacity, 0.8);
      expect(back.tone, 0.2);
      expect(back.medalScale, 1.2);
      expect(back.parts, const MedalCardParts(holder: false, logo: false));
    });

    test('ค่าเสีย/ไม่รู้จักตกไปใช้ค่าตั้งต้นทีละช่อง', () {
      final look = MedalLook.fromJson(const {
        'backdrop': 'neon',
        'layout': 'corner',
        'photo_opacity': 'x',
        'tone': 9,
        'medal_scale': 0.1,
        'parts': 'broken',
        'shape': 'triangle',
      });

      expect(look.shape, MedalShape.rosette);

      expect(look.backdrop, MedalLook.defaults.backdrop);
      expect(look.layout, MedalCardLayout.corner);
      expect(look.photoOpacity, kMedalPhotoOpacityDefault);
      expect(look.tone, 1);
      expect(look.medalScale, kMedalScaleMin);
      expect(look.parts, MedalCardParts.all);
    });

    test('storage จำค่าที่เขียนไว้', () async {
      SharedPreferences.setMockInitialValues({});
      const look = MedalLook(
        backdrop: MedalBackdrop.dark,
        layout: MedalCardLayout.hero,
        photoOpacity: 0.3,
        tone: 0.9,
        medalScale: 0.8,
        parts: MedalCardParts(stats: false),
      );

      await MedalLookStorage.instance.write(look);
      final read = await MedalLookStorage.instance.read();

      expect(read.backdrop, MedalBackdrop.dark);
      expect(read.layout, MedalCardLayout.hero);
      expect(read.parts.stats, isFalse);
    });
  });

  group('MedalShareSheet', () {
    testWidgets('สลับแท็บ ปรับข้อมูล แล้วค่าถูกจำไว้', (tester) async {
      SharedPreferences.setMockInitialValues({});
      _useTallSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedalShareSheet(medal: medal)),
        ),
      );
      await tester.pumpAndSettle();

      // แท็บพื้นหลัง: พื้นสีเหรียญมีแถบความเข้ม
      expect(find.text('ความเข้มของสี'), findsOneWidget);

      await tester.tap(find.text('มืด'));
      await tester.pumpAndSettle();
      expect(find.text('ความเข้มของสี'), findsNothing);
      expect(
        tester.widget<MedalStoryCard>(find.byType(MedalStoryCard)).backdrop,
        MedalBackdrop.dark,
      );

      await tester.tap(find.text('รูปแบบ'));
      await tester.pumpAndSettle();
      expect(find.text('ขนาดเหรียญ'), findsOneWidget);
      await tester.tap(find.text('โชว์วิว'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ข้อมูล'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ชื่อผู้พิชิต'));
      await tester.pumpAndSettle();

      final card = tester.widget<MedalStoryCard>(find.byType(MedalStoryCard));
      expect(card.layout, MedalCardLayout.corner);
      expect(card.parts.holder, isFalse);

      final saved = await MedalLookStorage.instance.read();
      expect(saved.backdrop, MedalBackdrop.dark);
      expect(saved.layout, MedalCardLayout.corner);
      expect(saved.parts.holder, isFalse);

      await tester.tap(find.text('ค่าเริ่มต้น'));
      await tester.pumpAndSettle();
      final reset = tester.widget<MedalStoryCard>(find.byType(MedalStoryCard));
      expect(reset.backdrop, MedalBackdrop.color);
      expect(reset.layout, MedalCardLayout.centered);
      expect(reset.parts, MedalCardParts.all);
      expect(tester.takeException(), isNull);
    });

    testWidgets('เลือกทรงเหรียญ แล้วค่าถูกจำ / ค่าเริ่มต้นกลับเป็นขอบหยัก', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      _useTallSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedalShareSheet(medal: medal)),
        ),
      );
      await tester.pumpAndSettle();

      MedalStoryCard card() =>
          tester.widget<MedalStoryCard>(find.byType(MedalStoryCard));

      expect(card().shape, MedalShape.rosette);

      await tester.tap(find.text('ทรงเหรียญ'));
      await tester.pumpAndSettle();
      // ทริปแม่แบบไม่มีตัวเลือก "แบบของทริป"
      expect(find.text('แบบของทริป'), findsNothing);

      await tester.tap(find.text('โล่'));
      await tester.pumpAndSettle();
      expect(card().shape, MedalShape.shield);
      expect((await MedalLookStorage.instance.read()).shape, MedalShape.shield);

      await tester.tap(find.text('ค่าเริ่มต้น'));
      await tester.pumpAndSettle();
      expect(card().shape, MedalShape.rosette);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ทริปมีภาพเหรียญออกแบบเอง เปิดมาเป็นภาพนั้นแม้จำทรงไว้', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await MedalLookStorage.instance.write(
        const MedalLook(
          backdrop: MedalBackdrop.color,
          layout: MedalCardLayout.centered,
          photoOpacity: 0.4,
          tone: 0.5,
          medalScale: 1,
          parts: MedalCardParts.all,
          shape: MedalShape.hexagon,
        ),
      );
      _useTallSurface(tester);

      final custom = TripMedal.fromJson(
        medalJson(
          overrides: {
            'design': {
              'name': 'โบลาเวน',
              'icon': 'coffee',
              'color': '#15803D',
              'image_url': 'https://example.com/medal.png',
            },
          },
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedalShareSheet(medal: custom)),
        ),
      );
      await tester.pumpAndSettle();

      MedalStoryCard card() =>
          tester.widget<MedalStoryCard>(find.byType(MedalStoryCard));

      expect(card().shape, isNull);

      await tester.tap(find.text('ทรงเหรียญ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('หกเหลี่ยม'));
      await tester.pumpAndSettle();
      expect(card().shape, MedalShape.hexagon);

      await tester.tap(find.text('แบบของทริป'));
      await tester.pumpAndSettle();
      expect(card().shape, isNull);
      // กลับไปใช้ภาพของทริปไม่ลบทรงที่ชอบไว้
      expect(
        (await MedalLookStorage.instance.read()).shape,
        MedalShape.hexagon,
      );
    });

    testWidgets(
      'เหรียญที่บันทึกทรงไว้เปิดมาเป็นทรงนั้น ไม่ใช่ทรงที่เครื่องจำ',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await MedalLookStorage.instance.write(
          const MedalLook(
            backdrop: MedalBackdrop.color,
            layout: MedalCardLayout.centered,
            photoOpacity: 0.4,
            tone: 0.5,
            medalScale: 1,
            parts: MedalCardParts.all,
            shape: MedalShape.coin,
          ),
        );
        _useTallSurface(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MedalShareSheet(
                medal: TripMedal.fromJson(
                  medalJson(overrides: {'shape': 'shield'}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<MedalStoryCard>(find.byType(MedalStoryCard)).shape,
          MedalShape.shield,
        );
      },
    );

    testWidgets(
      'กดแชร์แล้วบันทึกทรงที่เลือก — ขอบหยักของทริปแม่แบบส่งเป็น null',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        _useTallSurface(tester);
        final saved = <MedalShape?>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MedalShareSheet(
                medal: TripMedal.fromJson(
                  medalJson(overrides: {'shape': 'hexagon'}),
                ),
                onSaveShape: (shape) async {
                  saved.add(shape);
                  return shape;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('ทรงเหรียญ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ขอบหยัก'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('แชร์เหรียญ'));
        await tester.pump();

        expect(saved, [null]);
      },
    );

    testWidgets('ทรงไม่เปลี่ยนก็ไม่ยิงบันทึกซ้ำ', (tester) async {
      SharedPreferences.setMockInitialValues({});
      _useTallSurface(tester);
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedalShareSheet(
              medal: TripMedal.fromJson(
                medalJson(overrides: {'shape': 'coin'}),
              ),
              onSaveShape: (shape) async {
                calls++;
                return shape;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('แชร์เหรียญ'));
      await tester.pump();

      expect(calls, 0);
    });

    testWidgets('บอกผิวเหรียญและต้องมาอีกกี่ครั้งถึงผิวถัดไป', (tester) async {
      SharedPreferences.setMockInitialValues({});
      _useTallSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedalShareSheet(
              medal: TripMedal.fromJson(
                medalJson(overrides: {'attempt': 3, 'finish': 'platinum'}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ทรงเหรียญ'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'ผิวแพลทินัม  ·  มาพิชิตครั้งที่ 3  ·  มาอีก 2 ครั้งได้ผิวดำทอง',
        ),
        findsOneWidget,
      );
    });

    testWidgets('จำพื้นรูปไว้แต่ทริปนี้ไม่มีรูป → เปิดมาเป็นพื้นสีเหรียญ', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await MedalLookStorage.instance.write(
        const MedalLook(
          backdrop: MedalBackdrop.photo,
          layout: MedalCardLayout.centered,
          photoOpacity: 0.4,
          tone: 0.5,
          medalScale: 1,
          parts: MedalCardParts.all,
        ),
      );
      _useTallSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MedalShareSheet(medal: medal)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<MedalStoryCard>(find.byType(MedalStoryCard)).backdrop,
        MedalBackdrop.color,
      );
    });
  });
}
