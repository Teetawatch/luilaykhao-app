import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/screens/trip_contacts_screen.dart';
import 'package:luilaykhao_app/widgets/chat_social.dart';

void main() {
  testWidgets('intro card shows only what was shared', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatIntroCard(
            intro: {'hometown': 'เชียงใหม่', 'experience': 'first', 'note': null},
            name: 'เอ',
            isMine: false,
          ),
        ),
      ),
    );
    expect(find.text('เอ มาแนะนำตัว'), findsOneWidget);
    expect(find.text('มาจาก เชียงใหม่'), findsOneWidget);
    expect(find.text('มาครั้งแรก 🌱'), findsOneWidget);
    expect(find.text('แก้ไข'), findsNothing);
  });

  testWidgets('intro sheet needs at least one answer', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    addTearDown(tester.view.reset);
    IntroDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<IntroDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ChatIntroSheet(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final send = find.widgetWithText(FilledButton, 'ส่งการ์ดแนะนำตัว');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.tap(find.text('สายลุย ⛰️'));
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(result?.experience, 'lots');
  });

  test('contact handles open the right app', () {
    expect(contactHandleUri('line', 'abc').toString(), 'https://line.me/ti/p/~abc');
    expect(contactHandleUri('instagram', 'a.hiker').toString(), 'https://instagram.com/a.hiker');
    expect(contactHandleUri('tiktok', 'me').toString(), 'https://www.tiktok.com/@me');
    expect(contactHandleUri('facebook', 'https://fb.com/x').toString(), 'https://fb.com/x');
    expect(contactHandleUri('line', '  '), isNull);
  });
}
