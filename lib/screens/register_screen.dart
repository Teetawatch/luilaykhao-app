import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _healthNotesController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  String? _selectedTitle;
  String? _selectedBloodGroup;
  bool _isPasswordVisible = false;
  bool _isPasswordConfirmationVisible = false;
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

    if (_selectedTitle == null ||
        name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        passwordConfirmation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกอีเมลให้ถูกต้อง')));
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร')),
      );
      return;
    }

    if (password != passwordConfirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน')),
      );
      return;
    }

    if (idCard.isNotEmpty && idCard.length != 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลขบัตรประชาชนต้องมี 13 หลัก')),
      );
      return;
    }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('สมัครสมาชิกสำเร็จ')));
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              _RegisterHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _RegisterSelect(
                      value: _selectedTitle,
                      hint: 'คำนำหน้า',
                      icon: Icons.badge_outlined,
                      items: const ['นาย', 'นาง', 'นางสาว'],
                      onChanged: (value) =>
                          setState(() => _selectedTitle = value),
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _nameController,
                      hint: 'ชื่อ-นามสกุล',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _nicknameController,
                      hint: 'ชื่อเล่น',
                      icon: Icons.face_outlined,
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _emailController,
                      hint: 'อีเมล',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _phoneController,
                      hint: 'เบอร์โทรศัพท์',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _idCardController,
                      hint: 'เลขบัตรประชาชน',
                      icon: Icons.credit_card_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _RegisterSelect(
                      value: _selectedBloodGroup,
                      hint: 'กรุ๊ปเลือด',
                      icon: Icons.bloodtype_outlined,
                      items: const [
                        'A+',
                        'A-',
                        'B+',
                        'B-',
                        'AB+',
                        'AB-',
                        'O+',
                        'O-',
                        'ไม่ทราบ',
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedBloodGroup = value),
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _emergencyContactController,
                      hint: 'ผู้ติดต่อฉุกเฉิน',
                      icon: Icons.contact_emergency_outlined,
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _emergencyPhoneController,
                      hint: 'เบอร์ผู้ติดต่อฉุกเฉิน',
                      icon: Icons.local_phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _allergiesController,
                      hint: 'ประวัติแพ้ยา/แพ้อาหาร',
                      icon: Icons.medical_information_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _healthNotesController,
                      hint: 'โรคประจำตัวหรือข้อมูลสุขภาพเพิ่มเติม',
                      icon: Icons.health_and_safety_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _passwordController,
                      hint: 'รหัสผ่าน',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      isPasswordVisible: _isPasswordVisible,
                      onToggleVisibility: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RegisterInput(
                      controller: _passwordConfirmationController,
                      hint: 'ยืนยันรหัสผ่าน',
                      icon: Icons.lock_reset_rounded,
                      isPassword: true,
                      isPasswordVisible: _isPasswordConfirmationVisible,
                      onToggleVisibility: () => setState(
                        () => _isPasswordConfirmationVisible =
                            !_isPasswordConfirmationVisible,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryCTAButton(
                      label: 'สมัครสมาชิก',
                      onPressed: _isLoading ? null : _handleRegister,
                      icon: _isLoading ? null : Icons.person_add_rounded,
                    ),
                    const SizedBox(height: 48),
                    _LoginPrompt(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      height: size.height * 0.35,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            ApiConfig.mediaUrl('/images/register_page.png'),
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.4),
                  AppTheme.bgLight,
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สร้างบัญชีใหม่',
                  style: GoogleFonts.anuphan(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'เริ่มต้นการเดินทางไปกับเรา',
                  style: GoogleFonts.anuphan(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black26,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        minLines: 1,
        maxLines: isPassword ? 1 : maxLines,
        style: GoogleFonts.anuphan(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.anuphan(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 20,
          ),
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

  const _RegisterSelect({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(20),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.primaryColor,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.anuphan(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w600),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'มีบัญชีอยู่แล้ว? ',
          style: GoogleFonts.anuphan(color: AppTheme.textSecondary),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'เข้าสู่ระบบ',
            style: GoogleFonts.anuphan(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
