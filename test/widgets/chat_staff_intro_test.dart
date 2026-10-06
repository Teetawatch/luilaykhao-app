import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_staff_intro.dart';

Map<String, dynamic> _intro({
  int rounds = 12,
  String? phone = '081-234-5678',
  double? rating = 4.8,
}) => {
  'user_id': 7,
  'name': 'พี่ต้น',
  'avatar_url': '',
  'phone': phone,
  'bio': 'สายเดินชิล ไม่ทิ้งใครครับ',
  'trails': ['ภูกระดึง', 'ดอยหลวงเชียงดาว'],
  'skills': ['ปฐมพยาบาลเบื้องต้น'],
  'rounds_count': rounds,
  'this_trip_rounds': 3,
  'rating_avg': rating,
  'rating_count': 9,
};

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'shows who the staff is, where they have hiked and what they do',
    (tester) async {
      await tester.pumpWidget(_host(StaffIntroCard(intro: _intro())));

      expect(find.text('พี่ต้น'), findsOneWidget);
      expect(find.text('สายเดินชิล ไม่ทิ้งใครครับ'), findsOneWidget);
      expect(find.text('ภูกระดึง'), findsOneWidget);
      expect(find.text('ดอยหลวงเชียงดาว'), findsOneWidget);
      expect(find.text('ปฐมพยาบาลเบื้องต้น'), findsOneWidget);
      expect(find.text('ดูแลมาแล้ว 12 รอบ'), findsOneWidget);
      expect(find.text('ทริปนี้ 3 รอบ'), findsOneWidget);
      expect(find.text('4.8 (9 รีวิว)'), findsOneWidget);
      expect(find.text('081-234-5678'), findsOneWidget);
    },
  );

  testWidgets('greet fills a friendly hello for the composer', (tester) async {
    String? greeted;
    await tester.pumpWidget(
      _host(StaffIntroCard(intro: _intro(), onGreet: (g) => greeted = g)),
    );

    await tester.tap(find.text('ทักทาย'));
    expect(greeted, 'สวัสดีพี่ต้น 👋 ');
  });

  testWidgets('staff looking at their own card get no call or greet buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(StaffIntroCard(intro: _intro(), myUserId: 7, onGreet: (_) {})),
    );

    expect(find.text('ทักทาย'), findsNothing);
    expect(find.text('081-234-5678'), findsNothing);
  });

  testWidgets('a new staff with no history reads as fresh, not empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        StaffIntroCard(intro: _intro(rounds: 0, phone: null, rating: null)),
      ),
    );

    expect(find.text('ทีมงานไฟแรง'), findsOneWidget);
    expect(find.textContaining('ดูแลมาแล้ว'), findsNothing);
    expect(find.byIcon(Icons.call_rounded), findsNothing);
  });
}
