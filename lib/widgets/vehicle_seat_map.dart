import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visual state of a single seat. The widget maps each tone to a consistent,
/// iOS-flavoured palette so every screen that renders the bus layout looks the
/// same as the real booking flow.
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

typedef SeatToneResolver = SeatTone Function(
  Map<String, dynamic> seat,
  String id,
);
typedef SeatSelectableResolver = bool Function(
  Map<String, dynamic> seat,
  String id,
);
typedef SeatTapHandler = void Function(Map<String, dynamic> seat, String id);

/// A proportional, vehicle-shaped seat map: front seat + driver block up top, a
/// divider, then each row laid out left / aisle / right exactly as the seats sit
/// in the bus. Self-contained and theme-aware so it can be reused anywhere.
class VehicleSeatMap extends StatelessWidget {
  final Map<String, dynamic> seatMap;
  final SeatToneResolver toneFor;
  final SeatSelectableResolver selectableFor;
  final SeatTapHandler onSeatTap;

  /// เน้นที่นั่งของผู้ใช้ (SeatTone.mine) ให้เด่นเป็นพิเศษ — ไอคอนคน + ป้ายถูก
  /// ใหญ่ + วงแหวนไฮไลต์ ใช้ในหน้าดูการจองเพื่อบอกชัด ๆ ว่าเรานั่งที่ไหน
  final bool highlightMine;

  const VehicleSeatMap({
    super.key,
    required this.seatMap,
    required this.toneFor,
    required this.selectableFor,
    required this.onSeatTap,
    this.highlightMine = false,
  });

  @override
  Widget build(BuildContext context) {
    final frontSeatId = _text(seatMap['front_seat']);
    final frontSeat = frontSeatId.isEmpty ? null : _seatById(seatMap, frontSeatId);
    final rows = _seatRows(seatMap);
    final showDriver = seatMap['show_driver'] != false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    frontSeat == null
                        ? const SizedBox(width: 58)
                        : _buildSeat(context, frontSeat, frontSeatId),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _VehicleLabel(
                        text: _text(seatMap['front_label'], 'หน้ารถ'),
                      ),
                    ),
                    _DriverBlock(show: showDriver),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    width: 292,
                    child: Divider(height: 1, color: Color(0xFFD8DEDB)),
                  ),
                ),
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRow(context, row),
                  ),
                ),
                const SizedBox(height: 4),
                _VehicleLabel(
                  text: _text(
                    seatMap['rear_label'],
                    'ท้ายรถ (สำหรับเก็บสัมภาระ)',
                  ),
                  muted: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _SeatRowData row) {
    Widget seats(List<String> ids) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: ids.map((id) {
          final seat = _seatById(seatMap, id);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildSeat(context, seat, id),
          );
        }).toList(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        seats(row.left),
        if (row.center.isNotEmpty) ...[
          const SizedBox(width: 8),
          seats(row.center),
        ],
        SizedBox(
          width: 44,
          child: Center(
            child: row.hasAisle
                ? Container(
                    width: 2,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DEDB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : null,
          ),
        ),
        seats(row.right),
      ],
    );
  }

  Widget _buildSeat(
    BuildContext context,
    Map<String, dynamic>? seat,
    String id,
  ) {
    if (seat == null) {
      return _buildSeatTile(context, null, id, SeatTone.booked, false);
    }
    final tone = toneFor(seat, id);
    final selectable = selectableFor(seat, id);
    return _buildSeatTile(context, seat, id, tone, selectable);
  }

  Widget _buildSeatTile(
    BuildContext context,
    Map<String, dynamic>? seat,
    String id,
    SeatTone tone,
    bool selectable,
  ) {
    final visual = _visualFor(tone);
    final emphasised = tone == SeatTone.picking || tone == SeatTone.mine;
    // ที่นั่งของผู้ใช้ในโหมดเน้น — ทำให้เด่นชัดเป็นพิเศษ
    final spotlight = highlightMine && tone == SeatTone.mine;

    return InkWell(
      onTap: selectable && seat != null ? () => onSeatTap(seat, id) : null,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 52,
        height: spotlight ? 66 : 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 42,
              decoration: BoxDecoration(
                color: visual.fill,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: spotlight
                      ? Colors.white
                      : emphasised
                      ? Colors.transparent
                      : Colors.black.withValues(alpha: 0.04),
                  width: spotlight ? 2.5 : 1,
                ),
                boxShadow: emphasised
                    ? [
                        BoxShadow(
                          color: visual.fill.withValues(
                            alpha: spotlight ? 0.5 : 0.32,
                          ),
                          blurRadius: spotlight ? 16 : 12,
                          offset: Offset(0, spotlight ? 6 : 5),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // ไอคอนคนสำหรับที่นั่งของเรา (โหมดเน้น) — วางกึ่งกลางเบาะ
                  // สื่อว่า "เรานั่งตรงนี้"
                  if (spotlight)
                    const Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(9),
                      child: _SeatGlyph(color: visual.glyph),
                    ),
                  if (visual.badgeIcon != null)
                    Positioned(
                      top: spotlight ? -5 : 4,
                      right: spotlight ? -5 : 4,
                      child: Container(
                        width: spotlight ? 20 : 15,
                        height: spotlight ? 20 : 15,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: visual.badge,
                          shape: BoxShape.circle,
                          border: spotlight
                              ? Border.all(color: _accent, width: 2)
                              : null,
                          boxShadow: spotlight
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          visual.badgeIcon,
                          size: spotlight ? 13 : 9.5,
                          color: visual.badgeIconColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _text(seat?['label'], id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                color: visual.labelColor(context),
                fontSize: 10.5,
                fontWeight: spotlight ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact legend matching the seat tones, for screens that want to explain the
/// colours below the map.
class VehicleSeatLegend extends StatelessWidget {
  final List<SeatTone> tones;

  const VehicleSeatLegend({
    super.key,
    this.tones = const [
      SeatTone.available,
      SeatTone.mine,
      SeatTone.group,
      SeatTone.locked,
      SeatTone.booked,
    ],
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
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              ),
              child: _SeatGlyph(color: visual.glyph),
            ),
            const SizedBox(width: 6),
            Text(
              _labels[tone] ?? '',
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: 12,
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
        fill: const Color(0xFFEFEFF1),
        glyph: const Color(0xFFC4C8CF),
        badge: const Color(0xFF9CA3AF),
        badgeIconColor: Colors.white,
        badgeIcon: Icons.lock_rounded,
        labelColor: (context) =>
            AppTheme.mutedText(context).withValues(alpha: 0.62),
      );
    case SeatTone.available:
      return _SeatVisual(
        fill: const Color(0xFFE7F6EE),
        glyph: _accent,
        badge: _accent,
        badgeIconColor: Colors.white,
        badgeIcon: null,
        labelColor: (context) => AppTheme.mutedText(context),
      );
  }
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

class _DriverBlock extends StatelessWidget {
  final bool show;

  const _DriverBlock({required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox(width: 58);

    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFF1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Icon(
              Icons.drive_eta_rounded,
              color: AppTheme.mutedText(context),
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'คนขับ',
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        color: muted ? AppTheme.surface(context) : _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: muted ? AppTheme.border(context) : Colors.transparent,
        ),
      ),
      child: Text(
        text,
        style: appFont(
          color: muted ? AppTheme.mutedText(context) : _accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// --- Seat-map parsing (self-contained, mirrors the booking flow) -------------

class _SeatRowData {
  final List<String> left;
  final List<String> right;
  final List<String> center;
  final bool hasAisle;

  const _SeatRowData({
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
  final columns =
      _asList(seatMap['columns']).map((item) => item?.toString() ?? '').toList();
  final frontSeatId = _text(seatMap['front_seat']);
  final centerSeatIds = _asList(seatMap['last_row_center'])
      .map((item) => item?.toString() ?? '')
      .toSet();
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
        left: left,
        right: right,
        center: center,
        hasAisle: hasAisle && right.isNotEmpty,
      ),
    );
  }

  return result;
}
