import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/skeleton.dart';
import '../widgets/travel_widgets.dart';

/// เอกสารเดินทาง (พาสปอร์ต) ของทริปต่างประเทศ — กรอก/แก้หลังจองแล้ว
///
/// ทริปต่างประเทศบังคับพาสปอร์ตตอนจอง แต่ลูกค้าที่ใช้แอปรุ่นก่อนหน้า (ซึ่งยังไม่มี
/// ช่องกรอก) จองผ่านไปได้โดยยังไม่มีเอกสาร ก่อนหน้านี้เขามีทางเดียวคือลิงก์ในอีเมล
/// — คนที่ไม่เคยเปิดอ่านจึงตกขบวน หน้านี้คือทางเดียวกันแต่อยู่ในแอปที่เขาเปิดทุกวัน
///
/// ใช้แก้ได้ด้วย ไม่ใช่แค่กรอกครั้งแรก เพราะพาสปอร์ตเล่มใหม่ระหว่างรอเดินทางเป็น
/// เรื่องปกติ และการจองที่กรอกครบแล้วก็ยังตกเกณฑ์ 6 เดือนได้เมื่อเวลาผ่านไป
class TravelDocumentsScreen extends StatefulWidget {
  final String bookingRef;

  const TravelDocumentsScreen({super.key, required this.bookingRef});

  @override
  State<TravelDocumentsScreen> createState() => _TravelDocumentsScreenState();
}

class _TravelDocumentsScreenState extends State<TravelDocumentsScreen> {
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> _data = const {};
  final Map<int, _PassengerFields> _fields = {};
  final Map<int, String> _serverErrors = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().travelDocuments(
        widget.bookingRef,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _syncFields(asList(data['passengers']));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// สร้าง/อัปเดต controller ให้ตรงกับผู้เดินทางที่ได้จากเซิร์ฟเวอร์
  void _syncFields(List<dynamic> passengers) {
    final seen = <int>{};
    for (final raw in passengers) {
      final passenger = asMap(raw);
      final id = int.tryParse(textOf(passenger['id'])) ?? 0;
      if (id == 0) continue;
      seen.add(id);
      final existing = _fields[id];
      if (existing == null) {
        _fields[id] = _PassengerFields.fromJson(passenger);
      } else {
        existing.adoptSaved(passenger);
      }
    }
    // ผู้เดินทางที่หายไปจาก payload (ถูกลบ) — ปล่อย controller ทิ้ง
    for (final id in _fields.keys.toList()) {
      if (!seen.contains(id)) {
        _fields.remove(id)?.dispose();
      }
    }
  }

  DateTime? get _minimumExpiry {
    final raw = textOf(asMap(_data['passport'])['minimum_expiry']);
    return raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  Future<void> _save() async {
    setState(() => _serverErrors.clear());

    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }

    final payload = _fields.entries
        .map(
          (entry) => <String, dynamic>{
            'id': entry.key,
            'name_en': entry.value.nameEn.text.trim(),
            'passport_no': entry.value.passportNo.text.trim(),
            'passport_expires_at': entry.value.expiresAt == null
                ? ''
                : _isoDate(entry.value.expiresAt!),
          },
        )
        .toList();

    setState(() => _saving = true);
    HapticFeedback.selectionClick();

    try {
      final data = await context.read<AppProvider>().saveTravelDocuments(
        widget.bookingRef,
        payload,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _syncFields(asList(data['passengers']));
      });
      HapticFeedback.mediumImpact();
      final stillMissing =
          (int.tryParse(
                textOf(asMap(data['passport'])['missing_count'], '0'),
              ) ??
              0) >
          0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stillMissing
                ? 'บันทึกแล้ว ยังเหลือผู้เดินทางที่ยังไม่ได้กรอกอยู่นะครับ'
                : 'บันทึกเอกสารเดินทางครบทุกท่านแล้ว ขอบคุณครับ',
            style: appFont(fontWeight: FontWeight.w700),
          ),
          backgroundColor: stillMissing
              ? AppTheme.warningColor
              : AppTheme.successColor,
        ),
      );
      if (!stillMissing) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // เซิร์ฟเวอร์ส่งข้อความรายคนมาด้วย ชี้ให้ตรงคนดีกว่าขึ้น toast รวม ๆ
      final errors = e.errors;
      if (errors is Map) {
        final byPassenger = asMap(errors['passengers']);
        setState(() {
          byPassenger.forEach((key, value) {
            final id = int.tryParse(key);
            if (id != null) _serverErrors[id] = value.toString();
          });
        });
      }
      if (_serverErrors.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passengers = asList(_data['passengers']).map(asMap).toList();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'เอกสารเดินทาง',
          style: AppTheme.appBarTitleStyle(context),
        ),
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
      ),
      body: _loading && passengers.isEmpty
          ? const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: SkeletonDetail(showHero: false),
            )
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _IntroCard(data: _data),
                  const SizedBox(height: 20),
                  ...passengers.map((passenger) {
                    final id = int.tryParse(textOf(passenger['id'])) ?? 0;
                    final fields = _fields[id];
                    if (fields == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PassengerCard(
                        passenger: passenger,
                        fields: fields,
                        minimumExpiry: _minimumExpiry,
                        serverError: _serverErrors[id],
                        onChanged: () => setState(() {}),
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'บันทึกเอกสารเดินทาง',
                            style: appFont(
                              color: Colors.white,
                              fontSize: AppText.sizeBody,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ท่านที่ยังไม่มีเล่มอยู่กับตัว เว้นว่างไว้ได้ครับ กลับมากรอกทีหลังได้ '
                    'ตราบใดที่ยังไม่ถึงวันเดินทาง',
                    textAlign: TextAlign.center,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// สรุปว่าทำไมต้องกรอก + เกณฑ์วันหมดอายุที่ยังใช้เดินทางรอบนี้ได้
class _IntroCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _IntroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final passport = asMap(data['passport']);
    final country = textOf(data['country']);
    final minimumExpiry = DateTime.tryParse(
      textOf(passport['minimum_expiry']),
    );
    final missing = int.tryParse(textOf(passport['missing_count'], '0')) ?? 0;
    final expiring = int.tryParse(textOf(passport['expiring_count'], '0')) ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(
        context,
        radius: AppTheme.radiusMd,
        color: AppTheme.warningTint(context),
        borderColor: AppTheme.warningColor.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flight_takeoff_rounded,
                size: 18,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  country.isEmpty
                      ? textOf(data['trip_title'], 'ทริปต่างประเทศ')
                      : '${textOf(data['trip_title'])} · $country',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ทริปนี้ออกนอกประเทศ เราต้องใช้ข้อมูลหน้าพาสปอร์ตของผู้เดินทางทุกท่าน '
            'เพื่อออกตั๋วเครื่องบินและยื่นเอกสารครับ กรอกให้ตรงกับหน้าพาสปอร์ตทุกตัวอักษร',
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.mutedText(context),
              height: 1.6,
            ),
          ),
          if (minimumExpiry != null) ...[
            const SizedBox(height: 10),
            _Rule(
              icon: Icons.event_available_rounded,
              text:
                  'พาสปอร์ตต้องหมดอายุหลัง ${thaiDateFull(minimumExpiry)} '
                  '(เหลืออายุอย่างน้อย 6 เดือนนับจากวันเดินทาง)',
            ),
          ],
          if (missing > 0) ...[
            const SizedBox(height: 6),
            _Rule(
              icon: Icons.person_off_rounded,
              text: 'ยังไม่ได้กรอก $missing ท่าน',
            ),
          ],
          if (expiring > 0) ...[
            const SizedBox(height: 6),
            _Rule(
              icon: Icons.warning_amber_rounded,
              text: 'เล่มใกล้หมดอายุเกินเกณฑ์ $expiring ท่าน ต้องต่อเล่มใหม่',
            ),
          ],
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Rule({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.warningColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PassengerCard extends StatelessWidget {
  final Map<String, dynamic> passenger;
  final _PassengerFields fields;
  final DateTime? minimumExpiry;
  final String? serverError;
  final VoidCallback onChanged;

  const _PassengerCard({
    required this.passenger,
    required this.fields,
    required this.minimumExpiry,
    required this.serverError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMissing = passenger['is_missing'] == true;
    final isExpiring = passenger['is_expiring'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  textOf(passenger['name'], 'ผู้เดินทาง'),
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              _StatusPill(isMissing: isMissing, isExpiring: isExpiring),
            ],
          ),
          const SizedBox(height: 14),
          _Field(
            controller: fields.nameEn,
            label: 'ชื่อ-สกุลภาษาอังกฤษ (ตามพาสปอร์ต)',
            hint: 'SOMCHAI JAIDEE',
            icon: Icons.badge_rounded,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z\s.'-]")),
              _UpperCaseFormatter(),
            ],
            onChanged: (_) => onChanged(),
            validator: (value) {
              if (fields.isBlank) return null;
              return (value ?? '').trim().isEmpty
                  ? 'กรุณากรอกชื่อ-สกุลภาษาอังกฤษตามพาสปอร์ต'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          _Field(
            controller: fields.passportNo,
            label: 'เลขที่พาสปอร์ต',
            hint: 'AA1234567',
            icon: Icons.menu_book_rounded,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(20),
              _UpperCaseFormatter(),
            ],
            onChanged: (_) => onChanged(),
            validator: (value) {
              if (fields.isBlank) return null;
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'กรุณากรอกเลขที่พาสปอร์ต';
              if (text.length < 5) return 'เลขที่พาสปอร์ตไม่ถูกต้อง';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _ExpiryPicker(
            fields: fields,
            minimumExpiry: minimumExpiry,
            onChanged: onChanged,
          ),
          if (serverError != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    serverError!,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorColor,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isMissing;
  final bool isExpiring;

  const _StatusPill({required this.isMissing, required this.isExpiring});

  @override
  Widget build(BuildContext context) {
    final (label, color) = isMissing
        ? ('ยังไม่กรอก', AppTheme.errorColor)
        : isExpiring
        ? ('ใกล้หมดอายุ', AppTheme.warningColor)
        : ('ครบแล้ว', AppTheme.successColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.isDark(context) ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeMicro,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ExpiryPicker extends StatelessWidget {
  final _PassengerFields fields;
  final DateTime? minimumExpiry;
  final VoidCallback onChanged;

  const _ExpiryPicker({
    required this.fields,
    required this.minimumExpiry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      initialValue: fields.expiresAt,
      validator: (_) {
        if (fields.isBlank) return null;
        final date = fields.expiresAt;
        if (date == null) return 'กรุณาระบุวันหมดอายุพาสปอร์ต';
        final minimum = minimumExpiry;
        if (minimum != null && date.isBefore(minimum)) {
          return 'พาสปอร์ตต้องเหลืออายุอย่างน้อย 6 เดือนนับจากวันเดินทาง';
        }
        return null;
      },
      builder: (state) {
        final date = fields.expiresAt;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: () async {
                HapticFeedback.selectionClick();
                final now = DateTime.now();
                final first = minimumExpiry ?? now.add(const Duration(days: 1));
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date != null && !date.isBefore(first)
                      ? date
                      : first,
                  firstDate: first,
                  lastDate: DateTime(now.year + 15),
                  helpText: 'เลือกวันหมดอายุพาสปอร์ต',
                );
                if (picked == null) return;
                fields.expiresAt = picked;
                state.didChange(picked);
                onChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.fieldSurface(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: state.hasError
                        ? AppTheme.errorColor
                        : AppTheme.border(context).withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 18,
                      color: AppTheme.mutedText(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'วันหมดอายุพาสปอร์ต',
                            style: appFont(
                              fontSize: AppText.sizeMicro,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date == null
                                ? 'แตะเพื่อเลือกวันหมดอายุ'
                                : thaiDateFull(date),
                            style: appFont(
                              fontSize: AppText.sizeBody,
                              fontWeight: FontWeight.w700,
                              color: date == null
                                  ? AppTheme.mutedText(context)
                                  : AppTheme.onSurface(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError) ...[
              const SizedBox(height: 6),
              Text(
                state.errorText!,
                style: appFont(
                  fontSize: AppText.sizeMicro,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      style: appFont(
        fontSize: AppText.sizeBody,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurface(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.mutedText(context)),
        filled: true,
        fillColor: AppTheme.fieldSurface(context),
        labelStyle: appFont(
          fontSize: AppText.sizeCaption,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedText(context),
        ),
        hintStyle: appFont(
          fontSize: AppText.sizeCaption,
          color: AppTheme.mutedText(context).withValues(alpha: 0.7),
        ),
        errorStyle: appFont(
          fontSize: AppText.sizeMicro,
          fontWeight: FontWeight.w700,
          color: AppTheme.errorColor,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppTheme.mutedText(context),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(
                'ลองใหม่',
                style: appFont(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ช่องกรอกของผู้เดินทางหนึ่งคน
class _PassengerFields {
  final TextEditingController nameEn;
  final TextEditingController passportNo;
  DateTime? expiresAt;

  _PassengerFields({
    required this.nameEn,
    required this.passportNo,
    this.expiresAt,
  });

  factory _PassengerFields.fromJson(Map<String, dynamic> passenger) {
    return _PassengerFields(
      nameEn: TextEditingController(text: textOf(passenger['name_en'])),
      passportNo: TextEditingController(text: textOf(passenger['passport_no'])),
      expiresAt: DateTime.tryParse(textOf(passenger['passport_expires_at'])),
    );
  }

  /// หลังบันทึกสำเร็จ ค่าที่เซิร์ฟเวอร์เก็บจริง (ตัวพิมพ์ใหญ่) กลับมา — รับมาแทน
  /// ของที่พิมพ์ไว้ แต่ไม่แตะช่องที่ผู้ใช้ยังแก้ค้างอยู่
  void adoptSaved(Map<String, dynamic> passenger) {
    final savedName = textOf(passenger['name_en']);
    final savedNo = textOf(passenger['passport_no']);
    if (savedName.isNotEmpty) nameEn.text = savedName;
    if (savedNo.isNotEmpty) passportNo.text = savedNo;
    final savedExpiry = DateTime.tryParse(
      textOf(passenger['passport_expires_at']),
    );
    if (savedExpiry != null) expiresAt = savedExpiry;
  }

  /// เว้นว่างทั้งแถว = ยังไม่พร้อมกรอกของคนนี้ ไม่นับเป็นกรอกผิด
  bool get isBlank =>
      nameEn.text.trim().isEmpty &&
      passportNo.text.trim().isEmpty &&
      expiresAt == null;

  void dispose() {
    nameEn.dispose();
    passportNo.dispose();
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
