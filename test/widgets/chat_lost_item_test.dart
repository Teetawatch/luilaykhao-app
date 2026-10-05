import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_lost_item.dart';

Map<String, dynamic> _item(String status, {int? claimedBy}) => {
      'id': 1,
      'description': 'หมวกสีดำ เบาะหลังรถตู้',
      'photo_url': null,
      'status': status,
      'claimed_by_id': claimedBy,
    };

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('open item invites the owner to claim it', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        ChatLostItemCard(
          item: _item('open'),
          myUserId: 10,
          onOpen: () => opened++,
        ),
      ),
    );

    expect(find.text('หมวกสีดำ เบาะหลังรถตู้'), findsOneWidget);
    expect(find.text('ยังไม่มีเจ้าของ'), findsOneWidget);
    await tester.tap(find.text('ของฉัน / ดูรายละเอียด'));
    expect(opened, 1);
  });

  testWidgets('claimed item reads differently for the owner and others', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatLostItemCard(
          item: _item('claimed', claimedBy: 10),
          myUserId: 10,
          onOpen: () {},
        ),
      ),
    );
    expect(find.text('คุณแจ้งว่าเป็นของคุณ'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        ChatLostItemCard(
          item: _item('claimed', claimedBy: 10),
          myUserId: 11,
          onOpen: () {},
        ),
      ),
    );
    expect(find.text('มีเจ้าของแจ้งแล้ว'), findsOneWidget);
    expect(find.text('ดูรายละเอียด'), findsOneWidget);
  });

  testWidgets('returned item tells the owner it is back', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatLostItemCard(
          item: _item('returned', claimedBy: 10),
          myUserId: 10,
          onOpen: () {},
        ),
      ),
    );
    expect(find.text('ได้รับคืนแล้ว'), findsOneWidget);
  });
}
