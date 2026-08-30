/// การ์ดนับถอยหลัง 9:16 สำหรับแชร์ลงสตอรี่ IG / Facebook
///
/// ลูกค้าแคปการ์ด "ทริปของคุณ · อีก N วัน" บนหน้าโฮมไปลงสตอรี่กันเองอยู่แล้ว
/// แต่การ์ดใบนั้นเป็นแนวนอน พอถูกครอปลงกรอบ 9:16 เนื้อหาก็หายไปครึ่งหนึ่ง
/// การ์ดใบนี้จึงจัดองค์ประกอบใหม่ทั้งใบให้เป็นสัดส่วนสตอรี่ตั้งแต่ต้น
///
/// วาดที่ [kStoryCardWidth]×[kStoryCardHeight] หน่วย logical แล้วถูกจับภาพที่
/// [kShareCardPixelRatio] (3.0) → ได้ PNG 1080×1920 พอดีกับที่ IG/FB ต้องการ
///
/// **สิ่งที่จงใจไม่ใส่ในการ์ด: เลขที่จอง**
/// การ์ดใบนี้ถูกสร้างมาเพื่อให้คนแปลกหน้าเห็น การประกาศวันเดินทางก็เท่ากับบอก
/// ว่าบ้านจะว่างวันไหนอยู่แล้ว ไม่มีเหตุผลให้แถมเลขที่จองไปด้วย
library;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

/// ขนาด logical ของการ์ด — อัตราส่วน 9:16 เป๊ะ
const double kStoryCardWidth = 360;
const double kStoryCardHeight = 640;

/// ข้อความนับถอยหลังบนการ์ด แยกเป็นตัวเด่นกับหน่วย
///
/// ต่างจากถ้อยคำของวิดเจ็ตหน้าโฮม ("อีก N วัน" เป็นประโยค) โดยตั้งใจ — ที่นี่
/// ตัวเลขคือพระเอกของภาพ จึงยืนเดี่ยวตัวใหญ่แล้วค่อยมี "วัน" ห้อยข้างล่าง
/// ส่วนวันนี้/พรุ่งนี้ไม่มีตัวเลขให้เชิด เลยใช้คำเป็นตัวเด่นแทน
@immutable
class StoryCountdown {
  /// ตัวอักษรใหญ่กลางการ์ด — ตัวเลข หรือคำเมื่อนับเป็นตัวเลขไม่ได้
  final String headline;

  /// หน่วยที่ห้อยใต้ตัวเลข เป็น null เมื่อ [headline] เป็นคำอยู่แล้ว
  final String? unit;

  /// บรรทัดกำกับเหนือตัวเลข
  final String kicker;

  const StoryCountdown({
    required this.headline,
    required this.unit,
    required this.kicker,
  });

  /// [daysLeft] เป็น null เมื่อยังไม่รู้วันเดินทาง (รอบที่ยังไม่ระบุวัน)
  factory StoryCountdown.fromDaysLeft(int? daysLeft) {
    return switch (daysLeft) {
      null => const StoryCountdown(
        headline: 'เร็ว ๆ นี้',
        unit: null,
        kicker: 'ทริปต่อไปของฉัน',
      ),
      < 0 => const StoryCountdown(
        headline: 'กำลังลุย',
        unit: null,
        kicker: 'ตอนนี้ฉันอยู่ที่',
      ),
      0 => const StoryCountdown(
        headline: 'วันนี้!',
        unit: null,
        kicker: 'ออกเดินทางแล้ว',
      ),
      1 => const StoryCountdown(
        headline: 'พรุ่งนี้!',
        unit: null,
        kicker: 'อีกไม่กี่ชั่วโมง',
      ),
      _ => StoryCountdown(
        headline: '$daysLeft',
        unit: 'วัน',
        kicker: 'อีก',
      ),
    };
  }

  /// ขนาดตัวอักษรของ [headline] — คำยาวกว่าตัวเลขจึงต้องเล็กลงไม่ให้ล้นขอบ
  double get headlineSize {
    if (unit == null) return headline.characters.length > 7 ? 54 : 66;

    return headline.length >= 3 ? 108 : 140;
  }
}

/// องค์ประกอบทั้งใบ ไม่มี state ไม่แตะเครือข่าย — รูปถูกส่งเข้ามาเป็น
/// [ImageProvider] ที่ผู้เรียกโหลดไว้ก่อนแล้ว เพราะการจับภาพจะได้ช่องว่าง
/// ถ้ารูปยังโหลดไม่เสร็จตอนที่ `toImage` ทำงาน
///
/// **ต้องวางไว้ใต้ widget ที่ให้ constraint ความสูงแบบไม่จำกัด** (เช่น
/// [FittedBox] ที่ share sheet ใช้) ถ้าถูกกล่องที่เตี้ยกว่า 640 บีบไว้ การ์ดจะ
/// หดตามแล้ว PNG ที่ได้ก็จะไม่ใช่ 1080×1920 อีกต่อไป
class TripStoryCard extends StatelessWidget {
  final String tripTitle;
  final String location;
  final DateTime? departureDate;
  final int? daysLeft;

  /// รูปปกทริป เป็น null ได้ — การ์ดจะใช้พื้นเขียวเข้มไล่เฉดแทน
  final ImageProvider? coverImage;

  /// ลิงก์ชวนเพื่อนของเจ้าของการ์ด ใช้ทำ QR ท้ายการ์ด
  /// เป็น null เมื่อยังโหลดข้อมูลชวนเพื่อนไม่ได้ — QR จะถูกซ่อนไปทั้งบล็อก
  final String? shareUrl;

  const TripStoryCard({
    super.key,
    required this.tripTitle,
    required this.location,
    required this.departureDate,
    required this.daysLeft,
    this.coverImage,
    this.shareUrl,
  });

  @override
  Widget build(BuildContext context) {
    final countdown = StoryCountdown.fromDaysLeft(daysLeft);

    return SizedBox(
      width: kStoryCardWidth,
      height: kStoryCardHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _background(),
            _scrim(),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 34, 30, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandMark(),
                  const Spacer(),
                  _countdownBlock(countdown),
                  const SizedBox(height: 22),
                  _tripBlock(),
                  if (shareUrl != null) ...[
                    const SizedBox(height: 22),
                    _InviteFooter(shareUrl: shareUrl!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _background() {
    if (coverImage == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF065F46), Color(0xFF04231C)],
          ),
        ),
      );
    }

    return Image(image: coverImage!, fit: BoxFit.cover);
  }

  /// ไล่เฉดเข้มทับรูป ต้องเข้มพอให้ตัวอักษรขาวอ่านออกแม้รูปต้นทางจะเป็นท้องฟ้า
  /// สว่างจ้า — ค่าเดียวกับที่การ์ด OG ฝั่งเซิร์ฟเวอร์ใช้
  Widget _scrim() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66041A16), Color(0xCC041A16), Color(0xF2041A16)],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
    );
  }

  Widget _countdownBlock(StoryCountdown countdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          countdown.kicker,
          style: appFont(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.brandSoft,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                countdown.headline,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: appFont(
                  fontSize: countdown.headlineSize,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.02,
                ),
              ),
            ),
            if (countdown.unit != null) ...[
              const SizedBox(width: 8),
              Text(
                countdown.unit!,
                style: appFont(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _tripBlock() {
    final date = departureDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tripTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: appFont(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.28,
          ),
        ),
        if (location.isNotEmpty || date != null) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (location.isNotEmpty) location,
              if (date != null) thaiDateFull(date),
            ].join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// แถบแบรนด์มุมบน — ทึบ ไม่ใช่กระจกฝ้า เพราะพื้นหลังเป็นรูปที่คาดเดาไม่ได้
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hiking_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'ลุยเลเขา',
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// ท้ายการ์ด: QR ลิงก์ชวนเพื่อน — ทำให้สตอรี่กลายเป็นช่องทางหาลูกค้า ไม่ใช่
/// แค่ภาพสวย คนที่เห็นสตอรี่สแกนแล้วเข้าแอปพร้อมโค้ดชวนของเจ้าของการ์ดเลย
class _InviteFooter extends StatelessWidget {
  final String shareUrl;

  const _InviteFooter({required this.shareUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            ),
            child: QrImageView(
              data: shareUrl,
              version: QrVersions.auto,
              size: 58,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'สแกนมาลุยด้วยกัน',
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'รับส่วนลดทั้งคู่เมื่อจองทริปแรก',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
