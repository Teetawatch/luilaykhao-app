import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RegisterScreen
// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal info
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();
  String? _selectedTitle;
  String? _selectedBloodGroup;

  // Emergency & health
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _healthNotesController = TextEditingController();

  // Security
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isPasswordConfirmVisible = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idCardController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _allergiesController.dispose();
    _healthNotesController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final idCard = _idCardController.text.trim();
    final emergencyContact = _emergencyContactController.text.trim();
    final emergencyPhone = _emergencyPhoneController.text.trim();
    final allergies = _allergiesController.text.trim();
    final healthNotes = _healthNotesController.text.trim();
    final password = _passwordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      await context.read<AppProvider>().register({
        'title': _selectedTitle,
        'name': name,
        'nickname': nickname,
        'blood_group': _selectedBloodGroup,
        'email': email,
        'phone': phone,
        'id_card': idCard,
        'emergency_contact': emergencyContact,
        'emergency_phone': emergencyPhone,
        'allergies': allergies,
        'health_notes': healthNotes,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สมัครสมาชิกสำเร็จ ยินดีต้อนรับ!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                _RegisterHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 28),

                      // ── Section: ข้อมูลส่วนตัว ──────────────────────────
                      const _SectionHeader(
                        icon: Icons.person_rounded,
                        title: 'ข้อมูลส่วนตัว',
                        subtitle: 'ใช้ตรงตามบัตรประชาชน',
                      ),
                      const SizedBox(height: 14),
                      _TitleAndNameRow(
                        selectedTitle: _selectedTitle,
                        onTitleChanged: (v) =>
                            setState(() => _selectedTitle = v),
                        nameController: _nameController,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _RegisterInput(
                              controller: _nicknameController,
                              hint: 'ชื่อเล่น',
                              icon: Icons.face_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RegisterSelect(
                              value: _selectedBloodGroup,
                              hint: 'กรุ๊ปเลือด',
                              icon: Icons.bloodtype_outlined,
                              items: const ['A', 'B', 'AB', 'O'],
                              required: true,
                              onChanged: (v) =>
                                  setState(() => _selectedBloodGroup = v),
                              validator: (v) =>
                                  v == null ? 'กรุณาเลือกกรุ๊ปเลือด' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _RegisterInput(
                        controller: _idCardController,
                        hint: 'เลขบัตรประชาชน (13 หลัก)',
                        icon: Icons.credit_card_rounded,
                        keyboardType: TextInputType.number,
                        required: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(13),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'กรุณากรอกเลขบัตรประชาชน';
                          }
                          if (v.length != 13) {
                            return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),
                      // ── Section: ข้อมูลติดต่อ ──────────────────────────
                      const _SectionHeader(
                        icon: Icons.contact_phone_rounded,
                        title: 'ข้อมูลติดต่อ',
                        subtitle: 'สำหรับการแจ้งข่าวสารและนัดหมาย',
                      ),
                      const SizedBox(height: 14),
                      _RegisterInput(
                        controller: _emailController,
                        hint: 'อีเมล',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        required: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'กรุณากรอกอีเมล';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'รูปแบบอีเมลไม่ถูกต้อง';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _RegisterInput(
                        controller: _phoneController,
                        hint: 'เบอร์โทรศัพท์',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        required: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'กรุณากรอกเบอร์โทรศัพท์';
                          }
                          if (v.length != 10) {
                            return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),
                      // ── Section: ผู้ติดต่อฉุกเฉิน ──────────────────────
                      const _SectionHeader(
                        icon: Icons.emergency_rounded,
                        title: 'ผู้ติดต่อฉุกเฉิน',
                        subtitle: 'จำเป็นสำหรับความปลอดภัยระหว่างการเดินทาง',
                        accentColor: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 14),
                      _RegisterInput(
                        controller: _emergencyContactController,
                        hint: 'ชื่อผู้ติดต่อฉุกเฉิน',
                        icon: Icons.contact_emergency_outlined,
                      ),
                      const SizedBox(height: 12),
                      _RegisterInput(
                        controller: _emergencyPhoneController,
                        hint: 'เบอร์โทรผู้ติดต่อฉุกเฉิน',
                        icon: Icons.local_phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                          LengthLimitingTextInputFormatter(20),
                        ],
                      ),

                      const SizedBox(height: 24),
                      // ── Section: ข้อมูลสุขภาพ ──────────────────────────
                      const _SectionHeader(
                        icon: Icons.health_and_safety_rounded,
                        title: 'ข้อมูลสุขภาพ',
                        subtitle: 'ช่วยให้ทีมงานดูแลคุณได้ดียิ่งขึ้น',
                        accentColor: Color(0xFF0891B2),
                      ),
                      const SizedBox(height: 14),
                      _RegisterInput(
                        controller: _allergiesController,
                        hint: 'ประวัติแพ้ยา / แพ้อาหาร',
                        icon: Icons.medical_information_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _RegisterInput(
                        controller: _healthNotesController,
                        hint: 'โรคประจำตัวหรือข้อมูลสุขภาพเพิ่มเติม',
                        icon: Icons.favorite_border_rounded,
                        maxLines: 3,
                      ),

                      const SizedBox(height: 24),
                      // ── Section: รหัสผ่าน ──────────────────────────────
                      const _SectionHeader(
                        icon: Icons.lock_rounded,
                        title: 'ตั้งรหัสผ่าน',
                        subtitle: 'ใช้ตัวอักษร ตัวเลข ผสมกัน อย่างน้อย 8 ตัว',
                      ),
                      const SizedBox(height: 14),
                      _RegisterInput(
                        controller: _passwordController,
                        hint: 'รหัสผ่าน',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        onToggleVisibility: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        required: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'กรุณากรอกรหัสผ่าน';
                          }
                          if (v.length < 8) {
                            return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _RegisterInput(
                        controller: _passwordConfirmationController,
                        hint: 'ยืนยันรหัสผ่าน',
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                        isPasswordVisible: _isPasswordConfirmVisible,
                        onToggleVisibility: () => setState(
                          () => _isPasswordConfirmVisible =
                              !_isPasswordConfirmVisible,
                        ),
                        required: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'กรุณายืนยันรหัสผ่าน';
                          }
                          if (v != _passwordController.text) {
                            return 'รหัสผ่านไม่ตรงกัน';
                          }
                          return null;
                        },
                      ),
                      if (!isDark)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _PasswordStrengthHint(
                            password: _passwordController.text,
                          ),
                        ),

                      const SizedBox(height: 32),
                      // ── CTA ────────────────────────────────────────────
                      _RegisterButton(
                        loading: _isLoading,
                        onPressed: _handleRegister,
                      ),
                      const SizedBox(height: 24),
                      _LoginPrompt(),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final isDark = AppTheme.isDark(context);
    final bgFade = AppTheme.background(context);

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: ApiConfig.mediaUrl('/images/register_page.png'),
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              color: AppTheme.subtleSurface(context),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, _, _) => Container(
              color: AppTheme.subtleSurface(context),
              child: const Icon(
                Icons.landscape_rounded,
                color: AppTheme.primaryColor,
                size: 54,
              ),
            ),
          ),
          // Gradient overlay
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: isDark ? 0.35 : 0.20),
                  Colors.black.withValues(alpha: isDark ? 0.55 : 0.38),
                  bgFade,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Back button
          Positioned(
            top: topPad + 8,
            left: 12,
            child: _BackButton(),
          ),
          // Title
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'สร้างบัญชีใหม่',
                  style: GoogleFonts.anuphan(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'เริ่มต้นการเดินทางไปกับเรา',
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                      ),
                    ],
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

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.pop(context),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.primaryColor;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: AppTheme.isDark(context) ? 0.20 : 0.10,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.anuphan(
                  color: AppTheme.onSurface(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.anuphan(
                  color: AppTheme.mutedText(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Title + name combined row (คำนำหน้า + ชื่อ-นามสกุล)
// ─────────────────────────────────────────────────────────────────────────────

class _TitleAndNameRow extends StatelessWidget {
  final String? selectedTitle;
  final ValueChanged<String?> onTitleChanged;
  final TextEditingController nameController;

  const _TitleAndNameRow({
    required this.selectedTitle,
    required this.onTitleChanged,
    required this.nameController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: _RegisterSelect(
            value: selectedTitle,
            hint: 'คำนำหน้า',
            icon: Icons.badge_outlined,
            items: const ['นาย', 'นาง', 'นางสาว'],
            onChanged: onTitleChanged,
            required: true,
            validator: (v) =>
                v == null ? 'กรุณาเลือกคำนำหน้า' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RegisterInput(
            controller: nameController,
            hint: 'ชื่อ-นามสกุล',
            icon: Icons.person_outline_rounded,
            required: true,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ-นามสกุล' : null,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password strength hint
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordStrengthHint extends StatelessWidget {
  final String password;

  const _PasswordStrengthHint({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final hasLength = password.length >= 8;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));

    final checks = [
      (label: 'ยาวอย่างน้อย 8 ตัว', pass: hasLength),
      (label: 'มีตัวพิมพ์ใหญ่', pass: hasUpper),
      (label: 'มีตัวเลข', pass: hasDigit),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context).withValues(alpha: 0.5)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: checks.map((c) {
          final color = c.pass ? AppTheme.primaryColor : AppTheme.mutedText(context);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                c.pass ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: color,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                c.label,
                style: GoogleFonts.anuphan(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Register CTA button
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _RegisterButton({
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.40),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: loading ? 0 : 2,
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.40),
        ),
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.person_add_rounded, size: 22),
        label: Text(
          loading ? 'กำลังสมัครสมาชิก...' : 'สมัครสมาชิก',
          style: GoogleFonts.anuphan(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login prompt
// ─────────────────────────────────────────────────────────────────────────────

class _LoginPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'มีบัญชีอยู่แล้ว? ',
          style: GoogleFonts.anuphan(
            color: AppTheme.mutedText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'เข้าสู่ระบบ',
            style: GoogleFonts.anuphan(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared input widgets
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool isPasswordVisible;
  final VoidCallback? onToggleVisibility;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool required;
  final String? Function(String?)? validator;

  const _RegisterInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.onToggleVisibility,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.required = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: 1,
      maxLines: isPassword ? 1 : maxLines,
      validator: validator,
      style: GoogleFonts.anuphan(
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurface(context),
      ),
      decoration: InputDecoration(
        hintText: hint + (required ? ' *' : ''),
        hintStyle: GoogleFonts.anuphan(
          color: AppTheme.mutedText(context).withValues(alpha: 0.70),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppTheme.mutedText(context),
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: AppTheme.fieldSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.65),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.65),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.errorColor.withValues(alpha: 0.80),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: maxLines > 1 ? 16 : 18,
          horizontal: 16,
        ),
        errorStyle: GoogleFonts.anuphan(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RegisterSelect extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool required;
  final String? Function(String?)? validator;

  const _RegisterSelect({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(18),
      validator: validator,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTheme.mutedText(context),
      ),
      style: GoogleFonts.anuphan(
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurface(context),
        fontSize: 14,
      ),
      dropdownColor: AppTheme.surface(context),
      decoration: InputDecoration(
        hintText: hint + (required ? ' *' : ''),
        hintStyle: GoogleFonts.anuphan(
          color: AppTheme.mutedText(context).withValues(alpha: 0.70),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        filled: true,
        fillColor: AppTheme.fieldSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.65),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.65),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.errorColor.withValues(alpha: 0.80),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        errorStyle: GoogleFonts.anuphan(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
