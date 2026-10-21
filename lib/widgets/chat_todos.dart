import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'chat_rest_stop.dart' show RestStopSheetFrame;

// "รอคุณอยู่" — แถบบนหัวห้องแชท รวมสิ่งที่ฉันยังต้องกด (ประกาศรอรับทราบ โหวต
// สั่งอาหาร จ่ายเงิน กลับขึ้นรถ …) แตะแล้วกระโดดไปที่การ์ดนั้นในแชท
//
// รายการมาจาก GET chat/todos (ChatTodoService) — kind ตรงกับฝั่งเซิร์ฟเวอร์

class ChatTodo {
  final String kind;
  final int messageId;
  final String title;
  final String detail;
  final DateTime? dueAt;

  const ChatTodo({
    required this.kind,
    required this.messageId,
    required this.title,
    required this.detail,
    this.dueAt,
  });

  static List<ChatTodo> parseList(dynamic raw) {
    final out = <ChatTodo>[];
    for (final e in (raw is List ? raw : const [])) {
      if (e is! Map) continue;
      final id = int.tryParse('${e['message_id']}');
      if (id == null) continue;
      out.add(
        ChatTodo(
          kind: e['kind']?.toString() ?? '',
          messageId: id,
          title: e['title']?.toString() ?? '',
          detail: e['detail']?.toString() ?? '',
          dueAt: DateTime.tryParse(e['due_at']?.toString() ?? '')?.toLocal(),
        ),
      );
    }
    return out;
  }

  IconData get icon => switch (kind) {
    'ack' => Icons.task_alt_rounded,
    'vote' => Icons.how_to_vote_rounded,
    'poll' => Icons.bar_chart_rounded,
    'food_order' => Icons.ramen_dining_rounded,
    'food_pay' || 'collection' => Icons.payments_rounded,
    'rest_stop' => Icons.airport_shuttle_rounded,
    'meetup' => Icons.place_rounded,
    'wakeup' => Icons.alarm_rounded,
    'home' => Icons.home_rounded,
    'wellness' => Icons.favorite_rounded,
    _ => Icons.radio_button_unchecked_rounded,
  };

  /// เรื่องที่มีคนรอเราอยู่ตอนนี้ (รถ/ทีมงาน) — ใช้สีเตือน
  bool get urgent => const {'rest_stop', 'meetup', 'wakeup', 'vote'}.contains(kind);
}

/// "อีก 8 นาที" / "ภายใน 14:30" / "เลยเวลาแล้ว" — null เมื่อไม่มีเวลากำกับ
String? todoDueLabel(DateTime? due, DateTime now) {
  if (due == null) return null;
  final diff = due.difference(now);
  if (diff.isNegative) return 'เลยเวลาแล้ว';
  if (diff.inMinutes < 1) return 'ไม่ถึงนาที';
  if (diff.inMinutes < 60) return 'อีก ${diff.inMinutes} นาที';
  final hh = due.hour.toString().padLeft(2, '0');
  final mm = due.minute.toString().padLeft(2, '0');
  final sameDay = due.year == now.year && due.month == now.month && due.day == now.day;
  return sameDay ? 'ภายใน $hh:$mm' : 'ภายใน ${due.day}/${due.month} $hh:$mm';
}

/// แถบบางใต้หัวห้อง — เรื่องแรกเด่น ที่เหลือบอกเป็นจำนวน
class ChatTodoBar extends StatelessWidget {
  final List<ChatTodo> todos;
  final ValueChanged<ChatTodo> onOpen;
  final VoidCallback onOpenAll;
  final DateTime Function() now;

  const ChatTodoBar({
    super.key,
    required this.todos,
    required this.onOpen,
    required this.onOpenAll,
    this.now = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) return const SizedBox.shrink();
    final first = todos.first;
    final due = todoDueLabel(first.dueAt, now());
    final accent = first.urgent ? AppTheme.warningColor : AppTheme.primaryColor;
    final more = todos.length - 1;

    return Material(
      color: accent.withValues(alpha: AppTheme.isDark(context) ? 0.16 : 0.08),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          todos.length == 1 ? onOpen(first) : onOpenAll();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: accent.withValues(alpha: 0.25)),
            ),
          ),
          child: Row(
            children: [
              Icon(first.icon, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      todos.length == 1
                          ? 'รอคุณอยู่ · ${first.title}'
                          : 'รอคุณอยู่ ${todos.length} เรื่อง · ${first.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    Text(
                      [
                        if (first.detail.isNotEmpty) first.detail,
                        ?due,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (more > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '+$more',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.mutedText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// รายการทั้งหมด — แตะแล้วปิดชีตคืนรายการที่เลือก
class ChatTodoSheet extends StatelessWidget {
  final List<ChatTodo> todos;
  final DateTime Function() now;

  const ChatTodoSheet({super.key, required this.todos, this.now = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final at = now();

    return RestStopSheetFrame(
      icon: Icons.checklist_rounded,
      title: 'รอคุณอยู่ ${todos.length} เรื่อง',
      subtitle: 'แตะเพื่อไปที่ข้อความนั้นในแชท',
      children: [
        for (final t in todos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppTheme.subtleSurface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop(t);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      Icon(
                        t.icon,
                        size: 20,
                        color: t.urgent ? AppTheme.warningColor : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: appFont(
                                fontSize: AppText.sizeBody,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface(context),
                              ),
                            ),
                            if (t.detail.isNotEmpty)
                              Text(
                                t.detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: appFont(
                                  fontSize: AppText.sizeCaption,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.mutedText(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (todoDueLabel(t.dueAt, at) case final due?)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            due,
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w800,
                              color: t.urgent
                                  ? AppTheme.warningColor
                                  : AppTheme.mutedText(context),
                            ),
                          ),
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.mutedText(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
