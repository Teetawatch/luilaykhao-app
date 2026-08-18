import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'travel_widgets.dart';

/// เบอร์ฉุกเฉินของประเทศปลายทาง — แตะโทรออกได้ทันที
///
/// 191 กับ 1669 ใช้ที่ต่างประเทศไม่ได้ และตอนเกิดเหตุจริงไม่มีใครมีเวลาเปิด
/// เบราว์เซอร์หาเบอร์ตำรวจญี่ปุ่น เบอร์พวกนี้จึงต้องอยู่ในแอปพร้อมกดโทร
///
/// เบอร์เดินทางมากับ payload ของทริป ซึ่งถูกแคชไว้แล้ว (ดู TripDayPack) จึงยัง
/// อ่านได้ตอนไม่มีสัญญาณเน็ต — ซึ่งเป็นตอนที่ต้องใช้จริง
///
/// ซ่อนตัวเองเมื่อทริปเป็นทริปในประเทศหรือยังไม่รู้จักประเทศนั้น
class EmergencyNumbersCard extends StatelessWidget {
  final Map<String, dynamic> trip;

  /// ระยะห่างล่างที่การ์ดจัดการเอง เพื่อให้ผู้เรียกไม่ต้องเว้น SizedBox ค้างไว้
  /// ตอนการ์ดซ่อนตัว
  final double bottomSpacing;

  const EmergencyNumbersCard({
    super.key,
    required this.trip,
    this.bottomSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (trip['is_international'] != true) return const SizedBox.shrink();

    final numbers = asMap(trip['emergency_numbers']);
    if (numbers.isEmpty) return const SizedBox.shrink();

    final country = textOf(trip['country_label']).trim();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(
            alpha: AppTheme.isDark(context) ? 0.14 : 0.07,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.errorColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emergency_rounded,
                  size: 18,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    country.isEmpty
                        ? 'เบอร์ฉุกเฉินที่ปลายทาง'
                        : 'เบอร์ฉุกเฉินใน$country',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '191 และ 1669 ใช้ที่นี่ไม่ได้ — ใช้เบอร์ด้านล่างแทน',
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            ...numbers.entries.map(
              (entry) => _NumberRow(
                label: entry.key,
                number: entry.value.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final String label;
  final String number;

  const _NumberRow({required this.label, required this.number});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: () async {
          HapticFeedback.selectionClick();
          final uri = Uri.parse('tel:$number');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Text(
                number,
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.call_rounded, size: 16, color: AppTheme.errorColor),
            ],
          ),
        ),
      ),
    );
  }
}
