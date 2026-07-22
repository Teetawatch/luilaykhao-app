import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';

/// "แผนที่พิชิต" — every trip this traveller has actually finished, dropped on a
/// map of Thailand, with how deep they have gone into each region underneath.
///
/// This is a record, not a shop: the only trips plotted are ones already walked,
/// the numbers are the traveller's own, and regions never visited are shown as
/// plain counts rather than recommendations. Reads GET /me/passport/map.
class ConquestMapScreen extends StatefulWidget {
  const ConquestMapScreen({super.key});

  @override
  State<ConquestMapScreen> createState() => _ConquestMapScreenState();
}

class _ConquestMapScreenState extends State<ConquestMapScreen> {
  static const LatLng _thailandCenter = LatLng(13.6, 100.9);
  static const double _thailandZoom = 5.1;

  final MapController _map = MapController();

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _error = false;
  String? _selectedRegion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().fetchConquestMap();
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

  List<Map<String, dynamic>> get _pins => List<Map<String, dynamic>>.from(
    (_data?['pins'] as List? ?? const []).map(
      (e) => Map<String, dynamic>.from(e as Map),
    ),
  );

  List<Map<String, dynamic>> get _regions => List<Map<String, dynamic>>.from(
    (_data?['regions'] as List? ?? const []).map(
      (e) => Map<String, dynamic>.from(e as Map),
    ),
  );

  List<Map<String, dynamic>> get _frontier => List<Map<String, dynamic>>.from(
    (_data?['frontier'] as List? ?? const []).map(
      (e) => Map<String, dynamic>.from(e as Map),
    ),
  );

  Map<String, dynamic> get _summary =>
      Map<String, dynamic>.from(_data?['summary'] as Map? ?? const {});

  /// Pins for the region currently selected in the strip below the map — or all
  /// of them when nothing is selected.
  List<Map<String, dynamic>> get _visiblePins {
    final region = _selectedRegion;
    if (region == null) return _pins;
    return _pins.where((p) => p['region'] == region).toList();
  }

  void _focusRegion(String? key) {
    HapticFeedback.selectionClick();
    setState(() => _selectedRegion = _selectedRegion == key ? null : key);

    final pins = _visiblePins;
    if (pins.isEmpty) {
      _map.move(_thailandCenter, _thailandZoom);
      return;
    }
    if (pins.length == 1) {
      _map.move(
        LatLng(
          (pins.first['latitude'] as num).toDouble(),
          (pins.first['longitude'] as num).toDouble(),
        ),
        9,
      );
      return;
    }

    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          for (final p in pins)
            LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
        ]),
        padding: const EdgeInsets.all(56),
        maxZoom: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: const Text(
          'แผนที่พิชิต',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const _ConquestSkeleton()
          : _error
          ? EmptyStateView(
              icon: Icons.wifi_off_rounded,
              title: 'โหลดแผนที่ไม่สำเร็จ',
              body: 'ตรวจสอบการเชื่อมต่อแล้วลองใหม่อีกครั้ง',
              actionLabel: 'ลองอีกครั้ง',
              onAction: _load,
            )
          : _pins.isEmpty
          ? const EmptyStateView(
              icon: Icons.map_outlined,
              title: 'ยังไม่มีหมุดบนแผนที่',
              body:
                  'เมื่อคุณเดินทางจบทริปแรก ทริปนั้นจะขึ้นมาเป็นหมุดที่นี่ '
                  'พร้อมสถิติของคุณเองในแต่ละภาค',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMap(),
                  _ConquestSummary(summary: _summary),
                  _RegionProgress(
                    regions: _regions,
                    selected: _selectedRegion,
                    onSelect: _focusRegion,
                  ),
                  if (_selectedRegion != null)
                    _RegionDetail(
                      region: _regions.firstWhere(
                        (r) => r['key'] == _selectedRegion,
                        orElse: () => const {},
                      ),
                      pins: _visiblePins,
                    ),
                  _FrontierNote(frontier: _frontier),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildMap() {
    return SizedBox(
      height: 380,
      child: FlutterMap(
        mapController: _map,
        options: const MapOptions(
          initialCenter: _thailandCenter,
          initialZoom: _thailandZoom,
          minZoom: 4.5,
          maxZoom: 14,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.luilaykhao.app',
          ),
          // Faint line through the trips in the order they were walked — the
          // shape of one person's travelling, not a suggested route.
          if (_pins.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    for (final p in _pins)
                      LatLng(
                        (p['latitude'] as num).toDouble(),
                        (p['longitude'] as num).toDouble(),
                      ),
                  ],
                  strokeWidth: 1.5,
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final pin in _pins)
                Marker(
                  point: LatLng(
                    (pin['latitude'] as num).toDouble(),
                    (pin['longitude'] as num).toDouble(),
                  ),
                  width: 44,
                  height: 44,
                  child: _ConquestPin(
                    pin: pin,
                    dimmed:
                        _selectedRegion != null &&
                        pin['region'] != _selectedRegion,
                    onTap: () => _showPinSheet(pin),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPinSheet(Map<String, dynamic> pin) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinSheet(pin: pin),
    );
  }
}

// ─── Map pin ─────────────────────────────────────────────────────────────────

class _ConquestPin extends StatelessWidget {
  final Map<String, dynamic> pin;
  final bool dimmed;
  final VoidCallback onTap;

  const _ConquestPin({
    required this.pin,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visits = int.tryParse('${pin['visits'] ?? 1}') ?? 1;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.35 : 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                Icons.flag_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            // Repeat visits are worth showing — going back is its own signal.
            if (visits > 1)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '$visits',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
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

class _PinSheet extends StatelessWidget {
  final Map<String, dynamic> pin;

  const _PinSheet({required this.pin});

  @override
  Widget build(BuildContext context) {
    final thumbnail = ApiConfig.mediaUrl('${pin['thumbnail'] ?? ''}');
    final visits = int.tryParse('${pin['visits'] ?? 1}') ?? 1;
    final distance = double.tryParse('${pin['distance_km'] ?? 0}') ?? 0;
    final elevation = int.tryParse('${pin['elevation_gain_m'] ?? 0}') ?? 0;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnail.isNotEmpty)
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Image.network(thumbnail, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${pin['title'] ?? ''}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    visits > 1
                        ? 'ไปมาแล้ว $visits ครั้ง · ครั้งแรก ${pin['first_visit_label'] ?? ''} · ล่าสุด ${pin['last_visit_label'] ?? ''}'
                        : 'เดินทางเมื่อ ${pin['first_visit_label'] ?? ''}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (distance > 0)
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.straighten_rounded,
                            value: distance
                                .toStringAsFixed(distance % 1 == 0 ? 0 : 1),
                            unit: 'กม.',
                            label: 'ระยะทาง',
                          ),
                        ),
                      if (elevation > 0)
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.landscape_rounded,
                            value: '$elevation',
                            unit: 'ม.',
                            label: 'ความสูงสะสม',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
            children: [
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 12,
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

// ─── Summary ─────────────────────────────────────────────────────────────────

class _ConquestSummary extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _ConquestSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    final visited = int.tryParse('${summary['regions_visited'] ?? 0}') ?? 0;
    final total = int.tryParse('${summary['regions_total'] ?? 7}') ?? 7;
    final trips = int.tryParse('${summary['trips_visited'] ?? 0}') ?? 0;
    final departures = int.tryParse('${summary['departures_count'] ?? 0}') ?? 0;
    final distance =
        double.tryParse('${summary['total_distance_km'] ?? 0}') ?? 0;
    final elevation =
        int.tryParse('${summary['total_elevation_gain_m'] ?? 0}') ?? 0;
    final toughest = Map<String, dynamic>.from(
      summary['toughest'] as Map? ?? const {},
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'พิชิตแล้ว $visited จาก $total ภาค',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            departures > trips
                ? '$trips เส้นทาง · ออกเดินทาง $departures ครั้ง'
                : '$trips เส้นทาง',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.straighten_rounded,
                  value: distance.toStringAsFixed(distance % 1 == 0 ? 0 : 1),
                  unit: 'กม.',
                  label: 'เดินสะสม',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.landscape_rounded,
                  value: '$elevation',
                  unit: 'ม.',
                  label: 'ไต่สะสม',
                ),
              ),
            ],
          ),
          if (toughest.isNotEmpty && (toughest['elevation_gain_m'] ?? 0) != 0)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'หนักที่สุดที่เคยเดิน: ${toughest['title']} (${toughest['elevation_gain_m']} ม.)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Region progress ─────────────────────────────────────────────────────────

class _RegionProgress extends StatelessWidget {
  final List<Map<String, dynamic>> regions;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _RegionProgress({
    required this.regions,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text(
            'รายภาค',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: regions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final region = regions[index];
              final visited = region['visited'] == true;
              final isSelected = selected == region['key'];

              return GestureDetector(
                onTap: visited ? () => onSelect('${region['key']}') : null,
                child: Container(
                  width: 132,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : visited
                        ? AppTheme.subtleSurface(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: visited
                          ? Colors.transparent
                          : AppTheme.border(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${region['label']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : visited
                              ? AppTheme.onSurface(context)
                              : AppTheme.mutedText(context),
                        ),
                      ),
                      if (visited)
                        Text(
                          '${region['trips_count']} เส้นทาง\n${region['elevation_gain_m']} ม.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.85)
                                : AppTheme.mutedText(context),
                          ),
                        )
                      else
                        Text(
                          'ยังไม่เคยไป',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RegionDetail extends StatelessWidget {
  final Map<String, dynamic> region;
  final List<Map<String, dynamic>> pins;

  const _RegionDetail({required this.region, required this.pins});

  @override
  Widget build(BuildContext context) {
    if (region.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ไปครั้งแรก ${region['first_visit_label'] ?? '-'} · ล่าสุด ${region['last_visit_label'] ?? '-'}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          for (final pin in pins)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${pin['title']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                  Text(
                    '${pin['elevation_gain_m']} ม.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
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

/// The regions still untouched, stated as a fact rather than an offer.
class _FrontierNote extends StatelessWidget {
  final List<Map<String, dynamic>> frontier;

  const _FrontierNote({required this.frontier});

  @override
  Widget build(BuildContext context) {
    final withTrips = frontier
        .where((f) => (int.tryParse('${f['open_trips_count'] ?? 0}') ?? 0) > 0)
        .toList();
    if (withTrips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ภาคที่ยังไม่เคยไป',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            withTrips
                .map((f) => '${f['label']} (${f['open_trips_count']} เส้นทาง)')
                .join(' · '),
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConquestSkeleton extends StatelessWidget {
  const _ConquestSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SkeletonBox(height: 340, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 20),
        SkeletonBox(height: 24, width: 200, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 12),
        SkeletonBox(height: 16, width: 140, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 24),
        SkeletonBox(height: 96, borderRadius: BorderRadius.circular(14)),
      ],
    );
  }
}
