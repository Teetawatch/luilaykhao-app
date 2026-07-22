import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import 'conquest_map_screen.dart';

/// "สมุดสะสมการเดินทาง" (Passport) — a lifetime record of everywhere the
/// customer has trekked with us: total trips, distance, elevation climbed, plus
/// a wall of collectible badges. Built to gamify repeat bookings for the
/// สายเดินป่า crowd. Reads GET /me/passport.
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().fetchPassport();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _data == null;
      });
    }
  }

  void _openShare() {
    final data = _data;
    if (data == null) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(data: data),
    );
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
          'สมุดสะสมการเดินทาง',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (!_loading && !_error && _data != null)
            IconButton(
              tooltip: 'แชร์',
              icon: Icon(
                Icons.ios_share_rounded,
                color: AppTheme.onSurface(context),
              ),
              onPressed: _openShare,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error
          ? _ErrorState(onRetry: _load)
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _load,
              child: _content(),
            ),
    );
  }

  Widget _content() {
    final data = _data ?? const {};
    final stats = Map<String, dynamic>.from(data['stats'] ?? const {});
    final highlights = Map<String, dynamic>.from(data['highlights'] ?? const {});
    final badges = List<dynamic>.from(data['badges'] ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final earned = int.tryParse('${data['badges_earned_count'] ?? 0}') ?? 0;
    final total = int.tryParse('${data['badges_total'] ?? badges.length}') ?? 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _PassportHero(stats: stats),
        const SizedBox(height: 14),
        _InthanonStrip(highlights: highlights),
        const SizedBox(height: 14),
        // ตัวเลขจาก GPS ของผู้ใช้เอง — ซ่อนตัวเองจนกว่าจะมีการบันทึกครั้งแรก
        _RecordedStrip(
          recorded: Map<String, dynamic>.from(data['recorded'] ?? const {}),
        ),
        _ConquestMapEntry(stats: stats),
        const SizedBox(height: 26),
        Row(
          children: [
            Text(
              'ตราสะสม',
              style: appFont(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
            const Spacer(),
            Text(
              'ปลดล็อกแล้ว $earned/$total',
              style: appFont(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: [for (final b in badges) _BadgeTile(badge: b)],
        ),
      ],
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _PassportHero extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _PassportHero({required this.stats});

  @override
  Widget build(BuildContext context) {
    final trips = int.tryParse('${stats['trips_count'] ?? 0}') ?? 0;
    final distance =
        double.tryParse('${stats['total_distance_km'] ?? 0}') ?? 0;
    final elevation =
        int.tryParse('${stats['total_elevation_gain_m'] ?? 0}') ?? 0;
    final days = int.tryParse('${stats['total_days'] ?? 0}') ?? 0;
    final regions = int.tryParse('${stats['regions_count'] ?? 0}') ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14532D), Color(0xFF15803D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hiking_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'นักเดินทางสายเดินป่า',
                      style: appFont(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'ทริปที่ไปมาแล้ว',
            style: appFont(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _format(trips),
                style: appFont(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'ทริป',
                style: appFont(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroStat(
                icon: Icons.route_rounded,
                value: _trim(distance),
                unit: 'กม.',
                label: 'ระยะทาง',
              ),
              _HeroDivider(),
              _HeroStat(
                icon: Icons.terrain_rounded,
                value: _format(elevation),
                unit: 'ม.',
                label: 'ความสูงสะสม',
              ),
              _HeroDivider(),
              _HeroStat(
                icon: Icons.public_rounded,
                value: '$regions',
                unit: 'ภาค',
                label: 'ภูมิภาค',
              ),
            ],
          ),
          if (days > 0) ...[
            const SizedBox(height: 16),
            Text(
              'รวม $days วันบนเส้นทางธรรมชาติ',
              style: appFont(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.truncate() ? _format(v.toInt()) : v.toStringAsFixed(1);

  static String _format(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _HeroStat({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: appFont(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: appFont(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

// ─── Recorded (GPS) stats ─────────────────────────────────────────────────────

/// What the traveller's own GPS measured, kept visibly separate from the
/// published route figures above it — the two answer different questions and
/// blending them would quietly overstate both.
class _RecordedStrip extends StatelessWidget {
  final Map<String, dynamic> recorded;

  const _RecordedStrip({required this.recorded});

  @override
  Widget build(BuildContext context) {
    final tracks = int.tryParse('${recorded['tracks_count'] ?? 0}') ?? 0;
    if (tracks == 0) return const SizedBox.shrink();

    final distance = double.tryParse('${recorded['distance_km'] ?? 0}') ?? 0;
    final gain = int.tryParse('${recorded['elevation_gain_m'] ?? 0}') ?? 0;
    final pace = double.tryParse('${recorded['average_pace_kmh'] ?? ''}');
    final highest = int.tryParse('${recorded['highest_point_m'] ?? ''}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'วัดจาก GPS ของคุณเอง · $tracks ทริป',
              style: appFont(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 22,
              runSpacing: 12,
              children: [
                _RecordedFigure(
                  label: 'เดินจริง',
                  value: distance.toStringAsFixed(1),
                  unit: 'กม.',
                ),
                _RecordedFigure(
                  label: 'ไต่จริง',
                  value: '$gain',
                  unit: 'ม.',
                ),
                if (pace != null)
                  _RecordedFigure(
                    label: 'ความเร็วเฉลี่ย',
                    value: pace.toStringAsFixed(1),
                    unit: 'กม./ชม.',
                  ),
                if (highest != null && highest > 0)
                  _RecordedFigure(
                    label: 'จุดสูงสุด',
                    value: '$highest',
                    unit: 'ม.',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordedFigure extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _RecordedFigure({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: appFont(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 3),
        Text.rich(
          TextSpan(
            text: value,
            style: appFont(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
            children: [
              TextSpan(
                text: ' $unit',
                style: appFont(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Conquest map entry ───────────────────────────────────────────────────────

/// Doorway from the passport into the map of everywhere this traveller has been.
/// Leads with the one number that makes the map worth opening — how much of the
/// country is still blank.
class _ConquestMapEntry extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _ConquestMapEntry({required this.stats});

  @override
  Widget build(BuildContext context) {
    final regions = int.tryParse('${stats['regions_count'] ?? 0}') ?? 0;
    const totalRegions = 7;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConquestMapScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'แผนที่พิชิต',
                      style: appFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      regions > 0
                          ? 'ปักหมุดแล้ว $regions จาก $totalRegions ภาค'
                          : 'ยังไม่มีหมุด — เริ่มจากทริปแรกของคุณ',
                      style: appFont(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.mutedText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Doi Inthanon comparison strip ────────────────────────────────────────────

class _InthanonStrip extends StatelessWidget {
  final Map<String, dynamic> highlights;

  const _InthanonStrip({required this.highlights});

  @override
  Widget build(BuildContext context) {
    final multiple = double.tryParse('${highlights['inthanon_multiple'] ?? 0}') ?? 0;
    if (multiple <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Text('🏔️', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: appFont(
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface(context),
                ),
                children: [
                  const TextSpan(text: 'ความสูงที่ไต่สะสม เท่ากับปีนดอยอินทนนท์ '),
                  TextSpan(
                    text: '${_trim(multiple)} ครั้ง',
                    style: appFont(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ─── Badge tile ───────────────────────────────────────────────────────────────

class _BadgeTile extends StatelessWidget {
  final Map<String, dynamic> badge;

  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final earned = badge['earned'] == true;
    final emoji = '${badge['emoji'] ?? '🏅'}';
    final title = '${badge['title'] ?? ''}';
    final progress = badge['progress'] as Map?;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _BadgeSheet(badge: badge),
      ),
      child: Opacity(
        opacity: earned ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: earned
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : AppTheme.surface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: earned
                  ? AppTheme.primaryColor.withValues(alpha: 0.28)
                  : AppTheme.border(context).withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BadgeMedallion(emoji: emoji, earned: earned),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: 11.5,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: earned
                      ? AppTheme.onSurface(context)
                      : AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _hint(earned, progress),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: earned
                      ? AppTheme.primaryColor
                      : AppTheme.mutedText(context).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _hint(bool earned, Map? progress) {
    if (earned) return 'ปลดล็อกแล้ว';
    if (progress == null) return 'ยังไม่ปลดล็อก';
    final current = double.tryParse('${progress['current'] ?? 0}') ?? 0;
    final target = double.tryParse('${progress['target'] ?? 0}') ?? 0;
    final remaining = (target - current).clamp(0, target);
    final r = remaining == remaining.truncate()
        ? remaining.toInt().toString()
        : remaining.toStringAsFixed(1);
    return 'อีก $r';
  }
}

class _BadgeMedallion extends StatelessWidget {
  final String emoji;
  final bool earned;

  const _BadgeMedallion({required this.emoji, required this.earned});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: earned
            ? AppTheme.primaryColor.withValues(alpha: 0.14)
            : AppTheme.mutedText(context).withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: earned
          ? Text(emoji, style: const TextStyle(fontSize: 24))
          : Icon(
              Icons.lock_rounded,
              size: 20,
              color: AppTheme.mutedText(context).withValues(alpha: 0.7),
            ),
    );
  }
}

// ─── Badge detail sheet ───────────────────────────────────────────────────────

class _BadgeSheet extends StatelessWidget {
  final Map<String, dynamic> badge;

  const _BadgeSheet({required this.badge});

  @override
  Widget build(BuildContext context) {
    final earned = badge['earned'] == true;
    final emoji = '${badge['emoji'] ?? '🏅'}';
    final title = '${badge['title'] ?? ''}';
    final desc = '${badge['description'] ?? ''}';
    final progress = badge['progress'] as Map?;
    final earnedAt = DateTime.tryParse('${badge['earned_at'] ?? ''}');

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: earned
                      ? AppTheme.primaryColor.withValues(alpha: 0.14)
                      : AppTheme.mutedText(context).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: earned
                    ? Text(emoji, style: const TextStyle(fontSize: 38))
                    : Icon(
                        Icons.lock_rounded,
                        size: 32,
                        color: AppTheme.mutedText(context),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 18),
              if (earned)
                _StatusPill(
                  label: earnedAt != null
                      ? 'ปลดล็อก ${thaiDateShort(earnedAt)} 🎉'
                      : 'ปลดล็อกแล้ว 🎉',
                  color: AppTheme.primaryColor,
                )
              else if (progress != null)
                _ProgressBar(progress: Map<String, dynamic>.from(progress))
              else
                _StatusPill(
                  label: 'ยังไม่ปลดล็อก',
                  color: AppTheme.mutedText(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: appFont(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final Map<String, dynamic> progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final current = double.tryParse('${progress['current'] ?? 0}') ?? 0;
    final target = double.tryParse('${progress['target'] ?? 0}') ?? 0;
    final ratio = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.toDouble(),
            minHeight: 8,
            backgroundColor: AppTheme.mutedText(context).withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_trim(current)} / ${_trim(target)}',
          style: appFont(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface(context),
          ),
        ),
      ],
    );
  }

  static String _trim(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 46,
              color: AppTheme.mutedText(context).withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              'โหลดสมุดสะสมไม่สำเร็จ',
              style: appFont(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'ลองอีกครั้ง',
                style: appFont(fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Share card ───────────────────────────────────────────────────────────────

/// Bottom sheet that previews the shareable passport card and exports it as a
/// PNG via [SharePlus] — same RepaintBoundary→toImage flow as Trip Recap.
class _ShareSheet extends StatefulWidget {
  final Map<String, dynamic> data;

  const _ShareSheet({required this.data});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

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
      final file = File('${dir.path}/luilaykhao_passport.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'สมุดสะสมการเดินทางของฉันกับ ลุยเลเขา 🏔️ '
              'มาสะสมยอดดอยด้วยกันไหม? #ลุยเลเขา',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            content: Text(
              'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง',
              style: appFont(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            RepaintBoundary(
              key: _cardKey,
              child: _ShareCard(data: widget.data),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sharing ? null : _share,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                  _sharing ? 'กำลังเตรียม...' : 'แชร์การ์ด',
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

class _ShareCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ShareCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = Map<String, dynamic>.from(data['stats'] ?? const {});
    final highlights = Map<String, dynamic>.from(data['highlights'] ?? const {});
    final badges = List<dynamic>.from(data['badges'] ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final trips = int.tryParse('${stats['trips_count'] ?? 0}') ?? 0;
    final distance =
        double.tryParse('${stats['total_distance_km'] ?? 0}') ?? 0;
    final elevation =
        int.tryParse('${stats['total_elevation_gain_m'] ?? 0}') ?? 0;
    final regions = int.tryParse('${stats['regions_count'] ?? 0}') ?? 0;
    final days = int.tryParse('${stats['total_days'] ?? 0}') ?? 0;
    final multiple =
        double.tryParse('${highlights['inthanon_multiple'] ?? 0}') ?? 0;

    final earnedEmojis = badges
        .where((b) => b['earned'] == true)
        .map((b) => '${b['emoji'] ?? '🏅'}')
        .toList();
    final earnedCount = earnedEmojis.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14532D), Color(0xFF166534), Color(0xFF15803D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hiking_rounded, color: Colors.white, size: 20),
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
                'PASSPORT',
                style: appFont(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'ไปมาแล้วทั้งหมด',
            style: appFont(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmtInt(trips),
                style: appFont(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ทริป',
                style: appFont(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _ShareStat(value: _fmtDouble(distance), unit: 'กม.', label: 'ระยะทาง'),
              _ShareStat(
                value: _fmtInt(elevation),
                unit: 'ม.',
                label: 'ความสูงสะสม',
              ),
              _ShareStat(value: '$regions', unit: 'ภาค', label: 'ภูมิภาค'),
              _ShareStat(value: '$days', unit: 'วัน', label: 'บนเส้นทาง'),
            ],
          ),
          if (multiple > 0) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('🏔️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'สูงเท่าปีนดอยอินทนนท์ ${_fmtDouble(multiple)} ครั้ง',
                      style: appFont(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (earnedCount > 0) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (final e in earnedEmojis.take(6)) ...[
                  Text(e, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 6),
                ],
                const Spacer(),
                Text(
                  'ปลดล็อก $earnedCount ตรา',
                  style: appFont(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
          const SizedBox(height: 14),
          Text(
            '#ลุยเลเขา · สายเดินป่า',
            style: appFont(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _ShareStat({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: appFont(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: appFont(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtInt(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);

String _fmtDouble(double v) =>
    v == v.truncate() ? _fmtInt(v.toInt()) : v.toStringAsFixed(1);
