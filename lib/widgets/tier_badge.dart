import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ป้ายระดับสมาชิก — สำหรับติดข้างชื่อคนในที่ที่ "คนอื่นเห็น" (แชทกลุ่มทริป
/// รีวิว ฟีดรูปหลังทริป) เพราะคุณค่าของระดับอยู่ที่คนอื่นเห็น ไม่ใช่เจ้าตัวเห็นเอง
///
/// ระดับเริ่มต้น (`friend`) ไม่แสดงป้าย — ถ้าทุกคนมีป้าย ป้ายก็ไม่ได้แปลว่าอะไร
/// เช่นเดียวกับ `_RoleTag` ในหน้าแชทที่ซ่อนป้าย 'customer'
///
/// ชื่อระดับต้องรับมาจาก API (`tier_label`) เสมอ ไม่แปลเองในแอป — เคยมีปัญหา
/// เว็บกับแอปเรียกชื่อระดับเดียวกันไม่ตรงกันมาแล้ว ค่า fallback ด้านล่างมีไว้
/// เผื่อ response เก่าที่ยังไม่มีฟิลด์นี้เท่านั้น
class TierBadge extends StatelessWidget {
  final String tier;
  final String label;

  /// เล็กลงหนึ่งขั้น สำหรับแถวชื่อในบับเบิลแชทที่พื้นที่จำกัด
  final bool compact;

  const TierBadge({
    super.key,
    required this.tier,
    this.label = '',
    this.compact = false,
  });

  /// อ่านระดับจาก payload ของผู้ใช้ที่ API ส่งมา — คืน null เมื่อไม่ต้องแสดงป้าย
  static TierBadge? fromUser(
    Map<String, dynamic>? user, {
    bool compact = false,
  }) {
    if (user == null) return null;

    final tier = user['tier']?.toString().trim() ?? '';
    if (tier.isEmpty || tier == 'friend') return null;

    return TierBadge(
      tier: tier,
      label: user['tier_label']?.toString().trim() ?? '',
      compact: compact,
    );
  }

  static const _colors = <String, Color>{
    'frequent': Color(0xFF0F6B5C),
    'comrade': Color(0xFF1D4E86),
    'insider': Color(0xFF8A5A12),
  };

  static const _fallbackLabels = <String, String>{
    'frequent': 'ขาประจำ',
    'comrade': 'สหายนักเดิน',
    'insider': 'คนกันเอง',
  };

  @override
  Widget build(BuildContext context) {
    if (tier.isEmpty || tier == 'friend') return const SizedBox.shrink();

    final color = _colors[tier] ?? AppTheme.mutedText(context);
    final text = label.isNotEmpty ? label : (_fallbackLabels[tier] ?? tier);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.landscape_rounded, size: compact ? 10 : 12, color: color),
          SizedBox(width: compact ? 3 : 4),
          Text(
            text,
            style: appFont(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
