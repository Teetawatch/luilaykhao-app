import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/handover_claim_screen.dart';
import 'package:luilaykhao_app/screens/seat_handover_screen.dart';
import 'package:provider/provider.dart';

/// ส่งต่อที่นั่ง — สิ่งที่ต้องถูกคือ *ใครเห็นปุ่มอะไร* (กติกามาจากเซิร์ฟเวอร์ทั้งหมด)
/// และคนรับเห็นข้อผิดพลาดรายช่องตามที่เซิร์ฟเวอร์ตอบ
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  final booking = {
    'booking_ref': 'LLK-20991010-0001',
    'schedule': {
      'id': 5,
      'departure_date': '2099-10-10',
      'trip': {'title': 'ภูกระดึง'},
    },
  };

  Map<String, dynamic> overview({
    bool available = true,
    Map<String, dynamic>? openHandover,
  }) => {
    'available': available,
    'blocked_reason': available ? null : 'เลยเวลาส่งต่อที่นั่งแล้ว',
    'deadline_label': 'สิ้นวันที่ 9 ตุลาคม 2642',
    'viewer_role': 'owner',
    'can_transfer_ownership': true,
    'seats': [
      {
        'passenger_id': 1,
        'name': 'สมชาย ใจดี',
        'seat_label': 'A1',
        'is_owner_seat_guess': true,
        'can_hand_over': available,
        'open_handover': null,
      },
      {
        'passenger_id': 2,
        'name': 'สมหญิง รักดี',
        'seat_label': 'A2',
        'can_hand_over': available,
        'open_handover': openHandover,
      },
    ],
    'history': [
      {
        'id': 9,
        'status': 'claimed',
        'previous_name': 'มานี มีนา',
        'new_name': 'ปิติ ยินดี',
        'claimed_at': '2099-10-01T03:00:00Z',
      },
    ],
  };

  Map<String, dynamic> preview({bool claimable = true}) => {
    'token': 'tok',
    'status': claimable ? 'pending' : 'claimed',
    'claimable': claimable,
    'blocked_reason': claimable ? null : 'ที่นั่งนี้มีคนรับไปแล้ว',
    'from_name': 'ต้น',
    'note': 'ฝากด้วยนะ',
    'transfers_ownership': false,
    'trip': {
      'title': 'ภูกระดึง',
      'is_international': false,
      'is_women_only': false,
    },
    'schedule': {'departure_label': '10 ตุลาคม 2642'},
    'seat_label': 'A2',
    'pickup': {'label': 'หมอชิต', 'time': '21:00'},
    'terms': {'version': '2026-09-29', 'url': 'https://luilaykhao.com/terms'},
    'prefill': {
      'name': 'มานะ ขยันดี',
      'nickname': 'มานะ',
      'phone': '0833333333',
    },
  };

  final list = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<void> pump(
    WidgetTester tester,
    Widget screen,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    await http.runWithClient(() async {
      final provider = AppProvider();
      provider.api.token = 'test-token';
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
  }

  testWidgets('เจ้าของเห็นปุ่มส่งต่อทุกที่นั่ง และลิงก์ที่รอคนรับ', (
    tester,
  ) async {
    await pump(
      tester,
      SeatHandoverScreen(booking: booking),
      (_) async => json({
        'success': true,
        'data': overview(
          openHandover: {
            'id': 3,
            'url': 'https://luilaykhao.com/handover/tok',
            'expires_at': '2099-10-09T17:00:00Z',
          },
        ),
      }),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ส่งต่อที่นั่งนี้'), findsOneWidget);
    expect(find.text('รอคนรับ'), findsOneWidget);
    expect(find.text('ส่งลิงก์'), findsOneWidget);
    expect(find.textContaining('สิ้นวันที่ 9 ตุลาคม 2642'), findsOneWidget);
    expect(find.textContaining('มานี มีนา → ปิติ ยินดี'), findsOneWidget);
  });

  testWidgets('เลยเส้นตายแล้ว บอกเหตุผลและไม่มีปุ่มส่งต่อ', (tester) async {
    await pump(
      tester,
      SeatHandoverScreen(booking: booking),
      (_) async => json({'success': true, 'data': overview(available: false)}),
    );

    expect(find.text('เลยเวลาส่งต่อที่นั่งแล้ว'), findsOneWidget);
    expect(find.text('ส่งต่อที่นั่งนี้'), findsNothing);
  });

  testWidgets('คนรับเห็นทริป ฟอร์มเติมจากโปรไฟล์ และปุ่มรับ', (tester) async {
    await pump(
      tester,
      const HandoverClaimScreen(token: 'tok'),
      (_) async => json({'success': true, 'data': preview()}),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ต้น ส่งที่นั่งให้คุณ'), findsOneWidget);
    expect(find.text('ที่นั่ง A2'), findsOneWidget);
    expect(find.text('มานะ ขยันดี'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('รับที่นั่งนี้'),
      300,
      scrollable: list,
    );
    expect(find.text('รับที่นั่งนี้'), findsOneWidget);
  });

  testWidgets('ลิงก์ที่มีคนรับไปแล้ว ไม่โชว์ฟอร์ม', (tester) async {
    await pump(
      tester,
      const HandoverClaimScreen(token: 'tok'),
      (_) async => json({'success': true, 'data': preview(claimable: false)}),
    );

    expect(find.text('ที่นั่งนี้มีคนรับไปแล้ว'), findsOneWidget);
    expect(find.text('รับที่นั่งนี้'), findsNothing);
  });

  testWidgets('ข้อผิดพลาดรายช่องจากเซิร์ฟเวอร์ขึ้นใต้ช่องนั้น', (tester) async {
    await http.runWithClient(
      () async {
        final provider = AppProvider();
        provider.api.token = 'test-token';
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: const MaterialApp(home: HandoverClaimScreen(token: 'tok')),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('ไม่ต้องการ'),
          300,
          scrollable: list,
        );
        await tester.tap(find.text('ไม่ต้องการ'));
        await tester.scrollUntilVisible(
          find.byType(CheckboxListTile),
          300,
          scrollable: list,
        );
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('รับที่นั่งนี้'),
          300,
          scrollable: list,
        );
        await tester.tap(find.text('รับที่นั่งนี้'));
        await tester.pumpAndSettle();
      },
      () => MockClient((request) async {
        if (request.method == 'POST') {
          return json({
            'success': false,
            'message': 'ข้อมูลไม่ถูกต้อง',
            'errors': {
              'id_card': ['เลขบัตรประชาชนไม่ถูกต้อง ลองตรวจสอบอีกครั้งครับ'],
            },
          }, 422);
        }
        return json({'success': true, 'data': preview()});
      }),
    );

    expect(find.text('กรุณาตรวจสอบข้อมูลที่ไฮไลต์ไว้'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('เลขบัตรประชาชนไม่ถูกต้อง ลองตรวจสอบอีกครั้งครับ'),
      -300,
      scrollable: list,
    );
    expect(
      find.text('เลขบัตรประชาชนไม่ถูกต้อง ลองตรวจสอบอีกครั้งครับ'),
      findsOneWidget,
    );
  });
}
