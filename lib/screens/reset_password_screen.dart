import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'forgot_password_screen.dart';

/// ตั้งรหัสผ่านใหม่ — ปลายทางของลิงก์ในอีเมล
///
/// เปิดจาก deep link `https://luilaykhao.com/reset-password?token=..&email=..`
/// (หรือ `luilaykhao://reset-password?...`) โทเคนจึงมาพร้อมหน้าจอเสมอ ไม่ได้ให้
/// ผู้ใช้พิมพ์เอง — ถ้าเปิดหน้านี้โดยไม่มีโทเคน จะพากลับไปขอลิงก์ใหม่แทน
class ResetPasswordScreen extends StatefulWidget {
  final String token;
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.token,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      setState(() => _error = 'รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'รหัสผ่านทั้งสองช่องไม่ตรงกัน');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await context.read<AppProvider>().resetPassword(
        token: widget.token,
        email: widget.email,
        password: password,
      );
      if (!mounted) return;
      setState(() => _done = message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    final hasToken = widget.token.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'ตั้งรหัสผ่านใหม่',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (done != null)
              _DoneState(message: done)
            else if (!hasToken)
              _MissingTokenState(email: widget.email)
            else ...[
              Text(
                'ตั้งรหัสผ่านใหม่',
                style: appFont(
                  fontSize: AppText.sizeH2,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'สำหรับบัญชี ${widget.email}\nตั้งเสร็จแล้วอุปกรณ์อื่นที่ค้าง'
                'ล็อกอินอยู่จะถูกออกจากระบบทั้งหมดเพื่อความปลอดภัยครับ',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  color: AppTheme.mutedText(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _PasswordField(
                controller: _passwordController,
                hint: 'รหัสผ่านใหม่ (อย่างน้อย 8 ตัว)',
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirmController,
                hint: 'ยืนยันรหัสผ่านใหม่',
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _NoticeBanner(
                  color: Colors.red,
                  icon: Icons.error_outline_rounded,
                  text: _error!,
                ),
              ],
              const SizedBox(height: 20),
              PrimaryCTAButton(
                label: _saving ? 'กำลังบันทึก...' : 'บันทึกรหัสผ่านใหม่',
                icon: Icons.lock_reset_rounded,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    required this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppTheme.subtleSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DoneState extends StatelessWidget {
  final String message;

  const _DoneState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 56,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        Text(
          'เรียบร้อยแล้ว',
          style: appFont(
            fontSize: AppText.sizeH2,
            fontWeight: FontWeight.w900,
            color: AppTheme.onSurface(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: appFont(
            fontSize: AppText.sizeBody,
            color: AppTheme.mutedText(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        PrimaryCTAButton(
          label: 'เข้าสู่ระบบ',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _MissingTokenState extends StatelessWidget {
  final String email;

  const _MissingTokenState({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Icon(
          Icons.link_off_rounded,
          size: 56,
          color: AppTheme.mutedText(context),
        ),
        const SizedBox(height: 16),
        Text(
          'ลิงก์ไม่สมบูรณ์',
          style: appFont(
            fontSize: AppText.sizeH2,
            fontWeight: FontWeight.w900,
            color: AppTheme.onSurface(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ลิงก์ที่เปิดมาไม่มีรหัสยืนยัน อาจถูกตัดตอนคัดลอกมาครับ '
          'ขอลิงก์ใหม่อีกครั้งได้เลย',
          style: appFont(
            fontSize: AppText.sizeBody,
            color: AppTheme.mutedText(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        PrimaryCTAButton(
          label: 'ขอลิงก์ใหม่',
          icon: Icons.refresh_rounded,
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ForgotPasswordScreen(initialEmail: email),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _NoticeBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

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
