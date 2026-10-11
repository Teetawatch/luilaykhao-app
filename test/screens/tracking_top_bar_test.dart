import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:luilaykhao_app/models/tracking_model.dart';
import 'package:luilaykhao_app/screens/tracking_screen.dart';

/// แถบบนของหน้าติดตามรถต้องไม่พูดว่า "รถกำลังมาถึง" ในเวลาที่ยังไม่มีพิกัดของ
/// รอบนี้ หรือพิกัดเงียบไปนานแล้ว — ลูกค้าตัดสินใจลงไปยืนรอจากบรรทัดนี้
void main() {
  VehicleTracking tracking() => VehicleTracking(
    vehicleId: 1,
    licensePlate: 'กข 1234',
    driverLocation: const LatLng(18.78, 98.98),
    updatedAt: DateTime.now(),
  );

  Future<void> pump(WidgetTester tester, TrackingTopBar bar) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Stack(children: [bar]))),
    );
  }

  TrackingTopBar bar({
    VehicleTracking? vehicle,
    bool waiting = false,
    Duration? staleAge,
    bool vanIsHere = false,
  }) {
    return TrackingTopBar(
      eta: vehicle == null
          ? null
          : ETAResult.compute(
              from: vehicle.driverLocation,
              to: const LatLng(18.70, 98.98),
              speedKmh: 40,
            ),
      tracking: vehicle,
      onBack: () {},
      onShare: () {},
      waitingForSignal: waiting,
      staleAge: staleAge,
      vanIsHere: vanIsHere,
    );
  }

  testWidgets('no position for this round yet', (tester) async {
    await pump(tester, bar(waiting: true));

    expect(find.text('รถยังไม่เริ่มแชร์ตำแหน่ง'), findsOneWidget);
    expect(find.text('ทีมงานจะเปิดเมื่อใกล้เวลารถออก'), findsOneWidget);
    expect(find.text('รถกำลังมาถึง'), findsNothing);
  });

  testWidgets('a quiet position shows its age instead of an ETA', (
    tester,
  ) async {
    await pump(
      tester,
      bar(vehicle: tracking(), staleAge: const Duration(minutes: 12)),
    );

    expect(find.text('ตำแหน่งรถไม่อัปเดต'), findsOneWidget);
    expect(find.text('อัปเดตล่าสุด 12 นาทีที่แล้ว'), findsOneWidget);
  });

  testWidgets('hours-old position reads in hours', (tester) async {
    await pump(
      tester,
      bar(vehicle: tracking(), staleAge: const Duration(minutes: 65)),
    );

    expect(find.text('อัปเดตล่าสุด 1 ชม. 5 นาทีที่แล้ว'), findsOneWidget);
  });

  testWidgets('fresh position keeps the ETA line', (tester) async {
    await pump(tester, bar(vehicle: tracking()));

    expect(find.text('รถกำลังมาถึง'), findsOneWidget);
    expect(find.textContaining('•'), findsOneWidget);
  });

  testWidgets('staff marking the van arrived wins over a silent GPS', (
    tester,
  ) async {
    await pump(tester, bar(waiting: true, vanIsHere: true));

    expect(find.text('รถถึงจุดรับแล้ว'), findsOneWidget);
    expect(find.text('ดูรถที่จอดรอได้จากการ์ดด้านล่าง'), findsOneWidget);
  });
}
