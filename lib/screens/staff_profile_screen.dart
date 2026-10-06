import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/chat_staff_intro.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/travel_widgets.dart';

/// โปรไฟล์ทีมงาน — สิ่งที่ลูกทริปเห็นในการ์ด "แนะนำทีมงานประจำรอบ" ในห้องแชท
///
/// สตาฟเขียนเองได้: ชื่อเล่น แนะนำตัว ป่าที่เคยเดิน ความถนัด ส่วนจำนวนรอบ
/// คะแนนรีวิว และทริปที่เคยคุมรอบ ระบบนับให้เอง บันทึกแล้วห้องของรอบที่กำลัง
/// จะไปจะเห็นข้อมูลใหม่ทันที
class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  static const _trailSuggestions = [
    'ดอยหลวงเชียงดาว',
    'ภูกระดึง',
    'ดอยอินทนนท์',
    'ม่อนจอง',
    'ภูสอยดาว',
    'ภูชี้ฟ้า',
    'เขาช้างเผือก',
    'ยอดโมโกจู',
  ];

  static const _skillSuggestions = [
    'ปฐมพยาบาลเบื้องต้น',
    'ถ่ายรูป',
    'ทำอาหาร',
    'ภาษาอังกฤษ',
    'ดูดาว',
    'เล่าเรื่องป่า',
  ];

  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  List<String> _trails = [];
  List<String> _skills = [];

  Map<String, dynamic> _server = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  int _limit(String key, int fallback) {
    final limits = _server['limits'];
    return limits is Map
        ? int.tryParse('${limits[key]}') ?? fallback
        : fallback;
  }

  @override
  void initState() {
    super.initState();
    _nickname.addListener(_onChanged);
    _bio.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().loadStaffProfile();
      if (!mounted) return;
      _apply(data);
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _apply(Map<String, dynamic> data) {
    _server = data;
    _nickname.text = data['nickname']?.toString() ?? '';
    _bio.text = data['staff_bio']?.toString() ?? '';
    _trails = _strings(data['staff_trails']);
    _skills = _strings(data['staff_skills']);
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final data = await context.read<AppProvider>().saveStaffProfile(
        nickname: _nickname.text,
        bio: _bio.text,
        trails: _trails,
        skills: _skills,
      );
      if (!mounted) return;
      setState(() => _apply(data));
      HapticFeedback.mediumImpact();
      AppSnack.success(
        context,
        'บันทึกแล้ว ห้องแชทของรอบที่กำลังจะไปเห็นข้อมูลใหม่ทันที',
      );
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// การ์ดตัวอย่างจากฟอร์มตอนนี้ + ตัวเลขที่ระบบนับให้ (รอบ/รีวิว/ทริปที่เคยคุม)
  Map<String, dynamic> _previewIntro() {
    final preview = _server['preview'] is Map
        ? Map<String, dynamic>.from(_server['preview'] as Map)
        : <String, dynamic>{};
    final saved = _strings(
      _server['staff_trails'],
    ).map((e) => e.toLowerCase()).toSet();
    final mine = _trails.map((e) => e.toLowerCase()).toSet();
    final ledTrips = _strings(preview['trails']).where(
      (t) =>
          !saved.contains(t.toLowerCase()) && !mine.contains(t.toLowerCase()),
    );

    final nickname = _nickname.text.trim();
    return {
      ...preview,
      'name': nickname.isNotEmpty ? nickname : (preview['name'] ?? 'ทีมงาน'),
      'bio': _bio.text.trim(),
      'trails': [..._trails, ...ledTrips].take(8).toList(),
      'skills': _skills,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        // งานสตาฟชิดซ้ายทุกหน้า (ธีมรวมตั้ง centerTitle: true ไว้)
        centerTitle: false,
        title: Text(
          'โปรไฟล์ทีมงาน',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _body(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                10 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                border: Border(
                  top: BorderSide(color: AppTheme.border(context)),
                ),
              ),
              child: PrimaryCTAButton(
                label: 'บันทึก',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _save,
              ),
            ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดโปรไฟล์ไม่สำเร็จ',
        body: _error,
        actionLabel: 'ลองใหม่',
        onAction: _load,
      );
    }

    final phone = _server['phone']?.toString().trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'ข้อมูลนี้จะเด้งเป็นการ์ดแนะนำตัวในห้องแชทของทุกรอบที่คุณดูแล '
          'ลูกทริปจะได้รู้จักและกล้าทักก่อนวันเดินทาง',
          style: appFont(
            fontSize: AppText.sizeLabel,
            fontWeight: FontWeight.w500,
            color: AppTheme.mutedText(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        const _Heading('ตัวอย่างที่ลูกทริปเห็น'),
        const SizedBox(height: 8),
        StaffIntroCard(intro: _previewIntro()),
        const SizedBox(height: 22),
        const _Heading('ชื่อเล่น'),
        const SizedBox(height: 8),
        _field(controller: _nickname, hint: 'เช่น พี่ต้น', maxLength: 50),
        const SizedBox(height: 14),
        const _Heading('แนะนำตัวสั้น ๆ'),
        const SizedBox(height: 8),
        _field(
          controller: _bio,
          hint:
              'เช่น สายเดินชิล เดินช้าได้ไม่ทิ้งใครแน่นอน ชอบเล่าเรื่องต้นไม้ระหว่างทาง',
          maxLength: _limit('bio', 300),
          maxLines: 4,
        ),
        const SizedBox(height: 14),
        const _Heading('ป่าที่เคยเดิน'),
        const SizedBox(height: 4),
        Text(
          'ทริปที่เคยดูแลกับเรา ระบบใส่ให้เองอัตโนมัติ ตรงนี้เพิ่มที่เคยไปเองได้',
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w500,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 8),
        _ChipListEditor(
          items: _trails,
          hint: 'พิมพ์ชื่อป่า/ยอดเขา',
          max: _limit('trails', 12),
          maxLength: _limit('item', 40),
          suggestions: _trailSuggestions,
          onChanged: (v) => setState(() => _trails = v),
        ),
        const SizedBox(height: 18),
        const _Heading('ความถนัด / ใบรับรอง'),
        const SizedBox(height: 8),
        _ChipListEditor(
          items: _skills,
          hint: 'เช่น ปฐมพยาบาลเบื้องต้น',
          max: _limit('skills', 8),
          maxLength: _limit('item', 40),
          suggestions: _skillSuggestions,
          onChanged: (v) => setState(() => _skills = v),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.call_outlined,
                size: 18,
                color: AppTheme.mutedText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phone.isNotEmpty
                      ? 'ลูกทริปจะเห็นเบอร์ $phone และกดโทรได้จากการ์ดจนจบทริป '
                            'เปลี่ยนเบอร์ได้ที่ "ข้อมูลส่วนตัว" ในหน้าโปรไฟล์'
                      : 'ยังไม่มีเบอร์โทรในบัญชี การ์ดจะไม่มีปุ่มโทร '
                            'เพิ่มเบอร์ได้ที่ "ข้อมูลส่วนตัว" ในหน้าโปรไฟล์',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText(context),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: 1,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.done,
      style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: appFont(
          fontSize: AppText.sizeLabel,
          color: AppTheme.mutedText(context),
        ),
        isDense: true,
      ),
    );
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: AppText.sizeLabel,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}

/// รายการชิปที่พิมพ์เพิ่ม/กดลบได้ + ชิปแนะนำให้แตะเพิ่ม
class _ChipListEditor extends StatefulWidget {
  final List<String> items;
  final String hint;
  final int max;
  final int maxLength;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  const _ChipListEditor({
    required this.items,
    required this.hint,
    required this.max,
    required this.maxLength,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  State<_ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<_ChipListEditor> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _full => widget.items.length >= widget.max;

  bool _has(String value) =>
      widget.items.any((e) => e.toLowerCase() == value.toLowerCase());

  void _add(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty || _has(value)) {
      _input.clear();
      return;
    }
    if (_full) {
      AppSnack.show(context, 'ใส่ได้สูงสุด ${widget.max} รายการ');
      return;
    }
    HapticFeedback.selectionClick();
    widget.onChanged([...widget.items, value]);
    _input.clear();
  }

  void _remove(String value) {
    HapticFeedback.selectionClick();
    widget.onChanged(widget.items.where((e) => e != value).toList());
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.suggestions.where((s) => !_has(s)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in widget.items)
                InputChip(
                  label: Text(
                    item,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  onDeleted: () => _remove(item),
                  deleteIconColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.08,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (!_full)
          TextField(
            controller: _input,
            maxLength: widget.maxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: _add,
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: appFont(
                fontSize: AppText.sizeLabel,
                color: AppTheme.mutedText(context),
              ),
              counterText: '',
              isDense: true,
              suffixIcon: IconButton(
                tooltip: 'เพิ่ม',
                onPressed: () => _add(_input.text),
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        if (!_full && suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(
                    '+ $s',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  onPressed: () => _add(s),
                  backgroundColor: AppTheme.surface(context),
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
