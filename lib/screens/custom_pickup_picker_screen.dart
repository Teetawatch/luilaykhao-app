import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

/// แผนที่ให้ลูกค้าปักหมุดจุดรับเอง (อยู่ในเส้นทางผ่านที่รับได้)
/// คืนค่า { label, lat, lng, note } เมื่อยืนยัน
class CustomPickupPickerScreen extends StatefulWidget {
  final LatLng center;
  final Map<String, dynamic>? initial;

  const CustomPickupPickerScreen({
    super.key,
    required this.center,
    this.initial,
  });

  @override
  State<CustomPickupPickerScreen> createState() =>
      _CustomPickupPickerScreenState();
}

class _CustomPickupPickerScreenState extends State<CustomPickupPickerScreen> {
  final _mapController = MapController();
  final _label = TextEditingController();
  final _note = TextEditingController();
  // จุดที่เลือก = จุดกึ่งกลางแผนที่เสมอ (หมุดตรึงกลางจอ เลื่อนแผนที่เอาแบบ LINE MAN)
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _center = widget.center;
    if (initial != null) {
      _label.text = initial['label']?.toString() ?? '';
      _note.text = initial['note']?.toString() ?? '';
      final lat = double.tryParse('${initial['lat']}');
      final lng = double.tryParse('${initial['lng']}');
      if (lat != null && lng != null) _center = LatLng(lat, lng);
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _canConfirm => _label.text.trim().isNotEmpty;

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.pop(context, {
      'label': _label.text.trim(),
      'lat': _center.latitude,
      'lng': _center.longitude,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'ปักหมุดจุดรับ',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14.5,
                    minZoom: 5,
                    maxZoom: 18,
                    // หมุดตรึงกลางจอ — จุดที่เลือกคือกึ่งกลางแผนที่ขณะนั้น
                    onPositionChanged: (camera, _) => _center = camera.center,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.luilaykhao.app',
                    ),
                  ],
                ),
                // หมุดคงที่กลางจอ (ปลายหมุดชี้จุดกึ่งกลางพอดี)
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.primaryColor,
                        size: 46,
                        shadows: [
                          Shadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.open_with_rounded,
                            size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'เลื่อนแผนที่ให้หมุดอยู่ตรงจุดที่ต้องการ',
                            style: appFont(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildForm(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border(top: BorderSide(color: AppTheme.border(context))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ระบบจะส่งให้เจ้าหน้าที่ตรวจสอบว่าอยู่ในเส้นทางที่รับได้ แล้วแจ้งค่าบริการกลับไปยืนยันอีกครั้ง',
              style: appFont(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              maxLength: 255,
              onChanged: (_) => setState(() {}),
              style: appFont(fontSize: 14.5, fontWeight: FontWeight.w600),
              decoration: _decoration('ชื่อจุดรับ / จุดสังเกต *',
                  'เช่น ปั๊ม ปตท. ทางเข้าเขาใหญ่'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLength: 1000,
              maxLines: 2,
              minLines: 1,
              style: appFont(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: _decoration('รายละเอียดเพิ่มเติม (ถ้ามี)',
                  'เช่น รอตรงร้านกาแฟหน้าปั๊ม'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canConfirm ? _confirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'ใช้จุดนี้',
                  style: appFont(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      labelStyle: appFont(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
      hintStyle: appFont(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AppTheme.mutedText(context),
      ),
      filled: true,
      fillColor: AppTheme.subtleSurface(context),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
