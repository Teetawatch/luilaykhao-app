import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tracking_model.dart';
import '../theme/app_theme.dart';

/// "คันไหนคือคันของเรา" — การ์ดที่ขึ้นเฉพาะตอนที่คำถามนี้เกิดขึ้นจริง
///
/// ตอนรถยังอยู่ไกล คำถามคือ "อีกนานไหม" ซึ่ง [RightNowCard] ตอบอยู่แล้ว แต่พอรถ
/// จอดแล้วคำถามเปลี่ยนเป็น "คันไหน" ทันที และลานจอดของจุดรับส่วนใหญ่มีรถตู้สีขาว
/// จอดเรียงกันสิบคัน ทะเบียนตัวเล็ก ๆ ในการ์ดที่ต้องเลื่อนหาจึงตอบไม่ทัน
///
/// สิ่งที่การ์ดนี้ให้ เรียงตามที่ตาคนใช้จริง: ทะเบียนตัวใหญ่ที่อ่านได้จากสิบเมตร
/// → สีและรูปรถคันจริง → รูปตรงที่รถจอดซึ่งสตาฟถ่ายให้ → ปุ่มโทรหาคนขับ
class FindMyVanCard extends StatelessWidget {
  final BookingInfo booking;

  /// รถจอดถึงที่แล้วหรือกำลังจะถึงในไม่กี่นาที — ตัวการ์ดไม่คำนวณเอง เพราะ
  /// หน้าจอที่เรียกมันรู้ ETA อยู่แล้ว
  final bool imminent;

  const FindMyVanCard({
    super.key,
    required this.booking,
    this.imminent = false,
  });

  String get _plate => (booking.licensePlate ?? '').trim();
  String get _colour => (booking.vehicleColor ?? '').trim();
  String get _vehicleName => (booking.vehicleName ?? '').trim();
  String get _parkingNote => (booking.pickupArrivalNote ?? '').trim();
  String get _parkingPhoto => (booking.pickupArrivalPhotoUrl ?? '').trim();
  String get _vehiclePhoto => (booking.vehiclePhotoUrl ?? '').trim();
  String get _driverPhone => (booking.driverPhone ?? '').trim();

  /// ไม่มีทะเบียนก็ไม่มีอะไรจะช่วยหารถ — ซ่อนตัวเองดีกว่าขึ้นกรอบเปล่า
  bool get _worthShowing =>
      _plate.isNotEmpty && (booking.vanIsHere || imminent) && !booking.isFlight;

  Future<void> _callDriver() async {
    if (_driverPhone.isEmpty) return;
    HapticFeedback.selectionClick();
    final uri = Uri.parse('tel:$_driverPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (!_worthShowing) return const SizedBox.shrink();

    final here = booking.vanIsHere;
    final tone = here ? AppTheme.primaryColor : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus_filled_rounded, size: 18, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  here ? 'รถของคุณจอดรออยู่แล้ว' : 'มองหารถคันนี้ได้เลย',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ทะเบียน — ตัวใหญ่ที่สุดบนการ์ด เพราะเป็นสิ่งเดียวที่ยืนยันได้จริง
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      _plate,
                      style: appFont(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1.1,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    if (_vehicleName.isNotEmpty || _colour.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (_vehicleName.isNotEmpty) _vehicleName,
                            if (_colour.isNotEmpty) 'สี$_colour',
                          ].join(' · '),
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_vehiclePhoto.isNotEmpty) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: CachedNetworkImage(
                    imageUrl: _vehiclePhoto,
                    width: 92,
                    height: 62,
                    fit: BoxFit.cover,
                    memCacheWidth: 280,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),

          // รูปจุดจอดจากสตาฟ — สิ่งที่พิกัดบอกไม่ได้: จอดข้างร้านไหน หันหัวทางไหน
          if (_parkingPhoto.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openPhoto(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: _parkingPhoto,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  memCacheWidth: 900,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],

          if (_parkingNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 15,
                  color: AppTheme.mutedText(context),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _parkingNote,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_driverPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _callDriver,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tone,
                  side: BorderSide(color: tone.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.phone_rounded, size: 17),
                label: Text(
                  (booking.driverName ?? '').trim().isEmpty
                      ? 'โทรหาคนขับ'
                      : 'โทรหา${booking.driverName!.trim()}',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ดูรูปจุดจอดเต็มจอ — ในลานจอดจริงรายละเอียดเล็ก ๆ (ป้ายร้าน เสาไฟ) คือตัวชี้
  void _openPhoto(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              'จุดที่รถจอด',
              style: appFont(
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: CachedNetworkImage(imageUrl: _parkingPhoto),
            ),
          ),
        ),
      ),
    );
  }
}
