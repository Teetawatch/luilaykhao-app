import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/customer_app_screen.dart';
import 'package:provider/provider.dart';

/// หน้า "การจองของฉัน" ต้องเรนเดอร์ได้จริงกับข้อมูลที่ API ส่งมาจริง ๆ
/// (build ที่ throw จะกลายเป็นหน้าเปล่าสีเทาใน release build โดยไม่มีข้อความบอก)
void main() {
  // แอปจริงเรียกใน main() — เทสต์ต้องเตรียมเองไม่งั้น DateFormat('th_TH') โยน
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  Map<String, dynamic> booking({
    required String status,
    String? slipOcrStatus,
    String? expiresAt,
    String departureDate = '2099-01-10',
    int passengerCount = 1,
    bool viewerIsOwner = false,
    String title = 'ภูกระดึง',
    bool canReview = false,
    num? paidAmount,
    int id = 1,
  }) {
    return {
      'id': id,
      'booking_ref': 'LLK-20990110-000$id',
      'status': status,
      'viewer_is_owner': viewerIsOwner,
      'slip_ocr_status': slipOcrStatus,
      'expires_at': expiresAt,
      'can_review': canReview,
      'payment_type': 'full',
      'total_amount': 3500,
      'paid_amount': paidAmount ?? (status == 'confirmed' ? 3500 : 0),
      'created_at': '2026-08-04T10:00:00.000000Z',
      'passengers': [
        for (var i = 0; i < passengerCount; i++)
          {'name': 'ผู้เดินทาง ${i + 1}', 'nickname': 'ต้น'},
      ],
      'schedule': {
        'id': 5,
        'departure_date': departureDate,
        'return_date': departureDate,
        'trip': {'id': 2, 'title': title, 'location': 'เลย', 'slug': 'phu'},
        'pickup_points': const [],
        'travelers': const [],
      },
    };
  }

  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> data) async {
    final provider = AppProvider();
    provider.api.token = 'test-token';
    provider.bookings = data;
    provider.accountLoaded = true;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(home: MyBookingsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders a confirmed upcoming booking', (tester) async {
    await pump(tester, [booking(status: 'confirmed')]);
    expect(tester.takeException(), isNull);
    expect(find.text('ภูกระดึง'), findsWidgets);
  });

  testWidgets('renders an unpaid booking with its expiry countdown', (
    tester,
  ) async {
    await pump(tester, [
      booking(
        status: 'pending',
        expiresAt: DateTime.now()
            .add(const Duration(minutes: 7))
            .toIso8601String(),
      ),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('ก่อนที่นั่งถูกคืน'), findsOneWidget);
  });

  testWidgets('renders a booking whose slip is under review', (tester) async {
    await pump(tester, [
      booking(status: 'pending', slipOcrStatus: 'pending_review'),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('รอทีมงานตรวจสอบ'), findsOneWidget);
  });

  testWidgets('renders a finished trip as a compact history row', (
    tester,
  ) async {
    await pump(tester, [
      booking(status: 'completed', departureDate: '2020-01-10'),
    ]);
    expect(tester.takeException(), isNull);
  });

  // ทริปที่จบแล้วแต่ยังรีวิวได้ เคยแสดงเป็นการ์ดเต็มใบ ทำให้ลิสต์ "เดินทางแล้ว"
  // มีการ์ดใหญ่ปนแถวย่อ — ตอนนี้ย่อเท่ากันหมดเหมือนรายการที่ยกเลิก
  testWidgets('ทริปที่จบแล้วซึ่งยังรีวิวได้ ก็ย่อเป็นแถวเดียว', (tester) async {
    await pump(tester, [
      booking(
        status: 'confirmed',
        departureDate: '2020-01-10',
        canReview: true,
      ),
    ]);

    expect(tester.takeException(), isNull);
    // ปุ่มรีวิวยังอยู่ แต่เป็นชิปบนแถว ไม่ใช่ปุ่มเต็มความกว้างของการ์ดใหญ่
    expect(find.text('รีวิว'), findsOneWidget);
    expect(find.text('รีวิวทริปนี้'), findsNothing);
    expect(find.text('ดูรายละเอียดการเดินทาง'), findsNothing);
  });

  testWidgets('ลิสต์ "เดินทางแล้ว" สูงเท่ากันทุกใบ', (tester) async {
    await pump(tester, [
      booking(
        id: 1,
        status: 'confirmed',
        departureDate: '2020-01-10',
        canReview: true,
      ),
      booking(
        id: 2,
        status: 'completed',
        departureDate: '2020-02-10',
        title: 'เขาช้างเผือก',
      ),
    ]);

    expect(tester.takeException(), isNull);
    // การ์ดการจองทุกใบในหน้านี้ห่อด้วย _PressableCard (AnimatedScale)
    final heights = find
        .byType(AnimatedScale)
        .evaluate()
        .map((element) => element.size!.height)
        .toSet();
    expect(heights.length, 1);
  });

  testWidgets('แตะชิปรีวิวแล้วเปิดหน้าต่างรีวิวได้จริง', (tester) async {
    await pump(tester, [
      booking(
        status: 'confirmed',
        departureDate: '2020-01-10',
        canReview: true,
      ),
    ]);

    await tester.tap(find.text('รีวิว'));
    await tester.pumpAndSettle();

    expect(find.text('ทริปนี้เป็นยังไงบ้าง?'), findsOneWidget);
  });

  // ยกเลิกแล้วแต่จ่ายเงินไปแล้ว ยังต้องติดตามเงินคืน จึงไม่ใช่ประวัติที่ปิดจบ
  testWidgets('รายการยกเลิกที่จ่ายเงินไปแล้ว ยังเป็นการ์ดเต็ม', (tester) async {
    await pump(tester, [
      booking(
        status: 'cancelled',
        departureDate: '2020-01-10',
        paidAmount: 3500,
      ),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('ดูตั๋ว & รายละเอียด'), findsOneWidget);
  });

  testWidgets('renders a cancelled booking', (tester) async {
    await pump(tester, [
      booking(status: 'cancelled', departureDate: '2020-01-10'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders past, upcoming and cancelled together', (tester) async {
    await pump(tester, [
      booking(status: 'confirmed'),
      booking(status: 'pending'),
      booking(status: 'completed', departureDate: '2020-01-10'),
      booking(status: 'cancelled', departureDate: '2021-01-10'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the extras a booking can carry', (tester) async {
    final withExtras = booking(status: 'confirmed')
      ..addAll({
        'split': {'enabled': true, 'total_shares': 4, 'paid_shares': 2},
        'flexi_surcharge': 500,
        'selected_rentals': [
          {'name': 'เต็นท์', 'quantity': 1},
        ],
        'selected_addons': [
          {'name': 'อาหารเจ', 'quantity': 2},
        ],
        'is_gift': true,
        'gift': {'claimed': false},
        'custom_pickup': {
          'status': 'rejected',
          'label': 'หน้าปากซอย',
          'reject_reason': 'อยู่นอกเส้นทาง',
        },
      });

    await pump(tester, [withExtras]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('แบ่งจ่าย 2/4 คน'), findsOneWidget);
    expect(find.textContaining('จุดรับที่ขอไว้ถูกปฏิเสธ'), findsOneWidget);
  });

  // การเชิญเพื่อนเคยซ่อนอยู่ท้ายชีตรายละเอียด คนส่วนใหญ่จึงไม่รู้ว่ามี —
  // ตอนนี้มีทางเข้าพร้อมคำอธิบายอยู่บนการ์ดการจองของเจ้าของเอง
  testWidgets('เจ้าของการจองแบบหลายคนเห็นทางเข้า "เชิญเพื่อนร่วมทริป"', (
    tester,
  ) async {
    await pump(tester, [
      booking(status: 'confirmed', passengerCount: 2, viewerIsOwner: true),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('เชิญเพื่อนร่วมทริป'), findsOneWidget);
    expect(
      find.text('ให้เพื่อนเข้าแชทกลุ่มและติดตามรถได้ ไม่ต้องจองใหม่'),
      findsOneWidget,
    );
  });

  testWidgets('การจองที่นั่งเดียว/ไม่ใช่เจ้าของ ไม่ขึ้นทางเข้าเชิญเพื่อน', (
    tester,
  ) async {
    await pump(tester, [
      booking(status: 'confirmed', passengerCount: 1, viewerIsOwner: true),
    ]);
    expect(find.text('เชิญเพื่อนร่วมทริป'), findsNothing);

    await pump(tester, [
      booking(status: 'confirmed', passengerCount: 3, viewerIsOwner: false),
    ]);
    expect(find.text('เชิญเพื่อนร่วมทริป'), findsNothing);
  });

  testWidgets('ปุ่มมุมขวาบนบอกชัดว่าใช้ใส่รหัสคำเชิญที่เพื่อนส่งมา', (
    tester,
  ) async {
    await pump(tester, [booking(status: 'confirmed')]);

    expect(tester.takeException(), isNull);
    expect(find.text('ใส่รหัสคำเชิญ'), findsOneWidget);
  });

  // รอบเดิมโดนน้ำป่า (วันที่ผ่านไปแล้ว) — ต้องไม่กลายเป็น "ทริปที่จบแล้ว"
  // แต่เป็นการ์ดเต็มที่บอกให้เลือกรอบใหม่
  Map<String, dynamic> postponed({bool canChoose = true, bool owner = true}) {
    return booking(
      status: 'confirmed',
      departureDate: '2020-01-10',
      passengerCount: 2,
      viewerIsOwner: owner,
    )..addAll({
        'can_reschedule': canChoose,
        'reschedule_mode': 'force_majeure',
        'reschedule_latest_departure': '2099-07-10',
        'force_majeure': {
          'reason': 'น้ำป่าไหลหลาก',
          'original_departure_label': '10 มกราคม 2563',
          'until': '2099-07-10',
          'until_label': '10 กรกฎาคม 2642',
          'awaiting': true,
          'can_choose': canChoose,
          'expired': !canChoose,
          'days_left': canChoose ? 30 : -1,
          'resolved_at': null,
        },
      });
  }

  testWidgets('รอบที่ถูกเลื่อนเพราะเหตุสุดวิสัย เป็นการ์ดเต็มให้เลือกรอบใหม่', (
    tester,
  ) async {
    await pump(tester, [postponed()]);

    expect(tester.takeException(), isNull);
    expect(find.text('รอเลือกรอบใหม่'), findsWidgets);
    expect(find.textContaining('เลือกรอบใหม่ได้ฟรีถึง 10 กรกฎาคม 2642'), findsOneWidget);
    expect(find.text('เลือกรอบใหม่'), findsOneWidget);
    // ไม่ใช่ทริปที่จบไปแล้ว
    expect(find.text('ยินดีที่ได้พบกันครับ'), findsNothing);
  });

  testWidgets('เพื่อนร่วมทริปไม่เห็นปุ่มเลือกรอบ (ผู้จองเป็นคนเลือก)', (
    tester,
  ) async {
    await pump(tester, [postponed(owner: false)]);

    expect(tester.takeException(), isNull);
    expect(find.text('เลือกรอบใหม่'), findsNothing);
  });

  testWidgets('เลยกำหนดเลือกรอบแล้ว บอกให้ทักทีมงาน', (tester) async {
    await pump(tester, [postponed(canChoose: false)]);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('เลยกำหนดเลือกรอบใหม่แล้ว'), findsOneWidget);
    expect(find.text('เลือกรอบใหม่'), findsNothing);
  });

  // รอบไม่ได้ออกเพราะผู้ร่วมทริปไม่ครบ — เลือกรอบใหม่ หรือรับเงินคืนเต็มจำนวน
  Map<String, dynamic> underfilled({bool canChoose = true, bool owner = true}) {
    final b = postponed(canChoose: canChoose, owner: owner);
    b['force_majeure'] = {
      ...Map<String, dynamic>.from(b['force_majeure'] as Map),
      'kind': 'underfilled',
      'state': 'awaiting',
      'reason': 'ผู้ร่วมเดินทางไม่ครบตามจำนวนขั้นต่ำ',
      'decide_by': '2099-01-24',
      'decide_by_label': '24 มกราคม 2642',
      'can_request_refund': true,
      'refund_amount': 3500,
      'refund_banks': ['พร้อมเพย์', 'กสิกรไทย'],
    };
    return b;
  }

  testWidgets('รอบคนไม่ครบ บอกทางเลือกคืนเงินและกำหนดตัดสินใจ ไม่พูดถึงเหตุสุดวิสัย', (
    tester,
  ) async {
    await pump(tester, [underfilled()]);

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('เลือกรอบใหม่ฟรีหรือรับเงินคืน ภายใน 24 มกราคม 2642'),
      findsOneWidget,
    );
    expect(find.textContaining('เลือกรอบใหม่ได้ฟรีถึง'), findsNothing);
    expect(find.byIcon(Icons.thunderstorm_rounded), findsNothing);
    expect(find.text('เลือกรอบใหม่'), findsOneWidget);
    expect(find.text('ขอคืนเงิน'), findsOneWidget);
  });

  testWidgets('กดขอคืนเงินแล้วเปิดฟอร์มบัญชี ปุ่มยืนยันกดไม่ได้จนกรอกครบ', (
    tester,
  ) async {
    // จอสูงพอให้ทั้งการ์ดและชีตอยู่ในจอ (ค่าตั้งต้น 800x600 เตี้ยเกิน)
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, [underfilled()]);

    await tester.ensureVisible(find.text('ขอคืนเงิน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ขอคืนเงิน'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ขอรับเงินคืนเต็มจำนวน'), findsOneWidget);
    expect(find.textContaining('฿3,500'), findsWidgets);

    ButtonStyleButton? submit() {
      final finder = find.ancestor(
        of: find.text('ยกเลิกและขอรับเงินคืน'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      final widgets = finder
          .evaluate()
          .map((e) => e.widget)
          .whereType<ButtonStyleButton>();
      return widgets.isEmpty ? null : widgets.first;
    }

    expect(submit()?.onPressed, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('กสิกรไทย').last);
    await tester.pumpAndSettle();
    expect(find.text('กสิกรไทย'), findsOneWidget); // เลือกแล้วเมนูปิด เหลือค่าในช่อง
    await tester.enterText(find.widgetWithText(TextField, 'เลขบัญชี'), '123-4-56789-0');
    expect(submit()?.onPressed, isNull); // ยังไม่มีชื่อบัญชี
    await tester.enterText(find.widgetWithText(TextField, 'ชื่อบัญชี'), 'สมชาย ใจดี');
    await tester.pump();

    expect(submit()?.onPressed, isNotNull);
  });

  testWidgets('รอบคนไม่ครบที่เลยกำหนด ยังกรอกบัญชีรับเงินคืนได้', (tester) async {
    await pump(tester, [underfilled(canChoose: false)]);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('เลยกำหนดเลือกรอบแล้ว เราจะคืนเงินให้'), findsOneWidget);
    expect(find.text('เลือกรอบใหม่'), findsNothing);
    expect(find.text('ขอคืนเงิน'), findsOneWidget);
  });

  testWidgets('renders the empty state for someone with no bookings', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.text('ยังไม่มีการจอง'), findsOneWidget);
  });

  testWidgets('renders the error state when the load failed', (tester) async {
    final provider = AppProvider();
    provider.api.token = 'test-token';
    provider.accountLoaded = true;
    provider.accountError = 'เชื่อมต่อไม่ได้';

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(home: MyBookingsScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('โหลดการจองไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
  });

  // ประวัติโหลดทีละหน้า — ตัวเลขบนแท็บต้องนับทั้งชุดจากเซิร์ฟเวอร์ ไม่ใช่แค่ที่โหลดมา
  testWidgets('tab counts include history pages that are not loaded yet', (
    tester,
  ) async {
    final provider = AppProvider();
    provider.api.token = 'test-token';
    provider.accountLoaded = true;
    provider.debugApplyBookingsFirstPage(
      current: [booking(status: 'confirmed', id: 1)],
      history: [
        booking(status: 'confirmed', departureDate: '2020-01-10', id: 2),
        booking(status: 'cancelled', departureDate: '2020-02-10', id: 3),
      ],
      historyMeta: {
        'current_page': 1,
        'last_page': 4,
        'history_count': 70,
        'travelled_count': 60,
        'cancelled_count': 10,
        'destinations_count': 9,
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(home: MyBookingsScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('ทั้งหมด 71'), findsOneWidget);
    expect(find.text('กำลังจะถึง 1'), findsOneWidget);
    expect(find.text('เดินทางแล้ว 60'), findsOneWidget);
    expect(find.text('ยกเลิก 10'), findsOneWidget);

    // ไม่เลื่อนจอ — การเลื่อนจะสั่งโหลดหน้าถัดไปจริง
    expect(
      find.text('ดูรายการก่อนหน้า', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('no load-more footer once every page is in', (tester) async {
    final provider = AppProvider();
    provider.api.token = 'test-token';
    provider.accountLoaded = true;
    provider.debugApplyBookingsFirstPage(
      current: [booking(status: 'confirmed', id: 1)],
      history: [booking(status: 'confirmed', departureDate: '2020-01-10', id: 2)],
      historyMeta: {
        'current_page': 1,
        'last_page': 1,
        'history_count': 1,
        'travelled_count': 1,
        'cancelled_count': 0,
      },
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(home: MyBookingsScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('ทั้งหมด 2'), findsOneWidget);
    expect(
      find.text('ดูรายการก่อนหน้า', skipOffstage: false),
      findsNothing,
    );
  });
}
