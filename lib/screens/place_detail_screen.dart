import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import 'trip_detail_screen.dart' show TripDetailScreen;

/// หน้าปลายทางหนึ่งแห่ง — "ที่นั่นเป็นยังไง" ก่อนจะเป็น "จองเลย"
///
/// ทริปที่ไปที่นี่ถูกวางไว้ท้ายสุดโดยตั้งใจ ตามที่ฝั่งเว็บวางไว้: คนที่เข้ามา
/// อ่านหน้านี้ส่วนใหญ่ยังไม่ได้ตัดสินใจว่าจะไป การเอาราคาขึ้นก่อนทำให้หน้าที่
/// ควรเป็นข้อมูลกลายเป็นหน้าขาย
class PlaceDetailScreen extends StatefulWidget {
  final String slug;

  const PlaceDetailScreen({super.key, required this.slug});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  static const _monthLabels = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  Map<String, dynamic>? _place;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().place(widget.slug);
      if (!mounted) return;
      setState(() {
        _place = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<String> _stringList(dynamic value) => (value as List? ?? const [])
      .map((e) => '$e'.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final place = _place;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          '${place?['name'] ?? 'ปลายทาง'}',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : place == null
          ? EmptyStateView(
              icon: Icons.wifi_off_rounded,
              title: 'เปิดหน้านี้ไม่สำเร็จ',
              body: _error,
              actionLabel: 'ลองใหม่',
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryColor,
              child: _buildBody(place),
            ),
    );
  }

  Widget _buildBody(Map<String, dynamic> place) {
    final cover = ApiConfig.mediaUrl(place['cover_image']);
    final gallery = _stringList(place['gallery'])
        .map(ApiConfig.mediaUrl)
        .where((u) => u.isNotEmpty)
        .toList();
    final highlights = _stringList(place['highlights']);
    final knowBefore = _stringList(place['know_before']);
    final bestMonths = (place['best_months'] as List? ?? const [])
        .map((e) => int.tryParse('$e') ?? 0)
        .where((m) => m >= 1 && m <= 12)
        .toList();
    final closedMonths = (place['closed_months'] as List? ?? const [])
        .map((e) => int.tryParse('$e') ?? 0)
        .where((m) => m >= 1 && m <= 12)
        .toList();
    final trips = (place['trips'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final description = '${place['description'] ?? ''}'.trim();
    final seasonNote = '${place['season_note'] ?? ''}'.trim();
    final closureNote = '${place['closure_note'] ?? ''}'.trim();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      children: [
        if (cover.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: cover,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Container(color: AppTheme.subtleSurface(context)),
              errorWidget: (_, _, _) =>
                  Container(color: AppTheme.subtleSurface(context)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${place['name'] ?? ''}',
                style: appFont(
                  fontSize: AppText.sizeH1,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  '${place['province'] ?? ''}',
                  '${place['region_label'] ?? ''}',
                  '${place['type_label'] ?? ''}',
                ].where((t) => t.trim().isNotEmpty).join(' · '),
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (place['difficulty_label'] != null)
                    _Fact(
                      icon: Icons.terrain_rounded,
                      label: '${place['difficulty_label']}',
                    ),
                  if (place['elevation_m'] != null)
                    _Fact(
                      icon: Icons.height_rounded,
                      label: 'ยอดสูง ${place['elevation_m']} ม.',
                    ),
                  if (place['trail_distance_km'] != null)
                    _Fact(
                      icon: Icons.straighten_rounded,
                      label: 'ระยะเดิน ${place['trail_distance_km']} กม.',
                    ),
                  if (place['elevation_gain_m'] != null)
                    _Fact(
                      icon: Icons.trending_up_rounded,
                      label: 'ไต่สะสม ${place['elevation_gain_m']} ม.',
                    ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  description,
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    height: 1.65,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ],
              if (bestMonths.isNotEmpty || closedMonths.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle('ช่วงเวลาที่ควรไป'),
                const SizedBox(height: 10),
                _MonthStrip(best: bestMonths, closed: closedMonths),
                if (seasonNote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    seasonNote,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
                if (closureNote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _NoteBox(
                    icon: Icons.event_busy_rounded,
                    color: const Color(0xFFB45309),
                    text: closureNote,
                  ),
                ],
              ],
              if (highlights.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle('ไฮไลท์'),
                const SizedBox(height: 10),
                ...highlights.map(
                  (h) => _BulletRow(icon: Icons.star_rounded, text: h),
                ),
              ],
              if (knowBefore.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle('รู้ไว้ก่อนไป'),
                const SizedBox(height: 10),
                ...knowBefore.map(
                  (k) => _BulletRow(icon: Icons.info_outline_rounded, text: k),
                ),
              ],
            ],
          ),
        ),
        if (gallery.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SectionTitle('บรรยากาศ'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: gallery.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: CachedNetworkImage(
                  imageUrl: gallery[i],
                  width: 220,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    width: 220,
                    color: AppTheme.subtleSurface(context),
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 220,
                    color: AppTheme.subtleSurface(context),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (trips.isNotEmpty) ...[
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SectionTitle('ทริปที่ไปที่นี่'),
          ),
          const SizedBox(height: 10),
          ...trips.map(
            (trip) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _TripRow(trip: trip),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Fact({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// แถบ 12 เดือน: เดือนที่ควรไปเน้นสี เดือนที่ปิดขีดฆ่า
///
/// อ่านได้ในแวบเดียวว่า "เดือนที่ฉันว่างไปได้ไหม" ซึ่งเป็นคำถามจริงของคนที่
/// กำลังวางแผน — ดีกว่าประโยคบรรยายฤดูที่ต้องอ่านจบก่อนถึงจะรู้
class _MonthStrip extends StatelessWidget {
  final List<int> best;
  final List<int> closed;

  const _MonthStrip({required this.best, required this.closed});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var m = 1; m <= 12; m++)
          _MonthPill(
            label: _PlaceDetailScreenState._monthLabels[m - 1],
            best: best.contains(m),
            closed: closed.contains(m),
          ),
      ],
    );
  }
}

class _MonthPill extends StatelessWidget {
  final String label;
  final bool best;
  final bool closed;

  const _MonthPill({
    required this.label,
    required this.best,
    required this.closed,
  });

  @override
  Widget build(BuildContext context) {
    final color = closed
        ? const Color(0xFFB45309)
        : best
        ? AppTheme.primaryColor
        : AppTheme.mutedText(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: best
            ? AppTheme.primaryColor.withValues(alpha: 0.10)
            : AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeCaption,
          fontWeight: best ? FontWeight.w800 : FontWeight.w600,
          color: color,
          decoration: closed ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BulletRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: appFont(
                fontSize: AppText.sizeBody,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _NoteBox({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: appFont(
                fontSize: AppText.sizeLabel,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _TripRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final cover = ApiConfig.mediaUrl(trip['cover_image']);
    final nextLabel = '${trip['next_departure_label'] ?? ''}';
    final upcoming = int.tryParse('${trip['upcoming_count']}') ?? 0;

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(slug: '${trip['slug']}'),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (cover.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: CachedNetworkImage(
                    imageUrl: cover,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: 72,
                      height: 72,
                      color: AppTheme.subtleSurface(context),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 72,
                      height: 72,
                      color: AppTheme.subtleSurface(context),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      upcoming == 0
                          ? 'ยังไม่มีรอบเปิดจอง'
                          : nextLabel.isNotEmpty
                          ? 'รอบถัดไป $nextLabel · เปิดอยู่ $upcoming รอบ'
                          : 'เปิดอยู่ $upcoming รอบ',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
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
