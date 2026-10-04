import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../services/offline_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import 'staff_check_in_screen.dart' show asMap, asList, textOf;

int _int(dynamic value) => int.tryParse(textOf(value, '0')) ?? 0;

/// "อีก N วัน" นับจากวันนี้ตามเวลาไทย — คนจัดของอยากรู้ว่ารอบไหนต้องเสร็จก่อน
String _countdownLabel(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(today).inDays;
  if (days < 0) return 'ออกเดินทางแล้ว';
  if (days == 0) return 'วันนี้';
  if (days == 1) return 'พรุ่งนี้';
  return 'อีก $days วัน';
}

/// รอบที่ยังไม่ออกเดินทางและมีคนเช่าอุปกรณ์ — หน้าแรกของคนจัดของ (บทบาทเสริม packer)
///
/// ตัวเลขชุดเดียวกับหน้า "อุปกรณ์เช่าที่ต้องเตรียม" ของหลังบ้าน แต่ไม่มีราคาและ
/// เบอร์โทรลูกค้า — เดิมแอดมินต้องโหลด PDF ส่งให้ทุกรอบ
class PackingScheduleListScreen extends StatefulWidget {
  const PackingScheduleListScreen({super.key});

  @override
  State<PackingScheduleListScreen> createState() =>
      _PackingScheduleListScreenState();
}

class _PackingScheduleListScreenState extends State<PackingScheduleListScreen> {
  List<Map<String, dynamic>>? _schedules;
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
      final schedules = await context
          .read<AppProvider>()
          .loadPackingSchedules();
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'ใบเตรียมของ',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'โหลดใหม่',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _schedules == null) {
      return const SkeletonList(count: 4, padding: EdgeInsets.only(top: 8));
    }
    if (_error != null && _schedules == null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดรายการรอบไม่สำเร็จ',
        body: _error!,
        actionLabel: 'ลองใหม่',
        onAction: _load,
        accent: AppTheme.errorColor,
      );
    }

    final schedules = _schedules ?? const [];
    if (schedules.isEmpty) {
      return const ScrollableEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'ยังไม่มีรอบที่ต้องเตรียมของ',
        body: 'รอบที่กำลังจะออกเดินทางยังไม่มีใครเช่าอุปกรณ์',
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        Text(
          'รอบที่กำลังจะออกเดินทาง เรียงจากใกล้สุด',
          style: appFont(
            fontSize: AppText.sizeLabel,
            fontWeight: FontWeight.w700,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 8),
        for (final schedule in schedules) ...[
          _PackingScheduleCard(
            schedule: schedule,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PackingListScreen(
                    scheduleId: _int(schedule['id']),
                    title: textOf(schedule['trip_title'], 'ทริป'),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PackingScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onTap;

  const _PackingScheduleCard({required this.schedule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final countdown = _countdownLabel(textOf(schedule['departure_date']));
    final soon = countdown == 'วันนี้' || countdown == 'พรุ่งนี้';
    final bookings = _int(schedule['bookings_with_rentals']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: AppTheme.cardDecoration(
            context,
            radius: AppTheme.radiusMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textOf(schedule['trip_title'], 'ทริป'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      textOf(schedule['departure_date_thai']),
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (countdown.isNotEmpty)
                          _Pill(
                            label: countdown,
                            color: soon
                                ? AppTheme.warningColor
                                : AppTheme.primaryColor,
                          ),
                        _Pill(
                          label: '$bookings ใบจองเช่าอุปกรณ์',
                          color: AppTheme.mutedText(context),
                        ),
                      ],
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

/// ใบเตรียมของหนึ่งรอบ — สามมุมเหมือน PDF หลังบ้าน: ของที่ต้องหยิบ (แตกชุดแล้ว)
/// ชุดไหนประกอบด้วยอะไร และของใครบ้าง (ไว้แยกใส่ถุงรายคน)
///
/// ติ๊ก "จัดแล้ว" เก็บไว้ในเครื่องเท่านั้น เป็นเช็กลิสต์ส่วนตัวของคนจัด จำทั้งชื่อ
/// และจำนวน — ถ้ามีคนเช่าเพิ่มหลังติ๊ก จำนวนเปลี่ยน ติ๊กนั้นจะหลุดให้นับใหม่เอง
class PackingListScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const PackingListScreen({
    super.key,
    required this.scheduleId,
    required this.title,
  });

  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  /// แสดงอยู่จากแคชเพราะโหลดใหม่ไม่สำเร็จ
  bool _fromCache = false;

  /// "ชื่อชิ้น|จำนวน" ที่ติ๊กจัดแล้ว
  Set<String> _packed = {};

  String get _ticksKey => 'packing_ticks.${widget.scheduleId}';

  @override
  void initState() {
    super.initState();
    final ticks = OfflineCache.instance.readAccount<List>(_ticksKey);
    _packed = {...?ticks?.map((e) => '$e')};
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await app.loadPackingList(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _fromCache = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final cached = _data ?? app.cachedPackingList(widget.scheduleId);
      setState(() {
        _data = cached;
        _fromCache = cached != null;
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  void _toggle(String tickKey) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_packed.remove(tickKey)) _packed.add(tickKey);
    });
    OfflineCache.instance.writeAccount(_ticksKey, _packed.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'ใบเตรียมของ',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'โหลดใหม่',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) {
      return const SkeletonList(count: 5, padding: EdgeInsets.only(top: 8));
    }
    if (_data == null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดใบเตรียมของไม่สำเร็จ',
        body: _error ?? '',
        actionLabel: 'ลองใหม่',
        onAction: _load,
        accent: AppTheme.errorColor,
      );
    }

    final schedule = asMap(_data?['schedule']);
    final totals = asMap(_data?['totals']);
    final picking = asList(_data?['picking']).map(asMap).toList();
    final sets = asList(
      _data?['items'],
    ).map(asMap).where((item) => item['is_set'] == true).toList();
    final bookings = asList(_data?['bookings']).map(asMap).toList();

    if (picking.isEmpty) {
      return const ScrollableEmptyState(
        icon: Icons.backpack_outlined,
        title: 'รอบนี้ยังไม่มีใครเช่าอุปกรณ์',
        body: 'ไม่ต้องเตรียมอุปกรณ์เช่าสำหรับรอบนี้',
      );
    }

    final packedLines = picking
        .where((piece) => _packed.contains(_tickKeyOf(piece)))
        .length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        if (_fromCache) ...[
          _CachedBanner(cachedAt: textOf(_data?['cached_at'])),
          const SizedBox(height: 10),
        ],
        _PackingHeader(
          title: textOf(schedule['trip_title'], widget.title),
          dateLabel: textOf(schedule['departure_date_thai']),
          countdown: _countdownLabel(textOf(schedule['departure_date'])),
          pieces: _int(totals['picking_pieces']),
          lines: picking.length,
          bookings: _int(totals['bookings']),
          packedLines: packedLines,
        ),
        const SizedBox(height: 18),
        const _SectionLabel(
          'ของที่ต้องหยิบ',
          hint: 'แตกชุดเป็นชิ้นแล้ว แตะเพื่อติ๊กว่าจัดแล้ว',
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.cardDecoration(
            context,
            radius: AppTheme.radiusMd,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < picking.length; i++) ...[
                _PickRow(
                  piece: picking[i],
                  packed: _packed.contains(_tickKeyOf(picking[i])),
                  onTap: () => _toggle(_tickKeyOf(picking[i])),
                ),
                if (i < picking.length - 1)
                  Divider(height: 0.5, color: AppTheme.border(context)),
              ],
            ],
          ),
        ),
        if (sets.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _SectionLabel('ชุดประกอบด้วย'),
          const SizedBox(height: 8),
          for (final set in sets) ...[
            _SetCard(item: set),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 8),
        const _SectionLabel('ของใครบ้าง', hint: 'ไว้แยกใส่ถุงรายคน'),
        const SizedBox(height: 8),
        for (final booking in bookings) ...[
          _BookingCard(booking: booking),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static String _tickKeyOf(Map<String, dynamic> piece) =>
      '${textOf(piece['name'])}|${_int(piece['quantity'])}';
}

class _PackingHeader extends StatelessWidget {
  final String title;
  final String dateLabel;
  final String countdown;
  final int pieces;
  final int lines;
  final int bookings;
  final int packedLines;

  const _PackingHeader({
    required this.title,
    required this.dateLabel,
    required this.countdown,
    required this.pieces,
    required this.lines,
    required this.bookings,
    required this.packedLines,
  });

  @override
  Widget build(BuildContext context) {
    final done = lines > 0 && packedLines >= lines;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            countdown.isEmpty ? dateLabel : '$dateLabel · $countdown',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(value: '$pieces', label: 'ชิ้นทั้งหมด'),
              _Stat(value: '$lines', label: 'รายการ'),
              _Stat(value: '$bookings', label: 'ใบจอง'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                size: 16,
                color: done
                    ? AppTheme.primaryColor
                    : AppTheme.mutedText(context),
              ),
              const SizedBox(width: 6),
              Text(
                done
                    ? 'จัดครบทุกรายการแล้ว'
                    : 'จัดแล้ว $packedLines / $lines รายการ',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: done
                      ? AppTheme.primaryColor
                      : AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: lines == 0 ? 0 : (packedLines / lines).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppTheme.border(context),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: appFont(
              fontSize: AppText.sizeH2,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
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

/// ชิ้นที่ต้องหยิบหนึ่งบรรทัด — บอกด้วยว่ามาจากชุดไหน เพราะถุงนอนอาจมาจากทั้ง
/// "ชุดเต็นท์" และการเช่าถุงนอนเดี่ยว ๆ ในรอบเดียวกัน
class _PickRow extends StatelessWidget {
  final Map<String, dynamic> piece;
  final bool packed;
  final VoidCallback onTap;

  const _PickRow({
    required this.piece,
    required this.packed,
    required this.onTap,
  });

  String _sourcesLabel() {
    final sources = asList(piece['sources']).map(asMap).toList();
    // เช่าเดี่ยวอย่างเดียว ไม่มีอะไรต้องอธิบาย
    if (sources.length == 1 && sources.first['is_set'] != true) return '';

    return sources
        .map((source) {
          final label = source['is_set'] == true
              ? textOf(source['name'])
              : 'เช่าเดี่ยว';
          return '$label ${_int(source['quantity'])}';
        })
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sourcesLabel();
    final quantity = _int(piece['quantity']);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            Icon(
              packed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: packed
                  ? AppTheme.primaryColor
                  : AppTheme.mutedText(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textOf(piece['name']),
                    style:
                        appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w700,
                          color: packed
                              ? AppTheme.mutedText(context)
                              : AppTheme.onSurface(context),
                          height: 1.3,
                        ).copyWith(
                          decoration: packed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  if (sources.isNotEmpty)
                    Text(
                      sources,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '×$quantity',
              style: appFont(
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w800,
                color: packed
                    ? AppTheme.mutedText(context)
                    : AppTheme.onSurface(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _SetCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final parts = asList(item['parts']).map(asMap).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  textOf(item['name']),
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Text(
                '${_int(item['quantity'])} ชุด',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final part in parts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${textOf(part['name'])} (ชุดละ ${_int(part['quantity_each'])})',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ),
                  Text(
                    '×${_int(part['quantity'])}',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
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

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ref = textOf(booking['booking_ref']);
    final items = asList(booking['items']).map(asMap).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            textOf(booking['customer_name'], ref),
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          Text(
            ref,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 6),
          for (final line in items) _BookingLine(line: line),
        ],
      ),
    );
  }
}

class _BookingLine extends StatelessWidget {
  final Map<String, dynamic> line;

  const _BookingLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final quantity = _int(line['quantity']);
    final parts = asList(line['parts']).map(asMap).toList();
    final partsLabel = parts
        .map((p) => '${textOf(p['name'])} ${_int(p['quantity']) * quantity}')
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  textOf(line['name']),
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Text(
                '×$quantity',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          if (partsLabel.isNotEmpty)
            Text(
              partsLabel,
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

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? hint;

  const _SectionLabel(this.title, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface(context),
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeCaption,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CachedBanner extends StatelessWidget {
  final String cachedAt;

  const _CachedBanner({required this.cachedAt});

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse(cachedAt)?.toLocal();
    final time = at == null
        ? ''
        : ' (โหลดไว้เมื่อ ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} น.)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ไม่มีสัญญาณ — แสดงรายการล่าสุดที่โหลดไว้$time',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
