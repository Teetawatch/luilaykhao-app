import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../services/notification_navigator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/travel_widgets.dart';

/// หน้า "รับที่นั่งต่อ" — ปลายทางของลิงก์ส่งต่อที่นั่ง (https://luilaykhao.com/handover/TOKEN
/// หรือ luilaykhao://handover/TOKEN) คนรับกรอกข้อมูลของตัวเองแล้วรับที่นั่ง
///
/// กติกาทั้งหมดตรวจที่เซิร์ฟเวอร์ (ClaimSeatHandoverRequest) หน้านี้แสดงข้อความ
/// ผิดพลาดรายช่องตามที่เซิร์ฟเวอร์ตอบ จะได้ไม่ต้องลอกกติกามาไว้อีกที่
class HandoverClaimScreen extends StatefulWidget {
  final String token;

  const HandoverClaimScreen({super.key, required this.token});

  @override
  State<HandoverClaimScreen> createState() => _HandoverClaimScreenState();
}

class _HandoverClaimScreenState extends State<HandoverClaimScreen> {
  static const _textFields = [
    'name',
    'nickname',
    'id_card',
    'phone',
    'email',
    'allergies',
    'health_notes',
    'emergency_contact',
    'emergency_phone',
    'name_en',
    'passport_no',
    'nationality',
  ];

  final Map<String, TextEditingController> _c = {
    for (final f in _textFields) f: TextEditingController(),
  };

  Map<String, dynamic>? _preview;
  bool _loading = true;
  String? _loadError;
  bool _submitting = false;
  String? _formError;
  Map<String, String> _errors = {};

  String _title = '';
  String _bloodGroup = '';
  bool? _halal;
  DateTime? _birthDate;
  DateTime? _passportExpiry;
  bool _foreigner = false;
  bool _acceptTerms = false;

  bool get _isInternational =>
      asMap(_preview?['trip'])['is_international'] == true;
  bool get _womenOnly => asMap(_preview?['trip'])['is_women_only'] == true;
  List<String> get _titles =>
      _womenOnly ? const ['นาง', 'นางสาว'] : const ['นาย', 'นาง', 'นางสาว'];

  @override
  void initState() {
    super.initState();
    _load(prefill: true);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool prefill = false}) async {
    try {
      final data = await context.read<AppProvider>().previewSeatHandover(
        widget.token,
      );
      if (!mounted) return;
      setState(() {
        _preview = data;
        _loadError = null;
        _loading = false;
        if (prefill) _fillFrom(asMap(data['prefill']));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = _cleanError(e);
        _loading = false;
      });
    }
  }

  void _fillFrom(Map<String, dynamic> p) {
    for (final f in _textFields) {
      final v = textOf(p[f]);
      if (v.isNotEmpty) _c[f]!.text = v;
    }
    final title = textOf(p['title']);
    _title = _titles.contains(title) ? title : '';
    final blood = textOf(p['blood_group']);
    _bloodGroup = const ['A', 'B', 'O', 'AB'].contains(blood) ? blood : '';
    _birthDate = DateTime.tryParse(textOf(p['birth_date']));
    _passportExpiry = DateTime.tryParse(textOf(p['passport_expires_at']));
    final nationality = textOf(p['nationality'], 'TH');
    _foreigner = _isInternational && nationality != 'TH';
    if (!_foreigner) _c['nationality']!.text = 'TH';
  }

  String _cleanError(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() {
      _errors = {};
      _formError = null;
    });
    if (_halal == null) {
      setState(
        () => _errors = {'halal_food': 'กรุณาระบุว่าทานอาหารฮาลาลหรือไม่'},
      );
      return;
    }

    final payload = <String, dynamic>{
      'title': _title,
      for (final f in _textFields) f: _c[f]!.text.trim(),
      'nationality': _foreigner
          ? _c['nationality']!.text.trim().toUpperCase()
          : 'TH',
      'blood_group': _bloodGroup,
      'halal_food': _halal,
      'birth_date': _birthDate == null ? null : _date(_birthDate!),
      'accept_terms': _acceptTerms,
      'terms_version': textOf(asMap(_preview?['terms'])['version']),
    };
    if (_isInternational) {
      payload['passport_expires_at'] = _passportExpiry == null
          ? null
          : _date(_passportExpiry!);
    } else {
      payload
        ..remove('name_en')
        ..remove('passport_no');
    }
    if (_foreigner) payload.remove('id_card');

    setState(() => _submitting = true);
    try {
      final data = await context.read<AppProvider>().claimSeatHandover(
        widget.token,
        payload,
      );
      if (!mounted) return;
      AppSnack.success(
        context,
        'รับที่นั่ง "${textOf(data['trip_title'], 'ทริป')}" เรียบร้อย ยินดีต้อนรับครับ',
      );
      Navigator.of(context).pop(true);
      NotificationNavigator.goToBookings();
    } on ApiException catch (e) {
      if (!mounted) return;
      final raw = e.errors;
      if (raw is Map && raw.isNotEmpty) {
        setState(() {
          _errors = {
            for (final entry in raw.entries)
              '${entry.key}':
                  entry.value is List && (entry.value as List).isNotEmpty
                  ? '${(entry.value as List).first}'
                  : '${entry.value}',
          };
          _formError = 'กรุณาตรวจสอบข้อมูลที่ไฮไลต์ไว้';
        });
      } else {
        setState(() => _formError = e.message);
        // สถานะลิงก์อาจเปลี่ยนแล้ว (มีคนรับก่อน/ถูกยกเลิก) — โหลดใหม่ให้เห็นความจริง
        if (e.statusCode == 422 || e.statusCode == 404) await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _formError = _cleanError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required DateTime first,
    required DateTime last,
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: const Text('รับที่นั่งต่อ'),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  if (_loadError != null)
                    _Notice(
                      color: AppTheme.dangerColor,
                      icon: Icons.link_off_rounded,
                      text: _loadError!,
                    )
                  else if (preview != null) ...[
                    _TripCard(preview: preview),
                    const SizedBox(height: 16),
                    if (preview['claimable'] != true) ...[
                      _Notice(
                        color: AppTheme.warningColor,
                        icon: Icons.info_outline_rounded,
                        text: textOf(preview['blocked_reason']),
                      ),
                      if (preview['claimed_by_viewer'] == true) ...[
                        const SizedBox(height: 12),
                        PrimaryCTAButton(
                          label: 'ไปที่การจองของฉัน',
                          icon: Icons.confirmation_number_rounded,
                          onPressed: () {
                            Navigator.of(context).pop();
                            NotificationNavigator.goToBookings();
                          },
                        ),
                      ],
                    ] else
                      ..._form(context),
                  ],
                ],
              ),
      ),
    );
  }

  List<Widget> _form(BuildContext context) {
    final now = DateTime.now();
    return [
      Text(
        'ข้อมูลของคุณ',
        style: appFont(
          fontSize: AppText.sizeTitle,
          fontWeight: FontWeight.w900,
          color: AppTheme.onSurface(context),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'ใช้ทำประกันการเดินทางและให้ทีมงานติดต่อ — กรอกตามบัตรประชาชน',
        style: appFont(
          fontSize: AppText.sizeCaption,
          color: AppTheme.mutedText(context),
        ),
      ),
      const SizedBox(height: 14),
      if (_isInternational) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _foreigner,
          activeThumbColor: AppTheme.primaryColor,
          onChanged: (v) => setState(() {
            _foreigner = v;
            _c['nationality']!.text = v ? '' : 'TH';
          }),
          title: Text(
            'ไม่ได้ถือสัญชาติไทย',
            style: appFont(fontWeight: FontWeight.w700),
          ),
        ),
        if (_foreigner)
          _field('nationality', 'รหัสประเทศ 2 ตัวอักษร (เช่น US, JP)'),
      ],
      _dropdown(
        label: 'คำนำหน้า',
        value: _title,
        items: _titles,
        error: _errors['title'],
        onChanged: (v) => setState(() => _title = v),
      ),
      _field(
        'name',
        _foreigner ? 'ชื่อ-นามสกุล' : 'ชื่อ-นามสกุล (ภาษาไทยตามบัตร)',
      ),
      _field('nickname', 'ชื่อเล่น'),
      if (!_foreigner)
        _field(
          'id_card',
          'เลขบัตรประชาชน 13 หลัก',
          keyboard: TextInputType.number,
        ),
      if (_isInternational) ...[
        _field('name_en', 'ชื่อ-สกุลภาษาอังกฤษ (ตามพาสปอร์ต)'),
        _field('passport_no', 'เลขที่พาสปอร์ต'),
        _dateField(
          label: 'วันหมดอายุพาสปอร์ต',
          value: _passportExpiry,
          error: _errors['passport_expires_at'],
          onTap: () => _pickDate(
            current: _passportExpiry,
            first: now,
            last: DateTime(now.year + 20),
            initial: DateTime(now.year + 1, now.month, now.day),
            onPicked: (d) => _passportExpiry = d,
          ),
        ),
      ],
      _dateField(
        label: 'วันเกิด',
        value: _birthDate,
        error: _errors['birth_date'],
        onTap: () => _pickDate(
          current: _birthDate,
          first: DateTime(1920),
          last: now.subtract(const Duration(days: 1)),
          initial: DateTime(now.year - 25),
          onPicked: (d) => _birthDate = d,
        ),
      ),
      _dropdown(
        label: 'กรุ๊ปเลือด',
        value: _bloodGroup,
        items: const ['A', 'B', 'O', 'AB'],
        error: _errors['blood_group'],
        onChanged: (v) => setState(() => _bloodGroup = v),
      ),
      _field('phone', 'เบอร์โทร', keyboard: TextInputType.phone),
      _field(
        'email',
        'อีเมล (ไม่บังคับ)',
        keyboard: TextInputType.emailAddress,
      ),
      _field('emergency_contact', 'ผู้ติดต่อฉุกเฉิน (ชื่อ / ความสัมพันธ์)'),
      _field(
        'emergency_phone',
        'เบอร์ผู้ติดต่อฉุกเฉิน',
        keyboard: TextInputType.phone,
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'อาหารฮาลาล',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('ไม่ต้องการ'),
                  selected: _halal == false,
                  onSelected: (_) => setState(() => _halal = false),
                ),
                ChoiceChip(
                  label: const Text('ต้องการ'),
                  selected: _halal == true,
                  onSelected: (_) => setState(() => _halal = true),
                ),
              ],
            ),
            if (_errors['halal_food'] != null)
              _errorText(_errors['halal_food']!),
          ],
        ),
      ),
      _field('allergies', 'แพ้อาหาร/ยา (ไม่บังคับ)'),
      _field(
        'health_notes',
        'โรคประจำตัว / ข้อมูลสุขภาพ (ไม่บังคับ)',
        maxLines: 3,
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppTheme.primaryColor,
        value: _acceptTerms,
        onChanged: (v) => setState(() => _acceptTerms = v ?? false),
        title: Text(
          'ฉันอ่านและยอมรับเงื่อนไขการเดินทางของลุยเลเขา',
          style: appFont(fontSize: AppText.sizeLabel, height: 1.4),
        ),
        subtitle: Text(
          textOf(asMap(_preview?['terms'])['url']),
          style: appFont(
            fontSize: AppText.sizeMicro,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
      if (_errors['accept_terms'] != null) _errorText(_errors['accept_terms']!),
      if (_errors['terms_version'] != null)
        _errorText(_errors['terms_version']!),
      if (_formError != null) ...[
        const SizedBox(height: 8),
        _Notice(
          color: AppTheme.dangerColor,
          icon: Icons.error_outline_rounded,
          text: _formError!,
        ),
      ],
      const SizedBox(height: 16),
      PrimaryCTAButton(
        label: _submitting ? 'กำลังรับที่นั่ง...' : 'รับที่นั่งนี้',
        icon: Icons.how_to_reg_rounded,
        loading: _submitting,
        onPressed: _acceptTerms && !_submitting ? _submit : null,
      ),
    ];
  }

  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: appFont(
        fontSize: AppText.sizeCaption,
        color: AppTheme.dangerColor,
      ),
    ),
  );

  InputDecoration _decoration(String label, String? error) => InputDecoration(
    labelText: label,
    errorText: error,
    errorMaxLines: 3,
    filled: true,
    fillColor: AppTheme.fieldSurface(context),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      borderSide: BorderSide.none,
    ),
  );

  Widget _field(
    String key,
    String label, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[key],
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: _decoration(label, _errors[key]),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required String? error,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        items: [
          for (final item in items)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (v) => onChanged(v ?? ''),
        decoration: _decoration(label, error),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required String? error,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InputDecorator(
          decoration: _decoration(label, error).copyWith(
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          ),
          child: Text(
            value == null
                ? 'แตะเพื่อเลือก'
                : '${value.day}/${value.month}/${value.year + 543}',
            style: appFont(fontSize: AppText.sizeBody),
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> preview;

  const _TripCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final trip = asMap(preview['trip']);
    final schedule = asMap(preview['schedule']);
    final pickup = asMap(preview['pickup']);
    final cover = textOf(trip['cover_image']);
    final note = textOf(preview['note']);
    final seat = textOf(preview['seat_label']);
    final early = textOf(schedule['early_departure_label']);
    final share = double.tryParse(textOf(preview['pending_share_amount']));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cover.isNotEmpty)
            CachedNetworkImage(
              imageUrl: cover,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              memCacheWidth: 900,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${textOf(preview['from_name'], 'เพื่อนของคุณ')} ส่งที่นั่งให้คุณ',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  textOf(trip['title'], 'ทริป'),
                  style: appFont(
                    fontSize: AppText.sizeTitle,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                _Row(
                  icon: Icons.event_rounded,
                  text: textOf(schedule['departure_label']),
                ),
                if (early.isNotEmpty)
                  _Row(icon: Icons.nightlight_round, text: early),
                if (seat.isNotEmpty)
                  _Row(icon: Icons.event_seat_rounded, text: 'ที่นั่ง $seat'),
                if (pickup.isNotEmpty)
                  _Row(
                    icon: Icons.location_on_rounded,
                    text:
                        'ขึ้นรถที่ ${textOf(pickup['label'])}${textOf(pickup['time']).isNotEmpty ? ' · ${textOf(pickup['time'])} น.' : ''}',
                  ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '“$note”',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ],
                if (preview['transfers_ownership'] == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'คุณจะได้ดูแลการจองนี้แทนคนเดิมด้วย (แชท วันเดินทาง และเรื่องการจองทั้งหมด)',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ],
                if (share != null && share > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'ที่นั่งนี้ยังมีส่วนแบ่งค่าทริปค้างจ่าย ฿${share.toStringAsFixed(0)} รับแล้วจะเป็นส่วนของคุณ',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'ค่าที่นั่งตกลงกันเองกับคนที่ส่งให้คุณ ทางเราไม่เก็บเงินเพิ่มจากการรับที่นั่ง',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                color: AppTheme.onSurface(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Notice({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: appFont(
                fontSize: AppText.sizeLabel,
                color: AppTheme.onSurface(context),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
