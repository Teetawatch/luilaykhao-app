import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// "แต้มสะสม" — loyalty hub where customers spend points. Three tabs: redeemable
/// rewards (defined by admin), the coupons they own, and points history.
/// Designed to Apple HIG: a calm hero, a segmented control, and clear cards.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int _tab = 0;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<AppProvider>().loadAccountData();
    } catch (_) {
      // Non-fatal — cached data stays on screen.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  int _points(AppProvider app) =>
      int.tryParse('${(app.loyalty ?? const {})['points'] ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final loyalty = app.loyalty ?? const {};

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text(
          'แต้มสะสม',
          style: GoogleFonts.anuphan(
            color: AppTheme.onSurface(context),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            _PointsHero(loyalty: Map<String, dynamic>.from(loyalty)),
            const SizedBox(height: 20),
            _Segmented(
              index: _tab,
              labels: const ['ของรางวัล', 'คูปองของฉัน', 'ประวัติ'],
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 18),
            if (_tab == 0)
              _RewardsTab(
                rewards: app.rewards,
                points: _points(app),
                onRedeem: _handleRedeem,
              )
            else if (_tab == 1)
              _CouponsTab(coupons: app.coupons)
            else
              _HistoryTab(
                transactions: List<dynamic>.from(
                  (loyalty['transactions'] as List? ?? const []),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRedeem(Map<String, dynamic> reward) async {
    final name = '${reward['name'] ?? 'ของรางวัล'}';
    final cost = int.tryParse('${reward['points_required'] ?? 0}') ?? 0;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmRedeemSheet(name: name, cost: cost),
    );
    if (confirmed != true || !mounted) return;

    final id = int.tryParse('${reward['id']}');
    if (id == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await context.read<AppProvider>().redeemReward(id);
      if (!mounted) return;
      Navigator.of(context).pop(); // close loader
      HapticFeedback.heavyImpact();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _RedeemSuccessSheet(rewardName: name, result: result),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
          content: Text(
            'แลกไม่สำเร็จ ลองอีกครั้ง',
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
  }
}

// ─── Reward helpers ───────────────────────────────────────────────────────────

IconData _rewardIcon(String? type) => switch (type) {
  'discount_percent' => Icons.percent_rounded,
  'discount_fixed' => Icons.savings_rounded,
  'free_item' => Icons.redeem_rounded,
  _ => Icons.card_giftcard_rounded,
};

String _rewardValue(Map<String, dynamic> r) {
  final v = num.tryParse('${r['discount_value'] ?? ''}');
  switch ('${r['type']}') {
    case 'discount_percent':
      return v == null ? '-' : 'ลด ${_trim(v)}%';
    case 'discount_fixed':
      return v == null ? '-' : 'ลด ฿${_trim(v)}';
    case 'free_item':
      return 'ของแถมฟรี';
    default:
      return '-';
  }
}

String _trim(num v) => v == v.truncate() ? v.toInt().toString() : v.toString();

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _PointsHero extends StatelessWidget {
  final Map<String, dynamic> loyalty;

  const _PointsHero({required this.loyalty});

  @override
  Widget build(BuildContext context) {
    final points = int.tryParse('${loyalty['points'] ?? 0}') ?? 0;
    final lifetime = int.tryParse('${loyalty['lifetime_points'] ?? 0}') ?? 0;
    final tierLabel = '${loyalty['tier_label'] ?? 'Regular Member'}';
    final next = loyalty['next_tier'] as Map?;
    final at = int.tryParse('${next?['at'] ?? 0}') ?? 0;
    final needed = int.tryParse('${next?['points_needed'] ?? 0}') ?? 0;
    final progress = at <= 0 ? 1.0 : (lifetime / at).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF065F46), Color(0xFF0F9D77)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tierLabel,
                      style: GoogleFonts.anuphan(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'แต้มคงเหลือ',
            style: GoogleFonts.anuphan(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _format(points),
                style: GoogleFonts.anuphan(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'แต้ม',
                style: GoogleFonts.anuphan(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'คุณอยู่ในระดับสูงสุดแล้ว 🎉'
                : 'อีก ${_format(needed)} แต้ม เลื่อนเป็น ${next['tier']}',
            style: GoogleFonts.anuphan(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _format(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

// ─── Segmented control ────────────────────────────────────────────────────────

class _Segmented extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _Segmented({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: index == i
                        ? AppTheme.surface(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: index == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.anuphan(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: index == i
                          ? AppTheme.primaryColor
                          : AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Rewards tab ──────────────────────────────────────────────────────────────

class _RewardsTab extends StatelessWidget {
  final List<dynamic> rewards;
  final int points;
  final ValueChanged<Map<String, dynamic>> onRedeem;

  const _RewardsTab({
    required this.rewards,
    required this.points,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final active = rewards
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((r) => r['is_active'] != false)
        .toList();

    if (active.isEmpty) {
      return const _EmptyHint(
        icon: Icons.card_giftcard_rounded,
        title: 'ยังไม่มีของรางวัล',
        body: 'โปรดติดตามของรางวัลใหม่ ๆ เร็ว ๆ นี้',
      );
    }

    return Column(
      children: [
        for (final r in active) ...[
          _RewardCard(reward: r, points: points, onRedeem: onRedeem),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  final Map<String, dynamic> reward;
  final int points;
  final ValueChanged<Map<String, dynamic>> onRedeem;

  const _RewardCard({
    required this.reward,
    required this.points,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final cost = int.tryParse('${reward['points_required'] ?? 0}') ?? 0;
    final stock = reward['stock'];
    final outOfStock = stock != null && (int.tryParse('$stock') ?? 0) <= 0;
    final affordable = points >= cost && !outOfStock;
    final desc = '${reward['description'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _rewardIcon('${reward['type']}'),
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reward['name'] ?? ''}',
                      style: GoogleFonts.anuphan(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _rewardValue(reward),
                      style: GoogleFonts.anuphan(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (desc.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              desc,
              style: GoogleFonts.anuphan(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                size: 17,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: 5),
              Text(
                '${_PointsHero._format(cost)} แต้ม',
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: affordable ? () => onRedeem(reward) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: AppTheme.mutedText(
                    context,
                  ).withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  outOfStock
                      ? 'หมดแล้ว'
                      : affordable
                      ? 'แลกเลย'
                      : 'แต้มไม่พอ',
                  style: GoogleFonts.anuphan(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Coupons tab ──────────────────────────────────────────────────────────────

class _CouponsTab extends StatelessWidget {
  final List<dynamic> coupons;

  const _CouponsTab({required this.coupons});

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) {
      return const _EmptyHint(
        icon: Icons.local_play_rounded,
        title: 'ยังไม่มีคูปอง',
        body: 'แลกของรางวัลด้วยแต้มเพื่อรับคูปองส่วนลด',
      );
    }

    return Column(
      children: [
        for (final c in coupons) ...[
          _CouponCard(coupon: Map<String, dynamic>.from(c as Map)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;

  const _CouponCard({required this.coupon});

  bool get _used => coupon['is_used'] == true;
  bool get _expired {
    final exp = DateTime.tryParse('${coupon['expires_at'] ?? ''}');
    return exp != null && exp.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final code = '${coupon['coupon_code'] ?? ''}';
    final spent = !_used && !_expired;
    final color = spent ? AppTheme.primaryColor : AppTheme.mutedText(context);

    return Opacity(
      opacity: spent ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _rewardIcon('${coupon['reward_type']}'),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${coupon['reward_name'] ?? 'คูปอง'}',
                    style: GoogleFonts.anuphan(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: spent
                        ? () {
                            Clipboard.setData(ClipboardData(text: code));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppTheme.primaryColor,
                                  content: Text(
                                    'คัดลอกโค้ดแล้ว',
                                    style: GoogleFonts.anuphan(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                          }
                        : null,
                    child: Text(
                      code,
                      style: GoogleFonts.spaceMono(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _CouponStatus(used: _used, expired: _expired),
          ],
        ),
      ),
    );
  }
}

class _CouponStatus extends StatelessWidget {
  final bool used;
  final bool expired;

  const _CouponStatus({required this.used, required this.expired});

  @override
  Widget build(BuildContext context) {
    final (label, color) = used
        ? ('ใช้แล้ว', AppTheme.mutedText(context))
        : expired
        ? ('หมดอายุ', AppTheme.errorColor)
        : ('พร้อมใช้', AppTheme.primaryColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ─── History tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<dynamic> transactions;

  const _HistoryTab({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const _EmptyHint(
        icon: Icons.history_rounded,
        title: 'ยังไม่มีประวัติแต้ม',
        body: 'แต้มจากการจองและการแลกจะแสดงที่นี่',
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
          for (var i = 0; i < transactions.length; i++) ...[
            _HistoryRow(tx: Map<String, dynamic>.from(transactions[i] as Map)),
            if (i < transactions.length - 1)
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

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> tx;

  const _HistoryRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final points = int.tryParse('${tx['points'] ?? 0}') ?? 0;
    final earn = '${tx['type']}' == 'earn' || points > 0;
    final color = earn ? AppTheme.primaryColor : AppTheme.errorColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
      child: Row(
        children: [
          Icon(
            earn ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${tx['description'] ?? '-'}',
              style: GoogleFonts.anuphan(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${earn ? '+' : ''}${points.abs() * (earn ? 1 : -1)}',
            style: GoogleFonts.anuphan(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheets & shared bits ─────────────────────────────────────────────────────

class _ConfirmRedeemSheet extends StatelessWidget {
  final String name;
  final int cost;

  const _ConfirmRedeemSheet({required this.name, required this.cost});

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 44,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 14),
          Text(
            'ยืนยันการแลก',
            style: GoogleFonts.anuphan(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ใช้ ${_PointsHero._format(cost)} แต้ม แลก "$name" ?',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: AppTheme.border(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'ยกเลิก',
                    style: GoogleFonts.anuphan(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'แลกเลย',
                    style: GoogleFonts.anuphan(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RedeemSuccessSheet extends StatelessWidget {
  final String rewardName;
  final Map<String, dynamic> result;

  const _RedeemSuccessSheet({required this.rewardName, required this.result});

  @override
  Widget build(BuildContext context) {
    final code = '${result['coupon_code'] ?? ''}';
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 34,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'แลกสำเร็จ!',
            style: GoogleFonts.anuphan(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rewardName,
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.primaryColor,
                    content: Text(
                      'คัดลอกโค้ดแล้ว',
                      style: GoogleFonts.anuphan(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    code,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceMono(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'แตะเพื่อคัดลอกโค้ด',
                    style: GoogleFonts.anuphan(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'เสร็จสิ้น',
                style: GoogleFonts.anuphan(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final Widget child;

  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(26),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
            icon,
            size: 44,
            color: AppTheme.primaryColor.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.anuphan(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
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
}
