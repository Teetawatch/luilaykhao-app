import 'package:flutter/material.dart';

/// ตัวเลขที่ "วิ่ง" จากค่าเดิมไปค่าใหม่ แทนการเปลี่ยนเลขทันที — ยอดรวมตอนเพิ่ม
/// add-on/ใส่โค้ดส่วนลด, แต้ม, จำนวนวันที่เหลือ
///
/// ค่าแรกที่เห็นไม่วิ่ง (ราคาไม่ควรนับจาก 0 ทุกครั้งที่เปิดหน้า) เว้นแต่ตั้ง
/// [from] — วิ่งจากค่านั้นตอนโผล่ครั้งแรก เช่น แต้มสะสมนับขึ้นจาก 0 หรือวันที่
/// เหลือนับถอยลงมา (นับขึ้นจาก 0 จะแวบเป็น "อีก 0 วัน" ซึ่งอ่านว่าวันนี้)
///
/// ถ้าค่าต้นและค่าปลายเป็นจำนวนเต็ม ค่าระหว่างทางถูกปัดเป็นจำนวนเต็มด้วย
/// (ไม่โชว์ ฿3,214.37 กลางทาง) และใช้ตัวเลขความกว้างเท่ากัน (tabular figures)
/// ตัวหนังสือจึงไม่ส่ายตอนเลขวิ่ง ปิดเองเมื่อเครื่องตั้ง "ลดการเคลื่อนไหว"
class CountUpText extends StatelessWidget {
  final num value;
  final String Function(num value) format;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final num? from;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.from,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = (style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Text text(num shown) => Text(
      format(shown),
      style: textStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return text(value);
    }

    final end = value.toDouble();
    final whole = value == value.roundToDouble();
    return TweenAnimationBuilder<double>(
      // begin ถูกใช้แค่ตอน build แรก — หลังจากนั้นค่าใหม่จะวิ่งจากค่าที่โชว์อยู่
      tween: Tween(begin: (from ?? value).toDouble(), end: end),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, shown, _) => text(whole ? shown.round() : shown),
    );
  }
}
