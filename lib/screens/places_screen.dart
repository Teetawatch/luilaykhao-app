import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import 'place_detail_screen.dart';

/// "เที่ยวไหนดี" — รายการปลายทางที่เรียงตามสถานที่ ไม่ใช่ตามรอบขาย
///
/// เว็บมีหน้านี้อยู่แล้ว แต่แอปเดิมเข้าถึงเนื้อหาชุดนี้ไม่ได้เลย ทั้งที่เป็นสิ่งที่
/// คนเปิดดูตอนยังไม่รู้ว่าอยากไปไหน — คนละคำถามกับ "ทริปไหนว่าง" ที่หน้าแรกตอบอยู่
///
/// ฟิลเตอร์เดือนคือหัวใจ: ภูกระดึงปิดหน้าฝน ทะเลใต้คนละหน้ากับทะเลอันดามัน
/// backend กรองให้แล้วทั้งเดือนที่ "ควรไป" และตัดเดือนที่ปิดออก
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  static const _monthLabels = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  List<Map<String, dynamic>> _places = const [];
  List<Map<String, dynamic>> _regions = const [];
  bool _loading = true;
  String? _error;

  int? _month;
  String? _region;

  @override
  void initState() {
    super.initState();

    // ของที่เคยโหลดไว้ขึ้นก่อน แล้วค่อยไปเอาของสด — หน้านี้เป็นเนื้อหาที่แทบ
    // ไม่เปลี่ยนรายวัน จอเปล่ารอโหลดจึงเสียเปล่า
    final cached = context.read<AppProvider>().cachedPlaces;
    if (cached != null) _apply(cached, loading: true);

    _load();
  }

  void _apply(Map<String, dynamic> data, {required bool loading}) {
    _places = (data['places'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final filters = data['filters'];
    if (filters is Map) {
      _regions = (filters['regions'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    _loading = loading;
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await context.read<AppProvider>().places(
        month: _month,
        region: _region,
      );
      if (!mounted) return;
      setState(() => _apply(data, loading: false));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _places.isEmpty
            ? e.toString().replaceFirst('Exception: ', '')
            : null;
      });
    }
  }

  void _setMonth(int? month) {
    HapticFeedback.selectionClick();
    setState(() {
      _month = month;
      _loading = true;
    });
    _load();
  }

  void _setRegion(String? region) {
    HapticFeedback.selectionClick();
    setState(() {
      _region = region;
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'เที่ยวไหนดี',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
          children: [
            const _FilterLabel(
              label: 'ไปเดือนไหน',
              hint: 'เลือกเดือนแล้วจะเหลือเฉพาะที่ที่ไปช่วงนั้นสวย และตัดที่ปิดออกให้',
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _Chip(
                    label: 'ทั้งปี',
                    selected: _month == null,
                    onTap: () => _setMonth(null),
                  ),
                  for (var i = 1; i <= 12; i++)
                    _Chip(
                      label: _monthLabels[i - 1],
                      selected: _month == i,
                      onTap: () => _setMonth(_month == i ? null : i),
                    ),
                ],
              ),
            ),
            if (_regions.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _FilterLabel(label: 'ภาค'),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _Chip(
                      label: 'ทุกภาค',
                      selected: _region == null,
                      onTap: () => _setRegion(null),
                    ),
                    for (final region in _regions)
                      _Chip(
                        label: '${region['label']}',
                        selected: _region == '${region['key']}',
                        onTap: () => _setRegion(
                          _region == '${region['key']}'
                              ? null
                              : '${region['key']}',
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            ..._buildResults(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults() {
    if (_loading && _places.isEmpty) {
      return List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SkeletonBox(
            height: 190,
            borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusLg)),
          ),
        ),
      );
    }

    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyStateView(
            icon: Icons.wifi_off_rounded,
            title: 'โหลดปลายทางไม่สำเร็จ',
            body: _error!,
            actionLabel: 'ลองใหม่',
            onAction: _load,
          ),
        ),
      ];
    }

    if (_places.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyStateView(
            icon: Icons.travel_explore_rounded,
            title: 'เดือนนี้ยังไม่มีที่แนะนำ',
            body: _month == null
                ? 'ยังไม่มีข้อมูลปลายทางในตอนนี้'
                : 'ลองเลือกเดือนอื่น หรือดูทั้งปีดูครับ',
            actionLabel: _month == null ? null : 'ดูทั้งปี',
            onAction: _month == null ? null : () => _setMonth(null),
          ),
        ),
      ];
    }

    return _places
        .map(
          (place) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _PlaceCard(place: place),
          ),
        )
        .toList();
  }
}

class _FilterLabel extends StatelessWidget {
  final String label;
  final String? hint;

  const _FilterLabel({required this.label, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: appFont(
                fontSize: AppText.sizeCaption,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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

class _PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;

  const _PlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    final cover = ApiConfig.mediaUrl(place['cover_image']);
    final name = '${place['name'] ?? ''}';
    final summary = '${place['summary'] ?? ''}';
    final province = '${place['province'] ?? ''}';
    final typeLabel = '${place['type_label'] ?? ''}';
    final difficulty = '${place['difficulty_label'] ?? ''}';
    final elevation = place['elevation_m'];

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceDetailScreen(slug: '${place['slug']}'),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: appFont(
                      fontSize: AppText.sizeTitle,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  if (province.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        province,
                        typeLabel,
                      ].where((t) => t.isNotEmpty).join(' · '),
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                  if (difficulty.isNotEmpty || elevation != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (difficulty.isNotEmpty)
                          _MetaPill(
                            icon: Icons.terrain_rounded,
                            label: difficulty,
                          ),
                        if (elevation != null)
                          _MetaPill(
                            icon: Icons.height_rounded,
                            label: 'สูง $elevation ม.',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.mutedText(context)),
          const SizedBox(width: 5),
          Text(
            label,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}
