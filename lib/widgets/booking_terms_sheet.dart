import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

/// แผ่นเงื่อนไขก่อนยืนยันการจอง — ชุดเดียวกับที่เว็บและ LINE แสดง
///
/// ข้อความทุกบรรทัดมาจาก GET /legal/policy ไม่ได้พิมพ์ไว้ในแอป เพราะเงื่อนไข
/// ที่ลูกค้ากดยอมรับคือหลักฐานเวลามีข้อพิพาท (เช่น ขอเงินคืนเมื่อรอบถูกยกเลิก
/// เพราะน้ำป่า) ถ้าแอปพูดคนละอย่างกับเว็บ หลักฐานก็ใช้ไม่ได้ทั้งสองที่
///
/// คืน true เมื่อลูกค้าติ๊กยอมรับแล้วกดยืนยันเท่านั้น
class BookingTermsSheet {
  BookingTermsSheet._();

  static Future<bool> show(
    BuildContext context, {
    required List<String> lines,
    required String version,
    required String summary,
  }) async {
    HapticFeedback.selectionClick();
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (_) =>
          _TermsSheet(lines: lines, version: version, summary: summary),
    );
    return accepted == true;
  }
}

class _TermsSheet extends StatefulWidget {
  const _TermsSheet({
    required this.lines,
    required this.version,
    required this.summary,
  });

  final List<String> lines;
  final String version;
  final String summary;

  @override
  State<_TermsSheet> createState() => _TermsSheetState();
}

class _TermsSheetState extends State<_TermsSheet> {
  bool _agreed = false;

  /// "2026-09-29" → "29 กันยายน 2569" — อ่านไม่ออกก็ไม่แสดงบรรทัดนี้
  String? get _versionLabel {
    final parsed = DateTime.tryParse(widget.version);
    return parsed == null ? null : thaiDateFull(parsed);
  }

  Future<void> _openFullTerms() async {
    final uri = Uri.parse('${ApiConfig.siteUrl}/terms');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    final versionLabel = _versionLabel;

    return SafeArea(
      child: ConstrainedBox(
        // เงื่อนไขยาว — ให้เลื่อนอ่านได้ แต่ปุ่มยืนยันต้องอยู่ติดล่างเสมอ
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'เงื่อนไขก่อนยืนยันการจอง',
                style: appFont(
                  fontSize: AppText.sizeTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'การสำรองที่นั่ง และการเปลี่ยนแปลง',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.lines.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                '${i + 1}.',
                                style: appFont(
                                  fontSize: AppText.sizeBody,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.lines[i],
                                style: appFont(
                                  fontSize: AppText.sizeBody,
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successTint(context),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        'สรุปการจอง: ${widget.summary}',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onTintOf(
                            context,
                            AppTheme.successColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (versionLabel != null)
                          Expanded(
                            child: Text(
                              'เงื่อนไขฉบับวันที่ $versionLabel',
                              style: appFont(
                                fontSize: AppText.sizeCaption,
                                color: muted,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        TextButton(
                          onPressed: _openFullTerms,
                          child: Text(
                            'อ่านฉบับเต็ม',
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ติ๊กยอมรับอยู่นอกส่วนที่เลื่อน — ต้องเห็นพร้อมปุ่มยืนยันเสมอ
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _agreed = !_agreed);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (value) =>
                          setState(() => _agreed = value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'ข้าพเจ้าได้อ่านและยอมรับเงื่อนไขข้างต้นทุกข้อแล้ว',
                          style: appFont(
                            fontSize: AppText.sizeBody,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _agreed
                          ? () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context, true);
                            }
                          : null,
                      child: const Text('ยืนยันการจอง'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
