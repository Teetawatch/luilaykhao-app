import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

/// ลายของบัตร — ต้องตรงกับหน้าเว็บ /voucher/{code} (resources/views/voucher.blade.php)
/// และรายการใน config/gift_voucher.php
const Map<String, List<Color>> giftVoucherPalettes = {
  'forest': [Color(0xFF065F46), Color(0xFF059669)],
  'sunrise': [Color(0xFF9A3412), Color(0xFFF59E0B)],
  'ocean': [Color(0xFF0C4A6E), Color(0xFF0EA5E9)],
  'night': [Color(0xFF1E1B4B), Color(0xFF6366F1)],
};

const Map<String, String> giftVoucherDesignLabels = {
  'forest': 'ป่าเขียว',
  'sunrise': 'พระอาทิตย์ขึ้น',
  'ocean': 'ทะเล',
  'night': 'ดาวกลางคืน',
};

List<Color> giftVoucherPalette(String? design) =>
    giftVoucherPalettes[design] ?? giftVoucherPalettes['forest']!;

/// ฿1,250 / ฿62.50 — ไม่มีสตางค์ก็ไม่ต้องโชว์ .00
String voucherBaht(dynamic amount) {
  final v = double.tryParse('$amount') ?? 0;
  final whole = v == v.roundToDouble();
  final fixed = whole ? v.round().toString() : v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '฿$digits${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// "GVABCDEFGHJK" → "GV-ABCDE-FGHJK" (รูปเดียวกับ GiftVoucher::displayCode)
String formatVoucherCode(String raw) {
  final code = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (code.length != 12 || !code.startsWith('GV')) return code;
  return 'GV-${code.substring(2, 7)}-${code.substring(7)}';
}

/// ยอดที่บัตรจ่ายได้จริงจากยอดที่ต้องชำระ — ตรงกับ BookingService ฝั่งหลังบ้าน:
/// หักหลังส่วนลด และไม่เกินทั้งยอดคงเหลือของบัตรและยอดที่ต้องจ่าย
num voucherCoverage(num amountDue, num? balance) {
  if (balance == null || balance <= 0 || amountDue <= 0) return 0;
  return balance < amountDue ? balance : amountDue;
}

/// ป้ายสถานะของบัตร (สถานะมาจาก GiftVoucherResource.status)
String giftVoucherStatusLabel(String status) => switch (status) {
  'active' => 'ใช้ได้',
  'used_up' => 'ใช้ครบแล้ว',
  'expired' => 'หมดอายุ',
  'pending' => 'รอชำระเงิน',
  'under_review' => 'รอตรวจสลิป',
  'rejected' => 'สลิปไม่ผ่าน',
  'cancelled' => 'ยกเลิกแล้ว',
  _ => status,
};

/// การ์ดบัตรของขวัญ — หน้าตาเดียวกันทั้งในกระเป๋า หน้าซื้อ (พรีวิว) และหน้ารับบัตร
class GiftVoucherCard extends StatelessWidget {
  final num amount;

  /// ยอดคงเหลือ — null = ไม่ต้องโชว์ (พรีวิวก่อนซื้อ / บัตรของคนอื่น)
  final num? balance;
  final String? design;
  final String? recipientName;
  final String? fromName;
  final String? displayCode;
  final String? status;
  final DateTime? expiresAt;
  final VoidCallback? onTap;

  const GiftVoucherCard({
    super.key,
    required this.amount,
    this.balance,
    this.design,
    this.recipientName,
    this.fromName,
    this.displayCode,
    this.status,
    this.expiresAt,
    this.onTap,
  });

  /// จาก payload ของ API (GiftVoucherResource / lookup)
  factory GiftVoucherCard.fromJson(
    Map<String, dynamic> json, {
    VoidCallback? onTap,
    bool showBalance = true,
  }) {
    final balance = json['balance'];
    return GiftVoucherCard(
      amount: num.tryParse('${json['amount']}') ?? 0,
      balance: showBalance && balance != null ? num.tryParse('$balance') : null,
      design: json['design']?.toString(),
      recipientName: _text(json['recipient_name']),
      fromName: _text(json['from_name']),
      displayCode: _text(json['display_code']),
      status: _text(json['status']),
      expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}')?.toLocal(),
      onTap: onTap,
    );
  }

  static String? _text(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty || s == 'null' ? null : s;
  }

  bool get _dimmed =>
      status != null && !['active', 'pending', 'under_review'].contains(status);

  @override
  Widget build(BuildContext context) {
    final colors = giftVoucherPalette(design);
    final showBalance =
        balance != null && status == 'active' && balance! < amount;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -46,
            top: -46,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'LUILAYKHAO · บัตรของขวัญ',
                      style: appFont(
                        fontSize: AppText.sizeMicro,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  if (status != null && status != 'active')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      child: Text(
                        giftVoucherStatusLabel(status!),
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w800,
                          color: colors.first,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                showBalance ? 'คงเหลือ' : 'มูลค่า',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                voucherBaht(showBalance ? balance : amount),
                style: appFont(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              if (showBalance)
                Text(
                  'จากมูลค่า ${voucherBaht(amount)}',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              const SizedBox(height: 10),
              if (recipientName != null)
                Text(
                  'สำหรับ $recipientName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              if (fromName != null)
                Text(
                  'จาก $fromName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              if (displayCode != null || expiresAt != null) ...[
                const SizedBox(height: 10),
                // จอแคบ/ตัวหนังสือใหญ่ — วันหมดอายุตกลงบรรทัดใหม่ได้ ไม่ดันรหัสจนล้น
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    if (displayCode != null)
                      Text(
                        displayCode!,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    if (expiresAt != null)
                      Text(
                        'ใช้ได้ถึง ${thaiDateShort(expiresAt!)}',
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );

    final content = Opacity(opacity: _dimmed ? 0.55 : 1, child: card);
    if (onTap == null) return content;

    return Semantics(
      button: true,
      label: 'บัตรของขวัญ ${voucherBaht(amount)}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
