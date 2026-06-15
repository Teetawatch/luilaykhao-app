import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// "ชวนเพื่อน" — referral hub. Shows the user's invite code, a share CTA, how
/// the programme works, and the list of friends they've invited. Designed to
/// Apple HIG: calm surfaces, generous spacing, one clear primary action.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppProvider>().fetchReferral();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'โหลดข้อมูลไม่สำเร็จ ลองอีกครั้ง';
        });
      }
    }
  }

  Map<String, dynamic> get _data =>
      context.watch<AppProvider>().referral ?? const {};

  String _text(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  int _int(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  Future<void> _copyCode() async {
    final code = _text(_data['code']);
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryColor,
          content: Text(
            'คัดลอกโค้ดแล้ว',
            style: appFont(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  Future<void> _share() async {
    final msg = _text(_data['share_message'], _text(_data['share_url']));
    if (msg.isEmpty) return;
    HapticFeedback.selectionClick();
    try {
      await SharePlus.instance.share(
        ShareParams(text: msg, subject: 'ชวนเพื่อนมาเที่ยวลุยลายเขา'),
      );
    } catch (_) {
      await _copyCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text(
          'ชวนเพื่อน',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  _HeroCard(
                    referrerPoints: _int(_data['referrer_points']),
                    refereePoints: _int(_data['referee_points']),
                  ),
                  const SizedBox(height: 20),
                  _CodeCard(
                    code: _text(_data['code']),
                    onCopy: _copyCode,
                    onShare: _share,
                  ),
                  const SizedBox(height: 28),
                  _SummaryRow(
                    invited: _int((_data['summary'] ?? {})['invited']),
                    rewarded: _int((_data['summary'] ?? {})['rewarded']),
                    points: _int((_data['summary'] ?? {})['points_earned']),
                  ),
                  const SizedBox(height: 28),
                  const _SectionLabel('วิธีการ'),
                  const SizedBox(height: 12),
                  const _HowItWorks(),
                  const SizedBox(height: 28),
                  const _SectionLabel('เพื่อนที่คุณชวน'),
                  const SizedBox(height: 12),
                  _FriendsList(
                    friends: List<Map<String, dynamic>>.from(
                      (_data['friends'] as List? ?? const []).map(
                        (e) => Map<String, dynamic>.from(e as Map),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final int referrerPoints;
  final int refereePoints;

  const _HeroCard({required this.referrerPoints, required this.refereePoints});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF047857), Color(0xFF10B981)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'ชวนเพื่อน รับแต้มฟรีทั้งคู่',
            style: appFont(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เมื่อเพื่อนสมัครด้วยโค้ดของคุณและจองทริปแรกสำเร็จ '
            'คุณรับ $referrerPoints แต้ม และเพื่อนรับ $refereePoints แต้มทันที',
            style: appFont(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Code + share ──────────────────────────────────────────────────────────────

class _CodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _CodeCard({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Text(
            'โค้ดเชิญเพื่อนของคุณ',
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code.isEmpty ? '—' : code,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.primaryColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onShare,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 19),
              label: Text(
                'แชร์คำเชิญ',
                style: appFont(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary ──────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int invited;
  final int rewarded;
  final int points;

  const _SummaryRow({
    required this.invited,
    required this.rewarded,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryTile(
          value: '$invited',
          label: 'ชวนแล้ว',
          icon: Icons.group_rounded,
        ),
        const SizedBox(width: 12),
        _SummaryTile(
          value: '$rewarded',
          label: 'สำเร็จ',
          icon: Icons.verified_rounded,
        ),
        const SizedBox(width: 12),
        _SummaryTile(
          value: '$points',
          label: 'แต้มที่ได้',
          icon: Icons.stars_rounded,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _SummaryTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: appFont(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: appFont(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── How it works ─────────────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        icon: Icons.ios_share_rounded,
        title: 'แชร์โค้ดให้เพื่อน',
        body: 'ส่งโค้ดหรือลิงก์เชิญให้เพื่อนผ่านแอปไหนก็ได้',
      ),
      (
        icon: Icons.person_add_alt_1_rounded,
        title: 'เพื่อนสมัครด้วยโค้ด',
        body: 'เพื่อนกรอกโค้ดของคุณตอนสมัครสมาชิก',
      ),
      (
        icon: Icons.celebration_rounded,
        title: 'รับแต้มทั้งคู่',
        body: 'เมื่อเพื่อนจองทริปแรกสำเร็จ ทั้งคู่รับแต้มทันที',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      steps[i].icon,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${steps[i].title}',
                          style: appFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].body,
                          style: appFont(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < steps.length - 1)
              Divider(
                height: 1,
                color: AppTheme.border(context).withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Friends list ─────────────────────────────────────────────────────────────

class _FriendsList extends StatelessWidget {
  final List<Map<String, dynamic>> friends;

  const _FriendsList({required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.group_add_rounded,
              size: 40,
              color: AppTheme.primaryColor.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีเพื่อนที่ชวน',
              style: appFont(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'แชร์โค้ดของคุณให้เพื่อน แล้วมาดูความคืบหน้าที่นี่',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < friends.length; i++) ...[
            _FriendTile(friend: friends[i]),
            if (i < friends.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppTheme.border(context).withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;

  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final rewarded = '${friend['status']}' == 'rewarded';
    final name = '${friend['name'] ?? 'เพื่อนของคุณ'}';
    final points = int.tryParse('${friend['points'] ?? 0}') ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.10),
            child: Text(
              name.characters.isEmpty ? '?' : name.characters.first,
              style: appFont(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rewarded ? 'จองทริปแรกแล้ว' : 'รอจองทริปแรก',
                  style: appFont(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(rewarded: rewarded, points: points),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool rewarded;
  final int points;

  const _StatusChip({required this.rewarded, required this.points});

  @override
  Widget build(BuildContext context) {
    final color = rewarded ? AppTheme.primaryColor : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rewarded ? '+$points แต้ม' : 'รอดำเนินการ',
        style: appFont(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ─── Shared bits ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: AppTheme.mutedText(context),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(
                'ลองอีกครั้ง',
                style: appFont(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
