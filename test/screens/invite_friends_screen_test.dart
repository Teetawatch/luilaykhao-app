import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/invite_friends_screen.dart';
import 'package:provider/provider.dart';

/// หน้า "เชิญเพื่อนร่วมทริป" — สิ่งที่ต้องถูกต้องคือ *ใครเห็นปุ่มอะไร*
/// เจ้าของเท่านั้นที่เชิญได้ และเชิญได้เท่าที่ยังมีที่นั่งเหลือ
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  Map<String, dynamic> booking({bool viewerIsOwner = true}) => {
    'booking_ref': 'LLK-20990110-0001',
    'viewer_is_owner': viewerIsOwner,
    'schedule': {
      'id': 5,
      'departure_date': '2099-01-10',
      'trip': {'title': 'ภูกระดึง'},
    },
  };

  Map<String, dynamic> roster({
    bool canInviteMore = true,
    bool viewerIsOwner = true,
    List<Map<String, dynamic>> members = const [],
  }) => {
    'owner': {'user_id': 1, 'name': 'ต้น', 'nickname': 'ต้น', 'avatar_url': ''},
    'members': members,
    'can_invite_more': canInviteMore,
    'max_members': 3,
    'remaining_slots': canInviteMore ? 1 : 0,
    'viewer_is_owner': viewerIsOwner,
  };

  Future<void> pump(
    WidgetTester tester, {
    required Map<String, dynamic> data,
    bool viewerIsOwner = true,
  }) async {
    await http.runWithClient(
      () async {
        final provider = AppProvider();
        provider.api.token = 'test-token';

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: MaterialApp(
              home: InviteFriendsScreen(
                booking: booking(viewerIsOwner: viewerIsOwner),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode({'success': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
  }

  testWidgets('เจ้าของเห็นคำอธิบายและปุ่มสร้างลิงก์คำเชิญ', (tester) async {
    await pump(tester, data: roster());

    expect(tester.takeException(), isNull);
    expect(find.text('สร้างลิงก์คำเชิญ'), findsOneWidget);
    expect(find.text('แชทกลุ่มของรอบนี้'), findsOneWidget);
    expect(find.text('ติดตามรถแบบเรียลไทม์'), findsOneWidget);
    expect(find.textContaining('เชิญได้อีก 1 คน'), findsOneWidget);
  });

  testWidgets('คำเชิญที่ยังไม่ถูกรับ ส่งลิงก์เดิมซ้ำได้ ไม่ต้องสร้างใบใหม่', (
    tester,
  ) async {
    await pump(
      tester,
      data: roster(
        members: [
          {
            'id': 9,
            'status': 'pending',
            'invite_label': 'บอม',
            'invite_token': 'abc123',
            'invite_url': 'https://luilaykhao.com/join/abc123',
            'user': null,
          },
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    // รายชื่อสมาชิกอยู่ต่ำกว่าหน้าจอเทสต์ ต้องเลื่อนลงไปก่อน
    await tester.scrollUntilVisible(find.text('บอม'), 200);
    expect(find.text('บอม'), findsOneWidget);
    expect(find.text('ส่งลิงก์แล้ว รอเพื่อนกดเข้าร่วม'), findsOneWidget);
    expect(find.text('ส่งลิงก์อีกครั้ง'), findsOneWidget);
  });

  testWidgets('เชิญครบตามจำนวนผู้เดินทางแล้ว — ไม่มีปุ่มสร้างลิงก์', (
    tester,
  ) async {
    await pump(tester, data: roster(canInviteMore: false));

    expect(tester.takeException(), isNull);
    expect(find.text('สร้างลิงก์คำเชิญ'), findsNothing);
    expect(find.textContaining('เชิญครบตามจำนวนผู้เดินทาง'), findsOneWidget);
  });

  testWidgets('เพื่อนที่ถูกเชิญเข้ามาดูได้ แต่เชิญต่อไม่ได้', (tester) async {
    await pump(
      tester,
      viewerIsOwner: false,
      data: roster(viewerIsOwner: false),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('สร้างลิงก์คำเชิญ'), findsNothing);
    expect(
      find.textContaining('เฉพาะเจ้าของการจองเท่านั้น'),
      findsOneWidget,
    );
  });
}
