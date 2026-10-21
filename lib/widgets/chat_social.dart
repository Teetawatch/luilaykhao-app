import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'chat_rest_stop.dart'
    show RestStopSheetFrame, RestStopSheetLabel, restStopFieldDecoration;
import 'travel_widgets.dart';

// ลูกเล่นในห้องแชท: การ์ดแนะนำตัว (ChatIntroService) และวันเกิดระหว่างทริป
// สำหรับทีมงาน (ChatBirthdayService) — ไม่มีอายุ/ปีเกิดในอะไรที่แอปได้รับเลย

/// ระดับประสบการณ์ — ค่าตรงกับ ChatMemberIntro::EXPERIENCES
const introExperiences = [
  (key: 'first', label: 'มาครั้งแรก 🌱'),
  (key: 'some', label: 'เคยไปมาบ้าง 🥾'),
  (key: 'lots', label: 'สายลุย ⛰️'),
];

String? introExperienceLabel(dynamic key) {
  for (final e in introExperiences) {
    if (e.key == key) return e.label;
  }
  return null;
}

/// การ์ดแนะนำตัวในบับเบิล
class ChatIntroCard extends StatelessWidget {
  final Map<String, dynamic> intro;
  final String name;
  final bool isMine;
  final VoidCallback? onEdit;

  const ChatIntroCard({
    super.key,
    required this.intro,
    required this.name,
    required this.isMine,
    this.onEdit,
  });

  String? _text(dynamic v) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final hometown = _text(intro['hometown']);
    final experience = _text(intro['experience_label']) ?? introExperienceLabel(intro['experience']);
    final note = _text(intro['note']);

    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('👋', style: TextStyle(fontSize: AppText.sizeH2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMine ? 'คุณแนะนำตัวแล้ว' : '$name มาแนะนำตัว',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
          ],
        ),
        if (hometown != null) row(Icons.home_rounded, 'มาจาก $hometown'),
        if (experience != null) row(Icons.hiking_rounded, experience),
        if (note != null) row(Icons.chat_bubble_outline_rounded, note),
        if (isMine && onEdit != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onEdit,
              child: Text('แก้ไข', style: appFont(fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

class IntroDraft {
  final String? hometown;
  final String? experience;
  final String? note;

  const IntroDraft({this.hometown, this.experience, this.note});

  bool get isEmpty =>
      (hometown ?? '').trim().isEmpty && experience == null && (note ?? '').trim().isEmpty;
}

/// ฟอร์มแนะนำตัว — ทุกช่องไม่บังคับ แต่ต้องมีอย่างน้อยหนึ่งอย่าง
class ChatIntroSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;

  const ChatIntroSheet({super.key, this.initial});

  @override
  State<ChatIntroSheet> createState() => _ChatIntroSheetState();
}

class _ChatIntroSheetState extends State<ChatIntroSheet> {
  late final _hometown = TextEditingController(text: widget.initial?['hometown']?.toString() ?? '');
  late final _note = TextEditingController(text: widget.initial?['note']?.toString() ?? '');
  late String? _experience = widget.initial?['experience']?.toString();

  @override
  void dispose() {
    _hometown.dispose();
    _note.dispose();
    super.dispose();
  }

  IntroDraft get _draft => IntroDraft(
    hometown: _hometown.text.trim(),
    experience: _experience,
    note: _note.text.trim(),
  );

  @override
  Widget build(BuildContext context) {
    return RestStopSheetFrame(
      icon: Icons.waving_hand_rounded,
      title: widget.initial == null ? 'แนะนำตัวกับเพื่อนร่วมทริป' : 'แก้การ์ดแนะนำตัว',
      subtitle: 'บอกเท่าที่อยากบอก — ขึ้นในห้องแชทเป็นการ์ดของคุณ',
      footer: PrimaryCTAButton(
        label: widget.initial == null ? 'ส่งการ์ดแนะนำตัว' : 'บันทึก',
        icon: Icons.send_rounded,
        onPressed: _draft.isEmpty ? null : () => Navigator.of(context).pop(_draft),
      ),
      children: [
        const RestStopSheetLabel('มาจากไหน'),
        TextField(
          controller: _hometown,
          maxLength: 60,
          onChanged: (_) => setState(() {}),
          decoration: restStopFieldDecoration(context, 'เช่น เชียงใหม่ / บางนา'),
        ),
        const SizedBox(height: 8),
        const RestStopSheetLabel('เคยไปทริปแบบนี้ไหม'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in introExperiences)
              ChoiceChip(
                label: Text(e.label, style: appFont(fontWeight: FontWeight.w700)),
                selected: _experience == e.key,
                onSelected: (on) {
                  HapticFeedback.selectionClick();
                  setState(() => _experience = on ? e.key : null);
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        const RestStopSheetLabel('อยากบอกอะไรเพื่อน ๆ อีกไหม'),
        TextField(
          controller: _note,
          maxLength: 160,
          maxLines: 3,
          minLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: restStopFieldDecoration(context, 'เช่น ชอบถ่ายรูป ใครพกขาตั้งกล้องไปบ้าง'),
        ),
      ],
    );
  }
}

/// แถบของทีมงาน — มีลูกทริปวันเกิดระหว่างทริปที่ยังไม่ได้อวยพร
class BirthdayStaffBanner extends StatelessWidget {
  final int count;
  final VoidCallback onOpen;

  const BirthdayStaffBanner({super.key, required this.count, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.warningColor.withValues(alpha: AppTheme.isDark(context) ? 0.16 : 0.08),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onOpen();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          child: Row(
            children: [
              const Text('🎂', style: TextStyle(fontSize: AppText.sizeSubtitle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'มีวันเกิดในทริปนี้ $count คน · เห็นเฉพาะทีมงาน',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// รายชื่อวันเกิด + ปุ่มส่งคำอวยพรเข้าห้อง (ครั้งเดียวต่อคน)
class BirthdaySheet extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() load;

  /// ส่งคำอวยพร — คืนรายการใหม่
  final Future<List<Map<String, dynamic>>> Function(int passengerId) onGreet;

  const BirthdaySheet({super.key, required this.load, required this.onGreet});

  @override
  State<BirthdaySheet> createState() => _BirthdaySheetState();
}

class _BirthdaySheetState extends State<BirthdaySheet> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  int? _busy;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final items = await widget.load();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _greet(int passengerId) async {
    setState(() => _busy = passengerId);
    try {
      final items = await widget.onGreet(passengerId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _date(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return RestStopSheetFrame(
      icon: Icons.cake_rounded,
      title: 'วันเกิดในทริปนี้',
      subtitle: 'ลูกทริปไม่เห็นรายการนี้ — จะอวยพรในห้อง หรือเตรียมเซอร์ไพรส์เองก็ได้ (ไม่มีอายุในข้อความ)',
      children: [
        if (items == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          )
        else if (items == null)
          Center(child: TextButton(onPressed: _reload, child: const Text('โหลดไม่สำเร็จ · ลองอีกครั้ง')))
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('ไม่มีวันเกิดในช่วงทริปนี้', textAlign: TextAlign.center, style: appFont()),
          )
        else
          for (final b in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Text('🎂', style: TextStyle(fontSize: AppText.sizeSubtitle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['name']?.toString() ?? '',
                          style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _date(b['date']),
                          style: appFont(fontSize: AppText.sizeCaption, color: AppTheme.mutedText(context)),
                        ),
                      ],
                    ),
                  ),
                  if (b['greeted'] == true)
                    Text(
                      'อวยพรแล้ว ✓',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: _busy != null
                          ? null
                          : () => _greet(int.tryParse('${b['passenger_id']}') ?? 0),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        ),
                      ),
                      child: _busy == int.tryParse('${b['passenger_id']}')
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('อวยพรในห้อง', style: appFont(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
