import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ปุ่มปิดมุมขวาบนของชีตที่เด้งขึ้นมา — บนจอเล็กพอคีย์บอร์ดขึ้น ชีตจะดันขึ้นจน
/// แทบไม่เหลือพื้นหลังให้แตะปิด และลากลงก็ไม่ได้เพราะรายการข้างในกินการลากไป
/// ปุ่มนี้จึงเป็นทางออกที่เห็นชัดเสมอ ปิดแล้วคืนค่า null เหมือนแตะพื้นหลัง
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      tooltip: 'ปิด',
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.subtleSurface(context),
        foregroundColor: AppTheme.mutedText(context),
        minimumSize: const Size(36, 36),
        fixedSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.close_rounded, size: 20),
    );
  }
}
