import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/share_card.dart';
import 'app_snack.dart';
import 'trip_story_card.dart';

/// Bottom sheet ที่พรีวิว [TripStoryCard] แล้วส่งออกเป็น PNG 1080×1920
///
/// เปิดด้วย [showTripStoryShareSheet] เสมอ อย่าเรียก showModalBottomSheet เอง
/// เพราะตัวช่วยนั้นโหลดรูปปกให้เสร็จก่อนเปิด ซึ่งเป็นเงื่อนไขที่ทำให้ภาพที่จับ
/// ได้มีรูปจริงไม่ใช่ช่องว่าง
class TripStoryShareSheet extends StatefulWidget {
  final String tripTitle;
  final String location;
  final DateTime? departureDate;
  final int? daysLeft;
  final ImageProvider? coverImage;

  /// เลขที่จอง ใช้ *เฉพาะ* ขอลิงก์การ์ดสาธารณะจาก API — ไม่เคยถูกวาดลงการ์ด
  final String? bookingRef;

  const TripStoryShareSheet({
    super.key,
    required this.tripTitle,
    required this.location,
    required this.departureDate,
    required this.daysLeft,
    this.coverImage,
    this.bookingRef,
  });

  @override
  State<TripStoryShareSheet> createState() => _TripStoryShareSheetState();
}

class _TripStoryShareSheetState extends State<TripStoryShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;
  String? _shareUrl;

  @override
  void initState() {
    super.initState();
    _loadShareUrl();
  }

  /// ลิงก์ท้ายการ์ดเป็นของแถม ไม่ใช่เงื่อนไขของการแชร์ — โหลดไม่ได้ก็แค่ไม่มี
  /// บล็อก QR ผู้ใช้ยังแชร์การ์ดได้ตามปกติ
  ///
  /// เลือกลิงก์การ์ดสาธารณะ (/s/{token}) ก่อนเสมอ เพราะปลายทางมีภาพ OG เป็น
  /// การ์ดใบเดียวกัน พอโพสต์ลงฟีดแล้วพรีวิวจึงขึ้นเป็นรูป ไม่ใช่กล่องเปล่า
  /// ตกมาที่ลิงก์ชวนเพื่อนเมื่อขอลิงก์การ์ดไม่ได้ (เช่น การจองยังไม่ยืนยัน)
  Future<void> _loadShareUrl() async {
    final app = context.read<AppProvider>();
    final ref = widget.bookingRef;

    if (ref != null && ref.isNotEmpty) {
      try {
        final url = await app.fetchBookingStoryLink(ref);
        if (!mounted) return;

        if (url != null) {
          setState(() => _shareUrl = url);
          return;
        }
      } catch (_) {
        // ตกไปใช้ลิงก์ชวนเพื่อนด้านล่าง
      }
    }

    try {
      final referral = await app.fetchReferral();
      if (!mounted) return;

      final url = referral['share_url']?.toString();
      if (url != null && url.isNotEmpty) {
        setState(() => _shareUrl = url);
      }
    } catch (_) {
      // เงียบไว้ตั้งใจ — ดูหัวข้อคอมเมนต์ด้านบน
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);

    try {
      // การ์ดเพิ่งเปลี่ยนรูปร่างถ้า QR โผล่มาระหว่างนี้ — รอให้เฟรมล่าสุดวาดจบ
      // ก่อนจับภาพ ไม่งั้นได้ภาพของเลย์เอาต์เก่า
      await WidgetsBinding.instance.endOfFrame;

      await shareWidgetAsPng(
        boundaryKey: _cardKey,
        fileName: 'luilaykhao_countdown.png',
        text: _shareText(),
      );
    } on ShareCardException {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } catch (_) {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// คำบรรยายที่ติดไปกับรูป — บางแอป (IG Story) ทิ้งไป บางแอป (LINE, FB) ใช้
  /// จึงต้องอ่านรู้เรื่องด้วยตัวเองโดยไม่ต้องเห็นรูป
  String _shareText() {
    final days = widget.daysLeft;
    final lead = switch (days) {
      null => 'ทริปต่อไปของฉัน',
      < 0 => 'กำลังลุย "${widget.tripTitle}"',
      0 => 'วันนี้ออกเดินทางไป "${widget.tripTitle}" แล้ว',
      1 => 'พรุ่งนี้ไป "${widget.tripTitle}" แล้ว',
      _ => 'อีก $days วันจะได้ไป "${widget.tripTitle}"',
    };

    final url = _shareUrl;

    return '$lead กับ ลุยเลเขา 🏔️'
        '${url == null ? '' : '\nมาลุยด้วยกันไหม? $url'}'
        '\n#ลุยเลเขา';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppTheme.mutedText(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            // การ์ดวาดที่ 360×640 เสมอเพื่อให้ PNG ออกมา 1080×1920 เท่ากันทุก
            // เครื่อง ส่วน FittedBox แค่ย่อ *ตอนแสดงผล* ให้พอดีจอ — RepaintBoundary
            // จับภาพตามขนาด layout ของตัวเอง ไม่ใช่ขนาดที่ถูกย่อ
            Flexible(
              child: FittedBox(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: TripStoryCard(
                    tripTitle: widget.tripTitle,
                    location: widget.location,
                    departureDate: widget.departureDate,
                    daysLeft: widget.daysLeft,
                    coverImage: widget.coverImage,
                    shareUrl: _shareUrl,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sharing ? null : _share,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(
                  _sharing ? 'กำลังเตรียม...' : 'แชร์ลงสตอรี่',
                  style: appFont(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// เปิด sheet แชร์การ์ดนับถอยหลัง
///
/// โหลดรูปปกให้เข้าแคชก่อนเปิด sheet เพราะ `RenderRepaintBoundary.toImage`
/// จับเฉพาะสิ่งที่วาดแล้วจริง ๆ — รูปที่ยังโหลดไม่เสร็จจะกลายเป็นช่องว่างใน PNG
/// โดยไม่มีข้อผิดพลาดใด ๆ ให้จับได้
Future<void> showTripStoryShareSheet(
  BuildContext context, {
  required String tripTitle,
  required String location,
  required DateTime? departureDate,
  required int? daysLeft,
  String? coverImageUrl,
  String? bookingRef,
}) async {
  ImageProvider? cover;

  if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
    cover = NetworkImage(coverImageUrl);
    try {
      await precacheImage(cover, context);
    } catch (_) {
      // รูปโหลดไม่ได้ (ออฟไลน์ / ไฟล์หาย) — การ์ดมีพื้นหลังไล่เฉดรองรับอยู่แล้ว
      cover = null;
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => TripStoryShareSheet(
      tripTitle: tripTitle,
      location: location,
      departureDate: departureDate,
      daysLeft: daysLeft,
      coverImage: cover,
      bookingRef: bookingRef,
    ),
  );
}
