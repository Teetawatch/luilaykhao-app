import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../services/notification_navigator.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/app_snack.dart';
import '../widgets/travel_widgets.dart';
import 'login_screen.dart';

/// หน้า "รับการจองเข้าบัญชีนี้" — ปลายทางของ SMS "ทีมงานเปิดการจองให้คุณแล้ว"
/// (https://luilaykhao.com/claim/TOKEN หรือ luilaykhao://claim/TOKEN)
///
/// ทีมงานจองให้ลูกค้าก่อนลูกค้าจะมีบัญชี ใบจองจึงไปเกาะบัญชีเงาไว้ ลูกค้าโหลดแอป
/// แล้วจะเข้าด้วย LINE, Google หรืออีเมลก็ได้ — ถือลิงก์ที่ส่งเข้าเบอร์ตัวเองมาแล้ว
/// กดปุ่มเดียว ใบจองทั้งหมดก็ย้ายเข้าบัญชีที่ล็อกอินอยู่ ไม่ต้องตั้งรหัสผ่าน
/// และไม่ต้องรู้เลขที่จอง (ทางนั้นยังอยู่ที่ [ClaimBookingScreen])
class AccountClaimScreen extends StatefulWidget {
  final String token;

  const AccountClaimScreen({super.key, required this.token});

  @override
  State<AccountClaimScreen> createState() => _AccountClaimScreenState();
}

class _AccountClaimScreenState extends State<AccountClaimScreen> {
  Map<String, dynamic>? _preview;
  bool _loading = true;
  String? _loadError;
  bool _linkUsed = false;
  bool _submitting = false;
  String? _error;

  /// เปิดหน้าล็อกอินจากหน้านี้อยู่ — ล็อกอินเสร็จแล้วต้องพากลับมาที่ปุ่มรับการจอง
  /// เอง เพราะ LINE/Google กลับเข้าแอปผ่าน deep link และหน้าล็อกอินไม่ได้ปิด
  /// ตัวเองทุกทาง (สมัครใหม่ก็ซ้อนอีกหน้าหนึ่ง)
  bool _awaitingLogin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _linkUsed = false;
    });
    try {
      final data = await context.read<AppProvider>().previewAccountClaim(
        widget.token,
      );
      if (!mounted) return;
      setState(() {
        _preview = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _linkUsed = e.statusCode == 404;
        _loadError = e.isNetworkError
            ? 'เชื่อมต่ออินเทอร์เน็ตไม่ได้ ลองใหม่อีกครั้ง'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _clean(e);
      });
    }
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  void _openLogin() {
    setState(() {
      _awaitingLogin = true;
      _error = null;
    });
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  /// ล็อกอินสำเร็จ (ทางไหนก็ได้) — ปิดทุกหน้าที่ซ้อนอยู่บนหน้านี้ กลับมาที่ปุ่มรับ
  void _returnAfterLogin() {
    final route = ModalRoute.of(context);
    _awaitingLogin = false;
    if (route == null || !route.isActive || route.isCurrent) return;
    Navigator.of(context).popUntil((r) => r == route);
  }

  Future<void> _switchAccount() async {
    final app = context.read<AppProvider>();
    await app.logout();
    if (!mounted) return;
    _openLogin();
  }

  Future<void> _accept() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().acceptAccountClaim(
        widget.token,
      );
      if (!mounted) return;
      final moved = (data['bookings_moved'] as num?)?.toInt() ?? 0;
      HapticFeedback.mediumImpact();
      AppSnack.success(
        context,
        moved > 0
            ? 'รับการจอง $moved รายการเข้าบัญชีของคุณแล้ว'
            : 'เชื่อมบัญชีเรียบร้อยแล้ว',
      );
      Navigator.of(context).pop(true);
      NotificationNavigator.goToBookings();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.isNetworkError
            ? 'เชื่อมต่ออินเทอร์เน็ตไม่ได้ ลองกดอีกครั้ง'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _clean(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final loggedIn = app.isLoggedIn;

    if (loggedIn && _awaitingLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _awaitingLogin) _returnAfterLogin();
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: const Text('รับการจองเข้าบัญชี'),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: _loadError != null
                    ? _errorState(loggedIn)
                    : _content(app, loggedIn),
              ),
      ),
    );
  }

  List<Widget> _errorState(bool loggedIn) {
    return [
      _Banner(
        color: _linkUsed ? AppTheme.warningColor : AppTheme.dangerColor,
        icon: _linkUsed ? Icons.link_off_rounded : Icons.error_outline_rounded,
        text: _linkUsed
            ? 'ลิงก์นี้ถูกใช้ไปแล้ว ถ้าคุณกดรับไปแล้ว การจองจะอยู่ในหน้า '
                  '"การจองของฉัน" ของบัญชีที่ใช้รับ'
            : _loadError!,
      ),
      const SizedBox(height: 20),
      if (_linkUsed && loggedIn)
        PrimaryCTAButton(
          label: 'ไปที่การจองของฉัน',
          icon: Icons.confirmation_number_rounded,
          onPressed: () {
            Navigator.of(context).pop();
            NotificationNavigator.goToBookings();
          },
        )
      else if (!_linkUsed)
        PrimaryCTAButton(
          label: 'ลองใหม่',
          icon: Icons.refresh_rounded,
          onPressed: _load,
        ),
      const SizedBox(height: 16),
      Text(
        'ถ้ายังหาการจองไม่เจอ ทักทีมงานในไลน์ได้เลย '
        'หรือใช้เมนู "ผูกการจองที่ทีมงานจองให้" ด้วยเลขที่การจอง',
        textAlign: TextAlign.center,
        style: appFont(
          fontSize: AppText.sizeCaption,
          color: AppTheme.mutedText(context),
          height: 1.5,
        ),
      ),
    ];
  }

  List<Widget> _content(AppProvider app, bool loggedIn) {
    final preview = _preview ?? const <String, dynamic>{};
    final bookings = (preview['bookings'] is List)
        ? (preview['bookings'] as List).map(asMap).toList()
        : const <Map<String, dynamic>>[];
    final name = textOf(preview['name']);
    final phoneHint = textOf(preview['phone_hint']);

    return [
      _IntroCard(name: name, phoneHint: phoneHint),
      const SizedBox(height: 16),
      if (bookings.isEmpty)
        const _Banner(
          color: AppTheme.warningColor,
          icon: Icons.info_outline_rounded,
          text:
              'ลิงก์นี้ไม่มีการจองที่ยังใช้งานอยู่แล้ว '
              'ถ้าคิดว่าไม่ถูกต้อง ทักทีมงานในไลน์ได้เลย',
        )
      else ...[
        for (final booking in bookings) ...[
          _BookingTile(booking: booking),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        if (loggedIn) ..._acceptSection(app) else ..._loginSection(),
      ],
    ];
  }

  List<Widget> _loginSection() {
    return [
      Text(
        'เข้าสู่ระบบก่อน แล้วกดรับการจอง',
        style: appFont(
          fontSize: AppText.sizeTitle,
          fontWeight: FontWeight.w900,
          color: AppTheme.onSurface(context),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'ใช้ LINE, Google หรืออีเมลก็ได้ — เลือกบัญชีที่คุณจะใช้แอปต่อ '
        'การจองจะย้ายเข้าบัญชีนั้น ไม่ต้องตั้งรหัสผ่านใหม่',
        style: appFont(
          fontSize: AppText.sizeLabel,
          color: AppTheme.mutedText(context),
          height: 1.55,
        ),
      ),
      const SizedBox(height: 18),
      PrimaryCTAButton(
        label: 'เข้าสู่ระบบเพื่อรับการจอง',
        icon: Icons.login_rounded,
        onPressed: _openLogin,
      ),
    ];
  }

  List<Widget> _acceptSection(AppProvider app) {
    final user = app.user ?? const <String, dynamic>{};
    final accountName = textOf(user['name'], 'บัญชีของคุณ');
    final email = textOf(user['email']);
    // อีเมลที่ระบบสร้างให้ตอนเข้าด้วย LINE/Facebook (…@social.local) ไม่ใช่ของลูกค้า
    final showEmail = email.isNotEmpty && !email.endsWith('.local');

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_circle_rounded,
              color: AppTheme.primaryColor,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'จะย้ายเข้าบัญชีที่ใช้อยู่',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accountName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  if (showEmail)
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        _Banner(
          color: AppTheme.dangerColor,
          icon: Icons.error_outline_rounded,
          text: _error!,
        ),
      ],
      const SizedBox(height: 18),
      PrimaryCTAButton(
        label: _submitting ? 'กำลังย้ายการจอง...' : 'รับการจองเข้าบัญชีนี้',
        icon: Icons.download_done_rounded,
        loading: _submitting,
        onPressed: _submitting ? null : _accept,
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: _submitting ? null : _switchAccount,
          child: Text(
            'ไม่ใช่บัญชีนี้? เปลี่ยนบัญชี',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
      ),
    ];
  }
}

class _IntroCard extends StatelessWidget {
  final String name;
  final String phoneHint;

  const _IntroCard({required this.name, required this.phoneHint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.selectedTint(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? 'ทีมงานจองให้คุณแล้ว' : 'สวัสดีคุณ$name',
            style: appFont(
              fontSize: AppText.sizeH2,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            phoneHint.isEmpty
                ? 'ทีมงานเปิดการจองด้านล่างนี้ไว้ให้คุณ '
                      'กดรับเข้าบัญชีแล้วจะดูรายละเอียด ชำระเงิน และเช็คอินในแอปได้ทันที'
                : 'ทีมงานเปิดการจองด้านล่างนี้ไว้ให้เบอร์ที่ลงท้าย $phoneHint '
                      'กดรับเข้าบัญชีแล้วจะดูรายละเอียด ชำระเงิน และเช็คอินในแอปได้ทันที',
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.mutedText(context),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(textOf(booking['departure_date']));
    final ref = textOf(booking['booking_ref']);
    final awaitingPayment = textOf(booking['status']) == 'pending';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.landscape_rounded,
            color: AppTheme.primaryColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textOf(booking['trip_title'], 'ทริปของคุณ'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (date != null) thaiDateShort(date),
                    if (ref.isNotEmpty) ref,
                  ].join(' · '),
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          if (awaitingPayment)
            Text(
              'รอชำระเงิน',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: AppTheme.warningColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Banner({required this.color, required this.icon, required this.text});

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
