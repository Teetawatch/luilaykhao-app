import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

/// "ลืมรหัสผ่าน" — ขอลิงก์ตั้งรหัสผ่านใหม่ทางอีเมล
///
/// ฝั่งเซิร์ฟเวอร์ตอบข้อความเดียวกันเสมอไม่ว่าอีเมลนั้นจะมีบัญชีอยู่จริงหรือไม่
/// (กันไม่ให้ใครใช้หน้านี้เดารายชื่อลูกค้า) หน้านี้จึงไม่พยายามบอกว่า "ไม่พบ
/// อีเมลนี้" — พาไปหน้าสถานะ "ส่งแล้ว" ทุกครั้งที่ยิงสำเร็จ
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _sending = false;
  String? _error;
  String? _sentMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'กรุณากรอกอีเมลที่ใช้สมัครสมาชิก');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await context.read<AppProvider>().requestPasswordReset(
        email,
      );
      if (!mounted) return;
      setState(() => _sentMessage = message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sentMessage;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'ลืมรหัสผ่าน',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: sent != null
              ? [_SentState(message: sent, email: _emailController.text.trim())]
              : [
                  Text(
                    'จำรหัสผ่านไม่ได้ใช่ไหมครับ',
                    style: appFont(
                      fontSize: AppText.sizeH2,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'กรอกอีเมลที่ใช้สมัครสมาชิก แล้วเราจะส่งลิงก์สำหรับตั้ง'
                    'รหัสผ่านใหม่ไปให้ ลิงก์จะเปิดกลับมาที่แอปนี้ได้เลยครับ',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      color: AppTheme.mutedText(context),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'อีเมลของคุณ',
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                      filled: true,
                      fillColor: AppTheme.subtleSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
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
                    label: _sending ? 'กำลังส่ง...' : 'ส่งลิงก์ตั้งรหัสผ่านใหม่',
                    icon: Icons.send_rounded,
                    onPressed: _sending ? null : _submit,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'ถ้าสมัครด้วย Google, Facebook, LINE หรือ Apple ให้กดเข้าสู่'
                    'ระบบด้วยปุ่มนั้นได้เลย ไม่ต้องใช้รหัสผ่านครับ',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
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

class _SentState extends StatelessWidget {
  final String message;
  final String email;

  const _SentState({required this.message, required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          'ส่งลิงก์ไปที่อีเมลแล้ว',
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
        if (email.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.alternate_email_rounded,
                  size: 18,
                  color: AppTheme.mutedText(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const _NoticeBanner(
          color: Colors.blueGrey,
          icon: Icons.info_outline_rounded,
          text: 'ลิงก์มีอายุ 60 นาที ถ้าไม่เจอในกล่องจดหมาย ลองดูในอีเมลขยะ '
              '(Junk/Spam) อีกครั้งนะครับ',
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('กลับไปหน้าเข้าสู่ระบบ'),
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
