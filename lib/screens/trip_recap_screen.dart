import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/trip_story_card.dart';
import '../widgets/trip_story_share_sheet.dart';

/// สรุปทริปแบบ story (ลุยเลเขา Recap) — เปิดหลังจบทริป กดปัดทีละสไลด์
/// จบด้วยการ์ดสรุปที่แชร์/เซฟรูปได้ เพื่ออวดเพื่อน (UGC + โฆษณาฟรีให้แบรนด์).
class TripRecapScreen extends StatefulWidget {
  final String bookingRef;

  const TripRecapScreen({super.key, required this.bookingRef});

  static Future<void> open(BuildContext context, String bookingRef) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TripRecapScreen(bookingRef: bookingRef),
      ),
    );
  }

  @override
  State<TripRecapScreen> createState() => _TripRecapScreenState();
}

class _TripRecapScreenState extends State<TripRecapScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppProvider>().bookingRecap(widget.bookingRef);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snap.hasError || snap.data == null) {
            return _ErrorView(onClose: () => Navigator.of(context).pop());
          }
          return _RecapStory(data: snap.data!, bookingRef: widget.bookingRef);
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onClose;
  const _ErrorView({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.landscape_rounded,
              color: Colors.white38,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'ยังเปิดสรุปทริปไม่ได้ตอนนี้',
              style: appFont(
                color: Colors.white70,
                fontSize: AppText.sizeSubtitle,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClose,
              child: Text('ปิด', style: appFont(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// สีพื้นของแต่ละสไลด์ — ใช้ตอนไม่มีรูปรีวิวให้วาง (ทริปที่ยังไม่มีใครรีวิว
/// พร้อมรูป) และเป็นสีรองใต้รูประหว่างที่รูปยังโหลดไม่เสร็จ
const List<Color> _slideColors = [
  Color(0xFF065F46), // emerald (intro)
  Color(0xFFB45309), // amber (days)
  Color(0xFF1E3A8A), // blue (distance)
  Color(0xFF6D28D9), // purple (elevation)
  Color(0xFF9D174D), // pink (difficulty/travelers)
  Color(0xFF0E7490), // cyan (photos)
  Color(0xFF7C2D12), // sunset (summary)
];

/// รูปหนึ่งใบจากรีวิว พร้อมชื่อคนถ่าย — ต้องให้เครดิตทุกครั้งที่เอามาแสดง
class _ReviewPhoto {
  final String url;
  final String author;
  final bool sameRound;

  const _ReviewPhoto({
    required this.url,
    required this.author,
    required this.sameRound,
  });
}

class _RecapStory extends StatefulWidget {
  final Map<String, dynamic> data;
  final String bookingRef;

  const _RecapStory({required this.data, required this.bookingRef});

  @override
  State<_RecapStory> createState() => _RecapStoryState();
}

class _RecapStoryState extends State<_RecapStory> {
  final PageController _pc = PageController();
  int _index = 0;

  late final List<Widget> _slides = _buildSlides();

  // ---- helpers ----
  Map<String, dynamic> get _trip =>
      Map<String, dynamic>.from(widget.data['trip'] as Map? ?? {});

  String _text(dynamic v, [String fallback = '']) =>
      (v?.toString().trim().isNotEmpty ?? false)
      ? v.toString().trim()
      : fallback;

  num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

  String _fmt(num n) => NumberFormat('#,###.##').format(n);

  String get _tripTitle => _text(_trip['title'], 'ทริปเดินป่า');

  String get _dateLabel {
    final dep = DateTime.tryParse(_text(widget.data['departure_date']));
    final ret = DateTime.tryParse(_text(widget.data['return_date']));
    if (dep == null) return '';
    if (ret != null && ret != dep) {
      return '${thaiDateShort(dep)} – ${thaiDateFull(ret)}';
    }
    return thaiDateFull(dep);
  }

  List<String> get _photos => (widget.data['photos'] as List? ?? [])
      .map((e) => ApiConfig.mediaUrl(e))
      .where((e) => e.isNotEmpty)
      .toList();

  /// รูปจากรีวิวของคนที่ไปทริปนี้ — รอบเดียวกันมาก่อน (จัดลำดับมาจาก API)
  late final List<_ReviewPhoto> _reviewPhotos =
      (widget.data['review_photos'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(
            (e) => _ReviewPhoto(
              url: ApiConfig.mediaUrl(e['url']),
              author: _text(e['user_name'], 'เพื่อนร่วมทาง'),
              sameRound: e['same_round'] == true,
            ),
          )
          .where((e) => e.url.isNotEmpty)
          .toList();

  /// ตัวเด่นของการ์ดจบทริป — ระยะทางมาก่อน ถ้ารอบนั้นไม่ได้บันทึกไว้ก็ใช้จำนวนวัน
  StoryCountdown get _recapHighlight => StoryCountdown.recap(
    format: _fmt,
    distanceKm: _num(widget.data['distance_km']),
    days: _num(widget.data['duration_days']),
  );

  /// ตัวเลขรองท้ายการ์ด — ไม่เอาตัวที่ถูกเชิดเป็นตัวเด่นไปแล้วมาซ้ำ
  List<StoryStat> get _recapStats {
    final days = _num(widget.data['duration_days']);
    final elevation = _num(widget.data['elevation_gain_m']);
    final travelers = _num(widget.data['total_travelers']) ?? 0;
    final distance = _num(widget.data['distance_km']);
    final daysIsHeadline = distance == null || distance <= 0;

    return [
      if (!daysIsHeadline && days != null && days > 0)
        StoryStat('${_fmt(days)} วัน', 'บนเส้นทาง'),
      if (elevation != null && elevation > 0)
        StoryStat('${_fmt(elevation)} ม.', 'ความสูงสะสม'),
      if (travelers > 0) StoryStat('${_fmt(travelers)} คน', 'เพื่อนร่วมทาง'),
    ];
  }

  /// รูปพื้นหลังของสไลด์ที่ [index] — วนรูปที่มีให้แต่ละสไลด์ได้คนละใบ
  ///
  /// สไลด์สุดท้ายเว้นไว้เป็นพื้นสี เพราะการ์ดแชร์บนนั้นมีรูปปกของตัวเองอยู่แล้ว
  /// ซ้อนรูปอีกชั้นจะอ่านไม่ออกและเครดิตจะไปชนปุ่มแชร์
  _ReviewPhoto? _backdropFor(int index) {
    if (_reviewPhotos.isEmpty || index >= _slides.length - 1) return null;
    return _reviewPhotos[index % _reviewPhotos.length];
  }

  List<Widget> _buildSlides() {
    final days = _num(widget.data['duration_days']);
    final distance = _num(widget.data['distance_km']);
    final elevation = _num(widget.data['elevation_gain_m']);
    final group = _num(widget.data['group_size']) ?? 0;
    final travelers = _num(widget.data['total_travelers']) ?? 0;
    final diffLabel = _text(_trip['difficulty_label']);

    final slides = <Widget>[_IntroSlide(title: _tripTitle, date: _dateLabel)];

    if (days != null && days > 0) {
      slides.add(
        _StatSlide(
          emoji: '⛺️',
          bigValue: _fmt(days),
          unit: 'วัน',
          headline: 'บนเส้นทางธรรมชาติ',
          sub: 'ทุกวันคือความทรงจำ',
        ),
      );
    }
    if (distance != null && distance > 0) {
      slides.add(
        _StatSlide(
          emoji: '🥾',
          bigValue: _fmt(distance),
          unit: 'กม.',
          headline: 'ระยะทางที่คุณพิชิต',
          sub: 'ก้าวแล้วก้าวเล่า จนถึงเส้นชัย',
        ),
      );
    }
    if (elevation != null && elevation > 0) {
      slides.add(
        _StatSlide(
          emoji: '⛰️',
          bigValue: _fmt(elevation),
          unit: 'ม.',
          headline: 'ความสูงสะสมที่ปีนขึ้น',
          sub: 'สูงกว่าที่คิด แต่คุณทำได้',
        ),
      );
    }
    slides.add(
      _DifficultySlide(
        difficultyLabel: diffLabel,
        groupSize: group.toInt(),
        travelers: travelers.toInt(),
      ),
    );

    // ฟีดของรอบมาก่อน ถ้ารอบนี้ยังไม่มีใครโพสต์ก็ใช้รูปจากรีวิวแทน
    final gridPhotos = _photos.isNotEmpty
        ? _photos.take(6).toList()
        : _reviewPhotos.map((e) => e.url).take(6).toList();
    if (gridPhotos.isNotEmpty) {
      slides.add(
        _PhotosSlide(photos: gridPhotos, fromReviews: _photos.isEmpty),
      );
    }

    slides.add(
      _SummarySlide(
        title: _tripTitle,
        location: _text(_trip['location']),
        date: _dateLabel,
        highlight: _recapHighlight,
        stats: _recapStats,
        cover: ApiConfig.mediaUrl(_trip['cover_image']),
        hasReviewed: widget.data['has_reviewed'] == true,
        onShare: _share,
      ),
    );

    return slides;
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
  }

  void _prev() {
    if (_index > 0) {
      _pc.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
  }

  /// เปิด share sheet ใบเดียวกับการ์ดนับถอยหลังก่อนไป — ได้สไตล์ทั้งห้า
  /// การจัดรูปของตัวเอง และแถบความโปร่งใสมาใช้กับการ์ดจบทริปด้วยทั้งชุด
  Future<void> _share() async {
    HapticFeedback.mediumImpact();

    await showTripRecapShareSheet(
      context,
      tripTitle: _tripTitle,
      location: _text(_trip['location']),
      highlight: _recapHighlight,
      dateLabel: _dateLabel,
      stats: _recapStats,
      coverImageUrl: ApiConfig.mediaUrl(_trip['cover_image']),
      bookingRef: widget.bookingRef,
    );
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // โหลดรูปพื้นหลังไว้ล่วงหน้า ไม่งั้นสไลด์ถัดไปจะโผล่เป็นพื้นสีก่อนแล้วรูป
    // ค่อยตามมาทีหลัง — สะดุดตาเพราะคนปัดเร็วกว่ารูปโหลด
    for (final photo in _reviewPhotos) {
      precacheImage(NetworkImage(photo.url), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = _backdropFor(_index);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          color: _slideColors[_index % _slideColors.length],
        ),
        if (backdrop != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            // SizedBox.expand เพราะ Stack ข้างใน AnimatedSwitcher ส่งกรอบแบบ
            // หลวมลงมา ปล่อยไว้รูปจะกางแค่เท่าอัตราส่วนของตัวเอง ไม่เต็มจอ
            child: SizedBox.expand(
              key: ValueKey(backdrop.url),
              child: Image.network(
                backdrop.url,
                fit: BoxFit.cover,
                // จำกัดขนาดที่ถอดรหัส — รูปรีวิวเป็นไฟล์เต็มจากมือถือ เปิดดิบ ๆ
                // หลายใบแล้วแอปโดนระบบฆ่าเพราะหน่วยความจำ
                cacheWidth: _decodeWidth(context),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        // ม่านดำทับรูปให้ตัวเลขขาวตัวใหญ่ยังอ่านออกบนรูปอะไรก็ได้
        if (backdrop != null)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8C000000),
                  Color(0x66000000),
                  Color(0xD9000000),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
        SafeArea(
          child: Stack(
            children: [
              // Tap zones: left = back, right = forward
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _prev,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _next,
                      ),
                    ),
                  ],
                ),
              ),
              PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _index = i),
                children: _slides,
              ),
              // Progress bars
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  children: List.generate(_slides.length, (i) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned(
                top: 20,
                right: 12,
                child: IconButton(
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              // เครดิตเจ้าของรูป — ไม่รับ touch เพราะทั้งจอเป็นปุ่มปัดสไลด์
              if (backdrop != null)
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: 14,
                  child: IgnorePointer(child: _PhotoCredit(photo: backdrop)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// ความกว้างที่พอสำหรับเต็มจอ — เผื่อจอความละเอียดสูงแต่ไม่เกิน 1440
  static int _decodeWidth(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    return width.clamp(720, 1440).round();
  }
}

class _PhotoCredit extends StatelessWidget {
  final _ReviewPhoto photo;
  const _PhotoCredit({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.photo_camera_rounded,
          size: 13,
          color: Colors.white.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            photo.sameRound
                ? 'รูปจากรีวิวของ ${photo.author} · รอบเดียวกับคุณ'
                : 'รูปจากรีวิวของ ${photo.author}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================ Slides ============================

class _IntroSlide extends StatelessWidget {
  final String title;
  final String date;
  const _IntroSlide({required this.title, required this.date});

  @override
  Widget build(BuildContext context) {
    return _SlidePad(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏔️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text(
            'สรุปทริปของคุณ',
            style: appFont(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: AppText.sizeTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: appFont(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              date,
              style: appFont(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 40),
          Row(
            children: [
              Text(
                'แตะเพื่อดูต่อ',
                style: appFont(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: AppText.sizeLabel,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.touch_app_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatSlide extends StatelessWidget {
  final String emoji;
  final String bigValue;
  final String unit;
  final String headline;
  final String sub;

  const _StatSlide({
    required this.emoji,
    required this.bigValue,
    required this.unit,
    required this.headline,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return _SlidePad(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 28),
          Text(
            headline,
            style: appFont(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: AppText.sizeTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: bigValue,
                  style: appFont(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ),
                TextSpan(
                  text: '  $unit',
                  style: appFont(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: AppText.sizeHero,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            sub,
            style: appFont(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultySlide extends StatelessWidget {
  final String difficultyLabel;
  final int groupSize;
  final int travelers;

  const _DifficultySlide({
    required this.difficultyLabel,
    required this.groupSize,
    required this.travelers,
  });

  @override
  Widget build(BuildContext context) {
    return _SlidePad(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤝', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 28),
          if (difficultyLabel.isNotEmpty) ...[
            Text(
              'เส้นทาง',
              style: appFont(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'สาย$difficultyLabel',
              style: appFont(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 28),
          ],
          Text(
            'คุณไม่ได้เดินคนเดียว',
            style: appFont(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: AppText.sizeTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ทริปนี้มีเพื่อนร่วมทาง $travelers คน',
            style: appFont(
              color: Colors.white,
              fontSize: AppText.sizeH1,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (groupSize > 1) ...[
            const SizedBox(height: 6),
            Text(
              'มากับกลุ่มของคุณ $groupSize คน',
              style: appFont(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotosSlide extends StatelessWidget {
  final List<String> photos;

  /// true = รูปมาจากรีวิว ไม่ใช่ฟีดของรอบ — คำบรรยายใต้หัวเรื่องต่างกัน
  final bool fromReviews;

  const _PhotosSlide({required this.photos, required this.fromReviews});

  @override
  Widget build(BuildContext context) {
    return _SlidePad(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📸', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'ภาพแห่งความทรงจำ',
            style: appFont(
              color: Colors.white,
              fontSize: AppText.sizeH1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fromReviews ? 'จากรีวิวของเพื่อนร่วมทาง' : 'จากเพื่อนร่วมทริปในฟีด',
            style: appFont(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: AppText.sizeBody,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: photos.length <= 2 ? photos.length.clamp(1, 2) : 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: photos.map((url) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  // ช่องในตารางกว้างราว 1/3 จอ ไม่ต้องถอดรหัสเต็มไฟล์
                  cacheWidth: 480,
                  errorBuilder: (_, _, _) =>
                      Container(color: Colors.white.withValues(alpha: 0.12)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// สไลด์สุดท้าย: การ์ดที่เอาไปลงสตอรี่ได้ + ปุ่มแชร์
///
/// การ์ดเป็นใบเดียวกับ [TripStoryCard] ที่ใช้ตอนนับถอยหลังก่อนไป จึงเป็นสัดส่วน
/// 9:16 ตั้งแต่ต้น ไม่ใช่กล่องกว้างเท่าจอแบบเดิมที่พอลงสตอรี่แล้วโดนครอป และ
/// ภาพที่ได้ก็ขนาดเท่ากันทุกเครื่อง
class _SummarySlide extends StatelessWidget {
  final String title;
  final String location;
  final String date;
  final StoryCountdown highlight;
  final List<StoryStat> stats;
  final String cover;
  final bool hasReviewed;
  final VoidCallback onShare;

  const _SummarySlide({
    required this.title,
    required this.location,
    required this.date,
    required this.highlight,
    required this.stats,
    required this.cover,
    required this.hasReviewed,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return _SlidePad(
      child: Column(
        children: [
          // พรีวิวย่อให้พอดีสไลด์ ส่วนการ์ดจริงยังวาดที่ 360×640 เท่าเดิม
          Expanded(
            child: Center(
              child: FittedBox(
                child: TripStoryCard.recap(
                  tripTitle: title,
                  location: location,
                  highlight: highlight,
                  dateLabel: date,
                  stats: stats,
                  coverImage: cover.isEmpty ? null : NetworkImage(cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onShare,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.ios_share_rounded,
                    size: 19,
                    color: Color(0xFF7C2D12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'แชร์สรุปทริป',
                    style: appFont(
                      color: const Color(0xFF7C2D12),
                      fontSize: AppText.sizeSubtitle,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasReviewed
                ? 'ขอบคุณที่ร่วมเดินทางกับเรา 💚'
                : 'อย่าลืมรีวิวทริปนี้ให้เพื่อน ๆ ด้วยนะ',
            textAlign: TextAlign.center,
            style: appFont(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidePad extends StatelessWidget {
  final Widget child;
  const _SlidePad({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 40),
      child: child,
    );
  }
}
