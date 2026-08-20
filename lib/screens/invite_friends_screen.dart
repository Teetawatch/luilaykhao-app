import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/travel_widgets.dart';

/// หน้า "เชิญเพื่อนร่วมทริป" — เจ้าของการจองสร้างลิงก์คำเชิญ ส่งให้เพื่อน แล้ว
/// เพื่อนเข้าร่วมการจองใบเดียวกันด้วยบัญชีของตัวเอง (ไม่ต้องจองใหม่/จ่ายเพิ่ม)
///
/// เดิมฟีเจอร์นี้ซ่อนอยู่ท้ายชีตรายละเอียดการจองเป็นปุ่มเดียว คนส่วนใหญ่จึงไม่รู้
/// ว่าเชิญเพื่อนได้ หน้านี้จึงอธิบายให้ครบว่าเพื่อนจะได้อะไรและต้องทำยังไงต่อ
class InviteFriendsScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const InviteFriendsScreen({super.key, required this.booking});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _roster;

  String get _ref => textOf(widget.booking['booking_ref']);

  /// หลังโหลดแล้วเชื่อ roster เป็นหลัก (หลังบ้านตัดสินสิทธิ์เอง) ระหว่างนั้น
  /// ใช้ค่าที่ติดมากับการจอง
  bool get _isOwner {
    final roster = _roster;
    if (roster != null && roster.containsKey('viewer_is_owner')) {
      return roster['viewer_is_owner'] == true;
    }
    return widget.booking['viewer_is_owner'] != false;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().bookingMembers(_ref);
      if (!mounted) return;
      setState(() {
        _roster = data;
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

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _createInvite() async {
    final label = await _askLabel();
    if (label == null || !mounted) return; // ยกเลิก

    setState(() => _busy = true);
    Map<String, dynamic>? invite;
    try {
      invite = await context.read<AppProvider>().createBookingInvite(
        _ref,
        label: label.isEmpty ? null : label,
      );
      await _load();
    } catch (e) {
      if (mounted) AppSnack.error(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (invite == null || !mounted) return;
    await _showInviteReady(
      url: textOf(invite['invite_url']),
      token: textOf(invite['invite_token']),
      label: textOf(invite['invite_label']),
    );
  }

  Future<void> _revoke(Map<String, dynamic> member) async {
    final name = _memberName(member);
    final isPending = textOf(member['status']) != 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPending ? 'ยกเลิกคำเชิญนี้?' : 'นำ$nameออก?',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          isPending
              ? 'ลิงก์ที่ส่งไปแล้วจะใช้ไม่ได้อีก และที่นั่งจะกลับมาให้เชิญคนใหม่ได้'
              : '$nameจะออกจากแชทกลุ่มและดูข้อมูลทริปนี้ไม่ได้อีก '
                    'แต่ที่นั่งในการจองยังอยู่ครบเหมือนเดิม',
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
            child: Text(isPending ? 'ยกเลิกคำเชิญ' : 'นำออก'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<AppProvider>().revokeBookingMember(
        _ref,
        int.tryParse(textOf(member['id'])) ?? 0,
      );
      await _load();
      if (mounted) {
        AppSnack.show(
          context,
          isPending ? 'ยกเลิกคำเชิญแล้ว' : 'นำสมาชิกออกแล้ว',
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, _cleanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ตั้งชื่อเล่นให้คำเชิญ — ไม่บังคับ แต่ช่วยให้เจ้าของจำได้ว่าลิงก์ไหนของใคร
  /// คืน `null` = ยกเลิก, `''` = ข้ามการตั้งชื่อ
  Future<String?> _askLabel() {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _SheetShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 14),
              Text(
                'ลิงก์นี้สำหรับใคร',
                style: appFont(
                  fontSize: AppText.sizeH2,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.onSurface(ctx),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ตั้งชื่อเล่นไว้กันสับสนตอนเชิญหลายคน — ข้ามได้ ไม่มีผลกับเพื่อน',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  color: AppTheme.mutedText(ctx),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
                decoration: InputDecoration(
                  hintText: 'เช่น บอม, พี่หนึ่ง',
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.fieldSurface(ctx),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryCTAButton(
                label: 'สร้างลิงก์คำเชิญ',
                icon: Icons.link_rounded,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(ctx, controller.text.trim());
                },
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('ข้าม ไม่ต้องตั้งชื่อ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ลิงก์พร้อมแล้ว — เน้นสองอย่างที่ต้องทำต่อ: แชร์ หรือคัดลอก
  Future<void> _showInviteReady({
    required String url,
    required String token,
    String label = '',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SheetShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.selectedTint(ctx),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ลิงก์คำเชิญพร้อมแล้ว',
                        style: appFont(
                          fontSize: AppText.sizeH2,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.onSurface(ctx),
                        ),
                      ),
                      Text(
                        label.isEmpty ? 'ส่งให้เพื่อนได้เลย' : 'สำหรับ $label',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          color: AppTheme.mutedText(ctx),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CodeBox(url: url, token: token),
            const SizedBox(height: 16),
            PrimaryCTAButton(
              label: 'แชร์ให้เพื่อน',
              icon: Icons.ios_share_rounded,
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(ctx);
                _shareInvite(url: url, token: token);
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _copy(url.isEmpty ? token : url),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('คัดลอกลิงก์'),
              ),
            ),
            const SizedBox(height: 14),
            const _NoteLine(
              icon: Icons.person_rounded,
              text: 'ลิงก์นี้ใช้ได้กับเพื่อนหนึ่งคน ถ้าจะชวนอีกคนให้สร้างลิงก์ใหม่',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) AppSnack.show(context, 'คัดลอกลิงก์คำเชิญแล้ว');
  }

  Future<void> _shareInvite({required String url, required String token}) async {
    final schedule = asMap(widget.booking['schedule']);
    final trip = asMap(schedule['trip']);
    final title = textOf(trip['title'], 'ทริป');
    final date = departureText(schedule);
    final link = url.isEmpty ? token : url;

    final message = StringBuffer('มาลุยทริป "$title" ด้วยกันครับ 🏞️\n');
    if (date.isNotEmpty && date != '-') message.writeln('ออกเดินทาง $date');
    message
      ..writeln()
      ..writeln('กดลิงก์นี้เพื่อเข้าร่วมการจองเดียวกันได้เลย')
      ..writeln(link);
    if (url.isNotEmpty && token.isNotEmpty) {
      message
        ..writeln()
        ..writeln('หรือเปิดแอปลุยเลเขา > การจองของฉัน > เข้าร่วม แล้ววางรหัสนี้')
        ..writeln(token);
    }

    try {
      await SharePlus.instance.share(
        ShareParams(text: message.toString().trim(), subject: title),
      );
    } catch (_) {
      await _copy(link);
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(widget.booking['schedule']);
    final trip = asMap(schedule['trip']);
    final roster = _roster;
    final members = roster == null ? const [] : asList(roster['members']);
    final canInviteMore = roster?['can_invite_more'] == true;
    final remaining = int.tryParse(textOf(roster?['remaining_slots'])) ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: const Text('เชิญเพื่อนร่วมทริป'),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primaryColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _TripSummaryCard(
                title: textOf(trip['title'], 'การจองของคุณ'),
                departure: departureText(schedule),
                bookingRef: textOf(widget.booking['booking_ref'], '-'),
                // ยังไม่รู้จำนวนที่เหลือจนกว่าจะโหลด roster สำเร็จ — อย่าเดาเป็น 0
                remaining: _loading || _error != null ? null : remaining,
              ),
              const SizedBox(height: 24),
              const _SectionHeading('เพื่อนที่เข้าร่วมจะได้อะไร'),
              const SizedBox(height: 12),
              const _BenefitList(),
              const SizedBox(height: 24),
              _SectionHeading(
                _loading || roster == null
                    ? 'สมาชิกในการจอง'
                    : 'สมาชิกในการจอง (${members.length + 1}/'
                          '${textOf(roster['max_members'], '-')})',
              ),
              const SizedBox(height: 12),
              if (_loading)
                const _RosterLoading()
              else if (_error != null)
                _ErrorNote(message: _error!, onRetry: _load)
              else ...[
                _OwnerTile(owner: asMap(roster?['owner'])),
                ...members.map((m) {
                  final member = asMap(m);
                  return _MemberRow(
                    member: member,
                    name: _memberName(member),
                    isOwnerView: _isOwner,
                    busy: _busy,
                    onShare: () => _shareInvite(
                      url: textOf(member['invite_url']),
                      token: textOf(member['invite_token']),
                    ),
                    onCopy: () => _copy(
                      textOf(
                        member['invite_url'],
                        textOf(member['invite_token']),
                      ),
                    ),
                    onRemove: () => _revoke(member),
                  );
                }),
                if (members.isEmpty) const _NoMembersYet(),
              ],
              const SizedBox(height: 24),
              const _SectionHeading('เพื่อนเข้าร่วมยังไง'),
              const SizedBox(height: 12),
              const _StepsCard(),
            ],
          ),
        ),
      ),
      // ปุ่มหลักติดขอบล่างไว้เสมอ — หน้านี้ยาวกว่าหนึ่งจอ ปุ่มที่อยู่ท้ายสุด
      // จะถูกมองข้ามได้ง่าย
      bottomNavigationBar: _BottomBar(
        child: _loading
            ? null
            : !_isOwner
            ? const _NoteLine(
                icon: Icons.info_outline_rounded,
                text: 'เฉพาะเจ้าของการจองเท่านั้นที่เชิญเพื่อนเพิ่มได้',
              )
            : canInviteMore
            ? PrimaryCTAButton(
                label: _busy ? 'กำลังสร้างลิงก์...' : 'สร้างลิงก์คำเชิญ',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: _busy ? null : _createInvite,
              )
            : const _NoteLine(
                icon: Icons.groups_rounded,
                text:
                    'เชิญครบตามจำนวนผู้เดินทางในการจองนี้แล้ว '
                    'ถ้าอยากชวนเพิ่ม ต้องเพิ่มที่นั่งหรือจองอีกใบ',
              ),
      ),
    );
  }

  String _memberName(Map<String, dynamic> member) {
    final user = asMap(member['user']);
    final candidates = [
      textOf(user['nickname']),
      textOf(user['name']),
      textOf(member['invite_label']),
      textOf(member['passenger_name']),
    ];
    return candidates.firstWhere(
      (value) => value.isNotEmpty,
      orElse: () => 'เพื่อนที่ถูกเชิญ',
    );
  }
}

// ─── Pieces ──────────────────────────────────────────────────────────────────

class _TripSummaryCard extends StatelessWidget {
  final String title;
  final String departure;
  final String bookingRef;
  final int? remaining;

  const _TripSummaryCard({
    required this.title,
    required this.departure,
    required this.bookingRef,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final slots = remaining;

    return Container(
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
            'ชวนเพื่อนเข้าการจองใบเดียวกัน',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: appFont(
              fontSize: AppText.sizeTitle,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (departure.isNotEmpty && departure != '-')
                _MetaPill(icon: Icons.event_rounded, text: departure),
              _MetaPill(
                icon: Icons.confirmation_number_rounded,
                text: bookingRef,
              ),
              if (slots != null)
                _MetaPill(
                  icon: Icons.event_seat_rounded,
                  text: slots > 0 ? 'เชิญได้อีก $slots คน' : 'เชิญครบแล้ว',
                  highlight: slots > 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _MetaPill({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? AppTheme.primaryColor
        : AppTheme.mutedText(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: highlight ? color : AppTheme.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;

  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: AppText.sizeLabel,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _BenefitList extends StatelessWidget {
  const _BenefitList();

  static const _items = <(IconData, String, String)>[
    (
      Icons.forum_rounded,
      'แชทกลุ่มของรอบนี้',
      'คุยกับเพื่อนร่วมทริปและทีมงานได้ในห้องเดียวกัน',
    ),
    (
      Icons.near_me_rounded,
      'ติดตามรถแบบเรียลไทม์',
      'เห็นตำแหน่งรถและเวลาถึงจุดรับในวันเดินทาง',
    ),
    (
      Icons.event_note_rounded,
      'กำหนดการและจุดขึ้นรถ',
      'ดูรายละเอียดทริปชุดเดียวกับคุณจากแอปของตัวเอง',
    ),
    (
      Icons.notifications_active_rounded,
      'แจ้งเตือนก่อนเดินทาง',
      'ไม่พลาดนัดหมายและประกาศจากผู้จัด',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusLg),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppTheme.border(context).withValues(alpha: 0.5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.selectedTint(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      _items[i].$1,
                      size: 19,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _items[i].$2,
                          style: appFont(
                            fontSize: AppText.sizeBody,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$3,
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            color: AppTheme.mutedText(context),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: _NoteLine(
              icon: Icons.savings_rounded,
              text:
                  'ทุกคนอยู่ในการจองใบเดียวกัน เพื่อนไม่ต้องจองใหม่และไม่ต้องจ่ายเพิ่ม',
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard();

  static const _steps = <(String, String)>[
    ('สร้างลิงก์คำเชิญ', 'ตั้งชื่อเล่นไว้ก็ได้ จะได้จำได้ว่าลิงก์ไหนของใคร'),
    ('ส่งลิงก์ให้เพื่อน', 'ส่งทาง LINE แชท หรือช่องทางไหนก็ได้ที่สะดวก'),
    (
      'เพื่อนกดลิงก์แล้วเข้าร่วม',
      'เข้าสู่ระบบด้วยบัญชีของตัวเอง แล้วทริปจะไปโผล่ในแอปของเพื่อนทันที',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusLg),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[i].$1,
                          style: appFont(
                            fontSize: AppText.sizeBody,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _steps[i].$2,
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            color: AppTheme.mutedText(context),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
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

class _OwnerTile extends StatelessWidget {
  final Map<String, dynamic> owner;

  const _OwnerTile({required this.owner});

  @override
  Widget build(BuildContext context) {
    if (owner.isEmpty) return const SizedBox.shrink();
    final name = textOf(owner['nickname']).isNotEmpty
        ? textOf(owner['nickname'])
        : textOf(owner['name'], 'เจ้าของการจอง');

    return _RosterTile(
      avatarUrl: textOf(owner['avatar_url']),
      name: name,
      subtitle: 'เจ้าของการจอง',
      statusColor: AppTheme.primaryColor,
    );
  }
}

class _MemberRow extends StatelessWidget {
  final Map<String, dynamic> member;
  final String name;
  final bool isOwnerView;
  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.member,
    required this.name,
    required this.isOwnerView,
    required this.busy,
    required this.onShare,
    required this.onCopy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = textOf(member['status']) == 'active';
    final user = asMap(member['user']);
    final hasLink = textOf(member['invite_url']).isNotEmpty ||
        textOf(member['invite_token']).isNotEmpty;

    return _RosterTile(
      avatarUrl: textOf(user['avatar_url']),
      name: name,
      subtitle: isActive ? 'เข้าร่วมแล้ว' : 'ส่งลิงก์แล้ว รอเพื่อนกดเข้าร่วม',
      statusColor: isActive ? AppTheme.successColor : AppTheme.warningColor,
      onRemove: isOwnerView && !busy ? onRemove : null,
      // คำเชิญที่ยังไม่ถูกรับ — ส่งลิงก์เดิมซ้ำได้ ไม่ต้องสร้างใบใหม่ให้เปลืองที่นั่ง
      footer: !isActive && isOwnerView && hasLink
          ? Row(
              children: [
                _TinyAction(
                  icon: Icons.ios_share_rounded,
                  label: 'ส่งลิงก์อีกครั้ง',
                  onTap: busy ? null : onShare,
                ),
                const SizedBox(width: 8),
                _TinyAction(
                  icon: Icons.copy_rounded,
                  label: 'คัดลอก',
                  onTap: busy ? null : onCopy,
                ),
              ],
            )
          : null,
    );
  }
}

class _RosterTile extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final String subtitle;
  final Color statusColor;
  final VoidCallback? onRemove;
  final Widget? footer;

  const _RosterTile({
    required this.avatarUrl,
    required this.name,
    required this.subtitle,
    required this.statusColor,
    this.onRemove,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
        child: Column(
          children: [
            Row(
              children: [
                _Avatar(url: avatarUrl, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'นำออก',
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: footer!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final Color color;

  const _Avatar({required this.url, required this.color});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, size: 19, color: color),
    );

    if (url.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        memCacheWidth: 114,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _TinyAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _TinyAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String url;
  final String token;

  const _CodeBox({required this.url, required this.token});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ลิงก์คำเชิญ',
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            url.isEmpty ? token : url,
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
              height: 1.4,
            ),
          ),
          if (url.isNotEmpty && token.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'รหัสคำเชิญ (ใช้แทนลิงก์ได้)',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              token,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
                letterSpacing: 0.6,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoteLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.mutedText(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoMembersYet extends StatelessWidget {
  const _NoMembersYet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: const _NoteLine(
        icon: Icons.person_add_alt_1_rounded,
        text: 'ยังไม่ได้เชิญใคร กดสร้างลิงก์คำเชิญด้านล่างได้เลย',
      ),
    );
  }
}

class _RosterLoading extends StatelessWidget {
  const _RosterLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorNote({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerTint(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.dangerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface(context),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }
}

/// แถบล่างของหน้า — ว่างเปล่าไปเลยระหว่างโหลด จะได้ไม่กระพริบปุ่มผิดสถานะ
class _BottomBar extends StatelessWidget {
  final Widget? child;

  const _BottomBar({required this.child});

  @override
  Widget build(BuildContext context) {
    if (child == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: child!,
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final Widget child;

  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.border(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
      ),
    );
  }
}
