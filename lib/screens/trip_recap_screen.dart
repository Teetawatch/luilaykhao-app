import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

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
          return _RecapStory(data: snap.data!);
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
            const Icon(Icons.landscape_rounded, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              'ยังเปิดสรุปทริปไม่ได้ตอนนี้',
              style: appFont(color: Colors.white70, fontSize: 15),
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

/// Palette แบบพระอาทิตย์ขึ้นบนภูเขา — ไล่โทนอุ่นให้แต่ละสไลด์
const List<List<Color>> _slideGradients = [
  [Color(0xFF0F766E), Color(0xFF065F46)], // teal → emerald (intro)
  [Color(0xFFEA580C), Color(0xFFB45309)], // orange → amber (days)
  [Color(0xFF2563EB), Color(0xFF1E3A8A)], // blue (distance)
  [Color(0xFF9333EA), Color(0xFF6D28D9)], // purple (elevation)
  [Color(0xFFDB2777), Color(0xFF9D174D)], // pink (difficulty/travelers)
  [Color(0xFF0891B2), Color(0xFF0E7490)], // cyan (photos)
  [Color(0xFFEA580C), Color(0xFF7C2D12)], // sunset (summary)
];

class _RecapStory extends StatefulWidget {
  final Map<String, dynamic> data;
  const _RecapStory({required this.data});

  @override
  State<_RecapStory> createState() => _RecapStoryState();
}

class _RecapStoryState extends State<_RecapStory> {
  final PageController _pc = PageController();
  final GlobalKey _cardKey = GlobalKey();
  int _index = 0;
  bool _sharing = false;

  late final List<Widget> _slides = _buildSlides();

  // ---- helpers ----
  Map<String, dynamic> get _trip =>
      Map<String, dynamic>.from(widget.data['trip'] as Map? ?? {});

  String _text(dynamic v, [String fallback = '']) =>
      (v?.toString().trim().isNotEmpty ?? false) ? v.toString().trim() : fallback;

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

  List<String> get _photos =>
      (widget.data['photos'] as List? ?? [])
          .map((e) => ApiConfig.mediaUrl(e))
          .where((e) => e.isNotEmpty)
          .toList();

  List<Widget> _buildSlides() {
    final days = _num(widget.data['duration_days']);
    final distance = _num(widget.data['distance_km']);
    final elevation = _num(widget.data['elevation_gain_m']);
    final group = _num(widget.data['group_size']) ?? 0;
    final travelers = _num(widget.data['total_travelers']) ?? 0;
    final diffLabel = _text(_trip['difficulty_label']);

    final slides = <Widget>[
      _IntroSlide(title: _tripTitle, date: _dateLabel),
    ];

    if (days != null && days > 0) {
      slides.add(_StatSlide(
        emoji: '⛺️',
        bigValue: _fmt(days),
        unit: 'วัน',
        headline: 'บนเส้นทางธรรมชาติ',
        sub: 'ทุกวันคือความทรงจำ',
      ));
    }
    if (distance != null && distance > 0) {
      slides.add(_StatSlide(
        emoji: '🥾',
        bigValue: _fmt(distance),
        unit: 'กม.',
        headline: 'ระยะทางที่คุณพิชิต',
        sub: 'ก้าวแล้วก้าวเล่า จนถึงเส้นชัย',
      ));
    }
    if (elevation != null && elevation > 0) {
      slides.add(_StatSlide(
        emoji: '⛰️',
        bigValue: _fmt(elevation),
        unit: 'ม.',
        headline: 'ความสูงสะสมที่ปีนขึ้น',
        sub: 'สูงกว่าที่คิด แต่คุณทำได้',
      ));
    }
    slides.add(_DifficultySlide(
      difficultyLabel: diffLabel,
      groupSize: group.toInt(),
      travelers: travelers.toInt(),
    ));

    if (_photos.isNotEmpty) {
      slides.add(_PhotosSlide(photos: _photos.take(6).toList()));
    }

    slides.add(_SummarySlide(
      cardKey: _cardKey,
      title: _tripTitle,
      date: _dateLabel,
      days: days,
      distance: distance,
      elevation: elevation,
      travelers: travelers.toInt(),
      difficultyLabel: diffLabel,
      cover: ApiConfig.mediaUrl(_trip['cover_image']),
      fmt: _fmt,
      sharing: _sharing,
      hasReviewed: widget.data['has_reviewed'] == true,
      onShare: _share,
    ));

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

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/luilaykhao_recap.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'เพิ่งพิชิต "$_tripTitle" กับ ลุยเลเขา 🏔️ '
              'มาลุยด้วยกันไหม? #ลุยเลเขา',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง',
              style: appFont(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = _slideGradients[_index % _slideGradients.length];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
      ),
      child: SafeArea(
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
                        borderRadius: BorderRadius.circular(2),
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
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
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
              fontSize: 18,
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
                fontSize: 15,
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
                  fontSize: 13,
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
              fontSize: 18,
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
                    fontSize: 28,
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
              fontSize: 15,
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
                fontSize: 16,
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ทริปนี้มีเพื่อนร่วมทาง $travelers คน',
            style: appFont(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (groupSize > 1) ...[
            const SizedBox(height: 6),
            Text(
              'มากับกลุ่มของคุณ $groupSize คน',
              style: appFont(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
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
  const _PhotosSlide({required this.photos});

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
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'จากเพื่อนร่วมทริปในฟีด',
            style: appFont(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
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
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SummarySlide extends StatelessWidget {
  final GlobalKey cardKey;
  final String title;
  final String date;
  final num? days;
  final num? distance;
  final num? elevation;
  final int travelers;
  final String difficultyLabel;
  final String cover;
  final String Function(num) fmt;
  final bool sharing;
  final bool hasReviewed;
  final VoidCallback onShare;

  const _SummarySlide({
    required this.cardKey,
    required this.title,
    required this.date,
    required this.days,
    required this.distance,
    required this.elevation,
    required this.travelers,
    required this.difficultyLabel,
    required this.cover,
    required this.fmt,
    required this.sharing,
    required this.hasReviewed,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final stats = <List<String>>[
      if (days != null && days! > 0) ['${fmt(days!)} วัน', 'บนเส้นทาง'],
      if (distance != null && distance! > 0) ['${fmt(distance!)} กม.', 'ระยะทาง'],
      if (elevation != null && elevation! > 0)
        ['${fmt(elevation!)} ม.', 'ความสูงสะสม'],
      ['$travelers คน', 'เพื่อนร่วมทาง'],
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(
        children: [
          // ---- Shareable card (captured to PNG) ----
          RepaintBoundary(
            key: cardKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEA580C), Color(0xFF7C2D12)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🏔️', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        'ลุยเลเขา',
                        style: appFont(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'TRIP RECAP',
                        style: appFont(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (cover.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: appFont(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: appFont(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    runSpacing: 14,
                    children: stats.map((s) {
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 40 - 44) / 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s[0],
                              style: appFont(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              s[1],
                              style: appFont(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'luilaykhao.com',
                      style: appFont(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          // ---- Share button ----
          GestureDetector(
            onTap: sharing ? null : onShare,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sharing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF7C2D12),
                      ),
                    )
                  else
                    const Icon(Icons.ios_share_rounded,
                        size: 19, color: Color(0xFF7C2D12)),
                  const SizedBox(width: 8),
                  Text(
                    sharing ? 'กำลังเตรียมรูป...' : 'แชร์สรุปทริป',
                    style: appFont(
                      color: const Color(0xFF7C2D12),
                      fontSize: 15,
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
            style: appFont(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
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
