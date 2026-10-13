import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/waitlist_screen.dart';
import 'package:provider/provider.dart';

/// คิวรอที่นั่ง — รายการที่ API ส่งมาต้องขึ้นเป็นการ์ดจริง ไม่ใช่จอว่าง
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  http.Response ok(Object data) => http.Response(
    jsonEncode({'success': true, 'data': data, 'message': 'สำเร็จ'}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  // รูปร่างเดียวกับ WaitlistController::formatEntry()
  Map<String, dynamic> entry({
    String status = 'waiting',
    int? position = 3,
    int? expiresIn,
    String? thumbnail = 'trips/doi-inthanon.jpg',
  }) => {
    'id': 11,
    'schedule_id': 42,
    'schedule': {
      'id': 42,
      'departure_date': '2099-03-10',
      'return_date': '2099-03-12',
      'available_seats': 0,
      'status': 'open',
      'price': 3200,
      'trip': {
        'id': 1,
        'title': 'ดอยอินทนนท์ 3 วัน 2 คืน',
        'slug': 'doi-inthanon',
        'location': 'เชียงใหม่',
        'thumbnail_image': thumbnail,
        'cover_image': null,
      },
    },
    'seat_count': 1,
    'status': status,
    'position': position,
    'offered_at': null,
    'expires_at': null,
    'expires_in_seconds': expiresIn,
    'created_at': '2099-01-01T00:00:00.000000Z',
  };

  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> entries) {
    final app = AppProvider();
    app.api.token = 'test-token';
    return http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: const MaterialApp(home: WaitlistScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
    }, () => MockClient((_) async => ok(entries)));
  }

  testWidgets('คิวที่รออยู่ขึ้นเป็นการ์ดพร้อมลำดับคิว', (tester) async {
    await pump(tester, [entry()]);

    expect(tester.takeException(), isNull);
    expect(find.text('ดอยอินทนนท์ 3 วัน 2 คืน'), findsOneWidget);
    expect(find.text('คิวที่ 3 ในรายการรอ'), findsOneWidget);
    expect(find.text('ยังไม่มีคิวรอ'), findsNothing);
  });

  testWidgets('ทริปไม่มีรูปก็ยังขึ้นการ์ด', (tester) async {
    await pump(tester, [entry(thumbnail: null)]);

    expect(tester.takeException(), isNull);
    expect(find.text('ดอยอินทนนท์ 3 วัน 2 คืน'), findsOneWidget);
  });

  testWidgets('ได้สิทธิ์จองแล้วขึ้นนับถอยหลังกับปุ่มจองเลย', (tester) async {
    await pump(tester, [
      entry(status: 'offered', position: null, expiresIn: 600),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('มีที่นั่งว่างแล้ว! จองภายใน'), findsOneWidget);
    expect(find.text('จองเลย'), findsOneWidget);
  });
}
