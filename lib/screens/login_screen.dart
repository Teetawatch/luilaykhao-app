import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final bool popOnSuccess;

  const LoginScreen({super.key, this.onLoginSuccess, this.popOnSuccess = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _animController;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _socialLoadingProvider;

  bool get _isSocialLoading => _socialLoadingProvider != null;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canPop = Navigator.canPop(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF071A1A),
        body: Stack(
          children: [
            // ── Background image ──────────────────────────────────────
            Positioned.fill(
              child: _HeroBg(imageUrl: ApiConfig.mediaUrl('/images/khaochangphueak.webp')),
            ),

            // ── Back button ───────────────────────────────────────────
            if (canPop)
              Positioned(
                top: padding.top + 12,
                left: 16,
                child: _GlassBackButton(onPressed: () => Navigator.pop(context)),
              ),

            // ── Bottom sheet ──────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(0, 1 - _slideAnim.value),
                  child: Opacity(opacity: _fadeAnim.value, child: child),
                ),
                child: _LoginSheet(
                  size: size,
                  padding: padding,
                  bottomInset: bottomInset,
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
                  onGoogle: () => _handleSocialLogin('google'),
                  onFacebook: () => _handleSocialLogin('facebook'),
                  onLine: () => _handleSocialLogin('line'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Background ──────────────────────────────────────────────────────────

class _HeroBg extends StatelessWidget {
  final String imageUrl;
  const _HeroBg({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo
        imageUrl.isEmpty
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF044C4D), Color(0xFF082A2A)],
                  ),
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF044C4D), Color(0xFF082A2A)],
                    ),
                  ),
                ),
              ),
        // Vignette – darkens bottom for sheet contrast
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x28000000),
                Color(0x00000000),
                Color(0xCC071A1A),
                Color(0xFF071A1A),
              ],
              stops: [0.0, 0.30, 0.72, 1.0],
            ),
          ),
        ),
        // Headline block
        Positioned(
          left: 28,
          right: 28,
          bottom: 310,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF06C755).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF06C755).withValues(alpha: 0.38),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'พร้อมเดินทางทุกเส้นทาง',
                      style: GoogleFonts.anuphan(
                        color: const Color(0xFF34D399),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'ยินดีต้อนรับ\nกลับมา',
                style: GoogleFonts.anuphan(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'การผจญภัยครั้งใหม่รอคุณอยู่',
                style: GoogleFonts.anuphan(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Login Sheet ──────────────────────────────────────────────────────────────

class _LoginSheet extends StatelessWidget {
  final Size size;
  final EdgeInsets padding;
  final double bottomInset;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final bool isLoading;
  final String? socialLoadingProvider;
  final VoidCallback? onLogin;
  final VoidCallback onRegister;
  final VoidCallback onTogglePassword;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onLine;

  const _LoginSheet({
    required this.size,
    required this.padding,
    required this.bottomInset,
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.isLoading,
    required this.socialLoadingProvider,
    required this.onLogin,
    required this.onRegister,
    required this.onTogglePassword,
    required this.onGoogle,
    required this.onFacebook,
    required this.onLine,
  });

  bool get _isBusy => isLoading || socialLoadingProvider != null;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF2FFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, 28, 24, bottomInset + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    'เข้าสู่ระบบ',
                    style: GoogleFonts.anuphan(
                      color: AppTheme.textMain,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'ยังไม่มีบัญชี? ',
                        style: GoogleFonts.anuphan(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: onRegister,
                        child: Text(
                          'สมัครสมาชิกฟรี',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Social login – priority row
                  _SocialRow(
                    socialLoadingProvider: socialLoadingProvider,
                    isBusy: _isBusy,
                    onGoogle: onGoogle,
                    onFacebook: onFacebook,
                    onLine: onLine,
                  ),

                  const SizedBox(height: 24),
                  const _DividerOr(),
                  const SizedBox(height: 24),

                  // Email field
                  _SheetTextField(
                    controller: emailController,
                    hint: 'อีเมลของคุณ',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  // Password field
                  _SheetTextField(
                    controller: passwordController,
                    hint: 'รหัสผ่าน',
                    icon: Icons.lock_outline_rounded,
                    obscureText: !isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onLogin?.call(),
                    suffix: _ToggleVisibilityButton(
                      isVisible: isPasswordVisible,
                      onTap: onTogglePassword,
                    ),
                  ),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
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
                        style: GoogleFonts.anuphan(
                          fontSize: 13,
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
                  _LegalNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Social Row ───────────────────────────────────────────────────────────────

class _SocialRow extends StatelessWidget {
  final String? socialLoadingProvider;
  final bool isBusy;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onLine;

  const _SocialRow({
    required this.socialLoadingProvider,
    required this.isBusy,
    required this.onGoogle,
    required this.onFacebook,
    required this.onLine,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : mark,
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.anuphan(
                  color: AppTheme.textMain,
                  fontSize: 12,
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
        const Expanded(
          child: Divider(color: Color(0xFFE2E8F0), height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'หรือใช้อีเมล',
            style: GoogleFonts.anuphan(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0xFFE2E8F0), height: 1),
        ),
      ],
    );
  }
}

// ─── Text Field ───────────────────────────────────────────────────────────────

class _SheetTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _SheetTextField({
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
  State<_SheetTextField> createState() => _SheetTextFieldState();
}

class _SheetTextFieldState extends State<_SheetTextField> {
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
        color: focused ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused
              ? AppTheme.primaryColor.withValues(alpha: 0.6)
              : const Color(0xFFE2E8F0),
          width: focused ? 1.5 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        cursorColor: AppTheme.primaryColor,
        style: GoogleFonts.anuphan(
          color: AppTheme.textMain,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: GoogleFonts.anuphan(
            color: const Color(0xFF94A3B8),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 18, right: 12),
            child: Icon(
              widget.icon,
              size: 20,
              color: focused ? AppTheme.primaryColor : const Color(0xFF94A3B8),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
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

  const _ToggleVisibilityButton({
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        size: 20,
        color: const Color(0xFF94A3B8),
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
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                  )
                : null,
            color: enabled ? null : const Color(0xFFCBD5E1),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
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
                          style: GoogleFonts.anuphan(
                            color: Colors.white,
                            fontSize: 16,
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
                          style: GoogleFonts.anuphan(
                            color: enabled ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: enabled ? Colors.white : const Color(0xFF94A3B8),
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
      style: GoogleFonts.anuphan(
        color: const Color(0xFF94A3B8),
        fontSize: 11,
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
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
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
    return const SizedBox(
      width: 26,
      height: 26,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromLTWH(
      stroke,
      stroke,
      size.width - stroke * 2,
      size.height - stroke * 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    void arc(Color color, double start, double sweep) {
      paint.color = color;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    arc(const Color(0xFFEA4335), -2.75, 1.18);
    arc(const Color(0xFFFBBC05), 2.45, 1.18);
    arc(const Color(0xFF34A853), 1.05, 1.55);
    arc(const Color(0xFF4285F4), -0.15, 1.25);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    final center = Offset(size.width * 0.52, size.height * 0.50);
    canvas.drawLine(
      center,
      Offset(size.width * 0.86, size.height * 0.50),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          fontSize: 24,
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
          fontSize: 6.4,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: _hasFocus ? 1.3 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _hasFocus ? 0.07 : 0.035),
            blurRadius: _hasFocus ? 18 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        cursorColor: AppTheme.primaryColor,
        style: GoogleFonts.anuphan(
          color: AppTheme.textMain,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.anuphan(
            color: const Color(0xFF9AA0A6),
            fontSize: 15,
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
