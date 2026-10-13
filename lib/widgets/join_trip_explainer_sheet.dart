import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'sheet_close_button.dart';
import 'travel_widgets.dart';

/// "จอยทริปคืออะไร?" — the question customers keep asking at the booking step.
///
/// Every line here describes how the system actually treats a join-trip
/// booking (BookingService / TripSchedule): no van seat and no pickup point,
/// its own price (`join_trip_price`) and its own quota (`join_trip_seats`,
/// separate from the van, so a round with a full van can still take joiners),
/// meeting details sent by the team, check-in by QR. Nothing about what the
/// price includes, because that differs per trip — the trip page says it.
class JoinTripExplainerSheet {
  JoinTripExplainerSheet._();

  /// Returns true when the customer tapped "เลือกจอยทริป" in the sheet.
  static Future<bool> show(
    BuildContext context, {
    required num joinPrice,
    required num regularPrice,
    String quotaLabel = '',
    bool canSelect = false,
  }) async {
    HapticFeedback.selectionClick();
    final chosen = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (_) => _ExplainerBody(
        joinPrice: joinPrice,
        regularPrice: regularPrice,
        quotaLabel: quotaLabel,
        canSelect: canSelect,
      ),
    );
    return chosen == true;
  }
}

String _baht(num value) => '฿${NumberFormat('#,##0.##').format(value)}';

class _ExplainerBody extends StatelessWidget {
  final num joinPrice;
  final num regularPrice;
  final String quotaLabel;
  final bool canSelect;

  const _ExplainerBody({
    required this.joinPrice,
    required this.regularPrice,
    required this.quotaLabel,
    required this.canSelect,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = AppTheme.onSurface(context);
    final muted = AppTheme.mutedText(context);
    final saving = regularPrice - joinPrice;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'จอยทริปคืออะไร?',
                          style: AppText.title(color: onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // สั้นพอให้ไม่ตัดกลางคำ "ไม่ได้" — เรื่องรถอยู่ในตารางเทียบข้างล่างแล้ว
                          'ไปทริปเดียวกับกลุ่ม แต่เดินทางไปเองถึงจุดนัดพบ',
                          style: AppText.body(color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SheetCloseButton(),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Comparison(
                      joinPrice: joinPrice,
                      regularPrice: regularPrice,
                    ),
                    if (saving > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        'จอยทริปถูกกว่า ${_baht(saving)} ต่อคน เพราะไม่รวมค่ารถของทีมงาน',
                        textAlign: TextAlign.center,
                        style: AppText.label(
                          color: AppTheme.onTintOf(
                            context,
                            AppTheme.primaryColor,
                          ),
                          strong: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    const _Heading('เหมาะกับใคร'),
                    const _Point(
                      icon: Icons.directions_car_outlined,
                      text: 'มีรถส่วนตัว หรืออยากขับไปเอง',
                    ),
                    const _Point(
                      icon: Icons.home_work_outlined,
                      text: 'พักใกล้ปลายทางอยู่แล้ว ไม่สะดวกไปจุดขึ้นรถ',
                    ),
                    const _Point(
                      icon: Icons.schedule_outlined,
                      text: 'อยากออกเดินทางและกลับตามเวลาของตัวเอง',
                    ),
                    const SizedBox(height: 18),
                    const _Heading('จองแล้วเป็นอย่างไรต่อ'),
                    const _Step(
                      number: 1,
                      title: 'รับจุดนัดพบและเวลานัด',
                      detail: 'ทีมงานแจ้งให้ทราบก่อนวันเดินทาง',
                    ),
                    const _Step(
                      number: 2,
                      title: 'เดินทางไปเองให้ถึงจุดนัดพบตามเวลา',
                      detail: 'แล้วร่วมกิจกรรมไปพร้อมกับกลุ่ม',
                    ),
                    const _Step(
                      number: 3,
                      title: 'เช็คอินด้วย QR Code',
                      detail: 'ได้รับหลังทีมงานยืนยันการชำระเงิน',
                    ),
                    const SizedBox(height: 18),
                    const _Heading('ควรรู้ก่อนจอง'),
                    const _Point(
                      icon: Icons.local_gas_station_outlined,
                      text: 'ค่าเดินทางไป-กลับจุดนัดพบ ผู้เดินทางรับผิดชอบเอง',
                    ),
                    const _Point(
                      icon: Icons.event_seat_outlined,
                      text:
                          'ไม่ต้องเลือกจุดขึ้นรถหรือที่นั่ง และไม่ใช้ที่นั่งบนรถ '
                          'รอบที่รถเต็มแล้วจึงอาจยังจอยได้',
                    ),
                    _Point(
                      icon: Icons.groups_outlined,
                      text: quotaLabel.isEmpty
                          ? 'จอยทริปมีจำนวนรับของตัวเอง แยกจากที่นั่งบนรถ'
                          : 'จอยทริปมีจำนวนรับของตัวเอง แยกจากที่นั่งบนรถ '
                                '— รอบนี้$quotaLabel',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: canSelect
                  ? PrimaryCTAButton(
                      label: 'เลือกจอยทริป',
                      icon: Icons.groups_rounded,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop(true);
                      },
                    )
                  : OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: onSurface,
                        side: BorderSide(color: AppTheme.border(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(
                        'เข้าใจแล้ว',
                        style: AppText.button(color: onSurface),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Side-by-side: riding the team van vs joining on your own.
class _Comparison extends StatelessWidget {
  final num joinPrice;
  final num regularPrice;

  const _Comparison({required this.joinPrice, required this.regularPrice});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _OptionCard(
              icon: Icons.airport_shuttle_rounded,
              title: 'นั่งรถทีม',
              lines: const ['รถทีมงานรับที่จุดขึ้นรถ', 'จองที่นั่งบนรถ'],
              price: regularPrice,
              highlighted: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OptionCard(
              icon: Icons.groups_rounded,
              title: 'จอยทริป',
              lines: const ['เดินทางไปเองถึงจุดนัดพบ', 'ไม่ใช้ที่นั่งบนรถ'],
              price: joinPrice,
              highlighted: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  final num price;
  final bool highlighted;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.price,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = AppTheme.onSurface(context);
    final muted = AppTheme.mutedText(context);
    final accent = AppTheme.onTintOf(context, AppTheme.primaryColor);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.selectedTint(context)
            : AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: highlighted
              ? AppTheme.primaryColor.withValues(alpha: 0.35)
              : AppTheme.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: highlighted ? accent : muted),
          const SizedBox(height: 8),
          Text(title, style: AppText.subtitle(color: onSurface, strong: true)),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: AppText.label(color: muted)),
            ),
          const Spacer(),
          if (price > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${_baht(price)} / คน',
              style: AppText.body(
                color: highlighted ? accent : onSurface,
                strong: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppText.label(color: AppTheme.mutedText(context), strong: true),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.mutedText(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.body(color: AppTheme.onSurface(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String detail;

  const _Step({
    required this.number,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.onTintOf(context, AppTheme.primaryColor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.selectedTint(context),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppText.caption(color: accent, strong: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body(
                    color: AppTheme.onSurface(context),
                    strong: true,
                  ),
                ),
                Text(
                  detail,
                  style: AppText.label(color: AppTheme.mutedText(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
