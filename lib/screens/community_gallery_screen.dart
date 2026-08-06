import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/moderation_sheet.dart';
import '../widgets/skeleton.dart';
import 'trip_detail_screen.dart' show TripDetailScreen;

/// "รูปจากคนที่ไปมาแล้ว" — กำแพงรูปรีวิวของลูกค้าจริงทุกทริป
///
/// รูปในหน้าทริปเป็นรูปที่เราเลือกมา รูปในหน้านี้ไม่ใช่ — เป็นสิ่งที่คนไปเจอ
/// จริงและถ่ายเอง พร้อมชื่อคนถ่ายและเดือนที่ไป ซึ่งเป็นสองอย่างที่ทำให้รูป
/// กลายเป็นข้อมูล ("ไปเดือนนี้ฟ้าเป็นแบบนี้") ไม่ใช่แค่ภาพสวย
class CommunityGalleryScreen extends StatefulWidget {
  const CommunityGalleryScreen({super.key});

  @override
  State<CommunityGalleryScreen> createState() => _CommunityGalleryScreenState();
}

class _CommunityGalleryScreenState extends State<CommunityGalleryScreen> {
  static const _monthLabels = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  final _scroll = ScrollController();

  List<Map<String, dynamic>> _photos = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int? _month;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final data = await context.read<AppProvider>().communityPhotos(
        month: _month,
      );
      if (!mounted) return;
      setState(() {
        _photos = _parse(data);
        _hasMore = data['has_more'] == true;
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

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final data = await context.read<AppProvider>().communityPhotos(
        month: _month,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _photos = [..._photos, ..._parse(data)];
        _hasMore = data['has_more'] == true;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // หน้าถัดไปโหลดไม่ได้ก็ยังดูของเดิมต่อได้ — เลื่อนอีกครั้งจะลองใหม่เอง
      setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> _parse(Map<String, dynamic> data) {
    return (data['photos'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _selectMonth(int? month) {
    HapticFeedback.selectionClick();
    setState(() => _month = month);
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
          'รูปจากคนที่ไปมาแล้ว',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
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
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const SkeletonBox(),
      );
    }

    if (_photos.isEmpty) {
      return EmptyStateView(
        icon: _error == null
            ? Icons.photo_library_outlined
            : Icons.wifi_off_rounded,
        title: _error == null
            ? (_month == null ? 'ยังไม่มีรูปจากลูกค้า' : 'เดือนนี้ยังไม่มีรูป')
            : 'โหลดรูปไม่สำเร็จ',
        body: _error ??
            (_month == null
                ? 'เมื่อมีคนรีวิวพร้อมรูป จะแสดงที่นี่'
                : 'ลองเลือกเดือนอื่นดูครับ'),
        actionLabel: 'ลองใหม่',
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: _photos.length + (_loadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _photos.length) return const SkeletonBox();
          return _PhotoTile(photo: _photos[index]);
        },
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

class _PhotoTile extends StatelessWidget {
  final Map<String, dynamic> photo;

  const _PhotoTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.mediaUrl(photo['url']);
    final slug = '${photo['trip_slug'] ?? ''}';
    final tripTitle = '${photo['trip_title'] ?? ''}';
    final monthLabel = '${photo['travel_month_label'] ?? ''}';
    final userName = '${photo['user_name'] ?? ''}';

    return Material(
      color: AppTheme.subtleSurface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: slug.isEmpty
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripDetailScreen(slug: slug),
                ),
              ),
        // รูปในกำแพงนี้มาจากรีวิวของลูกค้าคนอื่น — กดค้างเพื่อรายงาน/บล็อกเจ้าของรูป
        onLongPress: () {
          final reviewId = int.tryParse('${photo['review_id']}') ?? 0;
          if (reviewId <= 0) return;
          ModerationSheet.open(
            context,
            type: ModerationSheet.typeReview,
            id: reviewId,
            authorId: int.tryParse('${photo['user_id']}'),
            authorName: userName,
            contentLabel: 'รูปนี้',
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: url,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppTheme.border(context)),
                errorWidget: (_, _, _) =>
                    Container(color: AppTheme.border(context)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tripTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      userName,
                      monthLabel,
                    ].where((t) => t.trim().isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeMicro,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
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
