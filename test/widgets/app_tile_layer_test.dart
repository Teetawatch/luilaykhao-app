import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/app_tile_layer.dart';

/// จอติดตามรถเคยค้างแล้วเด้งหลังเปิดไว้สักพัก เพราะทุกเฟรมที่หมุดรถเลื่อนสร้าง
/// NetworkTileProvider (= HTTP client) ใหม่ที่ไม่มีใครปิด
void main() {
  test('every map shares one tile provider', () {
    expect(
      identical(appTileLayer().tileProvider, appTileLayer().tileProvider),
      isTrue,
    );
  });

  test('no screen builds its own NetworkTileProvider', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('app_tile_layer.dart'))
        .where((f) => f.readAsStringSync().contains('NetworkTileProvider('))
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty, reason: 'ใช้ appTileLayer() แทน');
  });
}
