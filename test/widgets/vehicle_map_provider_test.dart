import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:luilaykhao_app/config/api_config.dart';
import 'package:luilaykhao_app/models/tracking_model.dart';
import 'package:luilaykhao_app/screens/tracking_screen.dart';
import 'package:luilaykhao_app/widgets/google_vehicle_map.dart';

/// จอติดตามรถต้องเลือกแผนที่ตามว่ามีคีย์ Google หรือไม่ — รันเทสต์นี้ทั้งแบบ
/// ไม่ใส่คีย์ (ได้ OSM) และแบบ --dart-define=GOOGLE_MAPS_API_KEY=xxx (ได้ Google)
void main() {
  testWidgets('picks the map provider that matches the configured key',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VehicleMapWidget(
            tracking: null,
            booking: null,
            customerLocation: const LatLng(13.7563, 100.5018),
            routePoints: const [],
            scheduleRoute: null,
            phase: TrackingPhase.far,
            pulse: const AlwaysStoppedAnimation<double>(1),
            mode: FollowMode.me,
            onUserGesture: () {},
          ),
        ),
      ),
    );

    if (ApiConfig.useGoogleMaps) {
      expect(find.byType(GoogleVehicleMap), findsOneWidget);
      expect(find.byType(gmaps.GoogleMap), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    } else {
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(gmaps.GoogleMap), findsNothing);
    }
  });
}
