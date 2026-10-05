import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'travel_widgets.dart';

/// ผลลัพธ์จากชีตเริ่มโหวต — options ว่าง = ใช้ เห็นด้วย / ไม่เห็นด้วย ของเซิร์ฟเวอร์
class VoteDraft {
  final String question;
  final List<String> options;
  final int minutes;

  const VoteDraft({
    required this.question,
    required this.options,
    required this.minutes,
  });
}

/// ชีตเริ่ม "โหวตตัดสิน" — ไว้จบเรื่องตอนลูกทริปเสียงแตกกลางทาง
///
/// ต่างจากโพลตรงที่เลือกได้ข้อเดียวเสมอ มีเส้นตายเป็นนาที และพอทุกคนโหวตครบหรือ
/// หมดเวลา ระบบปิดเองแล้วประกาศผลเสียงข้างมากเข้าห้อง ไม่ต้องมีใครมานั่งนับ
class CreateVoteSheet extends StatefulWidget {
  const CreateVoteSheet({super.key});

  @override
  State<CreateVoteSheet> createState() => _CreateVoteSheetState();
}

class _CreateVoteSheetState extends State<CreateVoteSheet> {
  static const _maxOptions = 4;
  static const _durations = [5, 10, 15, 30, 60];

  final _question = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  bool _custom = false;
  int _minutes = 10;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _filledOptions => _options
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  bool get _canSubmit =>
      _question.text.trim().isNotEmpty &&
      (!_custom || _filledOptions.length >= 2);

  void _submit() {
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      VoteDraft(
        question: _question.text.trim(),
        options: _custom ? _filledOptions : const [],
        minutes: _minutes,
      ),
    );
  }

  String _durationLabel(int m) => m >= 60 ? '${m ~/ 60} ชม.' : '$m นาที';

  InputDecoration _decoration(BuildContext context, String hint) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      borderSide: BorderSide(color: AppTheme.border(context)),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: appFont(
        fontSize: AppText.sizeBody,
        fontWeight: FontWeight.w500,
        color: AppTheme.mutedText(context),
      ),
      isDense: true,
      filled: true,
      fillColor: AppTheme.subtleSurface(context),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border,
      enabledBorder: border,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.how_to_vote_rounded,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'โหวตตัดสิน',
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'คนละ 1 เสียง เสียงข้างมากชนะ — ทุกคนโหวตครบหรือหมดเวลาแล้ว'
                  'ระบบปิดและประกาศผลในห้องให้เอง',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                    height: 1.4,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    TextField(
                      controller: _question,
                      autofocus: true,
                      maxLength: 200,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                      ),
                      decoration: _decoration(
                        context,
                        'เรื่องที่จะโหวต เช่น แวะคาเฟ่ก่อนกลับไหม',
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _SheetLabel('ตัวเลือก'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(
                            '👍 เห็นด้วย / 👎 ไม่เห็นด้วย',
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          selected: !_custom,
                          onSelected: (_) => setState(() => _custom = false),
                        ),
                        ChoiceChip(
                          label: Text(
                            'ตั้งตัวเลือกเอง',
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          selected: _custom,
                          onSelected: (_) => setState(() => _custom = true),
                        ),
                      ],
                    ),
                    if (_custom) ...[
                      const SizedBox(height: 10),
                      for (var i = 0; i < _options.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _options[i],
                                  maxLength: 100,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {}),
                                  style: appFont(
                                    fontSize: AppText.sizeBody,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onSurface(context),
                                  ),
                                  decoration: _decoration(
                                    context,
                                    i == 0
                                        ? 'เช่น หมูกระทะ'
                                        : (i == 1
                                              ? 'เช่น ส้มตำ'
                                              : 'ตัวเลือกที่ ${i + 1}'),
                                  ),
                                ),
                              ),
                              if (_options.length > 2)
                                IconButton(
                                  tooltip: 'ลบตัวเลือกนี้',
                                  onPressed: () => setState(
                                    () => _options.removeAt(i).dispose(),
                                  ),
                                  icon: Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 20,
                                    color: AppTheme.mutedText(context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_options.length < _maxOptions)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _options.add(TextEditingController()),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'เพิ่มตัวเลือก',
                              style: appFont(
                                fontSize: AppText.sizeLabel,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 14),
                    const _SheetLabel('ให้เวลาโหวต'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _durations)
                          ChoiceChip(
                            label: Text(
                              _durationLabel(m),
                              style: appFont(
                                fontSize: AppText.sizeLabel,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selected: _minutes == m,
                            onSelected: (_) => setState(() => _minutes = m),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: PrimaryCTAButton(
                  label: 'เริ่มโหวต',
                  icon: Icons.how_to_vote_rounded,
                  onPressed: _canSubmit ? _submit : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String label;

  const _SheetLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w800,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}
