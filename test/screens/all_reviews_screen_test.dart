import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:luilaykhao_app/providers/app_provider.dart';
import 'package:luilaykhao_app/screens/trip_detail_screen.dart';
import 'package:provider/provider.dart';

class _FakeApp extends AppProvider {
  final List<({int? rating, bool media, int page})> calls = [];
  Map<String, dynamic>? stats;
  bool statsFail = false;
  List<Map<String, dynamic>> reviewsList = [];

  @override
  Future<({List<dynamic> items, bool hasMore, int total})> allReviewsPage({
    int page = 1,
    int perPage = 12,
    int? rating,
    bool withMedia = false,
  }) async {
    calls.add((rating: rating, media: withMedia, page: page));
    final items = reviewsList.where((r) {
      if (rating != null && r['rating'] != rating) return false;
      if (withMedia && (r['images'] as List? ?? const []).isEmpty) return false;
      return true;
    }).toList();
    return (items: items, hasMore: false, total: items.length);
  }

  @override
  Future<Map<String, dynamic>> reviewStats() async {
    if (statsFail) throw Exception('offline');
    return stats ?? {};
  }
}

Map<String, dynamic> _review(
  int id,
  int rating, {
  String comment = 'ทีมงานดูแลดีมาก',
  List<String> images = const [],
  String? reply,
}) => {
  'id': id,
  'user_id': 100 + id,
  'rating': rating,
  'comment': comment,
  'images': images,
  'videos': const [],
  'admin_reply': reply,
  'user': {'name': 'ลูกทริป $id'},
  'trip_title': 'ภูกระดึง 3 วัน 2 คืน',
  'trip_slug': 'phu-kradueng',
  'created_at': DateTime.now()
      .subtract(const Duration(days: 2))
      .toIso8601String(),
};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
    // ฟอนต์จริงของแอป — ฟอนต์ทดสอบวาดอักษรไทยกว้างเกินจริง เช็คล้นไม่ได้
    Future<void> load(String family, List<String> assets) async {
      final loader = FontLoader(family);
      for (final asset in assets) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }

    await load('Inter', ['assets/fonts/Inter-Variable.ttf']);
    await load('LINE Seed Sans TH', [
      'assets/fonts/LINESeedSansTH_A_Rg.ttf',
      'assets/fonts/LINESeedSansTH_A_Bd.ttf',
    ]);
  });

  late _FakeApp app;

  setUp(() {
    app = _FakeApp()
      ..stats = {
        'total': 3,
        'average': 4.33,
        'distribution': {'5': 2, '4': 0, '3': 1, '2': 0, '1': 0},
        'with_media': 1,
        'categories': {
          'guide': {'average': 4.5, 'count': 2},
          'vehicle': {'average': null, 'count': 0},
          'food': {'average': 4.0, 'count': 1},
          'value': {'average': null, 'count': 0},
        },
      }
      ..reviewsList = [
        _review(1, 5, images: ['a.jpg'], reply: 'ขอบคุณที่ไปด้วยกันครับ'),
        _review(2, 5),
        _review(3, 3, comment: 'ทางชันกว่าที่คิด'),
      ];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: const MaterialApp(home: AllReviewsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the overview, the team reply and the trip of each review', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('3 รีวิว'), findsOneWidget);
    // Only categories somebody actually scored get a tile.
    expect(find.text('ไกด์'), findsOneWidget);
    expect(find.text('อาหาร'), findsOneWidget);
    expect(find.text('การเดินทาง'), findsNothing);

    expect(find.text('ตอบกลับจากทีมงาน'), findsOneWidget);
    expect(find.text('ขอบคุณที่ไปด้วยกันครับ'), findsOneWidget);
    expect(find.text('ภูกระดึง 3 วัน 2 คืน'), findsNWidgets(3));
    expect(find.text('รีวิวล่าสุด'), findsOneWidget);
  });

  testWidgets('tapping a star row filters to it, tapping again clears', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('กรองรีวิว 3 ดาว มี 1 รายการ'));
    await tester.pumpAndSettle();
    expect(app.calls.last, (rating: 3, media: false, page: 1));
    expect(find.text('รีวิว 3 ดาว'), findsOneWidget);
    expect(find.text('ทางชันกว่าที่คิด'), findsOneWidget);
    expect(find.text('ลูกทริป 1'), findsNothing);

    await tester.tap(find.bySemanticsLabel('กรองรีวิว 3 ดาว มี 1 รายการ'));
    await tester.pumpAndSettle();
    expect(app.calls.last, (rating: null, media: false, page: 1));
  });

  testWidgets('the photo chip asks the server for reviews with media only', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('มีรูป/วิดีโอ'));
    await tester.pumpAndSettle();

    expect(app.calls.last, (rating: null, media: true, page: 1));
    expect(find.text('รีวิวที่มีรูปหรือวิดีโอ'), findsOneWidget);
    expect(find.text('ลูกทริป 1'), findsOneWidget);
    expect(find.text('ลูกทริป 2'), findsNothing);
  });

  testWidgets('an empty filter offers a way back to every review', (
    tester,
  ) async {
    await pump(tester);

    final oneStar = find.bySemanticsLabel('แสดงรีวิว 1 ดาว 0 รายการ');
    await tester.dragUntilVisible(
      oneStar,
      find.byType(ListView).first,
      const Offset(-200, 0),
    );
    await tester.ensureVisible(oneStar);
    await tester.pumpAndSettle();
    await tester.tap(oneStar);
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีรีวิว 1 ดาว'), findsOneWidget);

    await tester.tap(find.text('ดูรีวิวทั้งหมด'));
    await tester.pumpAndSettle();
    expect(find.text('ลูกทริป 1'), findsOneWidget);
  });

  testWidgets('reviews still list when the summary fails to load', (
    tester,
  ) async {
    app.statsFail = true;
    await pump(tester);

    expect(find.text('4.3'), findsNothing);
    expect(find.text('ลูกทริป 1'), findsOneWidget);
    expect(find.text('ทั้งหมด'), findsOneWidget);
  });

  testWidgets('a long review folds behind อ่านต่อ', (tester) async {
    app.reviewsList = [_review(1, 5, comment: List.filled(80, 'สนุกมาก').join(' '))];
    await pump(tester);

    expect(find.text('อ่านต่อ'), findsOneWidget);
    await tester.tap(find.text('อ่านต่อ'));
    await tester.pumpAndSettle();
    expect(find.text('ย่อ'), findsOneWidget);
  });

  testWidgets('a narrow 320pt phone does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: const MaterialApp(home: AllReviewsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
