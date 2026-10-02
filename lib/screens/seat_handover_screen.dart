import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/travel_widgets.dart';

/// หน้า "ส่งต่อที่นั่ง" — คนที่ไปไม่ได้ (น้ำท่วม ป่วย ติดงาน) ออกลิงก์ให้คนอื่น
/// มารับที่นั่งไปแทน ที่นั่งจะได้ไม่ว่างเปล่า
///
/// กติกาทั้งหมด (เส้นตาย ใครส่งที่นั่งไหนได้ โอนสิทธิ์ดูแลการจองได้ไหม) มาจาก
/// GET bookings/{ref}/handovers หน้านี้แค่วาดตามนั้น ดู SeatHandoverService
class SeatHandoverScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const SeatHandoverScreen({super.key, required this.booking});

  @override
  State<SeatHandoverScreen> createState() => _SeatHandoverScreenState();
}

class _SeatHandoverScreenState extends State<SeatHandoverScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int? _busyPassengerId;

  String get _ref => textOf(widget.booking['booking_ref']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().seatHandovers(_ref);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _loading = false;
      });
    }
  }

  String _cleanError(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  bool _ownershipDisabled(Map<String, dynamic> seat) {
    final data = _data;
    if (data == null) return true;
    return data['can_transfer_ownership'] != true &&
        textOf(data['open_ownership_passenger_id']) !=
            textOf(seat['passenger_id']);
  }

  Future<void> _create(Map<String, dynamic> seat) async {
    final draft = await showModalBottomSheet<_HandoverDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => _HandoverDraftSheet(
        seatName: textOf(seat['name'], 'ผู้เดินทาง'),
        showOwnership: textOf(_data?['viewer_role']) == 'owner',
        ownershipDisabled: _ownershipDisabled(seat),
        ownershipReason: textOf(_data?['ownership_blocked_reason']),
        ownershipDefault:
            !_ownershipDisabled(seat) && seat['is_owner_seat_guess'] == true,
      ),
    );
    if (draft == null || !mounted) return;

    final passengerId = int.tryParse(textOf(seat['passenger_id'])) ?? 0;
    setState(() => _busyPassengerId = passengerId);
    try {
      final created = await context.read<AppProvider>().createSeatHandover(
        _ref,
        passengerId: passengerId,
        transfersOwnership: draft.transfersOwnership,
        note: draft.note.isEmpty ? null : draft.note,
      );
      await _load();
      if (!mounted) return;
      await _share(textOf(created['url']));
    } catch (e) {
      if (mounted) AppSnack.error(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => _busyPassengerId = null);
    }
  }

  Future<void> _cancel(Map<String, dynamic> seat) async {
    final open = asMap(seat['open_handover']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ยกเลิกลิงก์นี้?',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'ลิงก์ที่ส่งไปแล้วจะใช้รับที่นั่งไม่ได้อีก',
          style: appFont(fontSize: AppText.sizeLabel, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ใช่ตอนนี้'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยกเลิกลิงก์'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final passengerId = int.tryParse(textOf(seat['passenger_id'])) ?? 0;
    setState(() => _busyPassengerId = passengerId);
    try {
      await context.read<AppProvider>().cancelSeatHandover(
        _ref,
        int.tryParse(textOf(open['id'])) ?? 0,
      );
      await _load();
      if (mounted) AppSnack.show(context, 'ยกเลิกลิงก์แล้ว');
    } catch (e) {
      if (mounted) AppSnack.error(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => _busyPassengerId = null);
    }
  }

  Future<void> _share(String url) async {
    if (url.isEmpty) return;
    final schedule = asMap(widget.booking['schedule']);
    final title = textOf(asMap(schedule['trip'])['title'], 'ทริป');
    final date = departureText(schedule);

    final message = StringBuffer('ฝากไปทริป "$title" แทนหน่อยนะ 🙏\n');
    if (date.isNotEmpty && date != '-') message.writeln('ออกเดินทาง $date');
    message
      ..writeln()
      ..writeln('กดลิงก์นี้ กรอกข้อมูลของตัวเอง แล้วที่นั่งเป็นของคุณเลย')
      ..writeln(url);

    try {
      await SharePlus.instance.share(
        ShareParams(text: message.toString().trim(), subject: title),
      );
    } catch (_) {
      await _copy(url);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      AppSnack.show(context, 'คัดลอกลิงก์แล้ว ส่งให้คนที่จะไปแทนได้เลย');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: const Text('ส่งต่อที่นั่ง'),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.primaryColor,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    _IntroCard(deadlineLabel: textOf(data?['deadline_label'])),
                    const SizedBox(height: 16),
                    if (_error != null)
                      _Banner(
                        color: AppTheme.dangerColor,
                        icon: Icons.error_outline_rounded,
                        text: _error!,
                      )
                    else if (data != null) ...[
                      if (data['available'] != true) ...[
                        _Banner(
                          color: AppTheme.warningColor,
                          icon: Icons.info_outline_rounded,
                          text: textOf(data['blocked_reason']),
                        ),
                        const SizedBox(height: 16),
                      ],
                      for (final raw in asList(data['seats'])) ...[
                        _SeatCard(
                          seat: asMap(raw),
                          busy:
                              _busyPassengerId ==
                              int.tryParse(textOf(asMap(raw)['passenger_id'])),
                          onCreate: () => _create(asMap(raw)),
                          onCancel: () => _cancel(asMap(raw)),
                          onShare: () => _share(
                            textOf(asMap(asMap(raw)['open_handover'])['url']),
                          ),
                          onCopy: () => _copy(
                            textOf(asMap(asMap(raw)['open_handover'])['url']),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (asList(data['history']).isNotEmpty)
                        _HistoryList(history: asList(data['history'])),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _HandoverDraft {
  final bool transfersOwnership;
  final String note;

  const _HandoverDraft({required this.transfersOwnership, required this.note});
}

class _HandoverDraftSheet extends StatefulWidget {
  final String seatName;
  final bool showOwnership;
  final bool ownershipDisabled;
  final String ownershipReason;
  final bool ownershipDefault;

  const _HandoverDraftSheet({
    required this.seatName,
    required this.showOwnership,
    required this.ownershipDisabled,
    required this.ownershipReason,
    required this.ownershipDefault,
  });

  @override
  State<_HandoverDraftSheet> createState() => _HandoverDraftSheetState();
}

class _HandoverDraftSheetState extends State<_HandoverDraftSheet> {
  late bool _ownership = widget.ownershipDefault;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ส่งต่อที่นั่งของ ${widget.seatName}',
              style: appFont(
                fontSize: AppText.sizeTitle,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 14),
            if (widget.showOwnership) ...[
              Material(
                color: AppTheme.subtleSurface(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: CheckboxListTile(
                  value: _ownership,
                  onChanged: widget.ownershipDisabled
                      ? null
                      : (v) => setState(() => _ownership = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppTheme.primaryColor,
                  title: Text(
                    'นี่คือที่นั่งของฉันเอง',
                    style: appFont(
                      fontWeight: FontWeight.w800,
                      fontSize: AppText.sizeBody,
                    ),
                  ),
                  subtitle: Text(
                    widget.ownershipDisabled &&
                            widget.ownershipReason.isNotEmpty
                        ? widget.ownershipReason
                        : 'คนรับจะได้ดูแลการจองนี้แทนคุณ และการจองจะออกจากบัญชีของคุณ',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: widget.ownershipDisabled
                          ? AppTheme.warningColor
                          : AppTheme.mutedText(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _note,
              maxLength: 300,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'ฝากข้อความถึงคนรับ (ไม่บังคับ)',
                hintText: 'เช่น ฝากไปแทนด้วยนะ ค่าที่นั่งโอนมาที่เราได้เลย',
                filled: true,
                fillColor: AppTheme.fieldSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryCTAButton(
              label: 'สร้างลิงก์และส่งต่อ',
              icon: Icons.send_rounded,
              onPressed: () => Navigator.pop(
                context,
                _HandoverDraft(
                  transfersOwnership: _ownership,
                  note: _note.text.trim(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String deadlineLabel;

  const _IntroCard({required this.deadlineLabel});

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
          Text(
            'ไปไม่ได้? ส่งที่นั่งให้คนอื่นไปแทน',
            style: appFont(
              fontSize: AppText.sizeH2,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'สร้างลิงก์แล้วส่งให้คนที่จะไปแทน เขากรอกข้อมูลของตัวเอง แล้วที่นั่ง'
            'เป็นของเขาทันที ได้เข้าแชทกลุ่มและดูกำหนดการในบัญชีของเขาเอง',
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.mutedText(context),
              height: 1.55,
            ),
          ),
          if (deadlineLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'ส่งต่อได้ถึง $deadlineLabel',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'ค่าที่นั่งตกลงกันเองระหว่างคุณกับคนรับ ทางเราไม่คืนเงินและไม่เก็บเพิ่ม',
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.mutedText(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  final Map<String, dynamic> seat;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onCancel;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  const _SeatCard({
    required this.seat,
    required this.busy,
    required this.onCreate,
    required this.onCancel,
    required this.onShare,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final open = asMap(seat['open_handover']);
    final hasOpen = open.isNotEmpty;
    final seatLabel = textOf(seat['seat_label']);
    final nickname = textOf(seat['nickname']);
    final memberName = textOf(seat['member_name']);
    final meta = [
      if (seatLabel.isNotEmpty) 'ที่นั่ง $seatLabel',
      if (seat['is_mine'] == true) 'ที่นั่งของคุณ',
      if (seat['is_mine'] != true && memberName.isNotEmpty) 'บัญชี $memberName',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: hasOpen
              ? AppTheme.warningColor.withValues(alpha: 0.5)
              : AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname.isNotEmpty
                          ? '${textOf(seat['name'], 'ผู้เดินทาง')} ($nickname)'
                          : textOf(seat['name'], 'ผู้เดินทาง'),
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasOpen)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'รอคนรับ',
                    style: appFont(
                      fontSize: AppText.sizeMicro,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasOpen) ...[
            if (open['transfers_ownership'] == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'คนรับจะได้ดูแลการจองนี้แทนคุณด้วย',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              'ลิงก์ใช้ได้คนเดียว · หมดอายุ ${_formatInstant(textOf(open['expires_at']))}',
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onShare,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('ส่งลิงก์'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: busy ? null : onCopy,
                  child: const Text('คัดลอก'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerColor,
                  ),
                  onPressed: busy ? null : onCancel,
                  child: const Text('ยกเลิก'),
                ),
              ],
            ),
          ] else if (seat['can_hand_over'] == true)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onCreate,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('ส่งต่อที่นั่งนี้'),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<dynamic> history;

  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'ประวัติการส่งต่อ',
          style: appFont(
            fontSize: AppText.sizeLabel,
            fontWeight: FontWeight.w800,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 8),
        for (final raw in history)
          Builder(
            builder: (context) {
              final h = asMap(raw);
              final claimed = textOf(h['status']) == 'claimed';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      claimed
                          ? Icons.check_circle_rounded
                          : Icons.link_off_rounded,
                      size: 17,
                      color: claimed
                          ? AppTheme.successColor
                          : AppTheme.mutedText(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        claimed
                            ? '${textOf(h['previous_name'])} → ${textOf(h['new_name'])} · ${_formatInstant(textOf(h['claimed_at']))}'
                            : 'ลิงก์ของ ${textOf(h['previous_name'])} ${textOf(h['status']) == 'expired' ? 'หมดอายุ' : 'ถูกยกเลิก'}',
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          color: AppTheme.onSurface(context),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
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

const _thaiMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

/// เวลาจริงจากเซิร์ฟเวอร์ (ISO UTC) → เวลาไทย "3 ต.ค. 21:00 น."
String _formatInstant(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '-';
  final t = parsed.toUtc().add(const Duration(hours: 7));
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_thaiMonths[t.month - 1]} $hh:$mm น.';
}
