import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/trip_medal.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/medal_art.dart';
import '../widgets/medal_route.dart';
import '../widgets/medal_share_sheet.dart';
import '../widgets/medal_story_card.dart' show medalBackdropColor;
import 'trip_recap_screen.dart';

/// ตู้เหรียญพิชิต — เหรียญประจำตัวของทุกทริปที่เดินจบจริง (GET /me/medals)
///
/// เปิดครั้งแรกหลังได้เหรียญใหม่จะเจอฉากฉลอง ([showMedalUnlock]) ก่อนเสมอ
/// แล้วค่อยบอกเซิร์ฟเวอร์ว่าเห็นแล้ว — ถ้าบอกก่อนแล้วแอปถูกปิดกลางฉาก เจ้าของ
/// เหรียญจะไม่เคยได้เห็นช่วงเวลานั้นเลย
class MedalsScreen extends StatefulWidget {
  /// เหรียญที่ต้องเปิดดูทันทีหลังโหลด (มาจากการแตะ push "เหรียญมาแล้ว")
  final int? focusMedalId;

  const MedalsScreen({super.key, this.focusMedalId});

  @override
  State<MedalsScreen> createState() => _MedalsScreenState();
}

class _MedalsScreenState extends State<MedalsScreen> {
  MedalCabinet? _cabinet;
  bool _loading = true;
  bool _error = false;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final app = context.read<AppProvider>();

    try {
      // เปิดจาก push ต้องเห็นเหรียญที่เพิ่งได้ ไม่ใช่ตู้ที่แคชไว้ก่อนหน้านั้น
      final cabinet = await app.fetchMedals(
        force: force || widget.focusMedalId != null || _cabinet == null,
      );
      if (!mounted) return;

      setState(() {
        _cabinet = cabinet;
        _loading = false;
        _error = false;
      });

      await _celebrateIfNeeded(cabinet);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cabinet == null;
      });
    }
  }

  Future<void> _celebrateIfNeeded(MedalCabinet cabinet) async {
    if (_celebrated) return;
    _celebrated = true;

    final fresh = cabinet.unseen;

    if (fresh.isNotEmpty) {
      final wantsShare = await showMedalUnlock(context, fresh);
      if (!mounted) return;

      try {
        await context.read<AppProvider>().markMedalsSeen([
          for (final m in fresh) m.id,
        ]);
      } catch (_) {
        // ไม่สำคัญพอจะรบกวนผู้ใช้ — ครั้งหน้าที่เปิดตู้จะได้ฉลองอีกรอบเท่านั้น
      }

      if (!mounted) return;
      setState(() => _cabinet = _cabinet?.markAllSeen());

      // แชร์ต่อจากฉากฉลอง — เปิดหลังฉากปิดสนิทแล้ว ไม่งั้นจะซ้อนกับหน้า
      // รายละเอียดเหรียญที่อาจเปิดตามมาข้างล่าง
      if (wantsShare) {
        await showMedalShareSheet(context, fresh.first);
        if (!mounted) return;
      }
    }

    final focusId = widget.focusMedalId;
    if (focusId == null || !mounted) return;

    for (final medal in _cabinet?.medals ?? const <TripMedal>[]) {
      if (medal.id == focusId) {
        await MedalDetailScreen.open(context, medal);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text(
          'ตู้เหรียญพิชิต',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error
          ? _MessageState(
              icon: Icons.cloud_off_rounded,
              title: 'โหลดตู้เหรียญไม่สำเร็จ',
              body: 'ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่อีกครั้ง',
              actionLabel: 'ลองใหม่',
              onAction: () {
                setState(() => _loading = true);
                _load(force: true);
              },
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () => _load(force: true),
              child: _content(),
            ),
    );
  }

  Widget _content() {
    final cabinet = _cabinet ?? MedalCabinet.empty;

    if (cabinet.medals.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _MessageState(
            icon: Icons.military_tech_rounded,
            title: 'ยังไม่มีเหรียญในตู้',
            body:
                'เดินทริปกับเราจนจบ แล้วเหรียญพิชิตประจำตัวของทริปนั้นจะมาอยู่ที่นี่ '
                'พร้อมเลข Finisher ของคุณ',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Text(
          '${cabinet.medals.length} เหรียญ จาก ${cabinet.tripsCount} ทริป',
          style: appFont(
            fontSize: AppText.sizeLabel,
            fontWeight: FontWeight.w700,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final tileWidth = (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final medal in cabinet.medals)
                  SizedBox(
                    width: tileWidth,
                    child: _MedalTile(
                      medal: medal,
                      onTap: () => MedalDetailScreen.open(context, medal),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MedalTile extends StatelessWidget {
  final TripMedal medal;
  final VoidCallback onTap;

  const _MedalTile({required this.medal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusLg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                MedalArt(
                  design: medal.design,
                  size: math.min(constraints.maxWidth * 0.72, 130),
                  year: medal.buddhistYear,
                ),
                const SizedBox(height: 10),
                Text(
                  medal.design.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  medal.attempt > 1
                      ? '${medal.finisherLabel} · ครั้งที่ ${medal.attempt}'
                      : medal.finisherLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (medal.earnedLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    medal.earnedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── หน้ารายละเอียดเหรียญ ─────────────────────────────────────────────────────

class MedalDetailScreen extends StatelessWidget {
  final TripMedal medal;

  const MedalDetailScreen({super.key, required this.medal});

  static Future<void> open(BuildContext context, TripMedal medal) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MedalDetailScreen(medal: medal)));
  }

  @override
  Widget build(BuildContext context) {
    final background = medalBackdropColor(medal.design.color);
    final soft = Colors.white.withValues(alpha: 0.75);
    final width = MediaQuery.sizeOf(context).width;
    final medalSize = math.min(width * 0.6, 260.0);

    final stats = [
      if ((medal.distanceKm ?? 0) > 0)
        ('${_trim(medal.distanceKm!)} กม.', 'ระยะทาง'),
      if ((medal.elevationGainM ?? 0) > 0)
        ('${_thousands(medal.elevationGainM!)} ม.', 'ความสูงสะสม'),
      if ((medal.durationDays ?? 0) > 0)
        ('${medal.durationDays} วัน', 'ระยะเวลา'),
    ];

    final meta = [
      if (medal.placeLabel.isNotEmpty) medal.placeLabel,
      if (medal.dateLabel.isNotEmpty) medal.dateLabel,
    ].join('  ·  ');

    final bookingRef = medal.bookingRef;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'เหรียญพิชิต',
          style: appFont(
            color: Colors.white,
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Center(
              child: MedalFlip(medal: medal, size: medalSize),
            ),
            const SizedBox(height: 10),
            Text(
              'แตะเหรียญเพื่อพลิกดูด้านหลัง',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              medal.finisherLabel.toUpperCase(),
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFF7CD78),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              medal.design.name,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeH1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              medal.holderName,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meta,
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w600,
                  color: soft,
                  height: 1.4,
                ),
              ),
            ],
            if (medal.attemptsOfTrip > 1) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'มาพิชิตครั้งที่ ${medal.attempt} จาก ${medal.attemptsOfTrip} ครั้ง',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            // มีตัวเลขจาก GPS ของตัวเองแล้ว ส่วนเส้นทางด้านล่างโชว์ครบกว่า — ไม่ต้อง
            // โชว์ตัวเลขประมาณของทริปซ้ำอีกชุด
            if (stats.isNotEmpty && medal.personal == null) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    for (final (value, label) in stats)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              value,
                              style: appFont(
                                fontSize: AppText.sizeSubtitle,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: appFont(
                                fontSize: AppText.sizeCaption,
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
            ],
            if (medal.route != null || medal.personal != null) ...[
              const SizedBox(height: 22),
              _RouteSection(medal: medal),
            ],
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                showMedalShareSheet(context, medal);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(
                'แชร์เหรียญลงโซเชียล',
                style: appFont(fontWeight: FontWeight.w800, color: background),
              ),
            ),
            if (bookingRef != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  TripRecapScreen.open(context, bookingRef);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  'ดูสรุปทริปนี้',
                  style: appFont(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// เส้นทาง + ตัวเลขที่เดินจริง + สถิติส่วนตัวสูงสุด ของเหรียญหนึ่งเหรียญ
class _RouteSection extends StatelessWidget {
  final TripMedal medal;

  const _RouteSection({required this.medal});

  @override
  Widget build(BuildContext context) {
    final route = medal.route;
    final personal = medal.personal;
    final soft = Colors.white.withValues(alpha: 0.7);

    final figures = <(String, String)>[
      if (personal != null) ...[
        ('${_trim(personal.distanceKm)} กม.', 'ระยะทาง'),
        if (formatMovingTime(personal.movingSeconds) case final time?)
          (time, 'เวลาเดิน'),
        if (personal.avgSpeedKmh != null)
          ('${_trim(personal.avgSpeedKmh!)} กม./ชม.', 'ความเร็วเฉลี่ย'),
        if (personal.elevationGainM > 0)
          ('${_thousands(personal.elevationGainM)} ม.', 'ไต่ขึ้น'),
        if ((personal.maxElevationM ?? 0) > 0)
          ('${_thousands(personal.maxElevationM!)} ม.', 'จุดสูงสุด'),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                route?.isRecorded == false
                    ? Icons.map_rounded
                    : Icons.route_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                route?.isRecorded == false
                    ? 'เส้นทางของทริป'
                    : 'เส้นทางที่ฉันเดิน',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (personal != null)
                Text(
                  'จาก GPS ที่บันทึก',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: soft,
                  ),
                ),
            ],
          ),
          if (route != null) ...[
            const SizedBox(height: 12),
            SizedBox(height: 190, child: MedalRouteView(route: route)),
          ],
          if (route?.elevations case final elevations?) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: MedalElevationView(elevations: elevations),
            ),
          ],
          if (figures.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                for (final (value, label) in figures)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w600,
                          color: soft,
                        ),
                      ),
                      Text(
                        value,
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ] else if (route != null && !route.isRecorded) ...[
            const SizedBox(height: 10),
            Text(
              'ทริปหน้ากด "เริ่มบันทึก" ในหน้าวันเดินทาง แล้วการ์ดเหรียญจะใช้เส้นทางและตัวเลขที่คุณเดินจริง',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: soft,
                height: 1.45,
              ),
            ),
          ],
          if (medal.records.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final record in medal.records)
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7CD78).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 15,
                          color: Color(0xFFF7CD78),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            medalRecordLabel(record),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF7CD78),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── ฉากฉลองเหรียญใหม่ ───────────────────────────────────────────────────────

/// ฉากฉลองเหรียญใหม่ — เหรียญหมุนลงมากลางจอแล้วค่อยขึ้นข้อความ
///
/// หลายเหรียญพร้อมกัน (เช่น เปิดแอปครั้งแรกหลังระบบแจกย้อนหลังให้ทุกทริปเก่า)
/// โชว์เหรียญล่าสุดเป็นพระเอก แล้วบอกจำนวนที่เหลือเป็นบรรทัดเดียว — ไม่ไล่ฉลอง
/// ทีละเหรียญจนน่ารำคาญ
///
/// คืน true เมื่อเจ้าของกด "แชร์" — ผู้เรียกเปิด sheet แชร์ต่อเอง
Future<bool> showMedalUnlock(
  BuildContext context,
  List<TripMedal> medals,
) async {
  if (medals.isEmpty) return false;

  final result = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => _MedalUnlockView(medals: medals),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  return result ?? false;
}

class _MedalUnlockView extends StatefulWidget {
  final List<TripMedal> medals;

  const _MedalUnlockView({required this.medals});

  @override
  State<_MedalUnlockView> createState() => _MedalUnlockViewState();
}

class _MedalUnlockViewState extends State<_MedalUnlockView>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final AnimationController _rays = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  late final Animation<double> _scale = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0, 0.75, curve: Curves.elasticOut),
  ).drive(Tween(begin: 0.2, end: 1.0));

  /// หมุนสองรอบแล้วค่อย ๆ หยุดที่ด้านหน้า
  late final Animation<double> _spin = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
  ).drive(Tween(begin: math.pi * 4, end: 0));

  late final Animation<double> _text = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.6, 1, curve: Curves.easeOut),
  );

  TripMedal get _hero => widget.medals.first;

  @override
  void initState() {
    super.initState();
    _enter.forward();
    _rays.repeat();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _rays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medal = _hero;
    final others = widget.medals.length - 1;
    final size = math.min(MediaQuery.sizeOf(context).width * 0.58, 250.0);
    final background = medalBackdropColor(medal.design.color);

    return Material(
      color: background.withValues(alpha: 0.97),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              FadeTransition(
                opacity: _text,
                child: Text(
                  'ยินดีด้วย! คุณได้รับเหรียญพิชิต',
                  textAlign: TextAlign.center,
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: size * 1.6,
                height: size * kMedalAspect * 1.25,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: RotationTransition(
                        turns: _rays,
                        child: CustomPaint(painter: _RaysPainter()),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _enter,
                      builder: (context, child) {
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(_spin.value)
                            ..scaleByDouble(_scale.value, _scale.value, 1, 1),
                          child: child,
                        );
                      },
                      child: MedalArt(
                        design: medal.design,
                        size: size,
                        year: medal.buddhistYear,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _text,
                child: Column(
                  children: [
                    Text(
                      medal.finisherLabel.toUpperCase(),
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF7CD78),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      medal.design.name,
                      textAlign: TextAlign.center,
                      style: appFont(
                        fontSize: AppText.sizeH1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    if (medal.dateLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        medal.dateLabel,
                        textAlign: TextAlign.center,
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                    if (others > 0) ...[
                      const SizedBox(height: 14),
                      Text(
                        'และอีก $others เหรียญจากทริปที่ผ่านมา รออยู่ในตู้ของคุณ',
                        textAlign: TextAlign.center,
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _text,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(
                        'แชร์ความภูมิใจ',
                        style: appFont(
                          fontWeight: FontWeight.w800,
                          color: background,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(false);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'เก็บเข้าตู้เหรียญ',
                        style: appFont(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

/// แฉกแสงหมุนช้า ๆ หลังเหรียญ — สามเหลี่ยมทองโปร่งเรียบ ๆ ไม่มีเบลอ/แสงเรือง
class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide * 0.7;
    final paint = Paint()..color = kMedalGold.withValues(alpha: 0.13);
    const count = 12;

    for (var i = 0; i < count; i++) {
      final a = i * 2 * math.pi / count;
      const half = math.pi / count / 2;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + radius * math.cos(a - half),
            center.dy + radius * math.sin(a - half),
          )
          ..lineTo(
            center.dx + radius * math.cos(a + half),
            center.dy + radius * math.sin(a + half),
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}

/// ข้อความกลางจอสำหรับตู้ว่าง/โหลดไม่ได้
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.tintOf(context, AppTheme.primaryColor),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeBody,
              color: muted,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(
                actionLabel!,
                style: appFont(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
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
