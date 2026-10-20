import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import '../config/api_config.dart';

/// ตัวโหลด tile ตัวเดียวของทั้งแอป
///
/// ห้ามสร้าง `NetworkTileProvider()` ใน build — มันสร้าง HTTP client ใหม่ทุกครั้ง
/// แล้วไม่มีใครปิดตัวเก่า (TileLayer ปิดแค่ตัวล่าสุดตอน dispose) จอติดตามรถที่
/// rebuild ทุกเฟรมตอนหมุดรถเลื่อนเคยสะสม client + socket ค้างจนแอปค้างแล้วเด้ง
/// หลังเปิดไว้สักพัก — client ที่ส่งเข้าไปเองจะไม่ถูก TileLayer ปิด จึงใช้ร่วมกันได้
/// ตลอดอายุแอป
final TileProvider _sharedTileProvider = NetworkTileProvider(
  headers: ApiConfig.mapTileHeaders,
  httpClient: RetryClient(http.Client()),
);

/// ชั้นแผนที่พื้นหลัง (CARTO) ที่ทุกแผนที่ OSM ในแอปใช้
TileLayer appTileLayer() => TileLayer(
  urlTemplate: ApiConfig.mapTileUrl,
  tileProvider: _sharedTileProvider,
  userAgentPackageName: 'com.luilaykhao.app',
);
