import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ปุ่ม QR กลางแถบเมนู + แผ่น "QR เช็คอิน"
void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // วันที่สัมพัทธ์กับวันนี้ — เทสต์ไม่เน่าตามปฏิทิน
  String inDays(int days) => ymd(DateTime.now().add(Duration(days: days)));

  Map<String, dynamic> booking({
    required int id,
    String status = 'confirmed',
    int departInDays = 3,
    String title = 'ภูกระดึง',
    bool checkedIn = false,
    String? qrCode,
  }) => {
    'id': id,
    'booking_ref': 'LLK-REF-000$id',
    'status': status,
    'qr_code': qrCode ?? 'CHECKIN-$id',
    'checked_in': checkedIn,
    'checked_in_at': checkedIn ? '2026-10-07T01:00:00.000000Z' : null,
    'passengers': [
      {'name': 'ผู้เดินทาง 1'},
      {'name': 'ผู้เดินทาง 2'},
    ],
    'pickup_point': {'pickup_location': 'BTS หมอชิต', 'pickup_time': '05:30'},
    'schedule': {
      'id': 5,
      'departure_date': inDays(departInDays),
      'return_date': inDays(departInDays + 1),
      'trip': {'id': 2, 'title': title},
    },
  };

  // ───────────────────────── แถบเมนูล่าง ─────────────────────────

  group('CustomBottomNav', () {
    Future<void> pumpNav(
      WidgetTester tester, {
      bool staff = false,
      Size size = const Size(375, 812),
      double textScale = 1,
      required List<int> tabs,
      required List<int> qrTaps,
      List<int>? bodyTaps,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            extendBody: true,
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => bodyTaps?.add(1),
              child: const SizedBox.expand(),
            ),
            bottomNavigationBar: CustomBottomNav(
              index: 0,
              showStaffCheckIn: staff,
              onChanged: tabs.add,
              onCheckInPass: () => qrTaps.add(1),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    final qrButton = find.byKey(const ValueKey('nav-check-in-qr'));

    testWidgets('ปุ่ม QR อยู่กลางจอพอดี และกดแล้วเปิดแผ่น QR', (tester) async {
      final tabs = <int>[];
      final qr = <int>[];
      await pumpNav(tester, tabs: tabs, qrTaps: qr);

      expect(tester.takeException(), isNull);
      expect(tester.getCenter(qrButton).dx, closeTo(187.5, 0.01));

      await tester.tap(qrButton);
      await tester.pump(const Duration(milliseconds: 200));
      expect(qr, [1]);
      expect(tabs, isEmpty, reason: 'ปุ่ม QR ไม่ใช่แท็บ ห้ามสลับหน้า');

      // ป้าย "เช็คอิน" ใต้ปุ่มก็กดได้
      await tester.tap(find.text('เช็คอิน'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(qr, [1, 1]);
    });

    testWidgets('แท็บเดิมยังส่ง index เดิม (ปุ่ม QR ไม่ทำให้เลขเลื่อน)', (
      tester,
    ) async {
      final tabs = <int>[];
      await pumpNav(tester, tabs: tabs, qrTaps: []);

      for (final label in ['หน้าหลัก', 'ทริป', 'การจอง', 'แชท', 'บัญชี']) {
        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tabs, [0, 1, 2, 3, 4]);

      // ลูกค้า 5 แท็บ: ซ้าย 2 ขวา 3 — สองแท็บแรกอยู่ซ้ายปุ่ม ที่เหลืออยู่ขวา
      final mid = tester.getCenter(qrButton).dx;
      expect(tester.getCenter(find.text('ทริป')).dx, lessThan(mid));
      expect(tester.getCenter(find.text('การจอง')).dx, greaterThan(mid));
    });

    testWidgets(
      'สตาฟ 6 แท็บ แบ่ง 3/3 ปุ่มยังอยู่กลาง และงานสตาฟยังเป็นแท็บ 5',
      (tester) async {
        final tabs = <int>[];
        await pumpNav(tester, staff: true, tabs: tabs, qrTaps: []);

        expect(tester.getCenter(qrButton).dx, closeTo(187.5, 0.01));
        final mid = tester.getCenter(qrButton).dx;
        expect(tester.getCenter(find.text('การจอง')).dx, lessThan(mid));
        expect(tester.getCenter(find.text('แชท')).dx, greaterThan(mid));

        await tester.tap(find.text('งานสตาฟ'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tabs, [5]);
      },
    );

    testWidgets('จอแคบ + ตัวอักษรใหญ่ ไม่ล้น', (tester) async {
      await pumpNav(
        tester,
        staff: true,
        size: const Size(320, 640),
        textScale: 1.3,
        tabs: [],
        qrTaps: [],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('พื้นที่โปร่งใสข้างปุ่มไม่บังการแตะเนื้อหาด้านหลัง', (
      tester,
    ) async {
      final body = <int>[];
      final qr = <int>[];
      await pumpNav(tester, tabs: [], qrTaps: qr, bodyTaps: body);

      final navTop = tester.getTopLeft(find.byType(CustomBottomNav)).dy;
      // พื้นที่กดของปุ่ม = วงกลมของส่วนนูน ซึ่งยอดอยู่บนสุดของแถบพอดี
      expect(tester.getTopLeft(qrButton).dy, closeTo(navTop, 0.01));
      expect(
        navTop,
        closeTo(812 - 34 + 4 - 68 - CustomBottomNav.qrOverhang, 0.01),
      );

      // แถบโปร่งใสระดับเดียวกับปุ่ม แต่ห่างจากปุ่มไปทางซ้าย
      await tester.tapAt(Offset(40, navTop + 6));
      await tester.pump(const Duration(milliseconds: 200));
      expect(body, [1]);
      expect(qr, isEmpty);

      // ขอบส่วนนูนรอบปุ่ม (นอกวงสีเขียวแต่ยังในส่วนนูน) กดแล้วก็เปิด QR
      await tester.tapAt(Offset(187.5, navTop + 3));
      await tester.pump(const Duration(milliseconds: 200));
      expect(qr, [1]);
      expect(body, [1]);
    });
  });

  // ───────────────────────── แผ่น QR เช็คอิน ─────────────────────────

  group('CheckInPassSheet', () {
    Future<({List<int> tabs, List<String> opened})> pumpSheet(
      WidgetTester tester, {
      List<Map<String, dynamic>> bookings = const [],
      bool loggedIn = true,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final provider = AppProvider();
      if (loggedIn) provider.api.token = 'test-token';
      provider.bookings = bookings;
      provider.accountLoaded = true;

      final tabs = <int>[];
      final opened = <String>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => CheckInPassSheet.show(
                      context,
                      onSelectTab: tabs.add,
                      onOpenBooking: opened.add,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (tabs: tabs, opened: opened);
    }

    testWidgets('ยังไม่เข้าสู่ระบบ — ชวนเข้าสู่ระบบ แล้วพาไปแท็บการจอง', (
      tester,
    ) async {
      final r = await pumpSheet(tester, loggedIn: false);
      expect(tester.takeException(), isNull);
      expect(find.text('เข้าสู่ระบบเพื่อดู QR เช็คอิน'), findsOneWidget);

      await tester.tap(find.text('เข้าสู่ระบบ'));
      await tester.pumpAndSettle();
      expect(r.tabs, [2]);
      expect(find.text('เข้าสู่ระบบเพื่อดู QR เช็คอิน'), findsNothing);
    });

    testWidgets('ไม่มีทริป — บอกตรง ๆ และพาไปดูทริป', (tester) async {
      final r = await pumpSheet(tester);
      expect(find.text('ยังไม่มีทริปที่ต้องเช็คอิน'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      await tester.tap(find.text('ดูทริปทั้งหมด'));
      await tester.pumpAndSettle();
      expect(r.tabs, [1]);
    });

    testWidgets('มีแต่ใบรอยืนยัน — ยังไม่มี QR และบอกว่ารออะไร', (
      tester,
    ) async {
      await pumpSheet(tester, bookings: [booking(id: 1, status: 'pending')]);
      expect(find.text('รอยืนยันการจอง'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('ใบยืนยันแล้ว — โชว์ QR ทันทีจากข้อมูลในเครื่อง', (
      tester,
    ) async {
      final r = await pumpSheet(tester, bookings: [booking(id: 1)]);
      expect(tester.takeException(), isNull);

      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr, isNotNull);
      expect(find.text('ภูกระดึง'), findsOneWidget);
      expect(find.text('LLK-REF-0001'), findsOneWidget);
      expect(find.text('อีก 3 วัน'), findsOneWidget);
      expect(find.textContaining('ผู้เดินทาง 2 คน'), findsOneWidget);
      expect(find.text('BTS หมอชิต · 05:30 น.'), findsOneWidget);

      await tester.tap(find.text('ดูรายละเอียดการจอง'));
      await tester.pumpAndSettle();
      expect(r.opened, ['LLK-REF-0001']);
    });

    // ─────────── บัตรขึ้นรถรายคน (check_in_passes จากเซิร์ฟเวอร์) ───────────

    Map<String, dynamic> withPasses(
      Map<String, dynamic> base, {
      required String role,
      int? mine,
      bool groupVisible = true,
      List<int> aboard = const [],
      List<Map<String, dynamic>> pickable = const [],
    }) {
      final people = [
        {'id': 11, 'name': 'เอ', 'code': 'QR-PASS-A'},
        {'id': 12, 'name': 'บี', 'code': 'QR-PASS-B'},
      ];
      return {
        ...base,
        'checked_in': aboard.isNotEmpty,
        'passengers': [
          for (final p in people)
            {
              'id': p['id'],
              'name': p['name'],
              'checked_in_at': aboard.contains(p['id'])
                  ? '2026-10-10T00:10:00Z'
                  : null,
            },
        ],
        'check_in_passes': {
          'viewer_role': role,
          'mine_passenger_id': mine,
          'group': groupVisible
              ? {'code': base['qr_code'], 'passenger_count': 2}
              : null,
          'passes': [
            for (final p in people)
              if (role == 'owner' || p['id'] == mine)
                {
                  'passenger_id': p['id'],
                  'name': p['name'],
                  'full_name': p['name'],
                  'code': p['code'],
                  'checked_in': aboard.contains(p['id']),
                  'checked_in_at': aboard.contains(p['id'])
                      ? '2026-10-10T00:10:00Z'
                      : null,
                  'not_going': false,
                  'is_mine': p['id'] == mine,
                  'pass_url': null,
                },
          ],
          'pickable_passengers': pickable,
        },
      };
    }

    // QrImageView ไม่เปิดข้อมูลที่วาดให้อ่าน — ดูจากป้าย Semantics ที่ห่อ QR แต่ละแบบแทน
    Finder qrLabelled(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );
    final groupQr = qrLabelled('QR เช็คอินทั้งกลุ่ม ใบจอง LLK-REF-0001');

    testWidgets('คนจอง — เริ่มที่ QR ทั้งกลุ่ม แล้วสลับดูบัตรของแต่ละคนได้', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        bookings: [withPasses(booking(id: 1), role: 'owner')],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ทั้งกลุ่ม · 2 คน'), findsOneWidget);
      expect(groupQr, findsOneWidget);
      expect(find.textContaining('ทีมงานจะติ๊กเฉพาะคนที่มาถึง'), findsOneWidget);

      await tester.tap(find.text('บี'));
      await tester.pumpAndSettle();
      expect(qrLabelled('QR บัตรขึ้นรถของ บี'), findsOneWidget);
      expect(groupQr, findsNothing);
      expect(find.text('บัตรขึ้นรถของ บี'), findsOneWidget);
      expect(find.text('ส่งบัตรให้บี'), findsOneWidget);
    });

    testWidgets('เพื่อนที่ผูกชื่อแล้ว — เห็นบัตรของตัวเองใบเดียว ไม่มี QR กลุ่ม', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        bookings: [
          withPasses(
            booking(id: 1),
            role: 'member',
            mine: 12,
            groupVisible: false,
          ),
        ],
      );
      expect(find.byType(QrImageView), findsOneWidget);
      expect(qrLabelled('QR บัตรขึ้นรถของ บี'), findsOneWidget);
      expect(find.text('บัตรขึ้นรถของ บี'), findsOneWidget);
      expect(find.text('ทั้งกลุ่ม · 2 คน'), findsNothing);
      expect(find.textContaining('ส่งบัตรให้'), findsNothing);
    });

    testWidgets('เพื่อนที่ยังไม่เลือกชื่อ — QR กลุ่ม + ปุ่มเลือกชื่อของตัวเอง', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        bookings: [
          withPasses(
            booking(id: 1),
            role: 'member',
            pickable: [
              {'passenger_id': 12, 'name': 'บี', 'full_name': 'บี'},
            ],
          ),
        ],
      );
      expect(groupQr, findsOneWidget);
      expect(
        find.text('เลือกชื่อของฉัน เพื่อรับบัตรขึ้นรถของตัวเอง'),
        findsOneWidget,
      );
    });

    testWidgets('ขึ้นรถไปบางคน — QR กลุ่มยังอยู่สำหรับคนที่เหลือ', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        bookings: [withPasses(booking(id: 1), role: 'owner', aboard: [11])],
      );
      expect(groupQr, findsOneWidget);
      expect(find.textContaining('ขึ้นรถแล้ว 1/2 คน'), findsOneWidget);

      await tester.tap(find.text('เอ'));
      await tester.pumpAndSettle();
      expect(find.text('เอ ขึ้นรถแล้ว'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('ขึ้นรถครบทุกคน — การ์ดเช็คอินแล้ว ไม่มี QR', (tester) async {
      await pumpSheet(
        tester,
        bookings: [
          withPasses(booking(id: 1), role: 'owner', aboard: [11, 12]),
        ],
      );
      expect(find.text('เช็คอินแล้ว'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('เช็คอินแล้ว — ไม่โชว์ QR ที่สแกนได้อีก', (tester) async {
      await pumpSheet(tester, bookings: [booking(id: 1, checkedIn: true)]);
      expect(find.text('เช็คอินแล้ว'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('ใบยืนยันที่ไม่มีรหัส QR — บอกให้แจ้งรหัสการจองแทน', (
      tester,
    ) async {
      await pumpSheet(tester, bookings: [booking(id: 1, qrCode: ' ')]);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('แจ้งรหัสการจองกับทีมงาน'), findsOneWidget);
      expect(find.text('LLK-REF-0001'), findsOneWidget);
    });

    testWidgets('หลายทริป — ทริปที่ใกล้สุดก่อน และสลับดูใบอื่นได้', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        bookings: [
          booking(id: 2, departInDays: 20, title: 'ดอยหลวงเชียงดาว'),
          booking(id: 1, departInDays: 1, title: 'ภูกระดึง'),
          booking(id: 3, status: 'cancelled', title: 'ยกเลิกแล้ว'),
        ],
      );
      expect(tester.takeException(), isNull);
      // ชิปเลือกทริป 2 อัน (ใบที่ยกเลิกไม่นับ) ใบแรกที่โชว์คือทริปพรุ่งนี้
      expect(find.text('ยกเลิกแล้ว'), findsNothing);
      expect(find.text('LLK-REF-0001'), findsOneWidget);
      expect(find.text('LLK-REF-0002'), findsNothing);

      await tester.tap(find.text('ดอยหลวงเชียงดาว').first);
      await tester.pumpAndSettle();
      expect(find.text('LLK-REF-0002'), findsOneWidget);
      expect(find.text('LLK-REF-0001'), findsNothing);
    });

    testWidgets('ถามสถานะสดหลังเปิด — ถูกสแกนไปแล้วก็สลับเป็นเช็คอินแล้ว', (
      tester,
    ) async {
      final requested = <String>[];
      await http.runWithClient(
        () async {
          await pumpSheet(tester, bookings: [booking(id: 1)]);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          requested.add(request.url.path);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': booking(id: 1, checkedIn: true),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      expect(requested.single, endsWith('/bookings/LLK-REF-0001'));
      expect(find.text('เช็คอินแล้ว'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('ไม่มีสัญญาณ — QR ในเครื่องยังอยู่ ไม่มี error', (
      tester,
    ) async {
      await http.runWithClient(
        () async {
          await pumpSheet(tester, bookings: [booking(id: 1)]);
          await tester.pump(const Duration(seconds: 10));
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          throw http.ClientException('offline');
        }),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });
}
