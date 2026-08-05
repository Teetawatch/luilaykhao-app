import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import 'trip_detail_screen.dart' show TripDetailScreen;

/// "ทริปบนแผนที่" — เลือกจากตำแหน่งจริงแทนการเลื่อนดูรายการ
///
/// คำถามที่หน้ารายการตอบไม่ได้คือ "แถวนี้มีอะไรบ้าง" — คนที่ขับรถเองหรือมีเวลา
/// จำกัดคิดจากระยะทางก่อนคิดจากชื่อทริป เว็บมีหน้านี้แล้ว (/explore) แอปยังไม่มี
///
/// ใช้ flutter_map ตัวเดียวกับแผนที่พิชิต — ไม่ต้องมีคีย์ Google และเป็นสไตล์
/// แผนที่เดียวกันทั้งแอป
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  static const LatLng _thailandCenter = LatLng(13.6, 100.9);
  static const double _thailandZoom = 5.1;

  static const _monthLabels = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  final MapController _map = MapController();

  List<Map<String, dynamic>> _trips = const [];
  bool _loading = true;
  String? _error;
  int? _month;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();

    // หมุดชุดก่อนหน้าขึ้นทันที แล้วค่อยอัปเดตด้วยของสด — แผนที่ที่เปิดมาแล้ว
    // ว่างเปล่าสองวินาทีดูเหมือนไม่มีทริปเลย
    final cached = context.read<AppProvider>().cachedTripsOnMap;
    if (cached.isNotEmpty) {
      _trips = cached;
      _loading = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final trips = await context.read<AppProvider>().tripsOnMap();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _trips.isEmpty
            ? e.toString().replaceFirst('Exception: ', '')
            : null;
      });
    }
  }

  /// ทริปที่มีรอบออกเดินทางในเดือนที่เลือก — กรองในเครื่องจาก `months` ที่
  /// backend ส่งมาพร้อมหมุด ไม่ต้องยิงใหม่ทุกครั้งที่เปลี่ยนเดือน
  List<Map<String, dynamic>> get _visible {
    final month = _month;
    if (month == null) return _trips;
    return _trips.where((trip) {
      final months = (trip['months'] as List? ?? const [])
          .map((e) => int.tryParse('$e') ?? 0)
          .toList();
      return months.contains(month);
    }).toList();
  }

  void _selectMonth(int? month) {
    HapticFeedback.selectionClick();
    setState(() {
      _month = month;
      // หมุดที่เลือกค้างไว้อาจหลุดจากฟิลเตอร์ใหม่ — ปิดการ์ดไปด้วยกัน
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'ทริปบนแผนที่',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
          ? EmptyStateView(
              icon: _error == null
                  ? Icons.map_outlined
                  : Icons.wifi_off_rounded,
              title: _error == null ? 'ยังไม่มีทริปบนแผนที่' : 'โหลดแผนที่ไม่สำเร็จ',
              body: _error,
              actionLabel: 'ลองใหม่',
              onAction: _load,
            )
          : Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    children: [
                      _MonthChip(
                        label: 'ทุกเดือน',
                        selected: _month == null,
                        onTap: () => _selectMonth(null),
                      ),
                      for (var i = 1; i <= 12; i++)
                        _MonthChip(
                          label: _monthLabels[i - 1],
                          selected: _month == i,
                          onTap: () => _selectMonth(_month == i ? null : i),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: _thailandCenter,
                          initialZoom: _thailandZoom,
                          minZoom: 4.5,
                          maxZoom: 14,
                          // แตะที่ว่างบนแผนที่ = ปิดการ์ด
                          onTap: (_, _) => setState(() => _selected = null),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.luilaykhao.app',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final trip in visible)
                                Marker(
                                  point: LatLng(
                                    (trip['latitude'] as num).toDouble(),
                                    (trip['longitude'] as num).toDouble(),
                                  ),
                                  width: 44,
                                  height: 44,
                                  child: _TripPin(
                                    selected:
                                        _selected?['id'] == trip['id'],
                                    onTap: () =>
                                        setState(() => _selected = trip),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (visible.isEmpty)
                        const Positioned(
                          left: 16,
                          right: 16,
                          top: 16,
                          child: _FloatingNote(
                            text:
                                'เดือนนี้ยังไม่มีรอบเปิด ลองเลือกเดือนอื่นดูครับ',
                          ),
                        ),
                      if (_selected != null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _TripPreviewCard(
                            trip: _selected!,
                            onClose: () => setState(() => _selected = null),
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

class _MonthChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MonthChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppTheme.primaryColor
            : AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.onSurface(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripPin extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _TripPin({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: selected ? 26 : 20,
          height: selected ? 26 : 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}

class _FloatingNote extends StatelessWidget {
  final String text;

  const _FloatingNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurface(context),
        ),
      ),
    );
  }
}

class _TripPreviewCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onClose;

  const _TripPreviewCard({required this.trip, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cover = ApiConfig.mediaUrl(trip['cover_image']);
    final nextLabel = '${trip['next_departure_label'] ?? ''}';
    final upcoming = int.tryParse('${trip['upcoming_count']}') ?? 0;
    final price = (trip['price_from'] as num?)?.round();

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(slug: '${trip['slug']}'),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (cover.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: CachedNetworkImage(
                    imageUrl: cover,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: 76,
                      height: 76,
                      color: AppTheme.subtleSurface(context),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 76,
                      height: 76,
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
                    const SizedBox(height: 3),
                    Text(
                      [
                        '${trip['location'] ?? ''}',
                        if (nextLabel.isNotEmpty) 'รอบถัดไป $nextLabel',
                        if (upcoming > 0) 'เปิด $upcoming รอบ',
                      ].where((t) => t.trim().isNotEmpty).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'เริ่มต้น ฿$price',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ปิด',
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppTheme.mutedText(context),
                ),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
