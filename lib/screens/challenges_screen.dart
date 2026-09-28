import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medal_social.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// ชื่อไอคอนของชาเลนจ์ (จาก ChallengeService) → IconData
IconData challengeIconFor(String name) => switch (name) {
  'event_available' => Icons.event_available_rounded,
  'trending_up' => Icons.trending_up_rounded,
  'hiking' => Icons.hiking_rounded,
  'landscape' => Icons.landscape_rounded,
  'flag' => Icons.flag_rounded,
  'map' => Icons.map_rounded,
  _ => Icons.emoji_events_rounded,
};

/// ชาเลนจ์รายเดือน/รายปี (GET /me/challenges) — เป้าที่ชวนให้กลับมาเดินอีก
/// นับจากเหรียญพิชิต ใช้ตัวเลข GPS ก่อนถ้าบันทึกไว้
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  ChallengeBoard? _board;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final board = await context.read<AppProvider>().fetchChallenges();
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _board == null;
      });
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
          'ชาเลนจ์',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error
          ? _Retry(
              onRetry: () {
                setState(() => _loading = true);
                _load();
              },
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _load,
              child: _content(_board!),
            ),
    );
  }

  Widget _content(ChallengeBoard board) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Text(
          'นับจากทริปที่เดินจบและได้เหรียญ ถ้าบันทึก GPS ไว้จะใช้ระยะและความสูงที่เดินจริง',
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w600,
            color: AppTheme.mutedText(context),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _PeriodHeader(title: 'เดือนนี้', period: board.month),
        const SizedBox(height: 10),
        for (final c in board.month.challenges) ...[
          ChallengeCard(challenge: c),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        _PeriodHeader(title: 'ปีนี้', period: board.year),
        const SizedBox(height: 10),
        for (final c in board.year.challenges) ...[
          ChallengeCard(challenge: c),
          const SizedBox(height: 10),
        ],
        if (board.history.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'ความสำเร็จที่ผ่านมา (${board.history.length})',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 10),
          for (final h in board.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HistoryRow(item: h),
            ),
        ],
      ],
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  final String title;
  final ChallengePeriod period;

  const _PeriodHeader({required this.title, required this.period});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            '$title · ${period.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          period.daysLeft > 0
              ? 'เหลืออีก ${period.daysLeft} วัน'
              : 'วันสุดท้าย',
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}

/// การ์ดชาเลนจ์หนึ่งใบ — ไอคอน ชื่อ คำอธิบาย แถบความคืบหน้า
class ChallengeCard extends StatelessWidget {
  final ChallengeItem challenge;

  const ChallengeCard({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    final done = challenge.completed;
    final accent = done ? const Color(0xFFB45309) : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.tintOf(context, accent),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done
                  ? Icons.emoji_events_rounded
                  : challengeIconFor(challenge.icon),
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        challenge.title,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ),
                    if (done)
                      Text(
                        'สำเร็จแล้ว',
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  challenge.description,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  child: LinearProgressIndicator(
                    value: challenge.progress,
                    minHeight: 7,
                    backgroundColor: AppTheme.border(context),
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  challenge.progressLabel,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
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

class _HistoryRow extends StatelessWidget {
  final ChallengeHistoryItem item;

  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFB45309),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.periodLabel,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  final VoidCallback onRetry;

  const _Retry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppTheme.mutedText(context),
            ),
            const SizedBox(height: 12),
            Text(
              'โหลดชาเลนจ์ไม่สำเร็จ',
              style: appFont(
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(
                'ลองใหม่',
                style: appFont(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
