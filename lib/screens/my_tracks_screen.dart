import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';

/// "เส้นทางที่ฉันเดิน" — คลังแทร็ก GPS ที่ลูกค้าอัดไว้เองระหว่างทริป
///
/// แอปบันทึกเส้นทางได้อยู่แล้ว (TrekRecorderCard บนหน้าวันเดินทาง) และส่งขึ้น
/// เซิร์ฟเวอร์ไปนานแล้ว แต่ไม่เคยมีหน้าไหนให้ย้อนกลับมาดู — ข้อมูลที่ลูกค้า
/// ออกแรงเดินมาเองจึงหายเข้าไปในระบบเงียบ ๆ หน้านี้คือที่ที่มันกลับมา
class MyTracksScreen extends StatefulWidget {
  const MyTracksScreen({super.key});

  @override
  State<MyTracksScreen> createState() => _MyTracksScreenState();
}

class _MyTracksScreenState extends State<MyTracksScreen> {
  List<Map<String, dynamic>> _tracks = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await context.read<AppProvider>().myTracks();
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'เส้นทางที่ฉันเดิน',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(height: 110),
          SizedBox(height: 12),
          SkeletonBox(height: 110),
          SizedBox(height: 12),
          SkeletonBox(height: 110),
        ],
      );
    }

    if (_error != null && _tracks.isEmpty) {
      return EmptyStateView(
        icon: Icons.wifi_off_rounded,
        title: 'โหลดเส้นทางไม่สำเร็จ',
        body: _error,
        actionLabel: 'ลองใหม่',
        onAction: _load,
      );
    }

    if (_tracks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EmptyStateView(
            icon: Icons.route_rounded,
            title: 'ยังไม่มีเส้นทางที่บันทึกไว้',
            body: 'ระหว่างทริป เปิด "บันทึกเส้นทาง" ในหน้าวันเดินทาง '
                'แล้วระยะที่เดินจริงจะถูกเก็บไว้ที่นี่',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _TrackCard(track: _tracks[i]),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final Map<String, dynamic> track;

  const _TrackCard({required this.track});

  String _duration(dynamic seconds) {
    final total = int.tryParse('$seconds') ?? 0;
    if (total <= 0) return '-';
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    if (hours == 0) return '$minutes นาที';
    return '$hours ชม. $minutes นาที';
  }

  @override
  Widget build(BuildContext context) {
    final ref = '${track['booking_ref'] ?? ''}';
    final title = '${track['trip_title'] ?? 'ทริป'}';
    final dateLabel = '${track['started_at_label'] ?? ''}';
    final distance = (track['distance_km'] as num?)?.toStringAsFixed(1) ?? '0.0';
    final gain = track['elevation_gain_m'];

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ref.isEmpty
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TrackDetailScreen(bookingRef: ref, tripTitle: title),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
              if (dateLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat(label: 'ระยะทาง', value: '$distance กม.'),
                  _Stat(
                    label: 'ไต่สะสม',
                    value: gain == null ? '-' : '$gain ม.',
                  ),
                  _Stat(
                    label: 'เวลาเดิน',
                    value: _duration(track['moving_seconds']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// เส้นทางหนึ่งเส้นบนแผนที่ + สถิติเต็ม รวมถึงอันดับในรอบเดียวกันที่ backend
/// คำนวณให้ (ไม่เปิดเผยว่าใครเป็นใคร — เป็นบริบท ไม่ใช่การประกวด)
class TrackDetailScreen extends StatefulWidget {
  final String bookingRef;
  final String tripTitle;

  const TrackDetailScreen({
    super.key,
    required this.bookingRef,
    this.tripTitle = '',
  });

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  Map<String, dynamic>? _track;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final track = await context.read<AppProvider>().fetchMyTrack(
        widget.bookingRef,
      );
      if (!mounted) return;
      setState(() {
        _track = track;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<LatLng> get _points {
    final raw = _track?['points'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((p) {
          final lat = (p['lat'] as num?)?.toDouble();
          final lng = (p['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    final points = _points;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.tripTitle.isEmpty ? 'เส้นทางของฉัน' : widget.tripTitle,
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : track == null
          ? EmptyStateView(
              icon: _error == null
                  ? Icons.route_rounded
                  : Icons.wifi_off_rounded,
              title: _error == null
                  ? 'ไม่พบเส้นทางของรอบนี้'
                  : 'เปิดเส้นทางไม่สำเร็จ',
              body: _error,
              actionLabel: 'ลองใหม่',
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (points.length > 1)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    child: SizedBox(
                      height: 280,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCameraFit: CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.all(32),
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.luilaykhao.app',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: points,
                                strokeWidth: 4,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _DetailStats(track: track),
              ],
            ),
    );
  }
}

class _DetailStats extends StatelessWidget {
  final Map<String, dynamic> track;

  const _DetailStats({required this.track});

  String _duration(dynamic seconds) {
    final total = int.tryParse('$seconds') ?? 0;
    if (total <= 0) return '-';
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    if (hours == 0) return '$minutes นาที';
    return '$hours ชม. $minutes นาที';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      (
        'ระยะทางที่เดินจริง',
        '${(track['distance_km'] as num?)?.toStringAsFixed(2) ?? '-'} กม.',
      ),
      ('ความสูงสะสมที่ไต่', '${track['elevation_gain_m'] ?? '-'} ม.'),
      ('ความสูงสะสมที่ลง', '${track['elevation_loss_m'] ?? '-'} ม.'),
      ('จุดสูงสุด', '${track['max_elevation_m'] ?? '-'} ม.'),
      ('เวลาเดิน', _duration(track['moving_seconds'])),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    row.$1,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  Text(
                    row.$2,
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
