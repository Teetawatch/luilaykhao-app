import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual state of a single seat. The widget maps each tone to a consistent,
/// iOS-flavoured palette so every screen that renders the vehicle layout looks
/// the same as the real booking flow.
enum SeatTone {
  available,

  /// Seat the user is picking right now in this session.
  picking,

  /// Seat already claimed by the current user.
  mine,

  /// Seat claimed by another member of the same group.
  group,

  /// Seat temporarily locked by someone outside the group.
  locked,

  /// Seat already booked.
  booked,
}

typedef SeatToneResolver =
    SeatTone Function(Map<String, dynamic> seat, String id);
typedef SeatSelectableResolver =
    bool Function(Map<String, dynamic> seat, String id);
typedef SeatTapHandler = void Function(Map<String, dynamic> seat, String id);
typedef SeatTextResolver =
    String? Function(Map<String, dynamic> seat, String id);
typedef SeatBadgeResolver =
    IconData? Function(Map<String, dynamic> seat, String id);

/// ชนิดโครงรถที่วาดได้ — มาจาก `layout_kind` ของผัง (ฝั่งเซิร์ฟเวอร์เติมให้เสมอ
/// ดู `App\Support\SeatLayoutFactory`) ผังรุ่นเก่าที่ไม่มีคีย์นี้ถือเป็นรถตู้
enum VehicleKind { van, bus, boat }

/// ผังที่นั่งตามรูปทรงรถจริง — กระจกหน้า คนขับ (พวงมาลัยขวาแบบไทย จึงอยู่ฝั่งขวา)
/// ประตูฝั่งซ้าย ทางเดินกลาง แล้วปิดท้ายด้วยท้ายรถ
///
/// ความกว้างถูกย่อให้พอดีจอเสมอ (`_fitScale`) เพราะรถบัส 2+2 และแถวหลัง 5 ที่
/// กว้างเกินมือถือถ้าวาดขนาดเต็ม — การต้องเลื่อนซ้ายขวาเพื่อดูผังทำให้ลูกค้า
/// มองไม่เห็นรถทั้งคันพร้อมกัน ซึ่งเป็นเหตุผลเดียวที่ต้องมีผัง
class VehicleSeatMap extends StatelessWidget {
  final Map<String, dynamic> seatMap;
  final SeatToneResolver toneFor;
  final SeatSelectableResolver selectableFor;
  final SeatTapHandler onSeatTap;

  /// แตะที่นั่งที่เลือกไม่ได้ — ใช้บอกเหตุผลแทนที่จะเงียบไปเฉย ๆ
  final SeatTapHandler? onBlockedSeatTap;

  /// ข้อความอธิบายที่นั่ง (tooltip เมื่อกดค้าง)
  final SeatTextResolver? tooltipFor;

  /// ไอคอนมุมที่นั่ง — ไม่ส่งมาก็ใช้ของโทนสีนั้น
  final SeatBadgeResolver? badgeFor;

  /// เน้นที่นั่งของผู้ใช้ (SeatTone.mine) ให้เด่นเป็นพิเศษ — ไอคอนคน + ป้ายถูก
  /// ใหญ่ + วงแหวนไฮไลต์ ใช้ในหน้าดูการจองเพื่อบอกชัด ๆ ว่าเรานั่งที่ไหน
  final bool highlightMine;

  const VehicleSeatMap({
    super.key,
    required this.seatMap,
    required this.toneFor,
    required this.selectableFor,
    required this.onSeatTap,
    this.onBlockedSeatTap,
    this.tooltipFor,
    this.badgeFor,
    this.highlightMine = false,
  });

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(seatMap);
    final frontSeatId = _text(seatMap['front_seat']);
    final frontSeat = frontSeatId.isEmpty
        ? null
        : _seatById(seatMap, frontSeatId);
    final rows = _seatRows(seatMap);
    final showDriver = seatMap['show_driver'] != false;
    // ประตูขึ้นรถอยู่ติดที่นั่งหน้าฝั่งซ้าย ไม่ใช่แถบสีข้างแถว — แถบสีที่ไม่มี
    // ป้ายกำกับทำให้ต้องเดาว่ามันคืออะไร ซึ่งแปลว่ามันสื่อไม่สำเร็จ
    final hasDoor = _hasDoor(seatMap);
    // เลขแถวช่วยเฉพาะตอนที่แถวเยอะจนนับเองไม่ไหว (รถบัส) รถตู้ 3-4 แถวไม่ต้อง
    final showRowNumbers = rows.length >= 6;

    return LayoutBuilder(
      builder: (context, constraints) {
        // เฉพาะที่นั่งกับทางเดินเท่านั้นที่ย่อตาม — ช่องเลขแถว (และช่องเปล่า
        // ที่ถ่วงไว้อีกฝั่ง) เป็นความกว้างคงที่ ถ้าเอาไปคูณด้วยจะคำนวณเกินจนล้นขอบ
        final chrome = showRowNumbers ? _rowNumberWidth * 2 : 0.0;
        final natural = _naturalRowWidth(
          rows,
          noseSlots: (frontSeat == null ? 0 : 1) + 1,
        );
        // ขอบ 1px ของโครงรถกินความกว้างด้านละ 1 เพิ่มจาก padding
        final available = constraints.maxWidth - _bodyPadding * 2 - 2;
        final scale = _fitScale(available - chrome, natural);
        final metrics = _SeatMetrics(scale);
        final scaledWidth = natural * scale + chrome;
        // ย่อจนสุดแล้วยังไม่พอ (จอแคบมาก / ผังกว้างผิดปกติ) ค่อยยอมให้เลื่อน
        final needsScroll = scaledWidth > available + 0.5;

        final body = SizedBox(
          width: math.max(scaledWidth, needsScroll ? scaledWidth : available),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VehicleNose(
                kind: kind,
                metrics: metrics,
                label: _text(seatMap['front_label'], 'หน้ารถ'),
                showDriver: showDriver,
                driverIcon: _driverIcon(seatMap, kind),
                frontSeat: frontSeat == null
                    ? null
                    : _buildSeat(context, frontSeat, frontSeatId, metrics),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: metrics.rowGap),
                  child: _buildRow(
                    context,
                    rows[i],
                    metrics,
                    showRowNumbers: showRowNumbers,
                  ),
                ),
              const SizedBox(height: 2),
              _VehicleRear(
                label: _text(
                  seatMap['rear_label'],
                  'ท้ายรถ (สำหรับเก็บสัมภาระ)',
                ),
              ),
            ],
          ),
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(
            _bodyPadding,
            14,
            _bodyPadding,
            _bodyPadding,
          ),
          decoration: BoxDecoration(
            color: AppTheme.fieldSurface(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(38),
              bottom: Radius.circular(AppTheme.radiusLg),
            ),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              needsScroll
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: body,
                    )
                  : body,
              // ประตูขึ้นรถ ฝั่งซ้าย (รถไทยพวงมาลัยขวา ประตูผู้โดยสารอยู่ซ้ายเสมอ)
              // รถตู้ = ประตูเลื่อนแนบที่นั่งหน้า A1 · รถบัส = บันไดหน้าสุด
              // ต่ำลงมาเล็กน้อย แนบขอบซ้ายของลำตัวจึงต้องเลยขอบ padding ออกไป
              if (hasDoor)
                Positioned(
                  left: -_bodyPadding,
                  // แนวเดียวกับ A1 พอดี — รถตู้ A1 คือที่นั่งคู่คนขับที่หัวรถ
                  // ส่วนรถบัสไม่มีที่นั่งคู่คนขับ A1 จึงเป็นที่นั่งแถวแรก
                  top: kind == VehicleKind.bus
                      ? _noseTop + metrics.seatButtonHeight + _noseToRowsGap
                      : _noseTop,
                  child: _DoorTab(height: metrics.seatButtonHeight),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    _SeatRowData row,
    _SeatMetrics metrics, {
    required bool showRowNumbers,
  }) {
    Widget seats(List<String> ids) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: ids.map((id) {
          final seat = _seatById(seatMap, id);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.seatGap / 2),
            child: _buildSeat(context, seat, id, metrics),
          );
        }).toList(),
      );
    }

    return Row(
      children: [
        if (showRowNumbers)
          SizedBox(
            width: _rowNumberWidth,
            child: Text(
              '${row.index}',
              textAlign: TextAlign.center,
              style: appFont(
                color: AppTheme.mutedText(context).withValues(alpha: 0.55),
                fontSize: AppText.sizeMicro,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              seats(row.left),
              if (row.center.isNotEmpty) ...[
                if (row.left.isNotEmpty) SizedBox(width: metrics.seatGap),
                seats(row.center),
              ],
              // ทางเดินมีก็ต่อเมื่อมีที่นั่งอยู่ทั้งสองฝั่งจริง ๆ — แถวหลังที่นั่ง
              // เรียงยาวกลางคันไม่มีทางเดิน และต้องไม่ถูกดันให้เบี้ยวไปข้างหนึ่ง
              if (row.right.isNotEmpty) ...[
                SizedBox(
                  width: metrics.aisleWidth,
                  child: Center(
                    child: row.hasAisle
                        ? Container(
                            width: 2,
                            height: metrics.tileHeight,
                            decoration: BoxDecoration(
                              color: AppTheme.border(context),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusPill,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                seats(row.right),
              ],
            ],
          ),
        ),
        if (showRowNumbers) const SizedBox(width: _rowNumberWidth),
      ],
    );
  }

  Widget _buildSeat(
    BuildContext context,
    Map<String, dynamic>? seat,
    String id,
    _SeatMetrics metrics,
  ) {
    if (seat == null) {
      return _buildSeatTile(context, null, id, SeatTone.booked, false, metrics);
    }
    final tone = toneFor(seat, id);
    final selectable = selectableFor(seat, id);
    return _buildSeatTile(context, seat, id, tone, selectable, metrics);
  }

  Widget _buildSeatTile(
    BuildContext context,
    Map<String, dynamic>? seat,
    String id,
    SeatTone tone,
    bool selectable,
    _SeatMetrics metrics,
  ) {
    final visual = _visualFor(tone);
    final emphasised = tone == SeatTone.picking || tone == SeatTone.mine;
    // ที่นั่งของผู้ใช้ในโหมดเน้น — ทำให้เด่นชัดเป็นพิเศษ
    final spotlight = highlightMine && tone == SeatTone.mine;
    final badgeIcon = seat == null
        ? visual.badgeIcon
        : (badgeFor?.call(seat, id) ?? visual.badgeIcon);
    final tooltip = seat == null ? null : tooltipFor?.call(seat, id);
    final badgeSize = spotlight ? 20.0 : metrics.badgeSize;

    final tile = InkWell(
      onTap: seat == null
          ? null
          : selectable
          ? () => onSeatTap(seat, id)
          : onBlockedSeatTap == null
          ? null
          : () => onBlockedSeatTap!(seat, id),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        // ช่องไฟระหว่างที่นั่งมาจาก Padding รอบนอก — ตัวที่นั่งกว้างเท่าเบาะ
        // ส่วนความสูงปล่อยให้เนื้อหากำหนดเอง เพราะกล่องข้อความของป้ายที่นั่ง
        // สูงกว่า fontSize ตามระยะบรรทัด ตรึงไว้เองเมื่อไหร่ก็ล้นเมื่อนั้น
        width: metrics.tileWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: metrics.tileWidth,
              height: metrics.tileHeight,
              decoration: BoxDecoration(
                color: visual.fill,
                borderRadius: BorderRadius.circular(metrics.tileRadius),
                border: Border.all(
                  color: spotlight
                      ? Colors.white
                      : emphasised
                      ? Colors.transparent
                      : Colors.black.withValues(alpha: 0.04),
                  width: spotlight ? 2.5 : 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // ไอคอนคนสำหรับที่นั่งของเรา (โหมดเน้น) — วางกึ่งกลางเบาะ
                  // สื่อว่า "เรานั่งตรงนี้"
                  if (spotlight)
                    Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: metrics.tileHeight * 0.62,
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.all(metrics.glyphInset),
                      child: _SeatGlyph(color: visual.glyph),
                    ),
                  if (badgeIcon != null)
                    Positioned(
                      top: spotlight ? -5 : 3,
                      right: spotlight ? -5 : 3,
                      child: Container(
                        width: badgeSize,
                        height: badgeSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: visual.badge,
                          shape: BoxShape.circle,
                          border: spotlight
                              ? Border.all(color: _accent, width: 2)
                              : null,
                        ),
                        child: Icon(
                          badgeIcon,
                          size: badgeSize * 0.64,
                          color: visual.badgeIconColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: metrics.labelGap),
            Text(
              _text(seat?['label'], id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                color: visual.labelColor(context),
                fontSize: metrics.labelSize,
                fontWeight: spotlight ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip == null || tooltip.isEmpty) return tile;

    return Tooltip(message: tooltip, child: tile);
  }
}

/// Compact legend matching the seat tones, for screens that want to explain the
/// colours below the map.
class VehicleSeatLegend extends StatelessWidget {
  final List<SeatTone> tones;

  /// ป้ายกำกับที่อยากเขียนเอง (เช่น "ที่นั่งของคุณ" แทน "ในกลุ่ม")
  final Map<SeatTone, String> labelOverrides;

  const VehicleSeatLegend({
    super.key,
    this.tones = const [
      SeatTone.available,
      SeatTone.mine,
      SeatTone.group,
      SeatTone.locked,
      SeatTone.booked,
    ],
    this.labelOverrides = const {},
  });

  static const _labels = {
    SeatTone.available: 'ว่าง',
    SeatTone.picking: 'กำลังเลือก',
    SeatTone.mine: 'ที่นั่งของคุณ',
    SeatTone.group: 'ในกลุ่ม',
    SeatTone.locked: 'กำลังจอง',
    SeatTone.booked: 'จองแล้ว',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: tones.map((tone) {
        final visual = _visualFor(tone);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: visual.fill,
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              ),
              child: _SeatGlyph(color: visual.glyph),
            ),
            const SizedBox(width: 6),
            Text(
              labelOverrides[tone] ?? _labels[tone] ?? '',
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _SeatVisual {
  final Color fill;
  final Color glyph;
  final Color badge;
  final Color badgeIconColor;
  final IconData? badgeIcon;
  final Color Function(BuildContext context) labelColor;

  const _SeatVisual({
    required this.fill,
    required this.glyph,
    required this.badge,
    required this.badgeIconColor,
    required this.badgeIcon,
    required this.labelColor,
  });
}

const _accent = AppTheme.primaryColor; // Emerald 600
const _warning = AppTheme.warningColor; // Amber 600

const _door = Color(0xFFFBBF24); // Amber 400
const _doorInk = Color(0xFFB45309); // Amber 700

const double _bodyPadding = 16;

/// ระยะจากขอบบนของพื้นที่ในโครงรถถึงแถวหัวรถ: กระจกหน้า 10 + ช่องไฟ 10
const double _noseTop = 20;

/// ระยะจากท้ายแถวหัวรถถึงที่นั่งแถวแรก: ช่องไฟ 12 + เส้นประ 1 + ช่องไฟ 12
const double _noseToRowsGap = 25;
const double _rowNumberWidth = 18;

_SeatVisual _visualFor(SeatTone tone) {
  switch (tone) {
    case SeatTone.picking:
    case SeatTone.mine:
      return _SeatVisual(
        fill: _accent,
        glyph: Colors.white,
        badge: Colors.white,
        badgeIconColor: _accent,
        badgeIcon: Icons.check_rounded,
        labelColor: (_) => _accent,
      );
    case SeatTone.group:
      return _SeatVisual(
        fill: _warning.withValues(alpha: 0.16),
        glyph: _warning,
        badge: _warning,
        badgeIconColor: Colors.white,
        badgeIcon: Icons.groups_rounded,
        labelColor: (_) => const Color(0xFF92400E),
      );
    case SeatTone.locked:
      return _SeatVisual(
        fill: const Color(0xFFFFF3E0),
        glyph: const Color(0xFFE08A00),
        badge: const Color(0xFFE08A00),
        badgeIconColor: Colors.white,
        badgeIcon: Icons.schedule_rounded,
        labelColor: (_) => const Color(0xFF92400E),
      );
    case SeatTone.booked:
      return _SeatVisual(
        fill: const Color(0xFFF1F5F9),
        glyph: const Color(0xFFCBD5E1),
        badge: const Color(0xFF94A3B8),
        badgeIconColor: Colors.white,
        badgeIcon: Icons.lock_rounded,
        labelColor: (context) =>
            AppTheme.mutedText(context).withValues(alpha: 0.62),
      );
    case SeatTone.available:
      return _SeatVisual(
        fill: const Color(0xFFECFDF5),
        glyph: _accent,
        badge: _accent,
        badgeIconColor: Colors.white,
        badgeIcon: null,
        labelColor: (context) => AppTheme.mutedText(context),
      );
  }
}

/// ขนาดของทุกชิ้นในผัง ย่อ/ขยายพร้อมกันด้วยตัวคูณเดียว เพื่อให้ผังทั้งคันพอดี
/// ความกว้างจอโดยไม่ต้องเลื่อน
class _SeatMetrics {
  final double scale;

  const _SeatMetrics(this.scale);

  double get tileWidth => 44 * scale;
  double get tileHeight => 42 * scale;
  double get seatGap => 8 * scale;
  double get slotWidth => tileWidth + seatGap;

  /// ความสูงของปุ่มที่นั่งทั้งปุ่ม (เบาะ + ป้าย) — กล่องข้อความสูงกว่า fontSize
  /// ตามระยะบรรทัด จึงคูณเผื่อไว้
  double get seatButtonHeight => tileHeight + labelGap + labelSize * 1.5;
  double get aisleWidth => 34 * scale;
  double get rowGap => 10 * scale;
  double get labelGap => 4 * scale;
  double get labelSize => math.max(8, AppText.sizeMicro * scale);
  double get tileRadius => AppTheme.radiusMd * math.max(0.7, scale);
  double get glyphInset => 9 * scale;
  double get badgeSize => math.max(11, 15 * scale);
  double get driverSize => tileWidth;
}

/// ความกว้างของแถวที่กว้างที่สุดถ้าวาดขนาดเต็ม — เอาไว้คิดตัวคูณย่อ
double _naturalRowWidth(List<_SeatRowData> rows, {required int noseSlots}) {
  const base = _SeatMetrics(1);
  // หัวรถ (ที่นั่งคู่คนขับ + ประตู + คนขับ) ต้องไม่แคบกว่านี้ ไม่งั้นป้ายถูกบีบ
  var widest = (noseSlots + 1) * base.slotWidth;

  for (final row in rows) {
    final seats = row.left.length + row.center.length + row.right.length;
    var width = seats * base.slotWidth;
    if (row.center.isNotEmpty && row.left.isNotEmpty) width += base.seatGap;
    if (row.right.isNotEmpty) width += base.aisleWidth;
    widest = math.max(widest, width);
  }

  return widest;
}

double _fitScale(double available, double natural) {
  if (natural <= 0 || available <= 0) return 1;

  return math.min(1.0, available / natural).clamp(0.62, 1.0);
}

/// A clean, front-facing armchair silhouette drawn as a single-color glyph so
/// it reads crisply at seat size.
class _SeatGlyph extends StatelessWidget {
  final Color color;

  const _SeatGlyph({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.infinite, painter: _SeatGlyphPainter(color));
  }
}

class _SeatGlyphPainter extends CustomPainter {
  final Color color;

  const _SeatGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    final w = size.width;
    final h = size.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, 0, w * 0.64, h * 0.34),
        Radius.circular(w * 0.13),
      ),
      paint,
    );

    final armW = w * 0.15;
    final armTop = h * 0.32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, armTop, armW, h),
        Radius.circular(armW * 0.55),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w - armW, armTop, w, h),
        Radius.circular(armW * 0.55),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.2, h * 0.42, w * 0.8, h),
        topLeft: Radius.circular(w * 0.1),
        topRight: Radius.circular(w * 0.1),
        bottomLeft: Radius.circular(w * 0.2),
        bottomRight: Radius.circular(w * 0.2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SeatGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// หัวรถ — กระจกหน้า แล้วแถวคนขับ ประเทศไทยพวงมาลัยขวา คนขับจึงอยู่ฝั่งขวาเสมอ
/// รถตู้มีที่นั่งคู่คนขับฝั่งซ้าย รถบัสตรงนั้นเป็นบันไดขึ้นลง
class _VehicleNose extends StatelessWidget {
  final VehicleKind kind;
  final _SeatMetrics metrics;
  final String label;
  final bool showDriver;
  final IconData driverIcon;
  final Widget? frontSeat;

  const _VehicleNose({
    required this.kind,
    required this.metrics,
    required this.label,
    required this.showDriver,
    required this.driverIcon,
    this.frontSeat,
  });

  @override
  Widget build(BuildContext context) {
    final slot = metrics.slotWidth;

    return Column(
      children: [
        // กระจกหน้า — บอกว่าด้านบนของผังคือหน้ารถ โดยไม่ต้องอ่านตัวหนังสือ
        Container(
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppTheme.border(context)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (frontSeat != null) SizedBox(width: slot, child: frontSeat),
            Expanded(
              child: Center(child: _VehicleLabel(text: label)),
            ),
            SizedBox(
              width: slot,
              child: showDriver
                  ? _CrewBlock(
                      icon: driverIcon,
                      label: 'คนขับ',
                      size: metrics.driverSize,
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _DashedRule(),
      ],
    );
  }
}

class _VehicleRear extends StatelessWidget {
  final String label;

  const _VehicleRear({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _DashedRule(),
        const SizedBox(height: 10),
        _VehicleLabel(text: label, muted: true),
      ],
    );
  }
}

class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _DashedRulePainter(AppTheme.border(context)),
        size: Size.infinite,
      ),
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  final Color color;

  const _DashedRulePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dash, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRulePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// คนขับ / ประตูหน้า — บล็อกเทา ๆ ที่ไม่ใช่ที่นั่ง กดไม่ได้
class _CrewBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;

  const _CrewBlock({
    required this.icon,
    required this.label,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.mutedText(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size * 0.95,
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Icon(icon, color: color, size: size * 0.45),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: appFont(
            color: color,
            fontSize: AppText.sizeMicro,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// แถบประตูขึ้นรถที่แนบขอบซ้ายของลำตัว — มีไอคอนและคำว่า "ประตู" กำกับเสมอ
/// แถบสีเปล่า ๆ ที่ไม่มีป้ายทำให้ต้องเดาว่ามันคืออะไร ซึ่งแปลว่ามันสื่อไม่สำเร็จ
class _DoorTab extends StatelessWidget {
  final double height;

  const _DoorTab({required this.height});

  @override
  Widget build(BuildContext context) {
    // ไอคอนบวกคำว่า "ประตู" ที่ตะแคงอยู่กินความสูงเท่านี้เป็นอย่างน้อย
    // ผังที่ย่อลงจนที่นั่งเตี้ยกว่านี้ต้องไม่บีบแถบจนล้น
    return Container(
      width: 20,
      height: math.max(56, height),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _door.withValues(alpha: 0.16),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
        border: Border.all(color: _door.withValues(alpha: 0.45)),
      ),
      // ย่อเนื้อในให้พอดีเสมอ — ความสูงของคำที่ตะแคงขึ้นกับฟอนต์และ textScaler
      // ของเครื่อง เดาเป็นตัวเลขตายตัวเมื่อไหร่ก็ล้นบนเครื่องที่ตั้งค่าต่างไป
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.door_front_door_rounded,
              size: 12,
              color: _doorInk,
            ),
            const SizedBox(height: 2),
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                'ประตู',
                style: appFont(
                  color: _doorInk,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleLabel extends StatelessWidget {
  final String text;
  final bool muted;

  const _VehicleLabel({required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: muted
            ? AppTheme.surface(context)
            : _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: muted ? AppTheme.border(context) : Colors.transparent,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: appFont(
          color: muted ? AppTheme.mutedText(context) : _accent,
          fontSize: AppText.sizeCaption,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// --- Seat-map parsing (self-contained, mirrors the booking flow) -------------

class _SeatRowData {
  /// เลขแถวจริงในผัง (ไม่ใช่ลำดับที่วาด) — แถวที่ไม่มีที่นั่งเลยถูกข้ามไป
  final int index;
  final List<String> left;
  final List<String> right;
  final List<String> center;
  final bool hasAisle;

  const _SeatRowData({
    required this.index,
    required this.left,
    required this.right,
    required this.center,
    required this.hasAisle,
  });
}

String _text(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

List<dynamic> _asList(dynamic value) => value is List ? value : const [];

VehicleKind _kindOf(Map<String, dynamic> seatMap) {
  switch (_text(seatMap['layout_kind']).toLowerCase()) {
    case 'bus':
      return VehicleKind.bus;
    case 'boat':
      return VehicleKind.boat;
    default:
      return VehicleKind.van;
  }
}

IconData _driverIcon(Map<String, dynamic> seatMap, VehicleKind kind) {
  switch (_text(seatMap['driver_icon'])) {
    case 'directions_bus':
      return Icons.directions_bus_rounded;
    case 'sailing':
      return Icons.sailing_rounded;
    case 'two_wheeler':
      return Icons.two_wheeler_rounded;
    case 'directions_car':
      return Icons.drive_eta_rounded;
  }

  return switch (kind) {
    VehicleKind.bus => Icons.directions_bus_rounded,
    VehicleKind.boat => Icons.sailing_rounded,
    VehicleKind.van => Icons.drive_eta_rounded,
  };
}

/// รถคันนี้มีประตูผู้โดยสารให้วาดไหม — ผังบอกมาเป็นเลขแถว เราสนแค่ว่ามีหรือไม่มี
bool _hasDoor(Map<String, dynamic> seatMap) {
  return _asList(seatMap['door_rows'])
      .map((item) => int.tryParse(item?.toString() ?? '') ?? 0)
      .any((row) => row > 0);
}

Map<String, dynamic>? _seatById(Map<String, dynamic> seatMap, String id) {
  for (final item in _asList(seatMap['seats'])) {
    if (item is Map && _text(item['id']) == id) {
      return Map<String, dynamic>.from(item);
    }
  }
  return null;
}

List<_SeatRowData> _seatRows(Map<String, dynamic> seatMap) {
  final rows = int.tryParse(_text(seatMap['rows'])) ?? 0;
  final columns = _asList(
    seatMap['columns'],
  ).map((item) => item?.toString() ?? '').toList();
  final frontSeatId = _text(seatMap['front_seat']);
  final centerSeatIds = _asList(
    seatMap['last_row_center'],
  ).map((item) => item?.toString() ?? '').toSet();
  final result = <_SeatRowData>[];

  for (var rowIndex = 1; rowIndex <= rows; rowIndex++) {
    final left = <String>[];
    final right = <String>[];
    final center = <String>[];
    var hasAisle = false;
    var inRight = false;

    for (final column in columns) {
      if (column.isEmpty) {
        hasAisle = true;
        inRight = true;
        continue;
      }

      final seatId = '$column$rowIndex';
      if (seatId == frontSeatId) continue;
      if (_seatById(seatMap, seatId) == null) continue;

      if (centerSeatIds.contains(seatId)) {
        center.add(seatId);
      } else if (inRight) {
        right.add(seatId);
      } else {
        left.add(seatId);
      }
    }

    if (left.isEmpty && right.isEmpty && center.isEmpty) continue;

    result.add(
      _SeatRowData(
        index: rowIndex,
        left: left,
        right: right,
        center: center,
        hasAisle: hasAisle && right.isNotEmpty,
      ),
    );
  }

  return result;
}
