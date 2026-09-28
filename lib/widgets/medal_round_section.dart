import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/medal_social.dart';
import '../models/trip_medal.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'app_snack.dart';

/// "ใครพิชิตรอบนี้" — เพื่อนที่เดินจบรอบเดียวกัน พร้อมปุ่มปรบมือให้กัน
///
/// วางบนพื้นเข้มของหน้ารายละเอียดเหรียญ (ตัวอักษรขาว) โหลดเองแยกจากหน้า —
/// โหลดไม่ได้ก็ซ่อนตัวเอง ไม่ทำให้หน้าเหรียญพัง
class MedalRoundSection extends StatefulWidget {
  final TripMedal medal;

  const MedalRoundSection({super.key, required this.medal});

  @override
  State<MedalRoundSection> createState() => _MedalRoundSectionState();
}

class _MedalRoundSectionState extends State<MedalRoundSection> {
  MedalRound? _round;
  bool _failed = false;

  /// เหรียญที่กำลังรอเซิร์ฟเวอร์ตอบ — กันกดรัวจนสถานะสลับไปมา
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final round = await context.read<AppProvider>().fetchMedalRound(
        widget.medal.id,
      );
      if (mounted) setState(() => _round = round);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// เปลี่ยนบนจอทันที แล้วค่อยยืนยันกับเซิร์ฟเวอร์ — ไม่สำเร็จก็คืนค่าเดิม
  Future<void> _toggle(MedalRoundEntry entry) async {
    if (_busy.contains(entry.medalId) || entry.isMe) return;
    HapticFeedback.lightImpact();

    final optimistic = entry.withKudos(
      kudoed: !entry.kudoedByMe,
      count: entry.kudosCount + (entry.kudoedByMe ? -1 : 1),
    );
    _replace(optimistic);
    setState(() => _busy.add(entry.medalId));

    try {
      final result = await context.read<AppProvider>().toggleMedalKudos(
        entry.medalId,
      );
      _replace(entry.withKudos(kudoed: result.kudoed, count: result.count));
    } catch (_) {
      _replace(entry);
      if (mounted) AppSnack.error(context, 'ปรบมือไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _busy.remove(entry.medalId));
    }
  }

  void _replace(MedalRoundEntry next) {
    final round = _round;
    if (round == null || !mounted) return;

    setState(() {
      _round = MedalRound(
        tripName: round.tripName,
        finishers: [
          for (final f in round.finishers) f.medalId == next.medalId ? next : f,
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    final soft = Colors.white.withValues(alpha: 0.7);

    if (_failed) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  round == null
                      ? 'คนที่พิชิตรอบนี้'
                      : 'คนที่พิชิตรอบนี้ (${round.finishers.length})',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (widget.medal.kudosCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              _kudosLine(widget.medal),
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: soft,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (round == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else if (round.finishers.length <= 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'รอบนี้มีคุณพิชิตคนเดียว — ชวนเพื่อนมาลุยด้วยกันทริปหน้านะ',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                  color: soft,
                ),
              ),
            )
          else
            for (final entry in round.finishers)
              _FinisherRow(
                entry: entry,
                busy: _busy.contains(entry.medalId),
                onKudos: () => _toggle(entry),
              ),
        ],
      ),
    );
  }

  static String _kudosLine(TripMedal medal) {
    final names = medal.kudosRecent;
    final others = medal.kudosCount - names.length;

    if (names.isEmpty) return '👏 เพื่อน ${medal.kudosCount} คนปรบมือให้คุณ';

    final joined = names.join(', ');
    return others > 0
        ? '👏 $joined และอีก $others คนปรบมือให้คุณ'
        : '👏 $joined ปรบมือให้คุณ';
  }
}

class _FinisherRow extends StatelessWidget {
  final MedalRoundEntry entry;
  final bool busy;
  final VoidCallback onKudos;

  const _FinisherRow({
    required this.entry,
    required this.busy,
    required this.onKudos,
  });

  @override
  Widget build(BuildContext context) {
    final initial = avatarInitial(entry.holderName);
    final avatar = entry.avatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            foregroundImage: avatar == null
                ? null
                : ResizeImage(NetworkImage(avatar), width: 108),
            onForegroundImageError: avatar == null ? null : (_, _) {},
            child: Text(
              initial,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isMe ? '${entry.holderName} (คุณ)' : entry.holderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  entry.finisherLabel,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF7CD78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.isMe)
            _KudosCount(count: entry.kudosCount)
          else
            Semantics(
              button: true,
              toggled: entry.kudoedByMe,
              label: entry.kudoedByMe
                  ? 'เลิกปรบมือให้ ${entry.holderName}'
                  : 'ปรบมือให้ ${entry.holderName}',
              child: GestureDetector(
                onTap: busy ? null : onKudos,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: entry.kudoedByMe
                        ? const Color(0xFFF7CD78)
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('👏', style: appFont(fontSize: AppText.sizeBody)),
                      const SizedBox(width: 5),
                      Text(
                        entry.kudosCount > 0 ? '${entry.kudosCount}' : 'ปรบมือ',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w800,
                          color: entry.kudoedByMe
                              ? const Color(0xFF3A2A06)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KudosCount extends StatelessWidget {
  final int count;

  const _KudosCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Text(
      count > 0 ? '👏 $count' : '',
      style: appFont(
        fontSize: AppText.sizeLabel,
        fontWeight: FontWeight.w800,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}

/// ตัวอักษรแทนรูปโปรไฟล์ — ข้ามสระหน้า (เ แ โ ใ ไ) ไม่งั้น "เจ" จะได้ "เ"
@visibleForTesting
String avatarInitial(String name) {
  const leading = {'เ', 'แ', 'โ', 'ใ', 'ไ'};

  for (final char in name.trim().characters) {
    if (!leading.contains(char) && char.trim().isNotEmpty) return char;
  }

  return '?';
}
