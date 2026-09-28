import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/medal_social.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/share_card.dart';
import '../widgets/app_snack.dart';
import '../widgets/medal_art.dart';
import '../widgets/trip_story_card.dart';

/// สีพื้นของแต่ละสไลด์ — สีทึบเรียบตามธีม (ไม่ไล่เฉด)
const List<Color> _slideColors = [
  Color(0xFF065F46),
  Color(0xFF0F3D57),
  Color(0xFF5B3A21),
  Color(0xFF3B2F63),
  Color(0xFF7A2E1E),
  Color(0xFF1F2A24),
  Color(0xFF0E1412),
];

/// ความกว้างที่ใช้ถอดรหัสภาพเหรียญออกแบบเองบนการ์ดแชร์ — ตรงกับตอน precache
const double _cardMedalDecodeWidth = 120;

/// สรุปทั้งปี (Year in Review) — สไลด์แบบสตอรี่ ปิดท้ายด้วยการ์ดแชร์ 9:16
///
/// แตะครึ่งขวาเพื่อไปต่อ ครึ่งซ้ายเพื่อย้อน หรือปัดก็ได้ ปีที่มีเหรียญมากกว่า
/// หนึ่งปีสลับดูได้จากชิปบนสไลด์แรก
class YearReviewScreen extends StatefulWidget {
  /// ค.ศ. — null = ปีปัจจุบัน
  final int? year;

  const YearReviewScreen({super.key, this.year});

  @override
  State<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends State<YearReviewScreen> {
  final PageController _pages = PageController();
  final GlobalKey _cardKey = GlobalKey();
  YearReview? _review;
  bool _loading = true;
  bool _error = false;
  bool _sharing = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(widget.year));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load(int? year) async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final review = await context.read<AppProvider>().fetchYearReview(year);
      if (!mounted) return;
      await _warmImages(review);
      if (!mounted) return;

      setState(() {
        _review = review;
        _loading = false;
        _page = 0;
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// `toImage` จับเฉพาะสิ่งที่วาดเสร็จแล้ว — โลโก้กับภาพเหรียญออกแบบเองต้อง
  /// เข้าแคชก่อน ไม่งั้นหายจาก PNG เงียบ ๆ
  Future<void> _warmImages(YearReview review) async {
    Future<void> warm(ImageProvider provider) async {
      try {
        await precacheImage(provider, context);
      } catch (_) {}
    }

    // โหลดพร้อมกันและจำกัดเวลารวม — เน็ตช้าต้องไม่ทำให้หน้าค้างอยู่ที่วงหมุน
    // ภาพที่ยังไม่มาแค่อาจขาดจากการ์ดที่แชร์ ส่วนสไลด์ยังวาดเองได้ตามปกติ
    await Future.wait([
      warm(const AssetImage(kStoryLogoAsset)),
      for (final medal in review.medals.take(_YearStoryCard.maxMedals))
        if (medal.design.imageUrl case final url?)
          warm(
            medalImageProvider(
              url,
              _cardMedalDecodeWidth,
              kShareCardPixelRatio,
            ),
          ),
    ]).timeout(const Duration(seconds: 4), onTimeout: () => const []);
  }

  void _go(int delta, int count) {
    final next = (_page + delta).clamp(0, count - 1);
    if (next == _page) return;
    HapticFeedback.selectionClick();
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _share(YearReview review) async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);

    try {
      await WidgetsBinding.instance.endOfFrame;
      await shareWidgetAsPng(
        boundaryKey: _cardKey,
        fileName: 'luilaykhao_year_${review.year}.png',
        text:
            'ปี ${review.yearLabel} ของฉัน: พิชิต ${review.tripsCount} ทริป '
            '${_trim(review.distanceKm)} กม. 🏔️\n#ลุยเลเขา',
      );
    } catch (_) {
      if (mounted) AppSnack.error(context, 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    final slides = review == null ? const <Widget>[] : _slides(review);
    final color = _slideColors[_page % _slideColors.length];

    return Scaffold(
      backgroundColor: color,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _error || review == null
              ? _ErrorView(onRetry: () => _load(widget.year))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Progress(
                              count: slides.length,
                              index: _page,
                            ),
                          ),
                          IconButton(
                            tooltip: 'ปิด',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final width = MediaQuery.sizeOf(context).width;
                          _go(
                            details.localPosition.dx > width / 2 ? 1 : -1,
                            slides.length,
                          );
                        },
                        child: PageView(
                          controller: _pages,
                          onPageChanged: (i) => setState(() => _page = i),
                          children: slides,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _slides(YearReview r) {
    final intro = _Slide(
      kicker: 'สรุปปี ${r.yearLabel}',
      headline: r.isEmpty ? 'ยังไม่มีทริปที่พิชิต' : 'ปีนี้ของ${r.holderName}',
      body: r.isEmpty
          ? 'ปีนี้ยังไม่มีทริปที่เดินจบ — ทริปแรกที่พิชิตจะมาอยู่ที่นี่'
          : 'พิชิตไป ${r.tripsCount} ทริป ได้เหรียญ ${r.medals.length} เหรียญ\nแตะเพื่อดูว่าปีนี้คุณไปไกลแค่ไหน',
      footer:
          r.availableYears.length > 1 ||
              (r.isEmpty && r.availableYears.isNotEmpty)
          ? _YearChips(
              years: {...r.availableYears, r.year}.toList()
                ..sort((a, b) => b.compareTo(a)),
              selected: r.year,
              onSelected: _load,
            )
          : null,
    );

    if (r.isEmpty) return [intro];

    return [
      intro,
      _Slide(
        kicker: 'ระยะทางทั้งปี',
        big: _trim(r.distanceKm),
        unit: 'กม.',
        body: r.climbM > 0
            ? 'ไต่ความสูงสะสม ${thousands(r.climbM)} ม.\nเท่ากับขึ้นดอยอินทนนท์ ${_trim(r.inthanonMultiple)} รอบ'
            : null,
        footnote: r.gpsTrips > 0
            ? '${r.gpsTrips} ทริปนับจาก GPS ที่คุณบันทึกเอง'
            : null,
      ),
      _Slide(
        kicker: 'เวลาบนเส้นทาง',
        big: '${r.daysOnTrail}',
        unit: 'วัน',
        body: [
          'ออกลุย ${r.monthsActive} เดือนจาก 12 เดือน',
          if (r.topMonth != null && r.topMonthTrips > 1)
            'เดือนที่ลุยหนักสุดคือ${r.topMonth} (${r.topMonthTrips} ทริป)',
        ].join('\n'),
      ),
      if (r.longest != null || r.highest != null || r.places.isNotEmpty)
        _Slide(
          kicker: 'ไฮไลต์ของปี',
          lines: [
            if (r.longest != null)
              (
                'ไกลที่สุด',
                '${r.longest!.name} · ${_trim(r.longest!.distanceKm)} กม.',
              ),
            if (r.highest != null)
              (
                'สูงที่สุดที่ไปถึง',
                '${r.highest!.name} · ${thousands(r.highest!.elevationM)} ม.',
              ),
            if (r.places.isNotEmpty) ('ไปมาแล้ว', r.places.join(' · ')),
          ],
        ),
      if (r.companionsCount > 0 ||
          r.kudosReceived > 0 ||
          r.challengesCompleted > 0)
        _Slide(
          kicker: 'ไม่ได้ลุยคนเดียว',
          lines: [
            if (r.companionsCount > 0)
              (
                'เพื่อนร่วมทาง',
                '${r.companionsCount} คนที่พิชิตรอบเดียวกับคุณ',
              ),
            if (r.kudosReceived > 0)
              ('เสียงปรบมือ', '👏 ${r.kudosReceived} ครั้งจากเพื่อนร่วมทริป'),
            if (r.challengesCompleted > 0)
              ('ชาเลนจ์', '🏆 สำเร็จ ${r.challengesCompleted} ชาเลนจ์'),
          ],
        ),
      _MedalsSlide(review: r),
      _ShareSlide(
        review: r,
        cardKey: _cardKey,
        sharing: _sharing,
        onShare: () => _share(r),
      ),
    ];
  }
}

// ── สไลด์ ──────────────────────────────────────────────────────────────────

class _Slide extends StatelessWidget {
  final String kicker;
  final String? headline;
  final String? big;
  final String? unit;
  final String? body;
  final String? footnote;
  final List<(String, String)> lines;
  final Widget? footer;

  const _Slide({
    required this.kicker,
    this.headline,
    this.big,
    this.unit,
    this.body,
    this.footnote,
    this.lines = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: 0.75);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              kicker,
              style: appFont(
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF7CD78),
              ),
            ),
            const SizedBox(height: 10),
            if (headline != null)
              Text(
                headline!,
                style: appFont(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
            if (big != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      big!,
                      style: appFont(
                        fontSize: 96,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        unit!,
                        style: appFont(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (body != null && body!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                body!,
                style: appFont(
                  fontSize: AppText.sizeH2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.45,
                ),
              ),
            ],
            for (final (label, value) in lines) ...[
              const SizedBox(height: 18),
              Text(
                label,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w600,
                  color: soft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: appFont(
                  fontSize: AppText.sizeH2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ],
            if (footnote != null) ...[
              const SizedBox(height: 14),
              Text(
                footnote!,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                  color: soft,
                ),
              ),
            ],
            const Spacer(),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class _MedalsSlide extends StatelessWidget {
  final YearReview review;

  const _MedalsSlide({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เหรียญของปี ${review.yearLabel}',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF7CD78),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${review.medals.length} เหรียญ',
            style: appFont(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const columns = 3;
                const spacing = 12.0;
                final size =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: 14,
                    children: [
                      for (final medal in review.medals)
                        SizedBox(
                          width: size,
                          child: Column(
                            children: [
                              MedalArt(
                                design: medal.design,
                                size: size * 0.86,
                                year: medal.buddhistYear,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                medal.design.name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: appFont(
                                  fontSize: AppText.sizeCaption,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSlide extends StatelessWidget {
  final YearReview review;
  final GlobalKey cardKey;
  final bool sharing;
  final VoidCallback onShare;

  const _ShareSlide({
    required this.review,
    required this.cardKey,
    required this.sharing,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = math.min(
                  constraints.maxWidth / kStoryCardWidth,
                  constraints.maxHeight / kStoryCardHeight,
                );

                return Center(
                  child: SizedBox(
                    width: kStoryCardWidth * scale,
                    height: kStoryCardHeight * scale,
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: cardKey,
                        child: _YearStoryCard(review: review),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: sharing ? null : onShare,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0E1412),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              icon: sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(
                sharing ? 'กำลังเตรียม...' : 'แชร์สรุปปีนี้',
                style: appFont(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0E1412),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดสรุปทั้งปี 9:16 (PNG 1080×1920) — ไม่มีคำชวนจอง เป็นของคนที่พิชิต
class _YearStoryCard extends StatelessWidget {
  static const int maxMedals = 6;

  final YearReview review;

  const _YearStoryCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('${review.tripsCount}', 'ทริป'),
      (_trim(review.distanceKm), 'กม.'),
      (thousands(review.climbM), 'ม. ที่ไต่'),
      ('${review.daysOnTrail}', 'วันบนเส้นทาง'),
    ];
    final medals = review.medals.take(maxMedals).toList();
    final soft = Colors.white.withValues(alpha: 0.75);

    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: kStoryCardWidth,
        height: kStoryCardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          child: ColoredBox(
            color: const Color(0xFF0E1412),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StoryLogo(height: 36, tint: Colors.white),
                  // ก้อนเนื้อหาย่อทั้งก้อนเมื่อยาวเกิน — การ์ดต้องเป็น 360×640 เสมอ
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: kStoryCardWidth - 56,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'สรุปปี ${review.yearLabel}',
                                style: appFont(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFF7CD78),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                review.holderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: appFont(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 22),
                              // สองแถว ๆ ละสองช่อง สูงตามเนื้อหา — GridView ตรึงความสูง
                              // ช่องไว้ ตัวเลขใหญ่ + ป้ายจึงล้นช่องได้
                              for (var row = 0; row < stats.length; row += 2)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: row + 2 < stats.length ? 14 : 0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final (value, label)
                                          in stats.skip(row).take(2))
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  value,
                                                  style: appFont(
                                                    fontSize: 34,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                label,
                                                style: appFont(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: soft,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              if (review.inthanonMultiple > 0) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'ไต่สะสมเท่ากับขึ้นดอยอินทนนท์ ${_trim(review.inthanonMultiple)} รอบ',
                                  style: appFont(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: soft,
                                  ),
                                ),
                              ],
                              if (medals.isNotEmpty) ...[
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    for (final medal in medals)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: MedalArt(
                                          design: medal.design,
                                          size: 46,
                                          year: medal.buddhistYear,
                                          imageScale: kShareCardPixelRatio,
                                          imageDecodeWidth:
                                              _cardMedalDecodeWidth,
                                        ),
                                      ),
                                    if (review.medals.length > maxMedals)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(
                                          '+${review.medals.length - maxMedals}',
                                          style: appFont(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (review.places.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  review.places.join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: appFont(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: soft,
                                    height: 1.4,
                                  ),
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
          ),
        ),
      ),
    );
  }
}

// ── ชิ้นส่วน ────────────────────────────────────────────────────────────────

class _Progress extends StatelessWidget {
  final int count;
  final int index;

  const _Progress({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i <= index ? 0.95 : 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ),
      ],
    );
  }
}

class _YearChips extends StatelessWidget {
  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelected;

  const _YearChips({
    required this.years,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final year in years)
          GestureDetector(
            onTap: year == selected ? null : () => onSelected(year),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: year == selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                'ปี ${year + 543}',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: year == selected
                      ? const Color(0xFF065F46)
                      : Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            'โหลดสรุปปีไม่สำเร็จ',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: Colors.white),
            child: Text(
              'ลองใหม่',
              style: appFont(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF065F46),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(
              'ปิด',
              style: appFont(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

String _trim(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
