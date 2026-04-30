import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AppProvider>().register({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
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
        backgroundColor: AppTheme.bgLight,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _RegisterHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _RegisterInput(
                      controller: _nameController,
                      hint: 'ชื่อ-นามสกุล',
                      icon: Icons.person_outline_rounded,
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
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAkcoh81AthX8BRpp0grFV1rpVGg6w_keM6F2TZJWPth2Aa8BmMa4Kqn8kWvyjR0wJcprEVJMMda7Lwh9Zs20focIgUjy6iSfWYyLGzUSW3D8cOeuQg5wM0jnkpjmGE3LpL8ghj_vGPZVQZhktFhAqBcC4gf43zPAAFu6P2J775FSmbkAx25jCmK7UhGCqRnxFoBJTvpo72pU9jWONc9dSZ9eiGC0MfxnXouHdi2f6XqP6lRpgclEH59UJL0O7kT7mJCGiE81GHDw',
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

  const _RegisterInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.onToggleVisibility,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
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
