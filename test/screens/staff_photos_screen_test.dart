import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/staff_photos_screen.dart';
import 'package:provider/provider.dart';

/// อัลบั้มรอบฝั่งสตาฟ — เห็นรูปทั้งรอบ แต่ลบได้เฉพาะรูปของตัวเอง และปุ่มอัป
/// ปิดเมื่อเซิร์ฟเวอร์บอกว่ารอบนี้ยังไม่เปิด/ปิดรับรูปแล้ว
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  http.Response album({required bool canUpload}) => http.Response(
    jsonEncode({
      'success': true,
      'message': 'สำเร็จ',
      'data': {
        'photos': [
          {
            'id': 1,
            'url': 'https://example.test/1.jpg',
            'thumb_url': 'https://example.test/1_t.jpg',
            'uploaded_by': 7,
            'uploader_name': 'สตาฟบอย',
          },
          {
            'id': 2,
            'url': 'https://example.test/2.jpg',
            'thumb_url': null,
            'uploaded_by': 99,
            'uploader_name': 'แอดมิน',
          },
        ],
        'photos_count': 2,
        'can_upload': canUpload,
        'upload_until': '2026-10-20',
        'max_files_per_request': 20,
        'retention_days': 7,
      },
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<void> pump(WidgetTester tester, {required bool canUpload}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final app = AppProvider();
    app.api.token = 'test-token';
    app.user = {'id': 7, 'name': 'สตาฟบอย'};

    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: const MaterialApp(
            home: StaffPhotosScreen(scheduleId: 12, title: 'ภูกระดึง'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }, () => MockClient((_) async => album(canUpload: canUpload)));
  }

  testWidgets('only own photos get a delete button and a "mine" tag', (
    tester,
  ) async {
    await pump(tester, canUpload: true);

    expect(find.text('2 รูป'), findsOneWidget);
    expect(find.text('ของฉัน'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.textContaining('อัปได้ถึง'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('upload buttons are disabled when the round is closed', (
    tester,
  ) async {
    await pump(tester, canUpload: false);

    expect(find.textContaining('ยังอัปไม่ได้'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    final camera = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(camera.onPressed, isNull);
  });
}
