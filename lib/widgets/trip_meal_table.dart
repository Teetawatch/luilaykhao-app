import 'package:flutter/material.dart';

import '../models/trip_meals.dart';
import '../theme/app_theme.dart';
import 'sheet_close_button.dart';

/// ชีตตารางมื้ออาหาร — เปิดจากแถว "อาหาร" ในใบจอง (ที่ที่ไม่มีพื้นที่วาดตารางเต็ม)
Future<void> showTripMealsSheet(BuildContext context, TripMeals meals) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLg),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.restaurant_rounded,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'มื้ออาหาร',
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(sheetContext),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SheetCloseButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                meals.summary,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedText(sheetContext),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: TripMealTable(meals: meals),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// ตารางมื้ออาหารวัน × มื้อ — ใช้ร่วมกันทั้งหน้าทริป ใบจอง และชีตในห้องแชท
///
/// สีมีความหมายเดียวทุกที่: เขียว = รวมในราคา, เหลือง = มีแวะแต่จ่ายเอง,
/// เทา = ไม่มีมื้อนี้ ไม่มีเงา ใช้พื้นอ่อนแยกช่องแทน
class TripMealTable extends StatelessWidget {
  final TripMeals meals;

  const TripMealTable({super.key, required this.meals});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < meals.days.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _DayHeader(day: meals.days[i], showDate: meals.showDates),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var m = 0; m < meals.days[i].meals.length; m++) ...[
                if (m > 0) const SizedBox(width: 8),
                Expanded(child: _MealCell(meal: meals.days[i].meals[m])),
              ],
            ],
          ),
        ],
        if (meals.selfCount > 0) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.payments_outlined, size: 16, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'มื้อที่ "จ่ายเอง" มีแวะให้ แต่ค่าอาหารไม่รวมในราคาทริป',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: muted,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (meals.note != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meals.note!,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface(context),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final TripMealDay day;
  final bool showDate;

  const _DayHeader({required this.day, required this.showDate});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: day.label),
          if (showDate && day.dateLabel != null)
            TextSpan(
              text: ' · ${day.dateLabel}',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
        ],
      ),
      style: appFont(
        fontSize: AppText.sizeLabel,
        fontWeight: FontWeight.w800,
        color: AppTheme.onSurface(context),
      ),
    );
  }
}

class _MealCell extends StatelessWidget {
  final TripMeal meal;

  const _MealCell({required this.meal});

  @override
  Widget build(BuildContext context) {
    final (
      Color background,
      Color foreground,
      IconData icon,
    ) = switch (meal.status) {
      TripMealStatus.included => (
        AppTheme.successTint(context),
        AppTheme.onTintOf(context, AppTheme.successColor),
        Icons.check_circle_rounded,
      ),
      TripMealStatus.selfPay => (
        AppTheme.warningTint(context),
        AppTheme.onTintOf(context, AppTheme.warningColor),
        Icons.payments_rounded,
      ),
      TripMealStatus.none => (
        AppTheme.subtleSurface(context),
        AppTheme.mutedText(context),
        Icons.remove_rounded,
      ),
    };

    return Semantics(
      label:
          'มื้อ${meal.label} ${meal.statusLabel}'
          '${meal.note == null ? '' : ' ${meal.note}'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          // ช่อง "ไม่มี" เป็นพื้นเทาอ่อน — วางบนพื้นเทาอ่อนเดียวกัน (ชีตในแชท)
          // จะหายไปทั้งช่อง เส้นขอบบาง ๆ คงรูปตารางไว้
          border: meal.status == TripMealStatus.none
              ? Border.all(
                  color: AppTheme.border(context).withValues(alpha: 0.6),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ไอคอนอยู่บรรทัดชื่อมื้อ — ช่องกว้างแค่ราว 80dp บนจอ 390 ถ้าวางข้าง
            // สถานะ "รวมในราคา" จะหักเป็นสองบรรทัด
            Row(
              children: [
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    meal.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              meal.statusLabel,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: meal.status == TripMealStatus.none
                    ? FontWeight.w600
                    : FontWeight.w800,
                color: foreground,
                height: 1.3,
              ),
            ),
            if (meal.note != null) ...[
              const SizedBox(height: 4),
              Text(
                meal.note!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurface(context),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
