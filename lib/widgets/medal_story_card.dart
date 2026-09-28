/// การ์ดเหรียญพิชิต 9:16 สำหรับลงสตอรี่ IG / Facebook
///
/// วาดที่ [kStoryCardWidth]×[kStoryCardHeight] แล้วถูกจับภาพ 3 เท่า → PNG
/// 1080×1920 ชุดเดียวกับการ์ดนับถอยหลังและการ์ดสรุปทริป (ดู trip_story_card.dart)
///
/// เจ้าของการ์ดปรับได้เกือบทุกอย่าง — พื้นหลัง ความทึบ/ความเข้ม การจัดวาง ขนาด
/// เหรียญ และข้อมูลที่จะโชว์ — เพราะคนละคนอยากอวดคนละแบบ บางคนอยากให้รูป
/// วิวเป็นพระเอก บางคนอยากให้เหรียญเต็มจอ ([MedalLookStorage] จำไว้ให้)
///
/// **การ์ดใบนี้เป็นของคนที่พิชิต ไม่ใช่ป้ายโฆษณา** — ไม่มีคำชวนจอง ไม่มี QR
/// และไม่มีเลขที่จองด้วยเหตุผลเดียวกับการ์ดอื่น
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/trip_medal.dart';
import '../theme/app_theme.dart';
import '../utils/share_card.dart';
import 'medal_art.dart';
import 'medal_route.dart';
import 'trip_story_card.dart';

/// ขนาดดวงเหรียญปกติของรูปแบบ "กลางการ์ด"
const double kMedalStoryMedalSize = 210;

/// ความกว้างที่ใช้ถอดรหัสภาพเหรียญออกแบบเองบนการ์ด — ค่าเดียวเสมอไม่ว่าเหรียญ
/// จะถูกวาดใหญ่แค่ไหน เพื่อให้ตรงกับที่ share sheet precache ไว้ (ใหญ่พอสำหรับ
/// รูปแบบ "เหรียญเต็มตา" ที่ขยายสุด)
const double kMedalStoryDecodeWidth = 360;

/// ช่วงของแถบขนาดเหรียญ
const double kMedalScaleMin = 0.75;
const double kMedalScaleMax = 1.25;

/// ค่าตั้งต้นของความชัดของรูป — เงาทับเท่ากับการ์ดรุ่นแรก (0x99 ≈ 0.6)
const double kMedalPhotoOpacityDefault = 0.4;

/// ค่าตั้งต้นของความเข้มพื้นสี — เท่ากับการ์ดรุ่นแรก (ผสมดำ 70%)
const double kMedalToneDefault = 0.5;

/// พื้นหลังที่เจ้าของการ์ดเลือกได้
enum MedalBackdrop {
  /// สีเหรียญแบบเข้ม — ค่าตั้งต้น เหรียญเด่นที่สุด
  color('สีเหรียญ'),

  /// เกือบดำ — ขอบทองเด่นสุด เข้ากับทุกสีเหรียญ
  dark('มืด'),

  /// กระดาษขาวครีม ตัวอักษรเข้ม
  paper('กระดาษ'),

  /// รูปทริปหรือรูปของเจ้าของการ์ด มีเงาทึบทับให้ตัวอักษรอ่านออก
  photo('รูปถ่าย'),

  /// ไม่มีพื้นเลย — PNG โปร่งใสไว้วางทับรูปของตัวเองใน IG Story เป็นสติกเกอร์
  /// (ของที่คนแชร์จาก Strava มากที่สุด)
  transparent('สติกเกอร์โปร่งใส');

  const MedalBackdrop(this.label);

  final String label;
}

/// การจัดวางบนการ์ด
enum MedalCardLayout {
  /// เหรียญกลางการ์ด ข้อความเรียงใต้เหรียญ
  centered('กลางการ์ด'),

  /// เหรียญใหญ่เต็มตา ข้อความน้อยลง
  hero('เหรียญเต็มตา'),

  /// ทุกอย่างรวมไว้ขอบล่าง เปิดพื้นที่ด้านบนให้รูปวิว
  corner('โชว์วิว'),

  /// เส้นทางที่เดินเป็นพระเอก + กราฟความสูง + ตัวเลขใหญ่ แบบการ์ด Strava
  /// ใช้ได้เฉพาะเหรียญที่มีเส้นทาง ไม่มีก็ถอยไปเป็น [centered]
  route('เส้นทาง');

  const MedalCardLayout(this.label);

  final String label;
}

/// ส่วนไหนของการ์ดที่จะโชว์ — เหรียญกับชื่อทริปอยู่เสมอ ที่เหลือปิดได้
@immutable
class MedalCardParts {
  final bool holder;
  final bool meta;
  final bool stats;
  final bool attempt;
  final bool logo;

  /// ป้าย "เดินไกลที่สุดของฉัน" เมื่อเหรียญนี้ถือสถิติส่วนตัว
  final bool records;

  const MedalCardParts({
    this.holder = true,
    this.meta = true,
    this.stats = true,
    this.attempt = true,
    this.logo = true,
    this.records = true,
  });

  static const all = MedalCardParts();

  MedalCardParts copyWith({
    bool? holder,
    bool? meta,
    bool? stats,
    bool? attempt,
    bool? logo,
    bool? records,
  }) {
    return MedalCardParts(
      holder: holder ?? this.holder,
      meta: meta ?? this.meta,
      stats: stats ?? this.stats,
      attempt: attempt ?? this.attempt,
      logo: logo ?? this.logo,
      records: records ?? this.records,
    );
  }

  Map<String, bool> toJson() => {
    'holder': holder,
    'meta': meta,
    'stats': stats,
    'attempt': attempt,
    'logo': logo,
    'records': records,
  };

  factory MedalCardParts.fromJson(Map<dynamic, dynamic> json) {
    bool flag(String key) => json[key] is bool ? json[key] as bool : true;

    return MedalCardParts(
      holder: flag('holder'),
      meta: flag('meta'),
      stats: flag('stats'),
      attempt: flag('attempt'),
      logo: flag('logo'),
      records: flag('records'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MedalCardParts &&
      other.holder == holder &&
      other.meta == meta &&
      other.stats == stats &&
      other.attempt == attempt &&
      other.logo == logo &&
      other.records == records;

  @override
  int get hashCode => Object.hash(holder, meta, stats, attempt, logo, records);
}

/// สีกระดาษ — ตัวเดียวกับสไตล์โพลารอยด์ของการ์ดนับถอยหลัง
const Color _paper = Color(0xFFFDFBF5);

/// พื้น "มืด"
const Color _night = Color(0xFF0E1412);

/// ทองอ่อนของบรรทัด FINISHER บนพื้นเข้ม
const Color _goldLight = Color(0xFFF7CD78);

/// ทองเข้มของบรรทัด FINISHER บนกระดาษ (ทองอ่อนจางเกินไปบนพื้นขาว)
const Color _goldDeep = Color(0xFFB45309);

/// พื้นเข้มจากสีเหรียญ — ผสมดำให้ขอบทองกับตัวอักษรขาวเด่นขึ้น
///
/// [tone] 0 = สีเหรียญสว่างสุดที่ยังอ่านตัวขาวออก (ผสมดำ 45%), 1 = เกือบดำ (95%)
Color medalBackdropColor(Color medal, [double tone = kMedalToneDefault]) =>
    Color.lerp(medal, const Color(0xFF06120F), 0.45 + 0.5 * tone.clamp(0, 1))!;

/// ความทึบของเงาทับรูป — [photoOpacity] 0 = เงาทึบสุด (ตัวอักษรเด่น), 1 = รูป
/// ชัดสุด แต่ยังเหลือเงาบาง ๆ ไว้ ไม่งั้นตัวขาวบนท้องฟ้าจ้าจะอ่านไม่ออก
double medalScrimAlpha(double photoOpacity) =>
    0.85 - 0.65 * photoOpacity.clamp(0, 1);

/// **ต้องวางใต้ widget ที่ไม่จำกัดความสูง** (FittedBox ใน share sheet) เหมือน
/// การ์ดนับถอยหลัง ไม่งั้นการ์ดถูกบีบแล้ว PNG จะไม่ใช่ 1080×1920
class MedalStoryCard extends StatelessWidget {
  final TripMedal medal;
  final MedalBackdrop backdrop;
  final MedalCardLayout layout;

  /// รูปของพื้นหลังแบบ [MedalBackdrop.photo] — null ก็ถอยไปใช้สีเหรียญ
  final ImageProvider? photo;

  /// การเลื่อน/ซูมรูปที่เจ้าของจัดไว้ (หน่วย logical ของการ์ด)
  final StoryPhotoFraming framing;

  /// ความชัดของรูป 0–1 ดู [medalScrimAlpha]
  final double photoOpacity;

  /// ความเข้มของพื้นสีเหรียญ 0–1 ดู [medalBackdropColor]
  final double tone;

  /// ขนาดเหรียญเทียบขนาดปกติของ [layout] ([kMedalScaleMin]–[kMedalScaleMax])
  final double medalScale;

  final MedalCardParts parts;

  const MedalStoryCard({
    super.key,
    required this.medal,
    this.backdrop = MedalBackdrop.color,
    this.layout = MedalCardLayout.centered,
    this.photo,
    this.framing = StoryPhotoFraming.none,
    this.photoOpacity = kMedalPhotoOpacityDefault,
    this.tone = kMedalToneDefault,
    this.medalScale = 1,
    this.parts = MedalCardParts.all,
  });

  bool get _onPaper => backdrop == MedalBackdrop.paper;

  Color get _ink => _onPaper ? AppTheme.slate900 : Colors.white;

  Color get _soft =>
      _onPaper ? AppTheme.slate600 : Colors.white.withValues(alpha: 0.78);

  double get _scale => medalScale.clamp(kMedalScaleMin, kMedalScaleMax);

  @override
  Widget build(BuildContext context) {
    final usePhoto = backdrop == MedalBackdrop.photo && photo != null;

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
                _photoLayer(),
                // เงาทึบสม่ำเสมอทั้งใบ (แบนตามธีม) ความทึบตามแถบที่เจ้าของปรับ
                ColoredBox(
                  color: const Color(
                    0xFF061210,
                  ).withValues(alpha: medalScrimAlpha(photoOpacity)),
                ),
              ] else if (backdrop != MedalBackdrop.transparent)
                ColoredBox(color: _solidBackground()),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
                child: switch (layout) {
                  MedalCardLayout.centered => _centered(),
                  MedalCardLayout.hero => _hero(),
                  MedalCardLayout.corner => _corner(),
                  MedalCardLayout.route =>
                    medal.route == null ? _centered() : _routeLayout(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _solidBackground() {
    return switch (backdrop) {
      MedalBackdrop.paper => _paper,
      MedalBackdrop.dark => _night,
      // พื้นหลังรูปแต่ไม่มีรูป (โหลดไม่ได้) ถอยมาใช้สีเหรียญ
      MedalBackdrop.color ||
      MedalBackdrop.photo => medalBackdropColor(medal.design.color, tone),
      MedalBackdrop.transparent => Colors.transparent,
    };
  }

  Widget _photoLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = Size(constraints.maxWidth, constraints.maxHeight);

        return ClipRect(
          child: Transform.translate(
            offset: framing.clampOffset(frame),
            child: Transform.scale(
              scale: framing.scale,
              child: Image(image: photo!, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  // ── รูปแบบ ──────────────────────────────────────────────────────────────

  Widget _centered() {
    return Column(
      children: [
        _logoRow(),
        Expanded(
          child: _fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _medal(kMedalStoryMedalSize),
                const SizedBox(height: 22),
                ..._textBlock(
                  align: CrossAxisAlignment.center,
                  nameSize: _nameSize(26, 21),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero() {
    return Column(
      children: [
        _logoRow(),
        Expanded(
          child: _fitted(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _medal(280),
                const SizedBox(height: 18),
                ..._textBlock(
                  align: CrossAxisAlignment.center,
                  nameSize: _nameSize(24, 20),
                  // เหรียญเป็นพระเอก — ตัวเลขสถิติย้ายไปอยู่ด้านหลังเหรียญแทน
                  includeStats: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _corner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _logoRow(),
        // ชิดล่างทั้งก้อน ด้านบนเปิดโล่งให้รูปวิวเป็นพระเอก
        Expanded(
          child: _fitted(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _medal(120),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: _textBlock(
                          align: CrossAxisAlignment.start,
                          nameSize: _nameSize(22, 18),
                          includeStats: false,
                          includeMeta: false,
                        ),
                      ),
                    ),
                  ],
                ),
                if (parts.meta && _meta.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _metaText(TextAlign.start),
                ],
                if (parts.stats && _stats.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _statsRow(WrapAlignment.start),
                ],
              ],
            ),
            alignment: Alignment.bottomLeft,
          ),
        ),
      ],
    );
  }

  /// แบบการ์ด Strava — เส้นทางที่เดินเป็นพระเอก กราฟความสูง ตัวเลขใหญ่ด้านล่าง
  /// เหรียญย่อไปอยู่มุมขวาบนข้างชื่อทริป
  Widget _routeLayout() {
    final route = medal.route!;
    final elevations = route.elevations;
    final stats = parts.stats ? _bigStats : const <StoryStat>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _logoRow(),
                  const SizedBox(height: 12),
                  ..._textBlock(
                    align: CrossAxisAlignment.start,
                    nameSize: _nameSize(22, 18),
                    includeStats: false,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _medal(96),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: MedalRouteView(
              route: route,
              color: _onPaper ? medal.design.color : Colors.white,
            ),
          ),
        ),
        if (elevations != null) ...[
          SizedBox(
            height: 44,
            child: MedalElevationView(
              elevations: elevations,
              color: _onPaper ? medal.design.color : Colors.white,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (stats.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, stat) in stats.indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == stats.length - 1 ? 0 : 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stat.label,
                          style: appFont(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _soft,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            stat.value,
                            maxLines: 1,
                            style: appFont(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (medal.personal != null)
            _gpsCaption(TextAlign.start)
          else if (route.isRecorded == false)
            Text(
              'เส้นทางของทริป',
              style: appFont(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: _soft,
              ),
            ),
        ],
      ],
    );
  }

  // ── ชิ้นส่วน ────────────────────────────────────────────────────────────

  /// ก้อนเนื้อหาถูกย่อทั้งก้อนเมื่อยาวจนล้น — การ์ดต้องออกมา 360×640 เสมอ
  Widget _fitted(Widget child, {Alignment alignment = Alignment.center}) {
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: SizedBox(width: kStoryCardWidth - 56, child: child),
      ),
    );
  }

  Widget _logoRow() {
    // เว้นความสูงไว้เท่าเดิมแม้ซ่อนโลโก้ เหรียญจะได้ไม่กระโดดขึ้นลงตอนสลับ
    return SizedBox(
      height: 36,
      child: parts.logo
          ? Align(
              alignment: Alignment.centerLeft,
              child: StoryLogo(
                height: 36,
                tint: _onPaper ? null : Colors.white,
              ),
            )
          : null,
    );
  }

  Widget _medal(double base) {
    return MedalArt(
      design: medal.design,
      // ไม่ให้เกินความกว้างของเนื้อหา — "เหรียญเต็มตา" ขยายสุดจะกว้างกว่าการ์ด
      size: math.min(base * _scale, kStoryCardWidth - 56),
      imageScale: kShareCardPixelRatio,
      imageDecodeWidth: kMedalStoryDecodeWidth,
      year: medal.buddhistYear,
    );
  }

  double _nameSize(double normal, double long) =>
      medal.design.name.characters.length > 18 ? long : normal;

  String get _meta => [
    if (medal.placeLabel.isNotEmpty) medal.placeLabel,
    if (medal.dateLabel.isNotEmpty) medal.dateLabel,
  ].join('  ·  ');

  /// ตัวเลขบนการ์ด — ของที่เดินจริง (GPS) มาก่อนเสมอ ไม่มีค่อยใช้ตัวเลขของ
  /// เส้นทางทริป ซึ่งทุกคนในรอบได้เท่ากัน
  List<StoryStat> get _stats {
    final personal = medal.personal;

    if (personal != null) {
      final moving = formatMovingTime(personal.movingSeconds);

      return [
        StoryStat('${_trim(personal.distanceKm)} กม.', 'ระยะทาง'),
        if (moving != null) StoryStat(moving, 'เวลาเดิน'),
        if (personal.elevationGainM > 0)
          StoryStat('${_thousands(personal.elevationGainM)} ม.', 'ไต่ขึ้น'),
      ];
    }

    return _tripStats;
  }

  /// ตัวเลขใหญ่ของการ์ดแบบเส้นทาง — เหมือน [_stats] แต่เวลาเดินแบบสั้น
  List<StoryStat> get _bigStats {
    final personal = medal.personal;
    if (personal == null) return _stats;

    return [
      for (final stat in _stats)
        stat.label == 'เวลาเดิน'
            ? StoryStat(
                formatMovingTimeShort(personal.movingSeconds) ?? stat.value,
                stat.label,
              )
            : stat,
    ];
  }

  List<StoryStat> get _tripStats => [
    if ((medal.distanceKm ?? 0) > 0)
      StoryStat('${_trim(medal.distanceKm!)} กม.', 'ระยะทาง'),
    if ((medal.elevationGainM ?? 0) > 0)
      StoryStat('${_thousands(medal.elevationGainM!)} ม.', 'ความสูงสะสม'),
    if ((medal.durationDays ?? 0) > 0)
      StoryStat('${medal.durationDays} วัน', 'ระยะเวลา'),
  ];

  List<Widget> _textBlock({
    required CrossAxisAlignment align,
    required double nameSize,
    bool includeStats = true,
    bool includeMeta = true,
  }) {
    final center = align == CrossAxisAlignment.center;
    final textAlign = center ? TextAlign.center : TextAlign.start;

    return [
      // ถ่างตัวอักษรเฉพาะส่วนอังกฤษ — ข้อความไทยที่ถูกถ่างจะถูกฉีกสระออกจาก
      // พยัญชนะ ("ครั้งที่" กลายเป็น "ค รั้ ง")
      // บรรทัดเดียวเสมอ ย่อแทนการตัดบรรทัด — "ครั้งที่ 2" ที่ตกไปอยู่บรรทัดใหม่
      // เหลือเลข "2" โดด ๆ อ่านไม่รู้เรื่อง
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text.rich(
          maxLines: 1,
          softWrap: false,
          TextSpan(
            children: [
              TextSpan(
                text: medal.finisherLabel.toUpperCase(),
                style: const TextStyle(letterSpacing: 1.2),
              ),
              if (parts.attempt && medal.attempt > 1)
                TextSpan(text: '  ·  ครั้งที่ ${medal.attempt}'),
            ],
          ),
          textAlign: textAlign,
          style: appFont(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _onPaper ? _goldDeep : _goldLight,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        medal.design.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: appFont(
          fontSize: nameSize,
          fontWeight: FontWeight.w800,
          color: _ink,
          height: 1.28,
        ),
      ),
      if (parts.holder) ...[
        const SizedBox(height: 8),
        Text(
          medal.holderName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: appFont(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
      if (_showRecords) ...[
        const SizedBox(height: 10),
        _recordsLine(center ? WrapAlignment.center : WrapAlignment.start),
      ],
      if (includeMeta && parts.meta && _meta.isNotEmpty) ...[
        const SizedBox(height: 4),
        _metaText(textAlign),
      ],
      if (includeStats && parts.stats && _stats.isNotEmpty) ...[
        const SizedBox(height: 18),
        _statsRow(center ? WrapAlignment.center : WrapAlignment.start),
      ],
    ];
  }

  Widget _metaText(TextAlign align) {
    return Text(
      _meta,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: appFont(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: _soft,
        height: 1.4,
      ),
    );
  }

  bool get _showRecords => parts.records && medal.records.isNotEmpty;

  /// ป้ายสถิติส่วนตัวสูงสุด — ถ้วยทอง + "เดินไกลที่สุดของฉัน"
  Widget _recordsLine(WrapAlignment alignment) {
    final gold = _onPaper ? _goldDeep : _goldLight;

    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final record in medal.records)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: _onPaper ? 0.12 : 0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, size: 14, color: gold),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    medalRecordLabel(record),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// "จาก GPS ที่ฉันบันทึก" — บอกว่าตัวเลขเป็นของคนนี้ ไม่ใช่ของเส้นทางทริป
  Widget _gpsCaption(TextAlign align) {
    return Text(
      'จาก GPS ที่ฉันบันทึก',
      textAlign: align,
      style: appFont(fontSize: 10.5, fontWeight: FontWeight.w600, color: _soft),
    );
  }

  Widget _statsRow(WrapAlignment alignment) {
    final center = alignment == WrapAlignment.center;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        _statsWrap(alignment),
        if (medal.personal != null) ...[
          const SizedBox(height: 6),
          _gpsCaption(center ? TextAlign.center : TextAlign.start),
        ],
      ],
    );
  }

  Widget _statsWrap(WrapAlignment alignment) {
    return Wrap(
      alignment: alignment,
      spacing: 22,
      runSpacing: 8,
      children: [
        for (final stat in _stats)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: alignment == WrapAlignment.center
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                stat.value,
                style: appFont(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              Text(
                stat.label,
                style: appFont(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _soft,
                ),
              ),
            ],
          ),
      ],
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
