import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// ท้ายรายการเมื่อยังมีประวัติที่ไม่ได้โหลด — ปกติโหลดเองตอนเลื่อนใกล้ถึง ปุ่มนี้มี
/// ไว้สำหรับรายการสั้นที่เลื่อนไม่ได้ และเป็นทางลองใหม่เมื่อโหลดไม่สำเร็จ
class BookingHistoryFooter extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool searching;
  final Future<void> Function() onLoadMore;

  const BookingHistoryFooter({
    super.key,
    required this.loading,
    required this.error,
    this.searching = false,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              searching
                  ? 'กำลังค้นหาในประวัติทั้งหมด…'
                  : 'กำลังโหลดรายการก่อนหน้า…',
              style: appFont(fontSize: AppText.sizeLabel, color: muted),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error!,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeLabel,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              onLoadMore();
            },
            icon: Icon(
              error != null ? Icons.refresh_rounded : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(
              error != null ? 'ลองอีกครั้ง' : 'ดูรายการก่อนหน้า',
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
