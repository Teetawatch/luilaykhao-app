import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Storage keys & helpers
// ─────────────────────────────────────────────────────────────────────────────

const _kPrefix = 'doc_wallet_';

class DocumentWallet {
  static const _fields = [
    'title', 'name', 'nickname', 'phone', 'id_card', 'blood_group',
    'emergency_contact', 'emergency_phone', 'allergies', 'health_notes',
    'halal_food',
  ];

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, dynamic>{};
    for (final key in _fields) {
      if (key == 'halal_food') {
        result[key] = prefs.getBool('$_kPrefix$key') ?? false;
      } else {
        result[key] = prefs.getString('$_kPrefix$key') ?? '';
      }
    }
    return result;
  }

  static Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _fields) {
      if (key == 'halal_food') {
        await prefs.setBool('$_kPrefix$key', data[key] == true);
      } else {
        final val = (data[key] ?? '').toString().trim();
        if (val.isEmpty) {
          await prefs.remove('$_kPrefix$key');
        } else {
          await prefs.setString('$_kPrefix$key', val);
        }
      }
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _fields) {
      await prefs.remove('$_kPrefix$key');
    }
  }

  static Future<bool> hasData() async {
    final data = await load();
    return (data['name'] as String).isNotEmpty ||
        (data['phone'] as String).isNotEmpty;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DocumentWalletScreen
// ─────────────────────────────────────────────────────────────────────────────

class DocumentWalletScreen extends StatefulWidget {
  const DocumentWalletScreen({super.key});

  @override
  State<DocumentWalletScreen> createState() => _DocumentWalletScreenState();
}

class _DocumentWalletScreenState extends State<DocumentWalletScreen> {
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idCardCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _healthNotesCtrl = TextEditingController();

  String? _title;
  String? _bloodGroup;
  bool _halalFood = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final data = await DocumentWallet.load();
    setState(() {
      final t = (data['title'] as String);
      _title = t.isNotEmpty ? t : null;
      _nameCtrl.text = data['name'] as String;
      _nicknameCtrl.text = data['nickname'] as String;
      _phoneCtrl.text = data['phone'] as String;
      _idCardCtrl.text = data['id_card'] as String;
      final bg = data['blood_group'] as String;
      _bloodGroup = bg.isNotEmpty ? bg : null;
      _emergencyContactCtrl.text = data['emergency_contact'] as String;
      _emergencyPhoneCtrl.text = data['emergency_phone'] as String;
      _allergiesCtrl.text = data['allergies'] as String;
      _healthNotesCtrl.text = data['health_notes'] as String;
      _halalFood = data['halal_food'] as bool;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DocumentWallet.save({
        'title': _title ?? '',
        'name': _nameCtrl.text,
        'nickname': _nicknameCtrl.text,
        'phone': _phoneCtrl.text,
        'id_card': _idCardCtrl.text,
        'blood_group': _bloodGroup ?? '',
        'emergency_contact': _emergencyContactCtrl.text,
        'emergency_phone': _emergencyPhoneCtrl.text,
        'allergies': _allergiesCtrl.text,
        'health_notes': _healthNotesCtrl.text,
        'halal_food': _halalFood,
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึก Wallet แล้ว',
              style: GoogleFonts.anuphan(fontWeight: FontWeight.w700)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ล้างข้อมูล Wallet',
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w900)),
        content: Text('ข้อมูลผู้เดินทางที่บันทึกไว้จะถูกลบทั้งหมด',
            style: GoogleFonts.anuphan()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('ล้างข้อมูล'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await DocumentWallet.clear();
    await _loadWallet();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ล้างข้อมูล Wallet แล้ว',
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _phoneCtrl.dispose();
    _idCardCtrl.dispose();
    _emergencyContactCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _allergiesCtrl.dispose();
    _healthNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'Document Wallet',
          style: GoogleFonts.anuphan(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.onSurface(context),
          ),
        ),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: AppTheme.errorColor),
            tooltip: 'ล้างข้อมูล',
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.wallet_rounded,
                            color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'บันทึกข้อมูลผู้เดินทางไว้ที่นี่เพียงครั้งเดียว '
                            'แล้วกด "กรอกจาก Wallet" ในขั้นตอนจองได้เลย — '
                            'ข้อมูลเก็บไว้บนเครื่องนี้เท่านั้น',
                            style: GoogleFonts.anuphan(
                              fontSize: 12.5,
                              color: AppTheme.primaryColor,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── ข้อมูลส่วนตัว ──────────────────────────────────────
                  _WalletSectionHeader(
                    icon: Icons.person_rounded,
                    title: 'ข้อมูลส่วนตัว',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: _WalletDropdown(
                          value: _title,
                          hint: 'คำนำหน้า',
                          icon: Icons.badge_outlined,
                          items: const ['นาย', 'นาง', 'นางสาว'],
                          onChanged: (v) => setState(() => _title = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WalletField(
                          controller: _nameCtrl,
                          hint: 'ชื่อ-นามสกุล',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _WalletField(
                          controller: _nicknameCtrl,
                          hint: 'ชื่อเล่น',
                          icon: Icons.face_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WalletDropdown(
                          value: _bloodGroup,
                          hint: 'กรุ๊ปเลือด',
                          icon: Icons.bloodtype_outlined,
                          items: const ['A', 'B', 'AB', 'O'],
                          onChanged: (v) => setState(() => _bloodGroup = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _WalletField(
                    controller: _idCardCtrl,
                    hint: 'เลขบัตรประชาชน (13 หลัก)',
                    icon: Icons.credit_card_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // ── ข้อมูลติดต่อ ────────────────────────────────────────
                  _WalletSectionHeader(
                    icon: Icons.phone_rounded,
                    title: 'ข้อมูลติดต่อ',
                  ),
                  const SizedBox(height: 12),
                  _WalletField(
                    controller: _phoneCtrl,
                    hint: 'เบอร์โทรศัพท์',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // ── ผู้ติดต่อฉุกเฉิน ────────────────────────────────────
                  _WalletSectionHeader(
                    icon: Icons.emergency_rounded,
                    title: 'ผู้ติดต่อฉุกเฉิน',
                    accentColor: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 12),
                  _WalletField(
                    controller: _emergencyContactCtrl,
                    hint: 'ชื่อผู้ติดต่อฉุกเฉิน',
                    icon: Icons.contact_emergency_outlined,
                  ),
                  const SizedBox(height: 12),
                  _WalletField(
                    controller: _emergencyPhoneCtrl,
                    hint: 'เบอร์โทรผู้ติดต่อฉุกเฉิน',
                    icon: Icons.local_phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // ── ข้อมูลสุขภาพ ────────────────────────────────────────
                  _WalletSectionHeader(
                    icon: Icons.health_and_safety_rounded,
                    title: 'ข้อมูลสุขภาพ',
                    accentColor: const Color(0xFF0891B2),
                  ),
                  const SizedBox(height: 12),
                  _WalletField(
                    controller: _allergiesCtrl,
                    hint: 'ประวัติแพ้ยา / แพ้อาหาร',
                    icon: Icons.medical_information_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _WalletField(
                    controller: _healthNotesCtrl,
                    hint: 'โรคประจำตัวหรือข้อมูลสุขภาพเพิ่มเติม',
                    icon: Icons.favorite_border_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.fieldSurface(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            AppTheme.border(context).withValues(alpha: 0.65),
                      ),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'ต้องการอาหารฮาลาล',
                        style: GoogleFonts.anuphan(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      value: _halalFood,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (v) => setState(() => _halalFood = v),
                    ),
                  ),

                  const SizedBox(height: 32),
                  // ── Save button ──────────────────────────────────────────
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        _saving ? 'กำลังบันทึก...' : 'บันทึก Wallet',
                        style: GoogleFonts.anuphan(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WalletSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? accentColor;

  const _WalletSectionHeader({
    required this.icon,
    required this.title,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.primaryColor;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.anuphan(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.onSurface(context),
          ),
        ),
      ],
    );
  }
}

class _WalletField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const _WalletField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: 1,
      maxLines: maxLines,
      style: GoogleFonts.anuphan(
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurface(context),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.anuphan(
          color: AppTheme.mutedText(context).withValues(alpha: 0.65),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        filled: true,
        fillColor: AppTheme.fieldSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
              color: AppTheme.border(context).withValues(alpha: 0.65)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
              color: AppTheme.border(context).withValues(alpha: 0.65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: maxLines > 1 ? 16 : 18,
          horizontal: 16,
        ),
      ),
    );
  }
}

class _WalletDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _WalletDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(18),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: AppTheme.mutedText(context)),
      style: GoogleFonts.anuphan(
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurface(context),
        fontSize: 14,
      ),
      dropdownColor: AppTheme.surface(context),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.anuphan(
          color: AppTheme.mutedText(context).withValues(alpha: 0.65),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        filled: true,
        fillColor: AppTheme.fieldSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
              color: AppTheme.border(context).withValues(alpha: 0.65)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
              color: AppTheme.border(context).withValues(alpha: 0.65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
      items: items
          .map((item) =>
              DropdownMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
