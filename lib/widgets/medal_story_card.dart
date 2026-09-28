/// การ์ดเหรียญพิชิต 9:16 สำหรับลงสตอรี่ IG / Facebook
///
/// วาดที่ [kStoryCardWidth]×[kStoryCardHeight] แล้วถูกจับภาพ 3 เท่า → PNG
/// 1080×1920 ชุดเดียวกับการ์ดนับถอยหลังและการ์ดสรุปทริป (ดู trip_story_card.dart)
///
/// **การ์ดใบนี้เป็นของคนที่พิชิต ไม่ใช่ป้ายโฆษณา** — ไม่มีคำชวนจอง ไม่มี QR
/// มีแค่โลโก้เล็ก ๆ เป็นลายเซ็น และไม่มีเลขที่จองด้วยเหตุผลเดียวกับการ์ดอื่น
library;

import 'package:flutter/material.dart';

import '../models/trip_medal.dart';
import '../theme/app_theme.dart';
import '../utils/share_card.dart';
import 'medal_art.dart';
import 'trip_story_card.dart';

/// ขนาดดวงเหรียญบนการ์ด — ใช้ทั้งตอนวาดและตอน precache ภาพเหรียญออกแบบเอง
const double kMedalStoryMedalSize = 210;

/// พื้นหลังที่เจ้าของการ์ดเลือกได้
enum MedalBackdrop {
  /// สีเหรียญแบบเข้ม — ค่าตั้งต้น เหรียญเด่นที่สุด
  color('สีเหรียญ'),

  /// กระดาษขาวครีม ตัวอักษรเข้ม
  paper('กระดาษ'),

  /// รูปทริปหรือรูปของเจ้าของการ์ด มีเงาทึบทับให้ตัวอักษรอ่านออก
  photo('รูปถ่าย');

  const MedalBackdrop(this.label);

  final String label;
}

/// สีกระดาษ — ตัวเดียวกับสไตล์โพลารอยด์ของการ์ดนับถอยหลัง
const Color _paper = Color(0xFFFDFBF5);

/// ทองอ่อนของบรรทัด FINISHER บนพื้นเข้ม
const Color _goldLight = Color(0xFFF7CD78);

/// ทองเข้มของบรรทัด FINISHER บนกระดาษ (ทองอ่อนจางเกินไปบนพื้นขาว)
const Color _goldDeep = Color(0xFFB45309);

/// พื้นเข้มจากสีเหรียญ — ผสมดำให้ขอบทองกับตัวอักษรขาวเด่นขึ้น
Color medalBackdropColor(Color medal) =>
    Color.lerp(medal, const Color(0xFF06120F), 0.7)!;

/// **ต้องวางใต้ widget ที่ไม่จำกัดความสูง** (FittedBox ใน share sheet) เหมือน
/// การ์ดนับถอยหลัง ไม่งั้นการ์ดถูกบีบแล้ว PNG จะไม่ใช่ 1080×1920
class MedalStoryCard extends StatelessWidget {
  final TripMedal medal;
  final MedalBackdrop backdrop;

  /// รูปของพื้นหลังแบบ [MedalBackdrop.photo] — null ก็ถอยไปใช้สีเหรียญ
  final ImageProvider? photo;

  const MedalStoryCard({
    super.key,
    required this.medal,
    this.backdrop = MedalBackdrop.color,
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    final onPaper = backdrop == MedalBackdrop.paper;
    final usePhoto = backdrop == MedalBackdrop.photo && photo != null;
    final ink = onPaper ? AppTheme.slate900 : Colors.white;
    final soft = onPaper
        ? AppTheme.slate600
        : Colors.white.withValues(alpha: 0.78);

    final stats = <StoryStat>[
      if ((medal.distanceKm ?? 0) > 0)
        StoryStat('${_trim(medal.distanceKm!)} กม.', 'ระยะทาง'),
      if ((medal.elevationGainM ?? 0) > 0)
        StoryStat('${_thousands(medal.elevationGainM!)} ม.', 'ความสูงสะสม'),
      if ((medal.durationDays ?? 0) > 0)
        StoryStat('${medal.durationDays} วัน', 'ระยะเวลา'),
    ];

    final meta = [
      if (medal.placeLabel.isNotEmpty) medal.placeLabel,
      if (medal.dateLabel.isNotEmpty) medal.dateLabel,
    ].join('  ·  ');

    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: kStoryCardWidth,
        height: kStoryCardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (usePhoto) ...[
                Image(image: photo!, fit: BoxFit.cover),
                // เงาทึบสม่ำเสมอทั้งใบ — แบนตามธีม และทำให้ขอบทองของเหรียญ
                // ยังตัดกับพื้นได้ไม่ว่ารูปจะสว่างแค่ไหน
                const ColoredBox(color: Color(0x99061210)),
              ] else
                ColoredBox(
                  color: onPaper
                      ? _paper
                      : medalBackdropColor(medal.design.color),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StoryLogo(
                        height: 36,
                        tint: onPaper ? null : Colors.white,
                      ),
                    ),
                    // ก้อนกลางถูกย่อทั้งก้อนเมื่อชื่อ/บรรทัดสถานที่ยาวจนล้น — การ์ด
                    // ต้องออกมา 360×640 เสมอ ห้ามดันจนเกินขอบ
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: kStoryCardWidth - 56,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MedalArt(
                                  design: medal.design,
                                  size: kMedalStoryMedalSize,
                                  imageScale: kShareCardPixelRatio,
                                  year: medal.buddhistYear,
                                ),
                                const SizedBox(height: 22),
                                // ถ่างตัวอักษรเฉพาะส่วนอังกฤษ — ข้อความไทยที่ถูกถ่างจะถูกฉีก
                                // สระออกจากพยัญชนะ ("ครั้งที่" กลายเป็น "ค รั้ ง")
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: medal.finisherLabel.toUpperCase(),
                                        style: const TextStyle(
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      if (medal.attempt > 1)
                                        TextSpan(
                                          text:
                                              '  ·  ครั้งที่ ${medal.attempt}',
                                        ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                  style: appFont(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: onPaper ? _goldDeep : _goldLight,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  medal.design.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: appFont(
                                    // ชื่อยาวตัดบรรทัดกลางคำได้ ("โบลา/เวน") — ย่อตัวลงให้พอดีสองบรรทัดแทน
                                    fontSize:
                                        medal.design.name.characters.length > 18
                                        ? 21
                                        : 26,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                    height: 1.28,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  medal.holderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: appFont(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                                if (meta.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    meta,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: appFont(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: soft,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                if (stats.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 22,
                                    runSpacing: 8,
                                    children: [
                                      for (final stat in stats)
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              stat.value,
                                              style: appFont(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: ink,
                                              ),
                                            ),
                                            Text(
                                              stat.label,
                                              style: appFont(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: soft,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _trim(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

String _thousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}
