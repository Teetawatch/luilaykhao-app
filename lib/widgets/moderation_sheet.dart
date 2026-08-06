import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'app_snack.dart';

/// ชีต "รายงาน / บล็อก" ที่ใช้ได้กับทุกที่ที่มีเนื้อหาจากผู้ใช้คนอื่น —
/// แชท รีวิว โพสต์ในฟีด คอมเมนต์ และรูปในกำแพงรูป
///
/// มีที่เดียวเพราะข้อความ ตัวเลือกเหตุผล และลำดับการยืนยันควรเหมือนกันหมด
/// ผู้ใช้ที่เคยรายงานรีวิวจะได้รู้อยู่แล้วว่ากดรายงานในแชทจะเจออะไร
class ModerationSheet {
  ModerationSheet._();

  /// ชนิดเนื้อหาต้องตรงกับ ModerationService::TYPES ฝั่งเซิร์ฟเวอร์
  static const typeChatMessage = 'chat_message';
  static const typeReview = 'review';
  static const typeTripPost = 'trip_post';
  static const typeTripPostComment = 'trip_post_comment';
  static const typeUser = 'user';

  /// เหตุผลที่เลือกได้ — ชุดเดียวกับ ModerationService::REASONS
  /// เก็บไว้ฝั่งแอปด้วยเพื่อให้ชีตเปิดได้ทันทีโดยไม่ต้องรอเน็ต
  static const _reasons = <String, String>{
    'spam': 'สแปมหรือโฆษณา',
    'harassment': 'คุกคามหรือกลั่นแกล้ง',
    'hate': 'ใช้ถ้อยคำสร้างความเกลียดชัง',
    'sexual': 'เนื้อหาทางเพศ',
    'violence': 'ความรุนแรงหรือสิ่งผิดกฎหมาย',
    'false_info': 'ข้อมูลเท็จ',
    'other': 'อื่น ๆ',
  };

  /// เปิดเมนูสำหรับเนื้อหาหนึ่งชิ้น
  ///
  /// [contentLabel] คือคำที่เอาไปต่อท้าย "รายงาน" เช่น "ข้อความนี้"
  /// [onHidden] ถูกเรียกเมื่อผู้ใช้บล็อกเจ้าของเนื้อหาสำเร็จ เพื่อให้หน้าจอ
  /// เอาเนื้อหาออกจากลิสต์ได้ทันทีโดยไม่ต้องรอโหลดใหม่
  static Future<void> open(
    BuildContext context, {
    required String type,
    required int id,
    int? authorId,
    String? authorName,
    String contentLabel = 'เนื้อหานี้',
    VoidCallback? onHidden,
  }) async {
    final app = context.read<AppProvider>();

    if (!app.isLoggedIn) {
      AppSnack.show(context, 'เข้าสู่ระบบเพื่อรายงานหรือบล็อกผู้ใช้');
      return;
    }

    HapticFeedback.selectionClick();
    final name = (authorName ?? '').trim();
    final canBlock = authorId != null && authorId > 0 && authorId != app.userId;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(
                'รายงาน$contentLabel',
                style: appFont(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'ส่งให้ทีมงานตรวจสอบ ผู้ถูกรายงานจะไม่รู้ว่าเป็นคุณ',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  color: AppTheme.mutedText(sheetContext),
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
            if (canBlock)
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppTheme.errorColor),
                title: Text(
                  name.isEmpty ? 'บล็อกผู้ใช้คนนี้' : 'บล็อก $name',
                  style: appFont(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.errorColor,
                  ),
                ),
                subtitle: Text(
                  'จะไม่เห็นเนื้อหาของกันและกันอีก',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(sheetContext),
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, 'block'),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == 'report') {
      await _report(context, type: type, id: id, contentLabel: contentLabel);
    } else if (action == 'block') {
      await confirmBlock(
        context,
        userId: authorId!,
        name: name,
        onBlocked: onHidden,
      );
    }
  }

  /// ชีตเลือกเหตุผล + หมายเหตุ แล้วส่งรายงาน
  static Future<void> _report(
    BuildContext context, {
    required String type,
    required int id,
    required String contentLabel,
  }) async {
    final noteController = TextEditingController();
    String selected = _reasons.keys.first;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (builderContext, setSheetState) => Padding(
          // ดันชีตขึ้นเหนือคีย์บอร์ดตอนพิมพ์หมายเหตุ
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(builderContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'รายงาน$contentLabel',
                      style: appFont(
                        fontSize: AppText.sizeTitle,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'เลือกเหตุผลที่ตรงที่สุด',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(builderContext),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // เขียนเป็น ListTile + ไอคอนเอง แทน RadioListTile เพราะ
                  // groupValue/onChanged ถูก deprecate ไปแล้ว และแบบนี้ก็เข้ากับ
                  // ดีไซน์แบนของแอปมากกว่า
                  for (final entry in _reasons.entries)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        selected == entry.key
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected == entry.key
                            ? AppTheme.primaryColor
                            : AppTheme.mutedText(builderContext),
                      ),
                      title: Text(
                        entry.value,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => setSheetState(() => selected = entry.key),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: TextField(
                      controller: noteController,
                      maxLength: 300,
                      maxLines: 2,
                      style: appFont(fontSize: AppText.sizeBody),
                      decoration: InputDecoration(
                        hintText: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
                        hintStyle: appFont(
                          fontSize: AppText.sizeBody,
                          color: AppTheme.mutedText(builderContext),
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(builderContext, true),
                        child: Text(
                          'ส่งรายงาน',
                          style: appFont(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final note = noteController.text.trim();
    noteController.dispose();

    if (!context.mounted || confirmed != true) return;

    try {
      await context.read<AppProvider>().reportContent(
            type: type,
            id: id,
            reason: selected,
            note: note.isEmpty ? null : note,
          );
      if (context.mounted) {
        AppSnack.success(context, 'ขอบคุณที่แจ้งเข้ามา ทีมงานจะตรวจสอบโดยเร็ว');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnack.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// ยืนยันก่อนบล็อก — การบล็อกทำให้เนื้อหาหายไปทั้งสองฝั่ง จึงควรถามก่อน
  static Future<void> confirmBlock(
    BuildContext context, {
    required int userId,
    String name = '',
    VoidCallback? onBlocked,
  }) async {
    final who = name.trim().isEmpty ? 'ผู้ใช้คนนี้' : name.trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('บล็อก $who?', style: appFont(fontWeight: FontWeight.w800)),
        content: Text(
          'คุณจะไม่เห็นข้อความ รีวิว และโพสต์ของ$who อีก และเขาก็จะไม่เห็นของคุณเช่นกัน '
          'เลิกบล็อกได้ที่ โปรไฟล์ > ผู้ใช้ที่ถูกบล็อก',
          style: appFont(fontSize: AppText.sizeBody, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('ยกเลิก', style: appFont(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('บล็อก', style: appFont(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (!context.mounted || ok != true) return;

    try {
      await context.read<AppProvider>().blockUser(userId);
      if (context.mounted) {
        AppSnack.success(context, 'บล็อก$whoแล้ว');
        onBlocked?.call();
      }
    } catch (e) {
      if (context.mounted) {
        AppSnack.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }
}
