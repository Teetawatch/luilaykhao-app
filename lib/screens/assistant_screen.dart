import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart' show asMap, textOf;
import 'chat_screen.dart';
import 'customer_app_screen.dart' show BookingDetailSheet, MyBookingsScreen;
import 'payment_screen.dart';
import 'pre_trip_checklist_screen.dart';
import 'schedule_itinerary_screen.dart';
import 'support_chat_screen.dart';
import 'trip_day_screen.dart';

/// "ผู้ช่วยส่วนตัว" — ถามเป็นภาษาคนเรื่องการเดินทางของตัวเอง แล้วได้คำตอบจาก
/// ข้อมูลการจองจริง ("พรุ่งนี้รถออกกี่โมง", "ยอดคงเหลือเท่าไหร่ จ่ายวันไหน")
///
/// ต่างจากห้อง [SupportChatScreen] ที่รอทีมงานตอบ — ตัวนี้ตอบทันทีตลอด 24 ชม.
/// และจบด้วยปุ่มลัดไปหน้าที่เกี่ยวข้อง แทนที่จะให้ผู้ใช้ไปหาเองต่อ
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  /// จำนวนข้อความย้อนหลังที่ส่งไปเป็นบริบท — ต้องไม่เกินที่ backend ยอมรับ (20)
  static const _maxHistory = 10;

  final _scroll = ScrollController();
  final _input = TextEditingController();

  final List<_Turn> _turns = [];
  List<String> _suggestions = const [];
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await context.read<AppProvider>()
          .assistantSuggestions();
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (_) {
      // คำถามตัวอย่างเป็นของแถม ถ้าโหลดไม่ได้ก็ปล่อยให้พิมพ์เองได้ตามปกติ
    }
  }

  Future<void> _ask(String question) async {
    final message = question.trim();
    if (message.length < 2 || _asking) return;

    HapticFeedback.selectionClick();
    _input.clear();

    setState(() {
      _turns.add(_Turn.user(message));
      _asking = true;
    });
    _scrollToEnd();

    // ส่งเฉพาะเทิร์นที่สำเร็จไปเป็นบริบท — ฟองข้อความ error ไม่ใช่คำตอบของผู้ช่วย
    final history = _turns
        .where((turn) => !turn.isError)
        .take(_turns.length - 1)
        .map((turn) => {
              'role': turn.isMine ? 'user' : 'assistant',
              'content': turn.text,
            })
        .toList();

    try {
      final answer = await context.read<AppProvider>().askAssistant(
            message,
            history: history.length > _maxHistory
                ? history.sublist(history.length - _maxHistory)
                : history,
          );

      if (!mounted) return;
      setState(() {
        _turns.add(_Turn.assistant(
          textOf(answer['reply'], 'ขอโทษครับ ผู้ช่วยยังตอบไม่ได้ตอนนี้'),
          actions: (answer['actions'] as List? ?? const [])
              .map((raw) => _AssistantAction.fromJson(asMap(raw)))
              .toList(),
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _turns.add(_Turn.error(_readableError(e))));
    } finally {
      if (mounted) setState(() => _asking = false);
      _scrollToEnd();
    }
  }

  String _readableError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty
        ? 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้งนะครับ'
        : text;
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  /// การจองที่ปุ่มลัดอ้างถึง — ปุ่มบางอันต้องใช้ข้อมูลทั้งก้อน ไม่ใช่แค่เลขที่จอง
  Map<String, dynamic>? _bookingOf(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    for (final raw in context.read<AppProvider>().bookings) {
      final booking = asMap(raw);
      if (textOf(booking['booking_ref']) == ref) return booking;
    }
    return null;
  }

  void _openAction(_AssistantAction action) {
    HapticFeedback.selectionClick();

    if (action.type == 'support') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SupportChatScreen()),
      );
      return;
    }

    final booking = _bookingOf(action.bookingRef);
    if (booking == null) {
      // ไม่รู้ว่าหมายถึงการจองไหน (หรือยังโหลดไม่เสร็จ) — พาไปหน้ารวมการจองแทน
      // การเดาเป็นการจองใดการจองหนึ่งแล้วผิดน่าหงุดหงิดกว่า
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
      );
      return;
    }

    final ref = textOf(booking['booking_ref']);
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);

    switch (action.type) {
      case 'payment':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              bookingRef: ref,
              initialPaymentType: textOf(booking['payment_type'], 'full'),
            ),
          ),
        );
      case 'itinerary':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScheduleItineraryScreen(
              scheduleId: int.tryParse(textOf(schedule['id'])) ?? 0,
              tripTitle: textOf(trip['title']),
            ),
          ),
        );
      case 'checklist':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PreTripChecklistScreen.fromBooking(booking),
          ),
        );
      case 'chat':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              scheduleId: int.tryParse(textOf(schedule['id'])) ?? 0,
              title: textOf(trip['title']),
            ),
          ),
        );
      case 'trip_day':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDayScreen(booking: booking)),
        );
      // จุดรับ อากาศ และรายละเอียดอื่น ๆ อยู่บนใบจองอยู่แล้ว ไม่ต้องมีหน้าซ้ำ
      default:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BookingDetailSheet(bookingRef: ref),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.onSurface(context),
        title: Text(
          'ผู้ช่วยส่วนตัว',
          style: appFont(fontSize: AppText.sizeTitle, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _turns.isEmpty
                ? _EmptyState(
                    suggestions: _suggestions,
                    onPick: _ask,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: _turns.length + (_asking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _turns.length) return const _Thinking();
                      return _Bubble(
                        turn: _turns[index],
                        onAction: _openAction,
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _input,
            asking: _asking,
            onSend: () => _ask(_input.text),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── models ───────────────────────────

class _Turn {
  final String text;
  final bool isMine;
  final bool isError;
  final List<_AssistantAction> actions;

  const _Turn({
    required this.text,
    required this.isMine,
    this.isError = false,
    this.actions = const [],
  });

  factory _Turn.user(String text) => _Turn(text: text, isMine: true);

  factory _Turn.assistant(String text, {List<_AssistantAction> actions = const []}) =>
      _Turn(text: text, isMine: false, actions: actions);

  factory _Turn.error(String text) =>
      _Turn(text: text, isMine: false, isError: true);
}

class _AssistantAction {
  final String type;
  final String label;
  final String? bookingRef;

  const _AssistantAction({
    required this.type,
    required this.label,
    this.bookingRef,
  });

  factory _AssistantAction.fromJson(Map<String, dynamic> json) {
    final ref = textOf(json['booking_ref']);
    return _AssistantAction(
      type: textOf(json['type']),
      label: textOf(json['label'], 'เปิดดู'),
      bookingRef: ref.isEmpty ? null : ref,
    );
  }

  IconData get icon => switch (type) {
        'payment' => Icons.receipt_long_rounded,
        'pickup' => Icons.place_outlined,
        'itinerary' => Icons.event_note_outlined,
        'checklist' => Icons.checklist_rounded,
        'weather' => Icons.wb_cloudy_outlined,
        'trip_day' => Icons.hiking_rounded,
        'chat' => Icons.forum_outlined,
        'support' => Icons.support_agent_rounded,
        _ => Icons.confirmation_number_outlined,
      };
}

// ─────────────────────────── bubbles ───────────────────────────

class _Bubble extends StatelessWidget {
  final _Turn turn;
  final ValueChanged<_AssistantAction> onAction;

  const _Bubble({required this.turn, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final isMine = turn.isMine;

    final bg = isMine
        ? AppTheme.primaryColor
        : turn.isError
            ? AppTheme.subtleSurface(context)
            : AppTheme.surface(context);
    final fg = isMine
        ? Colors.white
        : turn.isError
            ? AppTheme.mutedText(context)
            : AppTheme.onSurface(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusMd),
                  topRight: const Radius.circular(AppTheme.radiusMd),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine
                    ? null
                    : Border.all(color: AppTheme.border(context)),
              ),
              child: Text(
                turn.text,
                style: appFont(fontSize: AppText.sizeSubtitle, color: fg, height: 1.4),
              ),
            ),
            if (turn.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in turn.actions)
                      _ActionChip(action: action, onTap: () => onAction(action)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final _AssistantAction action;
  final VoidCallback onTap;

  const _ActionChip({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                action.label,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusMd),
            topRight: Radius.circular(AppTheme.radiusMd),
            bottomLeft: Radius.circular(AppTheme.radiusPill),
            bottomRight: Radius.circular(AppTheme.radiusMd),
          ),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'กำลังดูข้อมูลการจองของคุณ...',
              style: appFont(
                fontSize: AppText.sizeBody,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── empty state ───────────────────────────

class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onPick;

  const _EmptyState({required this.suggestions, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          size: 40,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          'ถามอะไรก็ได้เรื่องทริปของคุณ',
          textAlign: TextAlign.center,
          style: appFont(fontSize: AppText.sizeH2, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'ผู้ช่วยเห็นการจองของคุณอยู่แล้ว จึงตอบเรื่องเวลารถออก จุดรับ '
          'ยอดคงเหลือ และของที่ต้องเตรียมได้ทันที',
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: AppText.sizeBody,
            height: 1.5,
            color: AppTheme.mutedText(context),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 28),
          for (final suggestion in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SuggestionTile(
                text: suggestion,
                onTap: () => onPick(suggestion),
              ),
            ),
        ],
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionTile({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border(context)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(text, style: appFont(fontSize: AppText.sizeBody)),
              ),
              Icon(
                Icons.north_east_rounded,
                size: 16,
                color: AppTheme.mutedText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── composer ───────────────────────────

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool asking;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.asking,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppTheme.fieldSurface(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  enabled: !asking,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: appFont(fontSize: AppText.sizeSubtitle),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'ถามเรื่องทริปของคุณ...',
                    hintStyle: appFont(
                      fontSize: AppText.sizeSubtitle,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: asking
                  ? AppTheme.mutedText(context).withValues(alpha: 0.35)
                  : AppTheme.primaryColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: asking ? null : onSend,
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
