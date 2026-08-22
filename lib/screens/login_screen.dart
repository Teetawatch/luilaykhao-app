import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../widgets/min_tap_target.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final bool popOnSuccess;

  const LoginScreen({super.key, this.onLoginSuccess, this.popOnSuccess = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _socialLoadingProvider;

  bool get _isSocialLoading => _socialLoadingProvider != null;

  // แอนิเมชันเลื่อนขึ้นของแผ่นถูกถอดออกพร้อมกับตัวแผ่น — หน้าเต็มที่เลื่อนขึ้น
  // มาตอนเปิดจะขัดกับ transition ของ Navigator ที่เลื่อนอยู่แล้ว

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSocialLogin(String provider) async {
    if (_isLoading || _isSocialLoading) return;
    setState(() => _socialLoadingProvider = provider);

    final callbackUrl = Uri(
      scheme: 'luilaykhao',
      host: 'auth',
      path: '/social/callback',
    );
    final redirectUrl = Uri.parse(
      '${ApiConfig.baseUrl}/auth/$provider/redirect',
    ).replace(queryParameters: {'return_to': callbackUrl.toString()});

    try {
      final launched = await launchUrl(
        redirectUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('ไม่สามารถเปิดหน้าล็อกอินได้');
    } catch (e) {
      if (mounted) _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _socialLoadingProvider = null);
    }
  }

  Future<void> _handleAppleLogin() async {
    if (_isLoading || _isSocialLoading) return;
    final app = context.read<AppProvider>();
    setState(() => _socialLoadingProvider = 'apple');
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      if (credential.identityToken == null) {
        throw Exception('ไม่ได้รับ identity token จาก Apple');
      }
      await app.loginWithApple(
        identityToken: credential.identityToken!,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
      if (mounted) _finishLogin();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        _showSnack('ไม่สามารถเข้าสู่ระบบด้วย Apple ได้');
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _socialLoadingProvider = null);
    }
  }

  void _finishLogin() {
    final onLoginSuccess = widget.onLoginSuccess;
    final navigator = Navigator.of(context);
    if (widget.popOnSuccess && navigator.canPop()) navigator.pop();
    onLoginSuccess?.call();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnack('กรุณากรอกอีเมลและรหัสผ่าน');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await context.read<AppProvider>().login(email, password);
      if (mounted) _finishLogin();
    } catch (e) {
      if (mounted) _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleForgotPassword() {
    // อีเมลที่พิมพ์ค้างไว้คือคำตอบของหน้าถัดไปอยู่แล้ว — ส่งต่อไปเลย
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: appFont(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    // Social login completed via deep link handled in AppProvider.
    if (app.isLoggedIn && _isSocialLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _socialLoadingProvider = null);
          _finishLogin();
        }
      });
    }

    // Show error surfaced from AppProvider deep link handler.
    final socialError = app.pendingSocialError;
    if (socialError != null) {
      app.clearPendingSocialError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _socialLoadingProvider = null);
          _showSnack(socialError);
        }
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        // หน้าเดียวไหลยาว ไม่มีแผ่นทับอีกแล้ว รูปจึงเป็นแถบหัวที่จางลงไปหาสี
        // พื้นหน้า แล้วฟอร์มวางต่อบนพื้นเดียวกัน — โครงเดียวกับหน้าสมัครสมาชิก
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _LoginHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: _LoginForm(
                  emailController: _emailController,
                  passwordController: _passwordController,
                  isPasswordVisible: _isPasswordVisible,
                  isLoading: _isLoading,
                  socialLoadingProvider: _socialLoadingProvider,
                  onTogglePassword: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                  onLogin: _isLoading ? null : _handleLogin,
                  onRegister: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  onApple: _handleAppleLogin,
                  onGoogle: () => _handleSocialLogin('google'),
                  onFacebook: () => _handleSocialLogin('facebook'),
                  onLine: () => _handleSocialLogin('line'),
                  onForgot: _handleForgotPassword,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แถบรูปหัวหน้า — จางลงไปหาสีพื้นหน้าจอที่ขอบล่าง จึงไม่มีรอยต่อให้เห็นว่า
/// เป็นคนละชั้นกัน โครงเดียวกับ `_RegisterHeader` เพื่อให้สองหน้าของ auth
/// อ่านเป็นชุดเดียวกัน
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  /// สูงกว่าหัวหน้าสมัครสมาชิก (260) เพราะต้องมีที่ให้ครึ่งล่างค่อยๆ จางเข้าหา
  /// สีพื้น โดยที่ตัวหนังสือยังอยู่ในโซนมืดพอจะอ่านออก
  static const double _height = 300;

  /// จุดที่เริ่มจางเข้าหาสีพื้นหน้าจอ
  static const double _fadeStart = 0.58;

  /// จำนวนจุดที่ซอยเฉดช่วงจาง
  ///
  /// [LinearGradient] ลากเส้นตรงระหว่างสองจุดที่ติดกัน ถ้าซอยหยาบ รอยต่อของแต่
  /// ละช่วงจะกลายเป็น "หักศอก" ที่ตาอ่านเป็นเส้นพาดขวาง (Mach band) — ของเดิม
  /// ใช้แค่ 4 จุดแล้วช่วงสุดท้ายกระโดดจากดำ 50% ไปสีพื้นทึบใน 15% ของความสูง
  /// วัดความโค้งได้แรงสุดที่ 85% พอดีกับตำแหน่งเส้นที่เห็น 16 จุดดันรอยต่อที่
  /// แรงสุดลงไปที่ ~94% ซึ่งสองฝั่งเป็นสีพื้นเกือบเท่ากันแล้วจึงมองไม่เห็น
  static const int _fadeSteps = 16;

  static double _smoothstep(double x) => x * x * (3 - 2 * x);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final isDark = AppTheme.isDark(context);
    final bgFade = AppTheme.background(context);
    // ถามที่ "route ของหน้านี้" ไม่ใช่ที่ navigator ทั้งเส้น — หน้าเข้าสู่ระบบ
    // ตัวเดียวกันนี้ถูกฝังอยู่ในแท็บโปรไฟล์ด้วย ถ้าถาม Navigator.canPop จะได้
    // true ทันทีที่มีหน้าอื่น (เช่น หน้าทริป) ถูก push ทับแท็บอยู่ แล้วค่านั้น
    // ค้างอยู่ต่อเพราะ canPop ไม่ใช่ dependency ที่ทำให้ rebuild — ปุ่มย้อนกลับ
    // จึงโผล่บนแท็บและกดแล้ว pop หน้าเดียวที่มีทิ้งจนจอดำ
    final canPop = ModalRoute.canPopOf(context) ?? false;

    return SizedBox(
      height: _height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            ApiConfig.mediaUrl('/images/khaochangphueak.webp'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF065F46), Color(0xFF052E24)],
                ),
              ),
            ),
          ),
          // สองชั้นแยกกัน ไม่ใช่เฉดเดียวที่ไล่จากดำไปสีพื้น — การไล่ข้ามจากดำ
          // โปร่งไปหาสีอ่อนทึบในเฉดเดียวคือสิ่งที่ทำให้เกิดแถบหมอกสว่างพาดขวาง
          //
          // ชั้นที่ 1: ม่านดำสำหรับให้ตัวหนังสืออ่านออก ไล่เป็นเส้นตรงล้วน
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: isDark ? 0.42 : 0.34),
                  Colors.black.withValues(alpha: isDark ? 0.60 : 0.52),
                ],
              ),
            ),
          ),
          // ชั้นที่ 2: สีพื้นหน้าจอค่อยๆ ทึบขึ้นจนกลืนกับหน้าที่อยู่ใต้แถบ
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bgFade.withValues(alpha: 0),
                  for (var i = 0; i < _fadeSteps; i++)
                    bgFade.withValues(
                      alpha: _smoothstep(i / (_fadeSteps - 1)),
                    ),
                ],
                stops: [
                  0,
                  for (var i = 0; i < _fadeSteps; i++)
                    _fadeStart + (1 - _fadeStart) * i / (_fadeSteps - 1),
                ],
              ),
            ),
          ),
          if (canPop)
            Positioned(
              top: topPad + 8,
              left: 12,
              child: _GlassBackButton(
                // maybePop ไม่ใช่ pop — ถ้าไม่มีอะไรให้ถอย ให้ไม่เกิดอะไรขึ้น
                // ดีกว่าดันหน้าสุดท้ายออกจนเหลือจอเปล่า
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            // อยู่เหนือจุดที่เริ่มจาง (58%) — วัดคอนทราสต์ในแถบนี้ได้ 6.5:1
            bottom: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'เข้าสู่ระบบ',
                  style: appFont(
                    fontSize: AppText.sizeHero,
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
                  'ยินดีต้อนรับกลับ พร้อมออกเดินทางอีกครั้งหรือยัง',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.4,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 8,
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

// ─── Login Sheet ──────────────────────────────────────────────────────────────

class _LoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final bool isLoading;
  final String? socialLoadingProvider;
  final VoidCallback? onLogin;
  final VoidCallback onRegister;
  final VoidCallback onTogglePassword;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onLine;
  final VoidCallback onForgot;

  const _LoginForm({
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.isLoading,
    required this.socialLoadingProvider,
    required this.onLogin,
    required this.onRegister,
    required this.onTogglePassword,
    required this.onApple,
    required this.onGoogle,
    required this.onFacebook,
    required this.onLine,
    required this.onForgot,
  });

  bool get _isBusy => isLoading || socialLoadingProvider != null;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Social login – Apple first and most prominent (Apple
            // guideline 4.8), other providers in a row below.
            _SocialRow(
              socialLoadingProvider: socialLoadingProvider,
              isBusy: _isBusy,
              onApple: onApple,
              onGoogle: onGoogle,
              onFacebook: onFacebook,
              onLine: onLine,
            ),

            const SizedBox(height: 22),
            const _DividerOr(),
            const SizedBox(height: 22),

            // Email + password grouped into one inset card with a
            // hairline divider — the calm, native iOS form look.
            _CredentialsCard(
              emailController: emailController,
              passwordController: passwordController,
              isPasswordVisible: isPasswordVisible,
              onTogglePassword: onTogglePassword,
              onSubmitted: (_) => onLogin?.call(),
            ),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgot,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'ลืมรหัสผ่าน?',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Login button
            _LoginButton(isLoading: isLoading, onPressed: onLogin),

            const SizedBox(height: 20),
            // ลิงก์สมัครสมาชิกย้ายมาท้ายหน้า — หัวเรื่องไปอยู่บนรูปแล้ว และคน
            // ที่ยังไม่มีบัญชีจะรู้ตัวตอนอ่านตัวเลือกครบแล้ว ไม่ใช่ตั้งแต่บรรทัดแรก
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'ยังไม่มีบัญชี? ',
                    style: appFont(
                      color: AppTheme.textSecondary,
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: onRegister,
                    child: Text(
                      'สมัครสมาชิกฟรี',
                      style: appFont(
                        color: AppTheme.primaryColor,
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _LegalNote(),
          ],
        ),
      ),
    );
  }
}

// ─── Social Row ───────────────────────────────────────────────────────────────

class _SocialRow extends StatelessWidget {
  final String? socialLoadingProvider;
  final bool isBusy;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onLine;

  const _SocialRow({
    required this.socialLoadingProvider,
    required this.isBusy,
    required this.onApple,
    required this.onGoogle,
    required this.onFacebook,
    required this.onLine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sign in with Apple — official black button style, given top billing
        // and full width so it reads as the primary option (Apple guideline 4.8).
        _AppleSignInButton(
          isLoading: socialLoadingProvider == 'apple',
          onPressed: isBusy ? null : onApple,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SocialTile(
                mark: const _GoogleMark(),
                label: 'Google',
                isLoading: socialLoadingProvider == 'google',
                onPressed: isBusy ? null : onGoogle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialTile(
                mark: const _FacebookMark(),
                label: 'Facebook',
                isLoading: socialLoadingProvider == 'facebook',
                onPressed: isBusy ? null : onFacebook,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialTile(
                mark: const _LineMark(),
                label: 'LINE',
                isLoading:
                    socialLoadingProvider == 'line' ||
                    socialLoadingProvider == 'callback',
                onPressed: isBusy ? null : onLine,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Sign in with Apple ───────────────────────────────────────────────────────

/// Follows Apple's official "black" Sign in with Apple button style: solid black
/// fill, white Apple logo + label, generous touch target. Kept as a custom build
/// so we control the loading state and Thai localisation while matching the spec.
class _AppleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _AppleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Optical nudge — the glyph sits slightly high otherwise.
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2.5),
                        child: Icon(Icons.apple, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ลงชื่อเข้าด้วย Apple',
                        style: appFont(
                          color: Colors.white,
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w600,
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

class _SocialTile extends StatelessWidget {
  final Widget mark;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SocialTile({
    required this.mark,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 26,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : mark,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: appFont(
                  color: AppTheme.textMain,
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Divider ──────────────────────────────────────────────────────────────────

class _DividerOr extends StatelessWidget {
  const _DividerOr();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.border(context), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'หรือใช้อีเมล',
            style: appFont(
              color: AppTheme.textSecondary,
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.border(context), height: 1)),
      ],
    );
  }
}

// ─── Credentials Fields ───────────────────────────────────────────────────────

/// Email and password as two distinct, separated fields. Grouping related-but-
/// independent inputs with clear spacing (rather than fusing them) keeps each
/// target obvious and gives the form breathing room.
class _CredentialsCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final VoidCallback onTogglePassword;
  final ValueChanged<String>? onSubmitted;

  const _CredentialsCard({
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.onTogglePassword,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FieldRow(
          controller: emailController,
          hint: 'อีเมลของคุณ',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _FieldRow(
          controller: passwordController,
          hint: 'รหัสผ่าน',
          icon: Icons.lock_outline_rounded,
          obscureText: !isPasswordVisible,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
          suffix: _ToggleVisibilityButton(
            isVisible: isPasswordVisible,
            onTap: onTogglePassword,
          ),
        ),
      ],
    );
  }
}

/// A single self-contained input field (its own rounded card + hairline border)
/// with a subtle focus highlight.
class _FieldRow extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _FieldRow({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
  });

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_rebuild);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: focused ? Colors.white : AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: focused
              ? AppTheme.primaryColor.withValues(alpha: 0.6)
              : AppTheme.border(context),
          width: focused ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        cursorColor: AppTheme.primaryColor,
        style: appFont(
          color: AppTheme.textMain,
          fontSize: AppText.sizeSubtitle,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: appFont(
            color: AppTheme.mutedText(context),
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 10),
            child: Icon(
              widget.icon,
              size: 20,
              color: focused ? AppTheme.primaryColor : AppTheme.mutedText(context),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

class _ToggleVisibilityButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onTap;

  const _ToggleVisibilityButton({required this.isVisible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: isVisible ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน',
      icon: Icon(
        isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        size: 20,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}

// ─── Login Button ─────────────────────────────────────────────────────────────

class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.975 : 1.0,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            color: enabled ? AppTheme.primaryColor : AppTheme.border(context),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: widget.isLoading
                  ? Row(
                      key: const ValueKey('loading'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'กำลังเข้าสู่ระบบ...',
                          style: appFont(
                            color: Colors.white,
                            fontSize: AppText.sizeSubtitle,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('ready'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'เข้าสู่ระบบ',
                          style: appFont(
                            color: enabled
                                ? Colors.white
                                : AppTheme.mutedText(context),
                            fontSize: AppText.sizeTitle,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: enabled
                              ? Colors.white
                              : AppTheme.mutedText(context),
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Legal Note ───────────────────────────────────────────────────────────────

class _LegalNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'การเข้าสู่ระบบถือว่าคุณยอมรับนโยบายความเป็นส่วนตัวและเงื่อนไขการใช้งานของเรา',
      textAlign: TextAlign.center,
      style: appFont(
        color: AppTheme.mutedText(context),
        fontSize: AppText.sizeCaption,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ─── Glass Back Button ────────────────────────────────────────────────────────

class _GlassBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GlassBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: MinTapTarget(child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.surface(context).withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20,
            ),
          )),
        ),
      ),
    );
  }
}

// ─── Brand Marks ──────────────────────────────────────────────────────────────

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/google_2025.svg',
      width: 26,
      height: 26,
      fit: BoxFit.contain,
    );
  }
}

class _FacebookMark extends StatelessWidget {
  const _FacebookMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: Text(
        'f',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: AppText.sizeH1,
          fontWeight: FontWeight.w900,
          height: 0.98,
        ),
      ),
    );
  }
}

class _LineMark extends StatelessWidget {
  const _LineMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 26,
      height: 26,
      child: CustomPaint(painter: _LineMarkPainter()),
    );
  }
}

class _LineMarkPainter extends CustomPainter {
  const _LineMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 2, size.width - 2, size.height - 5),
      Radius.circular(size.width * 0.26),
    );
    final paint = Paint()
      ..color = const Color(0xFF06C755)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bubble, paint);

    final tail = Path()
      ..moveTo(size.width * 0.44, size.height - 3)
      ..lineTo(size.width * 0.36, size.height - 0.2)
      ..lineTo(size.width * 0.56, size.height - 3)
      ..close();
    canvas.drawPath(tail, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'LINE',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: AppText.sizeMicro,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2 - 1.2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Public re-exports kept for backward compat ───────────────────────────────

class PremiumTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const PremiumTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<PremiumTextField> {
  late final FocusNode _focusNode;

  bool get _hasFocus => _focusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_rebuild);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final borderColor = _hasFocus
        ? AppTheme.primaryColor.withValues(alpha: 0.72)
        : AppTheme.border(context);
    final fillColor = _hasFocus
        ? AppTheme.surface(context)
        : AppTheme.fieldSurface(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 56,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: borderColor, width: _hasFocus ? 1.3 : 1),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        cursorColor: AppTheme.primaryColor,
        style: appFont(
          color: AppTheme.textMain,
          fontSize: AppText.sizeSubtitle,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: appFont(
            color: AppTheme.mutedText(context),
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            widget.icon,
            size: 21,
            color: _hasFocus
                ? AppTheme.primaryColor
                : AppTheme.textSecondary.withValues(alpha: 0.66),
          ),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isVisible;
  final VoidCallback onToggleVisibility;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.isVisible,
    required this.onToggleVisibility,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumTextField(
      controller: controller,
      hintText: hintText,
      icon: Icons.lock_outline_rounded,
      obscureText: !isVisible,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      suffix: IconButton(
        onPressed: onToggleVisibility,
        tooltip: isVisible ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน',
        visualDensity: VisualDensity.compact,
        icon: Icon(
          isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          size: 20,
          color: AppTheme.textSecondary.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
