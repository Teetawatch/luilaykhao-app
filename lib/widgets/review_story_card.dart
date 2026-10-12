/// การ์ดคำรีวิว 9:16 สำหรับแชร์ลงสตอรี่ — ประโยคที่ลูกค้าเขียน + ดาว + รูปจากทริป
///
/// จังหวะที่คนเพิ่งเขียนรีวิวเสร็จคือจังหวะที่อารมณ์ดีที่สุดกับทริป การ์ดใบนี้
/// เลยเป็น *คำของเขาเอง* ล้วน ๆ: ไม่มีราคา ไม่มีคำชวนจอง มีแค่โลโก้เล็ก ๆ ที่ปิดได้
/// คนที่เห็นในสตอรี่จะเชื่อเพราะเป็นเสียงของเพื่อน ไม่ใช่ป้ายโฆษณา
///
/// วาดที่ [kStoryCardWidth]×[kStoryCardHeight] แล้วจับภาพที่ 3 เท่า → PNG
/// 1080×1920 เหมือนการ์ดนับถอยหลัง ยกเว้น [ReviewBackdrop.sticker] ที่สูงเท่า
/// เนื้อหาและโปร่งใส ไว้แปะทับรูปของตัวเองใน IG
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'trip_story_card.dart';

/// ตัดคำรีวิวที่ยาวกว่านี้ — การ์ดหนึ่งใบอ่านจบในสามวินาทีที่สตอรี่ค้างอยู่
const int kReviewQuoteMaxLength = 280;

const Color _starColor = Color(0xFFFFB400);
const Color _paper = Color(0xFFFDFBF5);

/// พื้นหลังของการ์ดคำรีวิว
enum ReviewBackdrop {
  /// รูปที่แนบมากับรีวิว มีเงาไล่เฉดทับให้ตัวอักษรอ่านออก
  photo('รูปจากทริป'),

  /// เขียวป่าไล่เฉด — สำหรับรีวิวที่ไม่มีรูป
  forest('เขียวป่า'),

  /// กระดาษขาวครีม ตัวอักษรเข้ม เหมือนการ์ดเขียนมือ
  paper('กระดาษ'),

  /// ไม่มีพื้น — PNG โปร่งใสครอปพอดีเนื้อหา ไว้แปะทับรูป/วิดีโอใน IG Story
  sticker('สติกเกอร์');

  const ReviewBackdrop(this.label);

  final String label;
}

/// ตัดคำรีวิวให้พอดีการ์ด — ตัดที่ช่องว่างใกล้สุดก่อนถึงเพดาน ไม่ผ่ากลางคำ
/// (ภาษาไทยไม่เว้นวรรคทุกคำ ถ้าไม่เจอช่องว่างในช่วงท้ายก็ตัดตรงเพดานเลย)
String reviewQuoteExcerpt(String comment, {int max = kReviewQuoteMaxLength}) {
  final text = comment.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= max) return text;

  var cut = text.lastIndexOf(' ', max);
  if (cut < max * 0.7) cut = max;

  return '${text.substring(0, cut).trimRight()}…';
}

/// ขนาดตัวอักษรของคำรีวิวตามความยาว — สั้นตัวใหญ่ให้เป็นพระเอก ยาวตัวเล็กลง
/// จนยังพอดีการ์ด (ทดสอบด้วยคำยาวสุด [kReviewQuoteMaxLength] ตัว)
double reviewQuoteFontSize(String quote) {
  final n = quote.length;
  if (n <= 50) return 30;
  if (n <= 110) return 24;
  if (n <= 190) return 20;

  return 17;
}

class ReviewStoryCard extends StatelessWidget {
  final String comment;
  final int rating;
  final String tripTitle;

  /// ชื่อผู้รีวิว — ว่าง/ปิด [showName] = ไม่มีบรรทัดลงชื่อ
  final String reviewerName;
  final ReviewBackdrop backdrop;

  /// รูปพื้นหลังเมื่อ [backdrop] เป็น [ReviewBackdrop.photo] — ผู้เรียกโหลด
  /// เข้าแคชไว้ก่อน ไม่งั้นภาพที่จับได้จะเป็นช่องว่าง
  final ImageProvider? photo;
  final bool showLogo;
  final bool showName;

  /// สีตัวอักษรของสติกเกอร์ — พื้นอื่นไม่สนใจค่านี้
  final StickerInk ink;

  const ReviewStoryCard({
    super.key,
    required this.comment,
    required this.rating,
    required this.tripTitle,
    this.reviewerName = '',
    this.backdrop = ReviewBackdrop.forest,
    this.photo,
    this.showLogo = true,
    this.showName = true,
    this.ink = StickerInk.light,
  });

  bool get _sticker => backdrop == ReviewBackdrop.sticker;

  /// ตัวเข้มบนพื้นสว่าง: กระดาษ หรือสติกเกอร์หมึกเข้ม
  bool get _darkText =>
      backdrop == ReviewBackdrop.paper || (_sticker && ink == StickerInk.dark);

  List<Shadow>? get _shadows {
    if (!_sticker) return null;

    return ink == StickerInk.dark
        ? const [
            Shadow(color: Color(0xCCFFFFFF), blurRadius: 10),
            Shadow(color: Color(0x99FFFFFF), blurRadius: 3),
          ]
        : const [
            Shadow(
              color: Color(0x8C000000),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
            Shadow(
              color: Color(0x66000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ];
  }

  @override
  Widget build(BuildContext context) {
    if (_sticker) {
      return SizedBox(
        width: kStoryCardWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
          child: _content(compact: true),
        ),
      );
    }

    return SizedBox(
      width: kStoryCardWidth,
      height: kStoryCardHeight,
      // มุมฉากทึบ — มุมโค้งกลายเป็นพิกเซลใสที่ IG ถมสีให้เอง (ดู TripStoryCard)
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _background(),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 34),
              child: _content(compact: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _background() {
    switch (backdrop) {
      case ReviewBackdrop.paper:
        return const ColoredBox(color: _paper);
      case ReviewBackdrop.photo when photo != null:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image(image: photo!, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x8C041A16),
                    Color(0xA6041A16),
                    Color(0xE6041A16),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        );
      default:
        // เขียวป่า — และเป็นพื้นสำรองของ "รูปจากทริป" ที่ไม่มีรูปให้ใช้
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF065F46), Color(0xFF04231C)],
            ),
          ),
        );
    }
  }

  Widget _content({required bool compact}) {
    final text = _darkText ? AppTheme.slate900 : Colors.white;
    final soft = _darkText
        ? AppTheme.slate600
        : Colors.white.withValues(alpha: 0.82);
    final quote = reviewQuoteExcerpt(comment);
    final name = showName ? reviewerName.trim() : '';
    final align = compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = compact ? TextAlign.center : TextAlign.start;

    final body = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 26,
              color: i <= rating ? _starColor : soft,
              shadows: _shadows,
            ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        '“$quote”',
        textAlign: textAlign,
        maxLines: compact ? 8 : 12,
        overflow: TextOverflow.ellipsis,
        style: appFont(
          fontSize: reviewQuoteFontSize(quote) * (compact ? 0.85 : 1),
          fontWeight: FontWeight.w800,
          color: text,
          height: 1.4,
          shadows: _shadows,
        ),
      ),
      const SizedBox(height: 18),
      if (name.isNotEmpty)
        Text(
          '— $name',
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: appFont(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: text,
            shadows: _shadows,
          ),
        ),
      Text(
        'รีวิวทริป $tripTitle',
        textAlign: textAlign,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: appFont(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: soft,
          height: 1.4,
          shadows: _shadows,
        ),
      ),
    ];

    final logo = showLogo
        ? StoryLogo(
            height: compact ? 36 : 40,
            tint: backdrop == ReviewBackdrop.paper ? null : text,
          )
        : null;

    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align,
        children: [
          if (logo != null) ...[logo, const SizedBox(height: 16)],
          ...body,
        ],
      );
    }

    return Column(
      crossAxisAlignment: align,
      children: [?logo, const Spacer(), ...body],
    );
  }
}

/// คำบรรยายที่ติดไปกับรูป — LINE/FB ใช้ IG ทิ้งไป จึงต้องอ่านรู้เรื่องเองได้
///
/// ยกประโยคสั้น ๆ จากรีวิวมานำ แล้วแนบลิงก์หน้าทริปให้คนที่สนใจกดดูต่อ — เป็น
/// ลิงก์ข้อมูล ไม่ใช่คำชวนจอง
String reviewShareCaption({
  required String comment,
  required int rating,
  required String tripTitle,
  String? tripUrl,
}) {
  final excerpt = reviewQuoteExcerpt(comment, max: 90);
  final stars = '⭐' * rating.clamp(0, 5);
  final link = tripUrl == null || tripUrl.isEmpty ? '' : '\n$tripUrl';

  return '“$excerpt” $stars\nรีวิวทริป $tripTitle$link\n#ลุยเลเขา';
}
