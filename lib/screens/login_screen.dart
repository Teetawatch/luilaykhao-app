import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
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

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _socialLoadingProvider;
  StreamSubscription<Uri>? _linkSubscription;

  bool get _isSocialLoading => _socialLoadingProvider != null;

  @override
  void initState() {
    super.initState();
    _initSocialDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initSocialDeepLinks() async {
    final appLinks = AppLinks();
    _linkSubscription = appLinks.uriLinkStream.listen(
      (uri) => _handleSocialCallback(uri),
      onError: (_) {
        if (mounted) {
          setState(() => _socialLoadingProvider = null);
        }
      },
    );

    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      await _handleSocialCallback(initialLink);
    }
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
      if (!launched) {
        throw Exception('ไม่สามารถเปิดหน้าล็อกอินได้');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _socialLoadingProvider = null);
      }
    }
  }

  Future<void> _handleSocialCallback(Uri uri) async {
    if (!_isSocialCallback(uri) || !mounted) return;

    final params = uri.queryParameters;
    final error = params['error'];
    if (error != null && error.isNotEmpty) {
      final message = params['message']?.isNotEmpty == true
          ? params['message']!
          : 'เข้าสู่ระบบผ่าน Social ไม่สำเร็จ';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _socialLoadingProvider = null);
      return;
    }

    final token = params['token'];
    final userParam = params['user'];
    if (token == null || token.isEmpty || userParam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลเข้าสู่ระบบจาก Social')),
      );
      setState(() => _socialLoadingProvider = null);
      return;
    }

    setState(() => _socialLoadingProvider = 'callback');

    try {
      final decodedUser = jsonDecode(userParam);
      await context.read<AppProvider>().completeSocialLogin(
        token: token,
        user: Map<String, dynamic>.from(decodedUser as Map),
      );
      if (!mounted) return;
      _finishLogin();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _socialLoadingProvider = null);
      }
    }
  }

  bool _isSocialCallback(Uri uri) {
    return uri.scheme == 'luilaykhao' &&
        uri.host == 'auth' &&
        uri.path == '/social/callback';
  }

  void _finishLogin() {
    final onLoginSuccess = widget.onLoginSuccess;
    final navigator = Navigator.of(context);
    if (widget.popOnSuccess && navigator.canPop()) {
      navigator.pop();
    }
    onLoginSuccess?.call();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกอีเมลและรหัสผ่าน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AppProvider>().login(email, password);
      if (mounted) {
        _finishLogin();
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
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppTheme.background(context),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
            final compactHeight = constraints.maxHeight < 700;
            final heroHeight = math
                .min(
                  math.max(
                    constraints.maxHeight * (compactHeight ? 0.24 : 0.3),
                    compactHeight ? 170.0 : 220.0,
                  ),
                  compactHeight ? 240.0 : 300.0,
                )
                .toDouble();

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomInset + 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeroHeaderSection(height: heroHeight),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compactHeight ? 18 : 24,
                        24,
                        32 + bottomSafeArea,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PremiumTextField(
                            controller: _emailController,
                            hintText: 'อีเมลของคุณ',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          PasswordField(
                            controller: _passwordController,
                            hintText: 'รหัสผ่าน',
                            isVisible: _isPasswordVisible,
                            onToggleVisibility: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                            onSubmitted: (_) =>
                                _isLoading ? null : _handleLogin(),
                          ),
                          const SizedBox(height: 12),
                          RememberMeSection(
                            value: _rememberMe,
                            onChanged: (value) =>
                                setState(() => _rememberMe = value ?? false),
                            onForgotPassword: () {},
                          ),
                          const SizedBox(height: 24),
                          PrimaryLoginButton(
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _handleLogin,
                          ),
                          const SizedBox(height: 16),
                          SecondaryActions(
                            onRegister: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                            onPhoneLogin: () {},
                            onBiometricLogin: () {},
                          ),
                          const SizedBox(height: 24),
                          const DividerWithLabel(label: 'หรือดำเนินการด้วย'),
                          const SizedBox(height: 16),
                          SocialLoginSection(
                            loadingProvider: _socialLoadingProvider,
                            onGoogle: () => _handleSocialLogin('google'),
                            onFacebook: () => _handleSocialLogin('facebook'),
                            onLine: () => _handleSocialLogin('line'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HeroHeaderSection extends StatelessWidget {
  final double height;

  const HeroHeaderSection({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final imageUrl = ApiConfig.mediaUrl('/images/khaochangphueak.webp');

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.28),
                  const Color(0xFFF8F8F8),
                ],
                stops: const [0, 0.58, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ยินดีต้อนรับกลับมา',
                  style: GoogleFonts.anuphan(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'การผจญภัยครั้งใหม่รอคุณอยู่',
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (Navigator.canPop(context))
            Positioned(
              top: topPadding + 8,
              left: 16,
              child: _BackButton(onPressed: () => Navigator.pop(context)),
            ),
        ],
      ),
    );
  }
}

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
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() => setState(() {});

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

class RememberMeSection extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onForgotPassword;

  const RememberMeSection({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppTheme.primaryColor,
                  checkColor: Colors.white,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.32),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'จำฉันไว้',
                style: GoogleFonts.anuphan(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'ลืมรหัสผ่าน?',
            style: GoogleFonts.anuphan(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class PrimaryLoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const PrimaryLoginButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<PrimaryLoginButton> createState() => _PrimaryLoginButtonState();
}

class _PrimaryLoginButtonState extends State<PrimaryLoginButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_isEnabled) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _isPressed ? 0.985 : 1,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: _isEnabled ? const Color(0xFF087F5B) : Colors.grey[300],
            boxShadow: _isEnabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF087F5B).withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: widget.isLoading
                  ? Row(
                      key: const ValueKey('loading'),
                      mainAxisAlignment: MainAxisAlignment.center,
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
                          'กำลังเข้าสู่ระบบ',
                          style: GoogleFonts.anuphan(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('ready'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'เข้าสู่ระบบ',
                          style: GoogleFonts.anuphan(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryActions extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onPhoneLogin;
  final VoidCallback onBiometricLogin;

  const SecondaryActions({
    super.key,
    required this.onRegister,
    required this.onPhoneLogin,
    required this.onBiometricLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ยังไม่มีบัญชี? ',
              style: GoogleFonts.anuphan(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton(
              onPressed: onRegister,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'สมัครสมาชิก',
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DividerWithLabel extends StatelessWidget {
  final String label;

  const DividerWithLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2E4E7))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: AppTheme.textSecondary.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E4E7))),
      ],
    );
  }
}

class SocialLoginSection extends StatelessWidget {
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onLine;
  final String? loadingProvider;

  const SocialLoginSection({
    super.key,
    required this.onGoogle,
    required this.onFacebook,
    required this.onLine,
    this.loadingProvider,
  });

  bool get _isBusy => loadingProvider != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                icon: const _GoogleMark(),
                label: 'Google',
                accentColor: const Color(0xFF4285F4),
                isLoading: loadingProvider == 'google',
                onPressed: _isBusy ? null : onGoogle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                icon: const _FacebookMark(),
                label: 'Facebook',
                accentColor: const Color(0xFF1877F2),
                isLoading: loadingProvider == 'facebook',
                onPressed: _isBusy ? null : onFacebook,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SocialButton(
          icon: const _LineMark(),
          label: 'LINE',
          accentColor: const Color(0xFF06C755),
          isFullWidth: true,
          isLoading: loadingProvider == 'line' || loadingProvider == 'callback',
          onPressed: _isBusy ? null : onLine,
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color accentColor;
  final bool isFullWidth;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.accentColor = AppTheme.primaryColor,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isFullWidth ? 54 : 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.onSurface(context),
          backgroundColor: AppTheme.surface(context),
          disabledBackgroundColor: AppTheme.subtleSurface(context),
          side: BorderSide(
            color: isFullWidth
                ? accentColor.withValues(alpha: 0.22)
                : AppTheme.border(context),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isFullWidth ? 18 : 16),
          ),
          padding: EdgeInsets.symmetric(horizontal: isFullWidth ? 18 : 14),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textMain,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
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
      size.width - (stroke * 2),
      size.height - (stroke * 2),
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
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      child: Text(
        'f',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 23,
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
      width: 24,
      height: 24,
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
