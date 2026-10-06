import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/app_snack.dart';
import '../widgets/gift_voucher_card.dart' show voucherBaht;
import '../widgets/travel_widgets.dart';
import 'customer_app_screen.dart' show BookingDetailSheet;
import 'payment_screen.dart';

/// ป้ายสถานะคำขอเหมาทริป (ต้องตรงกับ CharterRequest::STATUS_* ฝั่งหลังบ้าน)
String charterStatusLabel(String status) => switch (status) {
  'new' => 'รอทีมงานเสนอราคา',
  'quoted' => 'ได้ใบเสนอราคาแล้ว',
  'accepted' => 'ตอบรับแล้ว รอเปิดการจอง',
  'declined' => 'ปฏิเสธใบเสนอราคา',
  'rejected' => 'ทีมงานรับไม่ได้',
  'cancelled' => 'ยกเลิกแล้ว',
  'booked' => 'เปิดการจองแล้ว',
  _ => status,
};

Color charterStatusColor(String status) => switch (status) {
  'quoted' => AppTheme.infoColor,
  'accepted' => AppTheme.warningColor,
  'booked' => AppTheme.primaryColor,
  'declined' || 'rejected' || 'cancelled' => AppTheme.errorColor,
  _ => AppTheme.warningColor,
};

const Map<String, String> _groupTypes = {
  'friends': 'กลุ่มเพื่อน',
  'family': 'ครอบครัว',
  'company': 'บริษัท / องค์กร',
  'school': 'โรงเรียน / มหาวิทยาลัย',
  'other': 'อื่น ๆ',
};

String _dateText(dynamic raw) {
  final date = DateTime.tryParse('${raw ?? ''}');
  return date == null ? '-' : thaiDateShort(date);
}

int? _id(dynamic raw) => int.tryParse('${raw ?? ''}');

// ─────────────────────────────────────────────────────────────────────────────
// รายการคำขอ
// ─────────────────────────────────────────────────────────────────────────────

/// "เหมาทริป / ทริปส่วนตัว" — รายการคำขอของฉัน + ปุ่มขอใหม่
class CharterRequestsScreen extends StatefulWidget {
  const CharterRequestsScreen({super.key});

  @override
  State<CharterRequestsScreen> createState() => _CharterRequestsScreenState();
}

class _CharterRequestsScreenState extends State<CharterRequestsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<AppProvider>().charterRequests();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'โหลดคำขอไม่สำเร็จ กรุณาลองใหม่';
        });
      }
    }
  }

  Future<void> _create() async {
    HapticFeedback.selectionClick();
    final created = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const CharterRequestFormScreen()),
    );
    if (!mounted) return;
    await _load();
    if (created != null && _id(created['id']) != null) {
      _openDetail(_id(created['id'])!);
    }
  }

  Future<void> _openDetail(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CharterRequestDetailScreen(requestId: id),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const TravelSliverAppBar(title: 'เหมาทริป / ทริปส่วนตัว'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HowItWorks(),
                    const SizedBox(height: 14),
                    PrimaryCTAButton(
                      label: 'ขอเหมาทริป',
                      icon: Icons.add_rounded,
                      onPressed: _create,
                    ),
                    const SizedBox(height: 26),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else if (_error != null) ...[
                      EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'โหลดคำขอไม่สำเร็จ',
                        body: _error!,
                      ),
                      Center(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load();
                          },
                          child: const Text('ลองอีกครั้ง'),
                        ),
                      ),
                    ] else if (_items.isEmpty)
                      const EmptyState(
                        icon: Icons.groups_rounded,
                        title: 'ยังไม่มีคำขอ',
                        body:
                            'ไปเป็นกลุ่มตั้งแต่ 4 คน เลือกวันเองได้ ทีมงานจัดรถ ที่พัก และไกด์ให้ทั้งกลุ่ม',
                      )
                    else
                      for (final item in _items) ...[
                        _RequestCard(
                          item: item,
                          onTap: () {
                            final id = _id(item['id']);
                            if (id != null) _openDetail(id);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.edit_note_rounded, 'บอกเราว่าอยากไปไหน กี่คน วันไหน'),
      (
        Icons.request_quote_rounded,
        'ทีมงานส่งใบเสนอราคามาในแอป ภายใน 1–2 วันทำการ',
      ),
      (
        Icons.check_circle_rounded,
        'ตอบรับแล้วทีมงานเปิดรอบเฉพาะกลุ่มคุณ ชำระเงินในแอปได้เลย',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ไปกันเองทั้งกลุ่ม ไม่ต้องรอใคร',
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 10),
          for (final (icon, text) in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        height: 1.5,
                        color: AppTheme.mutedText(context),
                      ),
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

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _RequestCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = '${item['status'] ?? ''}';
    final color = charterStatusColor(status);
    final quote = item['quote'] is Map ? item['quote'] as Map : null;

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['destination_label'] ?? 'ทริปส่วนตัว'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item['group_size']} คน · อยากไป ${_dateText(item['preferred_date'])} · ${item['ref']}',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.tintOf(context, color),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      charterStatusLabel(status),
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onTintOf(context, color),
                      ),
                    ),
                  ),
                  if (quote != null && quote['total'] != null)
                    Text(
                      'รวม ${voucherBaht(quote['total'])}',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ฟอร์มขอเหมาทริป
// ─────────────────────────────────────────────────────────────────────────────

/// ฟอร์มขอเหมาทริป — เปิดจากหน้าทริป (ส่ง [trip] มา) หรือจากเมนูโปรไฟล์ (บอกปลายทางเอง)
class CharterRequestFormScreen extends StatefulWidget {
  final Map<String, dynamic>? trip;

  const CharterRequestFormScreen({super.key, this.trip});

  @override
  State<CharterRequestFormScreen> createState() =>
      _CharterRequestFormScreenState();
}

class _CharterRequestFormScreenState extends State<CharterRequestFormScreen> {
  static const _minGroup = 4;
  static const _maxGroup = 300;

  final _formKey = GlobalKey<FormState>();
  final _destination = TextEditingController();
  final _groupSize = TextEditingController(text: '10');
  final _days = TextEditingController();
  final _pickup = TextEditingController();
  final _budget = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line = TextEditingController();
  final _note = TextEditingController();

  DateTime? _preferred;
  DateTime? _alternate;
  bool _flexible = false;
  bool _taxInvoice = false;
  String _groupType = 'friends';
  bool _submitting = false;
  String? _dateError;

  int? get _tripId => _id(widget.trip?['id']);

  @override
  void initState() {
    super.initState();
    final user = context.read<AppProvider>().user;
    _name.text = '${user?['name'] ?? ''}'.trim();
    _phone.text = '${user?['phone'] ?? ''}'.trim();
  }

  @override
  void dispose() {
    for (final c in [
      _destination,
      _groupSize,
      _days,
      _pickup,
      _budget,
      _name,
      _phone,
      _line,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return showDatePicker(
      context: context,
      initialDate: initial ?? tomorrow.add(const Duration(days: 29)),
      firstDate: tomorrow,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'เลือกวันเดินทาง',
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_submitting) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(
      () => _dateError = _preferred == null ? 'กรุณาเลือกวันที่อยากไป' : null,
    );
    if (!formValid || _preferred == null) return;

    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      final result = await context.read<AppProvider>().createCharterRequest({
        'trip_id': ?_tripId,
        if (_tripId == null) 'destination': _destination.text.trim(),
        'preferred_date': _iso(_preferred!),
        if (_alternate != null) 'alternate_date': _iso(_alternate!),
        'flexible_dates': _flexible,
        if (_tripId == null && _days.text.trim().isNotEmpty)
          'duration_days': int.parse(_days.text.trim()),
        'group_size': int.parse(_groupSize.text.trim()),
        if (_pickup.text.trim().isNotEmpty) 'pickup_area': _pickup.text.trim(),
        if (_budget.text.trim().isNotEmpty)
          'budget_per_person': int.parse(_budget.text.trim()),
        'group_type': _groupType,
        'needs_tax_invoice': _taxInvoice,
        'contact_name': _name.text.trim(),
        'contact_phone': _phone.text.trim(),
        if (_line.text.trim().isNotEmpty) 'contact_line': _line.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      AppSnack.success(
        context,
        result.message.isNotEmpty ? result.message : 'ส่งคำขอแล้ว',
      );
      Navigator.pop(context, result.request);
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'ส่งคำขอไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripTitle = '${widget.trip?['title'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(title: const Text('ขอเหมาทริป')),
      body: SafeArea(
        top: false,
        // SingleChildScrollView ไม่ใช่ ListView — ช่องที่เลื่อนพ้นจอจะยังถูก validate
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('อยากไปไหน'),
                const SizedBox(height: 8),
                if (_tripId != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.selectedTint(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.terrain_rounded,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tripTitle.isEmpty ? 'ทริปนี้' : tripTitle,
                            style: appFont(
                              fontSize: AppText.sizeBody,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  TextFormField(
                    controller: _destination,
                    maxLength: 150,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'ปลายทาง / ทริปที่อยากไป',
                      hintText: 'เช่น ดอยอินทนนท์ เดินป่า 2 วัน',
                      counterText: '',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'บอกเราหน่อยว่าอยากไปไหน'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _days,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'จำนวนวัน (ไม่บังคับ)',
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return null;
                      final n = int.tryParse(v!.trim()) ?? 0;
                      return n < 1 || n > 30 ? 'ระบุ 1–30 วัน' : null;
                    },
                  ),
                ],
                const SizedBox(height: 20),
                _label('วันเดินทาง'),
                const SizedBox(height: 8),
                _DateField(
                  label: 'วันที่อยากไป',
                  value: _preferred,
                  error: _dateError,
                  onTap: () async {
                    final picked = await _pickDate(_preferred);
                    if (picked != null) {
                      setState(() {
                        _preferred = picked;
                        _dateError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                _DateField(
                  label: 'วันสำรอง (ไม่บังคับ)',
                  value: _alternate,
                  onTap: () async {
                    final picked = await _pickDate(_alternate ?? _preferred);
                    if (picked != null) setState(() => _alternate = picked);
                  },
                  onClear: _alternate == null
                      ? null
                      : () => setState(() => _alternate = null),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _flexible,
                  onChanged: (v) => setState(() => _flexible = v),
                  title: const Text('เลื่อนวันได้ ถ้าทีมงานมีวันที่ดีกว่า'),
                ),
                const SizedBox(height: 12),
                _label('กลุ่มของคุณ'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _groupSize,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'จำนวนคน'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'กรุณาระบุจำนวนคน';
                    if (n < _minGroup) {
                      return 'เหมาทริปรับกลุ่มตั้งแต่ $_minGroup คนขึ้นไป (กลุ่มเล็กกว่านี้จองรอบปกติได้เลย)';
                    }
                    if (n > _maxGroup) {
                      return 'กลุ่มใหญ่กว่า $_maxGroup คน ทักทีมงานโดยตรงได้เลย';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _groupTypes.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _groupType == entry.key,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _groupType = entry.key);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pickup,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'จุดรับที่สะดวก (ไม่บังคับ)',
                    hintText: 'เช่น สีลม กรุงเทพฯ',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'งบประมาณต่อคน (บาท, ไม่บังคับ)',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _taxInvoice,
                  onChanged: (v) => setState(() => _taxInvoice = v),
                  title: const Text('ต้องการใบกำกับภาษี (ในนามบริษัท)'),
                ),
                const SizedBox(height: 12),
                _label('ติดต่อกลับ'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  maxLength: 150,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อผู้ติดต่อ',
                    counterText: '',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'กรุณาระบุชื่อผู้ติดต่อ'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'เบอร์โทร'),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length < 9
                        ? 'กรุณาระบุเบอร์โทรที่ติดต่อได้'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _line,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'LINE ID (ไม่บังคับ)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLength: 1000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'อยากให้ทีมงานรู้อะไรเพิ่ม (ไม่บังคับ)',
                    hintText: 'เช่น มีผู้สูงอายุ อยากได้ที่พักแบบบ้านทั้งหลัง',
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryCTAButton(
                  label: 'ส่งคำขอ',
                  icon: Icons.send_rounded,
                  loading: _submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 10),
                Text(
                  'ยังไม่มีค่าใช้จ่ายตอนนี้ — ทีมงานส่งใบเสนอราคามาให้ดูก่อน ตอบรับแล้วจึงชำระเงิน',
                  textAlign: TextAlign.center,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: appFont(
      fontSize: AppText.sizeBody,
      fontWeight: FontWeight.w800,
      color: AppTheme.onSurface(context),
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String? error;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.error,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: onClear != null
              ? IconButton(
                  tooltip: 'ล้างวัน',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_month_rounded),
        ),
        child: Text(
          value == null ? 'เลือกวัน' : thaiDateFull(value!),
          style: appFont(
            fontSize: AppText.sizeBody,
            color: value == null
                ? AppTheme.mutedText(context)
                : AppTheme.onSurface(context),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// รายละเอียดคำขอ + ใบเสนอราคา
// ─────────────────────────────────────────────────────────────────────────────

class CharterRequestDetailScreen extends StatefulWidget {
  final int requestId;

  const CharterRequestDetailScreen({super.key, required this.requestId});

  @override
  State<CharterRequestDetailScreen> createState() =>
      _CharterRequestDetailScreenState();
}

class _CharterRequestDetailScreenState
    extends State<CharterRequestDetailScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().charterRequest(
        widget.requestId,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดคำขอไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  Future<void> _respond(String action, {String? reason}) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final data = await context.read<AppProvider>().respondCharterRequest(
        widget.requestId,
        action,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _data = data);
      AppSnack.success(context, switch (action) {
        'accept' => 'ตอบรับแล้ว ทีมงานจะเปิดการจองให้เร็ว ๆ นี้',
        'decline' => 'แจ้งทีมงานแล้ว',
        _ => 'ยกเลิกคำขอแล้ว',
      });
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
      await _load();
    } catch (_) {
      if (mounted) AppSnack.error(context, 'ทำรายการไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Map quote) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ตอบรับใบเสนอราคา?'),
        content: Text(
          '${quote['group_size']} คน · รวม ${voucherBaht(quote['total'])}\n'
          'ทีมงานจะเปิดรอบเดินทางของกลุ่มและส่งการจองให้ชำระเงินในแอป',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยังก่อน'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ตอบรับ'),
          ),
        ],
      ),
    );
    if (ok == true) await _respond('accept');
  }

  Future<void> _decline() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ไม่ตกลงใบเสนอราคานี้?'),
        content: TextField(
          controller: controller,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'บอกเหตุผลให้ทีมงานปรับให้ เช่น งบเกิน อยากเปลี่ยนวัน',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('ไม่ตกลง'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null) await _respond('decline', reason: reason);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกคำขอนี้?'),
        content: const Text('ยกเลิกแล้วส่งคำขอใหม่ได้เสมอ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ใช่ตอนนี้'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('ยกเลิกคำขอ'),
          ),
        ],
      ),
    );
    if (ok == true) await _respond('cancel');
  }

  void _openBooking(String ref, String status) {
    if (status == 'pending') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaymentScreen(bookingRef: ref)),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingDetailSheet(bookingRef: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(data == null ? 'คำขอเหมาทริป' : '${data['ref']}'),
      ),
      body: data == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('ลองอีกครั้ง'),
                          ),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryColor,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: _content(context, data),
              ),
            ),
    );
  }

  List<Widget> _content(BuildContext context, Map<String, dynamic> data) {
    final status = '${data['status'] ?? ''}';
    final quote = data['quote'] is Map ? data['quote'] as Map : null;
    final bookingRef = '${data['booking_ref'] ?? ''}';
    final bookingStatus = '${data['booking_status'] ?? ''}';
    final color = charterStatusColor(status);

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.tintOf(context, color),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Text(
          switch (status) {
            'new' => 'ได้รับคำขอแล้ว ทีมงานจะส่งใบเสนอราคามาภายใน 1–2 วันทำการ',
            'quoted' =>
              quote?['expired'] == true
                  ? 'ใบเสนอราคาหมดอายุแล้ว ทักทีมงานเพื่อขอใบใหม่ได้เลย'
                  : 'ใบเสนอราคามาแล้ว ดูรายละเอียดด้านล่างแล้วตอบรับได้เลย',
            'accepted' =>
              'ตอบรับแล้ว ทีมงานกำลังเปิดรอบเดินทางของกลุ่ม จะแจ้งเตือนเมื่อพร้อมชำระเงิน',
            'declined' =>
              'แจ้งทีมงานแล้ว ถ้ามีใบเสนอราคาใหม่จะแจ้งเตือนให้ทันที',
            'rejected' =>
              'ทีมงานรับคำขอนี้ไม่ได้${(data['reject_reason'] ?? '').toString().isNotEmpty ? ': ${data['reject_reason']}' : ''}',
            'cancelled' => 'คุณยกเลิกคำขอนี้แล้ว',
            'booked' => 'การจองของกลุ่มพร้อมแล้ว',
            _ => charterStatusLabel(status),
          },
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
            height: 1.5,
            color: AppTheme.onTintOf(context, color),
          ),
        ),
      ),
      if (status == 'booked' && bookingRef.isNotEmpty) ...[
        const SizedBox(height: 14),
        PrimaryCTAButton(
          label: bookingStatus == 'pending'
              ? 'ชำระเงิน $bookingRef'
              : 'ดูการจอง $bookingRef',
          icon: bookingStatus == 'pending'
              ? Icons.qr_code_2_rounded
              : Icons.confirmation_number_rounded,
          onPressed: () => _openBooking(bookingRef, bookingStatus),
        ),
      ],
      if (quote != null) ...[
        const SizedBox(height: 18),
        _QuoteCard(quote: quote, active: status == 'quoted'),
        if (data['can_accept'] == true) ...[
          const SizedBox(height: 14),
          PrimaryCTAButton(
            label: 'ตอบรับใบเสนอราคา',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: () => _accept(quote),
          ),
        ],
        if (data['can_decline'] == true) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _decline,
            child: const Text('ไม่ตกลง / ขอปรับใบเสนอราคา'),
          ),
        ],
      ],
      const SizedBox(height: 18),
      _RequestSummary(data: data),
      if (data['can_cancel'] == true) ...[
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : _cancel,
          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          child: const Text('ยกเลิกคำขอ'),
        ),
      ],
    ];
  }
}

class _QuoteCard extends StatelessWidget {
  final Map quote;
  final bool active;

  const _QuoteCard({required this.quote, required this.active});

  @override
  Widget build(BuildContext context) {
    final trip = quote['trip'] is Map ? quote['trip'] as Map : const {};
    final includes = '${quote['includes'] ?? ''}'.trim();
    final note = '${quote['note'] ?? ''}'.trim();
    final expired = quote['expired'] == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ใบเสนอราคา',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${trip['title'] ?? 'ทริปส่วนตัว'}',
            style: appFont(
              fontSize: AppText.sizeTitle,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_dateText(quote['departure_date'])}'
            '${quote['return_date'] != quote['departure_date'] ? ' – ${_dateText(quote['return_date'])}' : ''}'
            ' · ${quote['group_size']} คน',
            style: appFont(
              fontSize: AppText.sizeBody,
              color: AppTheme.mutedText(context),
            ),
          ),
          const Divider(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'ท่านละ ${voucherBaht(quote['price_per_person'])}',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
              Text(
                voucherBaht(quote['total']),
                style: appFont(
                  fontSize: AppText.sizeH2,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'รวมทั้งกลุ่ม',
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
          if (includes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'ราคานี้รวม',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 4),
            for (final line
                in includes.split('\n').where((l) => l.trim().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        line.trim(),
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              note,
              style: appFont(
                fontSize: AppText.sizeLabel,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
          if (active && quote['valid_until'] != null) ...[
            const SizedBox(height: 12),
            Text(
              expired
                  ? 'หมดอายุเมื่อ ${_dateText(quote['valid_until'])}'
                  : 'ตอบรับได้ถึง ${_dateText(quote['valid_until'])}',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: expired ? AppTheme.errorColor : AppTheme.warningColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestSummary extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RequestSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('ปลายทาง', '${data['destination_label'] ?? '-'}'),
      (
        'วันที่อยากไป',
        '${_dateText(data['preferred_date'])}'
            '${data['alternate_date'] != null ? ' (สำรอง ${_dateText(data['alternate_date'])})' : ''}'
            '${data['flexible_dates'] == true ? ' · ยืดหยุ่น' : ''}',
      ),
      ('จำนวน', '${data['group_size']} คน · ${data['group_type_label'] ?? ''}'),
      if ('${data['pickup_area'] ?? ''}'.isNotEmpty)
        ('จุดรับ', '${data['pickup_area']}'),
      if (data['budget_per_person'] != null)
        ('งบต่อคน', voucherBaht(data['budget_per_person'])),
      if (data['needs_tax_invoice'] == true) ('ใบกำกับภาษี', 'ต้องการ'),
      ('ผู้ติดต่อ', '${data['contact_name']} · ${data['contact_phone']}'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คำขอของคุณ',
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      label,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if ('${data['note'] ?? ''}'.trim().isNotEmpty)
            Text(
              '"${data['note']}"',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontStyle: FontStyle.italic,
                color: AppTheme.mutedText(context),
              ),
            ),
        ],
      ),
    );
  }
}
