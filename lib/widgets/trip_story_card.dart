/// การ์ดนับถอยหลัง 9:16 สำหรับแชร์ลงสตอรี่ IG / Facebook
///
/// ลูกค้าแคปการ์ด "ทริปของคุณ · อีก N วัน" บนหน้าโฮมไปลงสตอรี่กันเองอยู่แล้ว
/// แต่การ์ดใบนั้นเป็นแนวนอน พอถูกครอปลงกรอบ 9:16 เนื้อหาก็หายไปครึ่งหนึ่ง
/// การ์ดใบนี้จึงจัดองค์ประกอบใหม่ทั้งใบให้เป็นสัดส่วนสตอรี่ตั้งแต่ต้น
///
/// วาดที่ [kStoryCardWidth]×[kStoryCardHeight] หน่วย logical แล้วถูกจับภาพที่
/// [kShareCardPixelRatio] (3.0) → ได้ PNG 1080×1920 พอดีกับที่ IG/FB ต้องการ
///
/// **การ์ดใบนี้เป็นของเจ้าของทริป ไม่ใช่ป้ายโฆษณา**
/// สตอรี่คือที่ที่คนอยากอวดว่า *ฉัน* กำลังจะไปไหน จึงไม่มี QR ชวนเพื่อนหรือคำ
/// ขายอยู่บนการ์ด เหลือแค่โลโก้เล็ก ๆ เป็นลายเซ็น แล้วเปิดให้เจ้าของเลือก
/// [StoryStyle] กับความโปร่งใสของรูปเองว่าจะอวดในแบบไหน
///
/// **สิ่งที่จงใจไม่ใส่ในการ์ด: เลขที่จอง**
/// การ์ดใบนี้ถูกสร้างมาเพื่อให้คนแปลกหน้าเห็น การประกาศวันเดินทางก็เท่ากับบอก
/// ว่าบ้านจะว่างวันไหนอยู่แล้ว ไม่มีเหตุผลให้แถมเลขที่จองไปด้วย
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

/// ขนาด logical ของการ์ด — อัตราส่วน 9:16 เป๊ะ
const double kStoryCardWidth = 360;
const double kStoryCardHeight = 640;

/// โลโก้พื้นหลังโปร่งใบเดียวกับที่เว็บใช้ ย่อมาให้พอดีกับที่การ์ดวาดจริง
///
/// ต้อง `precacheImage` ก่อนจับภาพเสมอ — `toImage` จับเฉพาะสิ่งที่วาดแล้ว รูป
/// ที่ยังถอดรหัสไม่เสร็จจะหายไปจาก PNG เงียบ ๆ เหมือนกับรูปปกทริป
const String kStoryLogoAsset = 'assets/images/logo_mark.png';

/// ค่าเริ่มต้นของ [TripStoryCard.photoOpacity] — ให้เงาทับรูปเท่ากับการ์ดรุ่นก่อน
/// ที่ยังไม่มีแถบปรับ คนที่ไม่แตะแถบเลยจึงได้ภาพหน้าตาเดิม
const double kStoryPhotoOpacityDefault = 0.4;

/// สไตล์การ์ดที่เจ้าของเลือกได้เอง
///
/// ทุกสไตล์ใช้เนื้อหาชุดเดียวกัน (โลโก้ + ตัวนับ + ชื่อทริป + วันที่) ต่างกันที่
/// การจัดวางกับโทนสี — คนละรสนิยมจึงหยิบไปใช้ได้โดยไม่ต้องมีการ์ดคนละชุด
enum StoryStyle {
  /// ตัวเลขใหญ่ชิดซ้ายล่างบนรูปเต็มใบ — โทนเดิมของแอป
  classic('คลาสสิก'),

  /// จัดกลางในกรอบเส้นบาง เหมือนโปสเตอร์หนัง
  poster('โปสเตอร์'),

  /// รูปเป็นพระเอก ข้อความย่อเหลือบรรทัดเดียวที่ก้นการ์ด
  minimal('เรียบ'),

  /// รูปอยู่ในกรอบกระดาษขาว ข้อความเป็นตัวเข้มใต้รูป
  polaroid('โพลารอยด์'),

  /// ขาวดำคอนทราสต์จัด
  mono('ขาวดำ');

  const StoryStyle(this.label);

  /// ชื่อที่ขึ้นบนชิปเลือกสไตล์
  final String label;

  /// อ่านค่าที่เก็บไว้กลับมา — ชื่อที่ไม่รู้จัก (ของเก่า/ของใหม่กว่า) ตกมาที่
  /// [StoryStyle.classic] แทนที่จะพัง
  static StoryStyle fromName(String? name) {
    for (final style in values) {
      if (style.name == name) return style;
    }

    return StoryStyle.classic;
  }
}

/// การวางรูปในกรอบการ์ด — เจ้าของการ์ดเลื่อน/ซูมรูปของตัวเองให้เข้าเฟรมได้
///
/// รูปถูกวาดด้วย `BoxFit.cover` เป็นฐานเสมอ ([scale] 1 จึงเต็มกรอบพอดีอยู่แล้ว)
/// แล้ว [scale] กับ [offset] คือสิ่งที่ผู้ใช้ปรับทับลงไป หน่วยของ [offset] เป็น
/// logical ของการ์ด (360×640) ไม่ใช่พิกเซลบนจอ ภาพที่จับได้จึงตรงกับที่เห็น
/// ไม่ว่าจอจะกว้างเท่าไร
@immutable
class StoryPhotoFraming {
  /// สัดส่วนรูปต้นฉบับ (กว้าง ÷ สูง) — null เมื่อยังไม่รู้ ซึ่งแปลว่ายังเลื่อน
  /// รูปไปได้ไกลเท่าที่ซูมไว้เท่านั้น
  final double? aspectRatio;

  /// เท่าของการซูม เริ่มที่ 1 (เต็มกรอบพอดี)
  final double scale;

  /// ระยะที่ผู้ใช้ลากรูปไป หน่วย logical ของการ์ด
  final Offset offset;

  const StoryPhotoFraming({
    this.aspectRatio,
    this.scale = 1,
    this.offset = Offset.zero,
  });

  /// รูปที่ยังไม่ถูกจัดเฟรม — เต็มกรอบแบบ cover เหมือนการ์ดรุ่นก่อน
  static const none = StoryPhotoFraming();

  bool get isDefault => scale == 1 && offset == Offset.zero;

  StoryPhotoFraming copyWith({
    double? aspectRatio,
    double? scale,
    Offset? offset,
  }) {
    return StoryPhotoFraming(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
    );
  }

  /// ระยะที่รูปยื่นพ้นกรอบในแต่ละแกน — ลากได้ไม่เกินนี้ ไม่งั้นขอบว่างจะโผล่
  ///
  /// รูป 4:3 ที่ถูก cover ลงกรอบ 9:16 จะยื่นพ้นด้านบน-ล่างอยู่แล้วตั้งแต่ยังไม่
  /// ซูม ผู้ใช้จึงเลื่อนหาหัวคนในรูปได้โดยไม่ต้องซูมก่อน
  Offset overflowIn(Size frame) {
    final ratio = aspectRatio;

    if (ratio == null || ratio <= 0) {
      final slack = (scale - 1) / 2;

      return Offset(frame.width * slack, frame.height * slack);
    }

    // ถือว่ารูปสูง 1 หน่วย กว้าง ratio หน่วย แล้วขยายแบบ cover ให้เต็มกรอบ
    final cover = math.max(frame.width / ratio, frame.height);
    final drawn = Size(ratio * cover * scale, cover * scale);

    return Offset(
      math.max(0, (drawn.width - frame.width) / 2),
      math.max(0, (drawn.height - frame.height) / 2),
    );
  }

  /// [offset] ที่ถูกดึงกลับให้อยู่ในกรอบ — การ์ดเรียกตอนวาด และ share sheet
  /// เรียกตอนผู้ใช้ลาก จะได้ไม่เกิดอาการ "ลากต่อไปเรื่อย ๆ แล้วนิ้วกลับมาไม่ทัน"
  Offset clampOffset(Size frame) {
    final limit = overflowIn(frame);

    return Offset(
      offset.dx.clamp(-limit.dx, limit.dx),
      offset.dy.clamp(-limit.dy, limit.dy),
    );
  }
}

/// ตัวเลขสรุปหนึ่งช่องบนการ์ดจบทริป เช่น ("1,240 ม.", "ความสูงสะสม")
@immutable
class StoryStat {
  final String value;
  final String label;

  const StoryStat(this.value, this.label);
}

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
      _ => StoryCountdown(headline: '$daysLeft', unit: 'วัน', kicker: 'อีก'),
    };
  }

  /// ตัวเด่นของการ์ดจบทริป — เชิดสถิติที่ "ใหญ่" ที่สุดเท่าที่รอบนั้นมีเก็บไว้
  ///
  /// ระยะทางมาก่อนจำนวนวันเพราะเป็นตัวเลขที่คนอวดกันจริง ๆ รอบที่ไม่ได้บันทึก
  /// อะไรไว้เลยก็ยังมีคำว่า "พิชิตแล้ว" ยืนเป็นตัวเด่นแทน ไม่ปล่อยให้การ์ดโล่ง
  factory StoryCountdown.recap({
    required String Function(num) format,
    num? distanceKm,
    num? days,
  }) {
    if (distanceKm != null && distanceKm > 0) {
      return StoryCountdown(
        headline: format(distanceKm),
        unit: 'กม.',
        kicker: 'พิชิตแล้ว',
      );
    }

    if (days != null && days > 0) {
      return StoryCountdown(
        headline: format(days),
        unit: 'วัน',
        kicker: 'พิชิตแล้ว',
      );
    }

    return const StoryCountdown(
      headline: 'พิชิตแล้ว',
      unit: null,
      kicker: 'ทริปที่ผ่านมา',
    );
  }

  /// ขนาดตัวอักษรของ [headline] — คำยาวกว่าตัวเลขจึงต้องเล็กลงไม่ให้ล้นขอบ
  double get headlineSize {
    if (unit == null) return headline.characters.length > 7 ? 54 : 66;

    return headline.length >= 3 ? 108 : 140;
  }

  /// ตัวนับแบบบรรทัดเดียว ("อีก 5 วัน") สำหรับสไตล์ที่ไม่เชิดตัวเลข
  ///
  /// คำที่ยืนเดี่ยวอยู่แล้ว ("วันนี้!") ไม่ต้องมี kicker มานำ เพราะ kicker ของ
  /// มันเป็นประโยคเต็ม ("ออกเดินทางแล้ว") ซึ่งจะกลายเป็นพูดซ้ำ
  String get inlineLabel => unit == null ? headline : '$kicker $headline $unit';
}

/// ฟิลเตอร์ขาวดำของสไตล์ [StoryStyle.mono] — ค่าถ่วงน้ำหนักแบบ luminance
/// มาตรฐาน (Rec. 709) สีเขียวของป่าจึงไม่กลายเป็นเทาทึบเท่ากันไปหมด
const ColorFilter _monoFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// สีกระดาษของสไตล์โพลารอยด์ — ขาวอมครีม ไม่ใช่ขาวจัด จะได้ไม่แสบตาในฟีด
const Color _paper = Color(0xFFFDFBF5);

/// โลโก้ลุยเลเขาบนการ์ด
///
/// [tint] เป็นสีที่ทาทับทั้งดวง (ใช้เงาของโลโก้เป็นแม่พิมพ์) — บนรูปถ่ายใช้สี
/// ขาวจะอ่านออกทุกพื้นหลัง ส่วนบนกระดาษขาวปล่อย null ไว้ให้เป็นโลโก้สีจริง
class StoryLogo extends StatelessWidget {
  final double height;
  final Color? tint;

  const StoryLogo({super.key, required this.height, this.tint});

  @override
  Widget build(BuildContext context) {
    final Widget logo = Image.asset(
      kStoryLogoAsset,
      height: height,
      filterQuality: FilterQuality.medium,
      // โลโก้หายไปเฉย ๆ ดีกว่าการ์ดพังทั้งใบ เช่นตอนรันเทสที่ไม่มี asset bundle
      errorBuilder: (_, _, _) => SizedBox(height: height),
    );

    if (tint == null) return logo;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint!, BlendMode.srcIn),
      child: logo,
    );
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

  /// รูปบนการ์ด — รูปปกทริป หรือรูปที่เจ้าของการ์ดเลือกมาเอง
  /// เป็น null ได้ การ์ดจะใช้พื้นเขียวเข้มไล่เฉดแทน
  final ImageProvider? coverImage;

  /// การเลื่อน/ซูมรูปที่เจ้าของการ์ดจัดไว้
  final StoryPhotoFraming framing;

  /// สไตล์ที่เจ้าของการ์ดเลือก
  final StoryStyle style;

  /// ความชัดของรูป 0–1 — ยิ่งมาก เงาที่ทับรูปยิ่งบาง รูปยิ่งโผล่
  ///
  /// ไม่ปล่อยให้เงาบางจนเป็นศูนย์ เพราะตัวอักษรขาวบนท้องฟ้าจ้าจะอ่านไม่ออก
  /// ค่าสูงสุดจึงยังเหลือเงาไว้ราวหนึ่งในห้าของค่าตั้งต้น
  final double photoOpacity;

  /// ตัวเด่นที่ผู้เรียกกำหนดเอง — การ์ดจบทริปใช้ช่องนี้ ส่วนการ์ดนับถอยหลัง
  /// ปล่อยว่างไว้แล้วให้ [daysLeft] เป็นคนบอก
  final StoryCountdown? highlight;

  /// ตัวเลขสรุปท้ายการ์ด — ว่างเสมอสำหรับการ์ดนับถอยหลัง
  final List<StoryStat> stats;

  /// บรรทัดวันที่สำเร็จรูป ใช้แทน [departureDate] เมื่อเป็นช่วงวัน ("5 – 7 ก.ย.")
  final String? dateLabel;

  const TripStoryCard({
    super.key,
    required this.tripTitle,
    required this.location,
    required this.departureDate,
    required this.daysLeft,
    this.coverImage,
    this.framing = StoryPhotoFraming.none,
    this.style = StoryStyle.classic,
    this.photoOpacity = kStoryPhotoOpacityDefault,
  }) : highlight = null,
       stats = const [],
       dateLabel = null;

  /// การ์ดสรุปหลังจบทริป — โครงเดียวกันเป๊ะ ต่างแค่ตัวเด่นเป็นสถิติแทนตัวนับ
  ///
  /// ใช้โครงเดียวกันโดยตั้งใจ: คนที่เคยแชร์การ์ดนับถอยหลังก่อนไป จะได้การ์ด
  /// หน้าตาเป็นชุดเดียวกันตอนกลับมา สไตล์ที่เขาเลือกไว้ก็ยังใช้ได้ทั้งสองใบ
  const TripStoryCard.recap({
    super.key,
    required this.tripTitle,
    required this.location,
    required this.highlight,
    required this.dateLabel,
    this.stats = const [],
    this.coverImage,
    this.framing = StoryPhotoFraming.none,
    this.style = StoryStyle.classic,
    this.photoOpacity = kStoryPhotoOpacityDefault,
  }) : departureDate = null,
       daysLeft = null;

  @override
  Widget build(BuildContext context) {
    final countdown = highlight ?? StoryCountdown.fromDaysLeft(daysLeft);

    return SizedBox(
      width: kStoryCardWidth,
      height: kStoryCardHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: switch (style) {
          StoryStyle.classic => _classic(countdown),
          StoryStyle.poster => _poster(countdown),
          StoryStyle.minimal => _minimal(countdown),
          StoryStyle.polaroid => _polaroid(countdown),
          StoryStyle.mono => _mono(countdown),
        },
      ),
    );
  }

  // ── ชั้นพื้นหลัง ────────────────────────────────────────────────────────

  Widget _photo({bool grayscale = false}) {
    final image = coverImage;
    final Widget layer = image == null
        ? const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF065F46), Color(0xFF04231C)],
              ),
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              // กรอบของแต่ละสไตล์ไม่เท่ากัน (โพลารอยด์เตี้ยกว่าใบอื่น) จึงดึง
              // ค่าที่ผู้ใช้ลากไว้กลับเข้ากรอบ *ของสไตล์นั้น* ตรงนี้ ไม่ใช่ตอนลาก
              final frame = Size(constraints.maxWidth, constraints.maxHeight);

              return ClipRect(
                child: Transform.translate(
                  offset: framing.clampOffset(frame),
                  child: Transform.scale(
                    scale: framing.scale,
                    child: Image(image: image, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          );

    if (!grayscale) return layer;

    return ColorFiltered(colorFilter: _monoFilter, child: layer);
  }

  /// ตัวคูณความเข้มของเงาทับรูป — [photoOpacity] 0 คือเข้มสุด, 1 คือบางสุด
  double get _scrimScale => 1.5 - photoOpacity.clamp(0.0, 1.0) * 1.3;

  Color _dim(Color color) =>
      color.withValues(alpha: (color.a * _scrimScale).clamp(0.0, 1.0));

  /// ไล่เฉดทับรูปให้ตัวอักษรอ่านออกแม้รูปต้นทางจะเป็นท้องฟ้าสว่างจ้า
  /// ความเข้มถูกคูณด้วย [_scrimScale] ตามที่เจ้าของการ์ดปรับไว้
  Widget _scrim(List<Color> colors, List<double> stops) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [for (final color in colors) _dim(color)],
          stops: stops,
        ),
      ),
    );
  }

  // ── สไตล์ ──────────────────────────────────────────────────────────────

  Widget _classic(StoryCountdown countdown) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _photo(),
        _scrim(
          const [Color(0x66041A16), Color(0xCC041A16), Color(0xF2041A16)],
          const [0.0, 0.52, 1.0],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 34, 30, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StoryLogo(height: 44, tint: Colors.white),
              const Spacer(),
              _countdownBlock(countdown, kickerColor: AppTheme.brandSoft),
              const SizedBox(height: 22),
              _tripBlock(),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 18),
                _statsRow(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _poster(StoryCountdown countdown) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _photo(),
        _scrim(
          const [Color(0x8C041A16), Color(0x73041A16), Color(0xD9041A16)],
          const [0.0, 0.45, 1.0],
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 1.4,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              // โลโก้ลอยอยู่บนสุดของกรอบ ส่วนเนื้อหาอยู่กลางการ์ดจริง ๆ ไม่ใช่
              // กลางของพื้นที่ที่เหลือจากโลโก้ — วางซ้อนกันจึงไม่ดันกันเอง
              child: Stack(
                children: [
                  const Align(
                    alignment: Alignment.topCenter,
                    child: StoryLogo(height: 46, tint: Colors.white),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _countdownBlock(
                          countdown,
                          kickerColor: Colors.white.withValues(alpha: 0.78),
                          align: CrossAxisAlignment.center,
                          scale: 0.88,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: 44,
                          height: 2,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 18),
                        _tripBlock(align: CrossAxisAlignment.center),
                        if (stats.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _statsRow(centered: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _minimal(StoryCountdown countdown) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _photo(),
        _scrim(
          const [Color(0x00041A16), Color(0x33041A16), Color(0xD9041A16)],
          const [0.0, 0.55, 1.0],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 30, 30, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StoryLogo(height: 34, tint: Colors.white),
              const Spacer(),
              Text(
                countdown.inlineLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              _tripBlock(titleSize: 20, metaSize: 14),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 16),
                _statsRow(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _polaroid(StoryCountdown countdown) {
    return ColoredBox(
      color: _paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _photo(),
                    // เงาบางมาก เพราะข้อความไม่ได้อยู่บนรูป — แถบนี้มีไว้ให้
                    // แถบปรับความโปร่งใสยังทำงานเห็นผลในสไตล์นี้ด้วย
                    _scrim(
                      const [Color(0x14041A16), Color(0x4D041A16)],
                      const [0.0, 1.0],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _countdownBlock(
                        countdown,
                        kickerColor: AppTheme.brandDeep,
                        textColor: AppTheme.slate900,
                        scale: 0.42,
                        unitSize: 20,
                        kickerSize: 13,
                      ),
                      const SizedBox(height: 6),
                      _tripBlock(
                        titleColor: AppTheme.slate900,
                        metaColor: AppTheme.slate600,
                        titleSize: 20,
                        metaSize: 13,
                      ),
                      if (stats.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _statsRow(
                          valueColor: AppTheme.slate900,
                          labelColor: AppTheme.slate600,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: StoryLogo(height: 54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mono(StoryCountdown countdown) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _photo(grayscale: true),
        _scrim(
          const [Color(0x59000000), Color(0xB3000000), Color(0xF2000000)],
          const [0.0, 0.5, 1.0],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 34, 30, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StoryLogo(height: 40, tint: Colors.white),
              const Spacer(),
              Container(width: 36, height: 2, color: Colors.white),
              const SizedBox(height: 16),
              _countdownBlock(
                countdown,
                kickerColor: Colors.white.withValues(alpha: 0.72),
              ),
              const SizedBox(height: 20),
              _tripBlock(metaColor: Colors.white.withValues(alpha: 0.72)),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 18),
                _statsRow(labelColor: Colors.white.withValues(alpha: 0.6)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── บล็อกเนื้อหาที่ทุกสไตล์ใช้ร่วมกัน ───────────────────────────────────

  Widget _countdownBlock(
    StoryCountdown countdown, {
    required Color kickerColor,
    Color textColor = Colors.white,
    CrossAxisAlignment align = CrossAxisAlignment.start,
    double scale = 1,
    double unitSize = 30,
    double kickerSize = 15,
    double kickerSpacing = 0.6,
  }) {
    final centered = align == CrossAxisAlignment.center;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          countdown.kicker,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: appFont(
            fontSize: kickerSize,
            fontWeight: FontWeight.w700,
            color: kickerColor,
            letterSpacing: kickerSpacing,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                countdown.headline,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: appFont(
                  fontSize: countdown.headlineSize * scale,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.02,
                ),
              ),
            ),
            if (countdown.unit != null) ...[
              const SizedBox(width: 8),
              Text(
                countdown.unit!,
                style: appFont(
                  fontSize: unitSize,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// แถวตัวเลขสรุปท้ายการ์ดจบทริป — ว่างเปล่าสำหรับการ์ดนับถอยหลัง
  ///
  /// ใช้ [Wrap] ไม่ใช่ [Row] เพราะตัวเลขไทยยาวไม่เท่ากัน ("1,240 ม." กับ
  /// "8 คน") พอจอแคบหรือมีสี่ช่องก็ตกบรรทัดแทนที่จะล้นขอบการ์ด
  Widget _statsRow({
    Color valueColor = Colors.white,
    Color? labelColor,
    bool centered = false,
  }) {
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      children: [
        for (final stat in stats)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                stat.value,
                style: appFont(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  height: 1.15,
                ),
              ),
              Text(
                stat.label,
                style: appFont(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? Colors.white.withValues(alpha: 0.72),
                  height: 1.3,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _tripBlock({
    CrossAxisAlignment align = CrossAxisAlignment.start,
    Color titleColor = Colors.white,
    Color? metaColor,
    double titleSize = 25,
    double metaSize = 15,
  }) {
    final date = departureDate;
    final centered = align == CrossAxisAlignment.center;
    final when = dateLabel ?? (date == null ? '' : thaiDateFull(date));
    final meta = [
      if (location.isNotEmpty) location,
      if (when.isNotEmpty) when,
    ].join('  ·  ');

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tripTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: appFont(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: titleColor,
            height: 1.28,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            meta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: appFont(
              fontSize: metaSize,
              fontWeight: FontWeight.w600,
              color: metaColor ?? Colors.white.withValues(alpha: 0.86),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
