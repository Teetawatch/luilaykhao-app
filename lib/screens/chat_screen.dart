import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/chat_notify_level.dart';
import '../providers/app_provider.dart';
import '../providers/tracking_provider.dart';
import '../services/push_notification_service.dart';
import '../services/wake_alarm_service.dart';
import '../widgets/app_snack.dart';
import '../widgets/chat_ack.dart';
import '../widgets/chat_collection.dart';
import '../widgets/chat_dropoff.dart';
import '../widgets/chat_food_bill.dart';
import '../widgets/chat_food_round.dart';
import '../widgets/chat_lost_item.dart';
import '../widgets/chat_porter.dart';
import '../widgets/chat_requests.dart';
import '../widgets/chat_rest_stop.dart';
import '../widgets/chat_social.dart';
import '../widgets/chat_staff_intro.dart';
import '../widgets/chat_stickers.dart';
import '../widgets/chat_todos.dart';
import '../widgets/chat_trail_check.dart';
import '../widgets/chat_voice.dart';
import '../widgets/chat_vote_sheet.dart';
import '../widgets/chat_wellness.dart';
import '../widgets/moderation_sheet.dart';
import '../widgets/sheet_close_button.dart';
import '../theme/app_theme.dart';
import '../services/quick_ask_matcher.dart';
import '../utils/thai_date.dart';
import '../widgets/weather_card.dart';
import '../widgets/tier_badge.dart';
import 'chat_private_screen.dart';
import 'custom_pickup_picker_screen.dart';
import 'schedule_itinerary_screen.dart';
import 'lost_items_screen.dart';
import 'onsite_money_screen.dart';
import 'trip_contacts_screen.dart';
import 'trip_rooms_screen.dart';
import 'tracking_screen.dart' show TrackingMapPage;
import '../widgets/confirm_dialog.dart';

part 'chat_trip_tools.part.dart';
part 'chat_browse.part.dart';

/// Group chat room for a trip schedule. Members are the customers booked on
/// the schedule, the assigned staff, and admins. Real-time via Reverb.
class ChatScreen extends StatefulWidget {
  final int scheduleId;
  final String? title;

  const ChatScreen({super.key, required this.scheduleId, this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, _TripToolsMixin {
  // Slow fallback poll cadence — only used when the realtime socket hasn't
  // delivered anything recently. When Reverb is alive we lengthen this so we
  // don't burn battery/data on a duplicate channel.
  static const _pollIdle = Duration(seconds: 4);
  static const _pollSocketActive = Duration(seconds: 20);
  // Window during which an incoming socket event suppresses aggressive polling.
  static const _socketFreshWindow = Duration(seconds: 30);
  // Messages within this gap from the same sender visually group into one
  // unit (no avatar/name repeat) — iMessage/LINE convention.
  static const _groupGap = Duration(minutes: 2);

  @override
  final List<Map<String, dynamic>> _messages = [];
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  // ข้อความเสียง — แตะไมค์ (ตอนช่องพิมพ์ว่าง) แถบกำลังอัดขึ้นแทนช่องพิมพ์
  final _voice = VoiceRecordingController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _sending = false;
  bool _polling = false;
  bool _isForeground = true;
  String? _error;
  VoidCallback? _disposer;
  Timer? _pollTimer;
  DateTime? _lastSocketAt;

  // Room metadata (members + per-member read positions + vehicle). Refreshed
  // alongside polling so the member roster and read receipts stay live.
  Map<String, dynamic>? _room;
  DateTime? _lastRoomFetch;
  bool _roomFetching = false;
  static const _roomRefreshGap = Duration(seconds: 8);

  // การแจ้งเตือนของห้องนี้ (ของฉันคนเดียว) — _notifyEpoch กันไม่ให้ผลรีเฟรช
  // ห้องที่ยิงออกไปก่อนผู้ใช้เปลี่ยนค่า กลับมาทับค่าใหม่ด้วยค่าเก่า
  ChatNotifyLevel _notifyLevel = ChatNotifyLevel.all;
  int _notifyEpoch = 0;
  bool _savingNotify = false;
  VoidCallback? _roomWatchDisposer;
  // How long before the same person can pop a "เข้าห้องแชท" notice again.
  static const _joinedCooldown = Duration(minutes: 3);

  // Pinned announcement, kept in sync with room load + chat.pinned broadcasts.
  // ปักได้หลายอัน (ปักล่าสุดก่อน) — แถบโชว์ทีละอัน แตะแล้วไปที่ข้อความและเลื่อนไปอันถัดไป
  List<Map<String, dynamic>> _pins = const [];
  int _pinIndex = 0;

  /// รับหมุดจาก payload — เซิร์ฟเวอร์รุ่นก่อนมีแค่ pinned_message (อันเดียว)
  void _setPins(dynamic list, dynamic single) {
    final next = list is List
        ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : (single is Map ? [Map<String, dynamic>.from(single)] : <Map<String, dynamic>>[]);
    _pins = next;
    if (_pinIndex >= next.length) _pinIndex = 0;
  }

  bool _isPinned(int messageId) =>
      _pins.any((p) => int.tryParse('${p['id']}') == messageId);

  // Reply composer target (the message being quoted), null when not replying.
  Map<String, dynamic>? _replyingTo;

  // Edit composer target (the message being edited), null when not editing.
  Map<String, dynamic>? _editing;

  // @mention candidates picked from the suggestion bar this compose session —
  // {id, label}. On send we keep only those whose "@label" still appears.
  final List<Map<String, dynamic>> _mentionPicks = [];
  // Active "@query" the user is typing (null when not mentioning).
  String? _mentionQuery;

  // Live "is typing…" — userId → (name, expiry). A 1s sweeper clears stale ones.
  final Map<int, ({String name, DateTime until})> _typing = {};
  Timer? _typingSweeper;
  DateTime? _lastTypingSentAt;

  // Transient "X เข้าห้องแชท" notices — userId → (name, role, expiry), swept
  // like typing. Staff get their own wording and colour so the room can tell
  // "ทีมงานเข้ามาแล้ว" apart from another traveller dropping in.
  final Map<int, ({String name, String role, DateTime until})> _joined = {};
  Timer? _joinedSweeper;
  // Last time we showed a notice for each user — someone flipping in and out of
  // the room shouldn't keep popping the banner at everyone else.
  final Map<int, DateTime> _joinedShownAt = {};

  // Unread divider: messages with id beyond this (and not mine) are "new" since
  // we opened. Captured once from our own read marker on first room load.
  int _unreadBoundaryId = 0;
  bool _unreadBoundaryLocked = false;

  // Jump-to-latest affordance.
  bool _showJumpButton = false;
  int _newWhileAway = 0;

  // "@mention me" tracking: mentions of me with id beyond this are considered
  // unread and surfaced via a jump chip. Seeded from the unread boundary so
  // mentions from before we opened aren't re-flagged.
  int _mentionAckId = 0;

  @override
  bool _canModerate = false;

  // ชีตรายการรวมของรอบสั่งอาหารที่เปิดอยู่ (ถ้ามี) — realtime ป้อนค่าใหม่เข้ามา
  // ให้ชีตอัปเดตเองระหว่างสตาฟเปิดค้างรอคนสั่ง
  final _foodSheetRound = ValueNotifier<Map<String, dynamic>?>(null);
  // แพ้อาหาร/ฮาลาลของรอบที่เปิดอยู่ — ทีมงานเท่านั้น
  final _foodSheetDietary = ValueNotifier<List<Map<String, dynamic>>>(const []);
  int? _foodSheetMessageId;
  Timer? _foodSheetRefresh;

  // ชีตเช็คยอดเก็บเงินที่เปิดอยู่ (ถ้ามี)
  final _collectionSheet = ValueNotifier<Map<String, dynamic>?>(null);
  int? _collectionSheetMessageId;

  // ชีตเช็คชื่อขึ้นรถที่เปิดอยู่ (ถ้ามี) — realtime ป้อนค่าใหม่ให้เหมือนชีตรายการอาหาร
  final _restSheetStop = ValueNotifier<Map<String, dynamic>?>(null);
  int? _restSheetMessageId;
  List<String> _reactionEmojis = const ['👍', '❤️', '😂', '😮', '😢', '🙏'];
  @override
  int? _myUserId;

  // Per-message keys so reply-quote and mention jumps can precisely anchor the
  // target via Scrollable.ensureVisible instead of a scroll-ratio guess.
  final Map<int, GlobalKey> _messageKeys = {};
  // Message briefly highlighted after a jump, to confirm where we landed.
  int _highlightId = 0;
  Timer? _highlightTimer;

  VoidCallback? _signalsDisposer;

  /// กำลังพิมพ์อยู่ไหม — ใช้ซ่อน/แสดงแถบคำถามด่วนเหนือช่องพิมพ์
  bool _isComposing = false;

  /// ข้อมูลการเดินทางของฉัน (โหลดครั้งแรกที่กดถาม แล้วแคชไว้ในหน้านี้)
  Map<String, dynamic>? _tripInfo;
  DateTime? _tripInfoAt;

  /// คำถามที่แอปเดาว่ากำลังจะถาม/เพิ่งถามไป — แถบคำตอบเหนือช่องพิมพ์
  /// ขึ้นเฉพาะเครื่องคนถาม ไม่มีอะไรถูกโพสต์ลงห้อง
  _QuickAsk? _suggested;

  /// ข้อความต้นทางของคำเดาปัจจุบัน ใช้จำว่าปัดทิ้งอันไหนไปแล้ว
  String? _suggestedFrom;
  String? _dismissedSuggestion;

  // สติกเกอร์ — แผงขึ้นแทนคีย์บอร์ด และแถบเสนอสติกเกอร์ตอนพิมพ์คำที่ตรงป้าย
  List<ChatStickerPack> _stickerPacks = const [];
  bool _stickersLoading = false;
  String? _stickersError;
  bool _stickerPanelOpen = false;
  List<int> _recentStickerIds = const [];
  List<ChatSticker> _stickerSuggestions = const [];
  String? _dismissedStickerText;

  // ทีมงาน: ข้อความที่กำลังพิมพ์จะส่งเป็นประกาศที่ทุกคนต้องกดรับทราบ
  bool _requestAck = false;
  // ข้อความที่กำลังกดรับทราบอยู่ (กันกดรัว)
  final Set<int> _ackBusy = {};

  // "รอคุณอยู่" — ดึงใหม่แบบหน่วง (หลายสัญญาณมาติดกันยิงครั้งเดียว) และทุกนาที
  // เพราะบางเรื่องเปิดให้กดตามเวลา (นัดรวมพล 3 ชม.ก่อน / ปลุก 1 ชม.ก่อน)
  List<ChatTodo> _todos = const [];
  Timer? _todoDebounce;
  Timer? _todoTicker;
  bool _todoFetching = false;
  bool _todoAgain = false;
  // กำลังโหลดย้อนไปหาข้อความเก่า (จากแถบรอคุณอยู่/ผลค้นหา)
  bool _jumping = false;

  // ข้อความที่พิมพ์ค้างไว้ — ออกจากห้องไปแล้วกลับมายังอยู่ (รายห้อง เก็บในเครื่อง)
  Timer? _draftSave;
  String get _draftKey => 'chat_draft_${widget.scheduleId}';

  // ชวน "เงียบไว้ก่อน" ในห้องที่ยังอีกนานกว่าจะเดินทาง — ปัดทิ้งแล้วไม่ถามซ้ำในห้องนี้
  bool _quietSuggestDismissed = true;
  String get _quietSuggestKey => 'chat_quiet_suggest_dismissed_${widget.scheduleId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _input.addListener(_watchComposing);
    _inputFocus.addListener(_onInputFocus);
    unawaited(_restoreDraft());
    // ครบ 2 นาทีหยุดอัดแล้วส่งเอง — คนที่พูดยาวขนาดนั้นตั้งใจจะส่งอยู่แล้ว
    _voice.onAutoStop = (clip) {
      if (!mounted) return;
      setState(() {});
      _sendVoiceClip(clip);
      _snack('ครบ 2 นาที ส่งข้อความเสียงให้แล้ว');
    };
    // ข้อความของห้องนี้ไม่ต้องเด้งแจ้งเตือนระหว่างที่ผู้ใช้กำลังดูห้องอยู่
    _roomWatchDisposer = PushNotificationService.instance.watchChatRoom(
      (scheduleId) =>
          scheduleId == widget.scheduleId &&
          mounted &&
          _isForeground &&
          (ModalRoute.of(context)?.isCurrent ?? false),
    );
    _init();
  }

  /// พอเริ่มพิมพ์ให้ซ่อนแถบคำถามด่วน — คนที่พิมพ์เองอยู่แล้วไม่ต้องการทางลัด
  /// และแชทควรได้พื้นที่คืน (setState เฉพาะตอนสถานะพลิก ไม่ใช่ทุกตัวอักษร)
  void _watchComposing() {
    final text = _input.text.trim();
    final composing = text.isNotEmpty;
    if (composing != _isComposing && mounted) {
      setState(() => _isComposing = composing);
    }
    _considerSuggestion(text);
    _considerStickers(text);
    _scheduleDraftSave();
  }

  /// เก็บร่างแบบหน่วง (ไม่เขียนดิสก์ทุกตัวอักษร) — กำลังแก้ข้อความเก่าไม่นับเป็นร่าง
  void _scheduleDraftSave() {
    if (_editing != null) return;
    _draftSave?.cancel();
    _draftSave = Timer(const Duration(milliseconds: 500), _saveDraftNow);
  }

  Future<void> _saveDraftNow() async {
    if (_editing != null) return;
    final text = _input.text;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (text.trim().isEmpty) {
        await prefs.remove(_draftKey);
      } else {
        await prefs.setString(_draftKey, text);
      }
    } catch (_) {
      // จำร่างไม่ได้ก็แค่ไม่มีร่าง ไม่ต้องเตือน
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString(_draftKey) ?? '';
      // ผู้ใช้เริ่มพิมพ์ไปก่อนร่างโหลดเสร็จ — ไม่ทับของที่เพิ่งพิมพ์
      if (!mounted || draft.trim().isEmpty || _input.text.isNotEmpty) return;
      _input.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    } catch (_) {}
  }

  /// แตะช่องพิมพ์ = ผู้ใช้อยากพิมพ์ คีย์บอร์ดขึ้นแทนแผงสติกเกอร์
  void _onInputFocus() {
    if (_inputFocus.hasFocus && _stickerPanelOpen && mounted) {
      setState(() => _stickerPanelOpen = false);
    }
  }

  /// คำที่พิมพ์ตรงกับป้ายสติกเกอร์ → เสนอให้กดส่งเป็นสติกเกอร์แทน (ไม่บังคับ)
  void _considerStickers(String text) {
    final next = (_editing != null ||
            text.isEmpty ||
            text == _dismissedStickerText ||
            _stickerPacks.isEmpty)
        ? const <ChatSticker>[]
        : matchStickers(_stickerPacks, text);
    final same = next.length == _stickerSuggestions.length &&
        Iterable.generate(next.length)
            .every((i) => next[i].id == _stickerSuggestions[i].id);
    if (same || !mounted) return;
    setState(() => _stickerSuggestions = next);
  }

  /// โหลดชุดสติกเกอร์ (AppProvider จำไว้ทั้งแอป) — เงียบเมื่อล้มเหลว เพราะผู้ใช้
  /// ยังไม่ได้ขอ แผงจะขึ้นปุ่ม "ลองอีกครั้ง" ให้ตอนเปิดดูเอง
  Future<void> _loadStickers({bool force = false}) async {
    if (_stickersLoading) return;
    final app = context.read<AppProvider>();
    setState(() {
      _stickersLoading = true;
      _stickersError = null;
    });
    try {
      final results = await Future.wait([
        app.chatStickerPacks(force: force),
        StickerRecents.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _stickerPacks = ChatStickerPack.parseList(results[0]);
        _recentStickerIds = List<int>.from(results[1]);
        _stickersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stickersLoading = false;
        _stickersError = e.toString();
      });
    }
  }

  void _toggleStickerPanel() {
    HapticFeedback.selectionClick();
    if (_stickerPanelOpen) {
      setState(() => _stickerPanelOpen = false);
      _inputFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _stickerPanelOpen = true);
    // ขอใหม่ทุกครั้งที่เปิดแผง (AppProvider กันยิงถี่ด้วย TTL) — เดิมโหลดครั้งเดียวตอน
    // เข้าห้อง สติกเกอร์ที่แอดมินอัปเพิ่มระหว่างนั้นจึงไม่โผล่จนกว่าจะออกแล้วเข้าใหม่
    _loadStickers(force: _stickersError != null);
  }

  /// ส่งสติกเกอร์ — จากแผง หรือจากแถบเสนอ (ซึ่งแทนข้อความที่พิมพ์ค้างไว้)
  void _sendSticker(ChatSticker sticker, {bool fromSuggestion = false}) {
    if (_editing != null) return;
    final replyId = _replyingTo == null
        ? null
        : int.tryParse('${_replyingTo!['id']}');
    final replyPreview = _replyPreviewOf(_replyingTo);
    final token = _newClientToken();
    final optimistic = <String, dynamic>{
      'client_token': token,
      'is_mine': true,
      'sender_role': 'customer',
      'body': sticker.fallbackBody,
      'sticker': sticker.toMessageJson(),
      'created_at': DateTime.now().toIso8601String(),
      'reply_to': ?replyPreview,
      '_reply_to_id': ?replyId,
      '_sticker_id': sticker.id,
      '_pending': true,
    };
    final recents = StickerRecents.bump(_recentStickerIds, sticker.id);
    setState(() {
      _messages.add(optimistic);
      _replyingTo = null;
      _recentStickerIds = recents;
      _stickerSuggestions = const [];
      if (fromSuggestion) {
        _input.clear();
        _mentionPicks.clear();
        _mentionQuery = null;
      }
    });
    unawaited(StickerRecents.save(recents));
    _scrollToBottom();
    _dispatchOptimistic(token);
  }

  void _dismissStickerSuggestions() {
    HapticFeedback.selectionClick();
    setState(() {
      _dismissedStickerText = _input.text.trim();
      _stickerSuggestions = const [];
    });
  }

  /// อ่านข้อความแล้วยกคำตอบขึ้นมาให้เอง ถ้าเข้าข้อที่แอปตอบได้อยู่แล้ว
  ///
  /// เรียกทั้งตอนพิมพ์ (ยื่นให้ก่อนกดส่งด้วยซ้ำ) และตอนส่งไปแล้ว เพราะคนที่พิมพ์
  /// รวดเดียวแล้วกดส่งไม่ทันเห็นแถบตอนพิมพ์ ปัดทิ้งแล้วข้อความเดิมจะไม่เด้งซ้ำ
  void _considerSuggestion(String text) {
    if (text.isEmpty) {
      if (_suggested != null && mounted) {
        setState(() {
          _suggested = null;
          _suggestedFrom = null;
        });
      }

      return;
    }

    if (text == _dismissedSuggestion) return;

    final topic = QuickAskMatcher.match(text);
    final ask = topic == null ? null : _QuickAsk.forTopic(topic);

    if (ask == _suggested) {
      _suggestedFrom = text;

      return;
    }

    if (!mounted) return;

    setState(() {
      _suggested = ask;
      _suggestedFrom = text;
    });

    // ดึงคำตอบมารอไว้เงียบ ๆ ให้แถบโชว์คำตอบจริง ไม่ใช่แค่ปุ่มให้กดต่อ
    if (ask != null) {
      final stale = _tripInfoAt == null ||
          DateTime.now().difference(_tripInfoAt!) > const Duration(minutes: 1);
      _warmTripInfo(fresh: ask == _QuickAsk.van && stale);
    }
  }

  /// โหลดข้อมูลการเดินทางล่วงหน้าแบบไม่รบกวน — ล้มเหลวก็เงียบ แถบจะกลายเป็น
  /// คำชวนให้กดดูแทน แล้วค่อยโหลดใหม่ตอนกด
  Future<void> _warmTripInfo({bool fresh = false}) async {
    if (_tripInfo != null && !fresh) return;

    try {
      final info = await context.read<AppProvider>().chatTripInfo(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _tripInfo = info;
        _tripInfoAt = DateTime.now();
      });
    } catch (_) {
      // ผู้ใช้ไม่ได้เป็นคนสั่งโหลด จึงไม่ควรมี error เด้งใส่
    }
  }

  void _dismissSuggestion() {
    HapticFeedback.selectionClick();
    setState(() {
      _dismissedSuggestion = _suggestedFrom;
      _suggested = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomWatchDisposer?.call();
    _stopPolling();
    _typingSweeper?.cancel();
    _joinedSweeper?.cancel();
    _highlightTimer?.cancel();
    _disposer?.call();
    _signalsDisposer?.call();
    _foodSheetRefresh?.cancel();
    _todoDebounce?.cancel();
    _todoTicker?.cancel();
    // ออกจากห้องระหว่างที่ยังไม่ถึงรอบเก็บ — เก็บทันทีให้ร่างล่าสุดไม่หาย
    if (_draftSave?.isActive ?? false) {
      _draftSave!.cancel();
      unawaited(_saveDraftNow());
    }
    _foodSheetRound.dispose();
    _foodSheetDietary.dispose();
    _restSheetStop.dispose();
    _collectionSheet.dispose();
    disposeTripTools();
    _supplyQueue.dispose();
    _voice.dispose();
    // ออกจากห้องแล้วเสียงไม่ควรเล่นค้างต่อไปหน้าอื่น
    unawaited(ChatVoicePlayback.instance.stop());
    _input.removeListener(_watchComposing);
    _input.dispose();
    _inputFocus.removeListener(_onInputFocus);
    _inputFocus.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _startPolling();
      _poll();
      // Refresh server-side read marker — the user is looking at the chat now.
      _markRead();
      // กลับจากตั้งค่าที่เพิ่งเปิดสิทธิ์ "นาฬิกาปลุก" — ย้ายปลุกรวมไปแบบตรงเวลา
      unawaited(WakeAlarmService.instance.refreshExactness());
    } else {
      _stopPolling();
      // สายเข้า/สลับแอประหว่างอัด — ทิ้งไปเลย ดีกว่าอัดเสียงรอบข้างค้างไว้
      if (_voice.isRecording) {
        unawaited(_voice.cancel().then((_) {
          if (mounted) setState(() {});
        }));
      }
      unawaited(ChatVoicePlayback.instance.stop());
    }
  }

  Future<void> _init() async {
    final app = context.read<AppProvider>();
    _myUserId = int.tryParse('${app.user?['id']}');
    await _load();
    // Bind realtime *after* the initial HTTP load so the socket has no chance
    // to deliver a message that arrives before the history is rendered.
    _disposer = await app.subscribeChat(widget.scheduleId, _onIncoming);
    _signalsDisposer = await app.subscribeChatSignals(
      widget.scheduleId,
      onRead: _onReadSignal,
      onTyping: _onTypingSignal,
      onJoined: _onJoinedSignal,
      onReaction: _onReactionSignal,
      onPinned: _onPinnedSignal,
      onUpdated: _onMessageUpdated,
      onPoll: _onPollSignal,
      onFood: _onFoodSignal,
      onRestStop: _onRestStopSignal,
      onStopRequests: _onStopRequestsSignal,
      onCollection: _onCollectionSignal,
      onLostItem: _onLostItemSignal,
      onSupplies: _onSuppliesSignal,
      onTrail: (d) => _onToolSignal('trail_check', d),
      onDropoff: (d) => _onToolSignal('dropoff', d),
      onWellness: (d) => _onToolSignal('wellness', d),
      onPorter: (d) => _onToolSignal('porter', d),
      onAck: _onAckSignal,
    );
    // Let the rest of the room know we've entered, so they see a brief notice.
    app.sendChatJoin(widget.scheduleId);
    _startPolling();
    // โหลดสติกเกอร์รอไว้ — แถบเสนอสติกเกอร์ตอนพิมพ์ต้องมีรายการก่อนผู้ใช้เปิดแผง
    if (mounted) unawaited(_loadStickers());
    unawaited(_loadQuietSuggestState());
  }

  Future<void> _loadQuietSuggestState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_quietSuggestKey) ?? false;
      if (mounted) setState(() => _quietSuggestDismissed = dismissed);
    } catch (_) {
      // อ่านค่าไม่ได้ = ไม่ชวน (ดีกว่าชวนซ้ำทุกครั้งที่เปิดห้อง)
    }
  }

  Future<void> _dismissQuietSuggest() async {
    setState(() => _quietSuggestDismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_quietSuggestKey, true);
    } catch (_) {}
  }

  Future<void> _acceptQuietSuggest() async {
    HapticFeedback.selectionClick();
    unawaited(_dismissQuietSuggest());
    await _saveNotifyLevel(ChatNotifyLevel.untilTrip);
  }

  bool get _showQuietSuggest =>
      !_quietSuggestDismissed &&
      _room?['suggest_quiet'] == true &&
      _notifyLevel == ChatNotifyLevel.all;

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    try {
      final data = await app.chatMessages(widget.scheduleId);
      final list = (data['messages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _hasMore = data['has_more'] == true;
        _loading = false;
        _error = null;
      });
      _hydrateTools(list);
      _scrollToBottom();
      _markRead();
      _refreshRoom(force: true);
      _refreshTodos(immediate: true);
      _todoTicker ??= Timer.periodic(const Duration(minutes: 1), (_) {
        if (_isForeground) _refreshTodos();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Fetches room metadata (members, read positions, vehicle), throttled to
  /// [_roomRefreshGap] unless [force]d so the live poll doesn't hammer it.
  Future<void> _refreshRoom({bool force = false}) async {
    if (_roomFetching) return;
    if (!force &&
        _lastRoomFetch != null &&
        DateTime.now().difference(_lastRoomFetch!) < _roomRefreshGap) {
      return;
    }
    _roomFetching = true;
    final notifyEpoch = _notifyEpoch;
    try {
      final room = await context.read<AppProvider>().chatRoom(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _room = room;
        if (notifyEpoch == _notifyEpoch && !_savingNotify) {
          _notifyLevel = ChatNotifyLevel.fromValue(room['notify_level']);
        }
        _setPins(room['pinned_messages'], room['pinned_message']);
        _canModerate = room['can_moderate'] == true;
        final emojis = (room['reaction_emojis'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        if (emojis.isNotEmpty) _reactionEmojis = emojis;
        _lockUnreadBoundary();
      });
    } catch (_) {
      // Non-critical — the chat works without the roster; next tick retries.
    } finally {
      _lastRoomFetch = DateTime.now();
      _roomFetching = false;
    }
  }

  /// Freeze the "new messages" divider at our last-read marker the first time
  /// the roster loads, so it doesn't keep jumping as we read.
  void _lockUnreadBoundary() {
    if (_unreadBoundaryLocked) return;
    final me = _members.where((m) => m['is_me'] == true).toList();
    if (me.isEmpty) return;
    _unreadBoundaryId = int.tryParse('${me.first['last_read_message_id']}') ?? 0;
    _mentionAckId = _unreadBoundaryId;
    _unreadBoundaryLocked = true;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    final app = context.read<AppProvider>();
    final beforeId = int.tryParse('${_messages.first['id']}');
    try {
      final data = await app.chatMessages(widget.scheduleId, beforeId: beforeId);
      final older = (data['messages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, older);
        _hasMore = data['has_more'] == true;
        _loadingMore = false;
      });
      _hydrateTools(older);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onIncoming(Map<String, dynamic> data) {
    _lastSocketAt = DateTime.now();
    // Bump cadence back down to the slow track since we know the socket works.
    _startPolling();
    _ingest([
      {...data, 'is_mine': false},
    ]);
    _refreshRoom();
    // ข้อความใหม่อาจเป็นการ์ดที่ต้องตอบ (โหวต/สั่งอาหาร/ประกาศรอรับทราบ)
    _refreshTodos();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final socketAlive = _lastSocketAt != null &&
        DateTime.now().difference(_lastSocketAt!) < _socketFreshWindow;
    final interval = socketAlive ? _pollSocketActive : _pollIdle;
    _pollTimer = Timer.periodic(interval, (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (!mounted || _polling || _loading || _messages.isEmpty) return;
    if (!_isForeground) return;
    _polling = true;
    try {
      final afterId = _latestId();
      if (afterId == 0) return;
      final data = await context
          .read<AppProvider>()
          .chatMessages(widget.scheduleId, afterId: afterId);
      final fresh = (data['messages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _ingest(fresh);
      if (fresh.isNotEmpty) _refreshTodos();
      // Keep the roster / read receipts current (throttled internally).
      _refreshRoom();
    } catch (_) {
      // Transient network failure — next tick retries.
    } finally {
      _polling = false;
    }
  }

  /// Append messages we don't already have, then update the UI / read state.
  /// Dedupe on both `id` (server-assigned) and `client_token` (echo of an
  /// optimistic send) so a socket broadcast arriving before the HTTP response
  /// returns can't double-paint the message.
  void _ingest(List<Map<String, dynamic>> incoming) {
    if (!mounted || incoming.isEmpty) return;
    final app = context.read<AppProvider>();
    final fresh = incoming.where((m) {
      // ข้อความสดที่มาทาง Reverb ไม่ผ่านตัวกรองฝั่งเซิร์ฟเวอร์ — ต้องกันเอง
      // ตรงนี้ ไม่งั้นบล็อกไปแล้วข้อความยังเด้งเข้ามาจนกว่าจะปิดห้อง
      final author = m['user'];
      if (author is Map && app.isBlocked(int.tryParse('${author['id']}'))) {
        return false;
      }
      final id = m['id'];
      if (id != null && _messages.any((e) => e['id'] == id)) return false;
      final token = m['client_token']?.toString();
      if (token != null &&
          token.isNotEmpty &&
          _messages.any((e) => e['client_token']?.toString() == token)) {
        return false;
      }
      return true;
    }).toList();
    if (fresh.isEmpty) return;
    final wasAtBottom = _isNearBottom();
    // Count messages from others that arrived while we're scrolled up, to badge
    // the jump-to-latest button.
    final incomingFromOthers = fresh.where((m) => m['is_mine'] != true).length;
    setState(() {
      _messages.addAll(fresh);
      if (!wasAtBottom) _newWhileAway += incomingFromOthers;
    });
    _hydrateTools(fresh);
    _markRead();
    if (wasAtBottom) _scrollToBottom();
  }

  @override
  void _markRead() {
    if (!_isForeground) return;
    context.read<AppProvider>().markChatRead(widget.scheduleId);
    // อ่านแล้ว — แจ้งเตือนของห้องนี้ที่ค้างอยู่ในถาดไม่มีความหมายอีกต่อไป
    unawaited(
      PushNotificationService.instance.clearChatNotifications(
        widget.scheduleId,
      ),
    );
  }

  Future<void> _openNotifySettings() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<ChatNotifyLevel>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => _NotifyLevelSheet(
        current: _notifyLevel,
        wakesOn: DateTime.tryParse(_room?['notify_wakes_on']?.toString() ?? ''),
      ),
    );
    if (picked == null || picked == _notifyLevel || !mounted) return;
    await _saveNotifyLevel(picked);
  }

  /// เปลี่ยนทันทีบนจอ แล้วถอยกลับถ้าบันทึกไม่สำเร็จ
  Future<void> _saveNotifyLevel(ChatNotifyLevel level) async {
    if (_savingNotify) return;
    final previous = _notifyLevel;
    final app = context.read<AppProvider>();
    setState(() {
      _notifyLevel = level;
      _notifyEpoch++;
      _savingNotify = true;
    });
    try {
      final saved = await app.setChatNotifyLevel(widget.scheduleId, level);
      if (!mounted) return;
      setState(() => _notifyLevel = saved);
      AppSnack.show(
        context,
        switch (saved) {
          ChatNotifyLevel.all => 'เปิดแจ้งเตือนทุกข้อความแล้ว',
          ChatNotifyLevel.important => 'แจ้งเตือนเฉพาะทีมงานและแท็กถึงคุณ',
          ChatNotifyLevel.untilTrip =>
            'เงียบไว้ก่อน — เปิดทุกข้อความให้เอง 3 วันก่อนเดินทาง',
          ChatNotifyLevel.off => 'ปิดการแจ้งเตือนห้องนี้แล้ว',
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _notifyLevel = previous);
      AppSnack.error(context, 'บันทึกการแจ้งเตือนไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) {
        setState(() {
          _savingNotify = false;
          _notifyEpoch++;
        });
      }
    }
  }

  int _latestId() {
    var max = 0;
    for (final m in _messages) {
      final id = int.tryParse('${m['id']}') ?? 0;
      if (id > max) max = id;
    }
    return max;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final app = context.read<AppProvider>();
    final mentions = _activeMentionIds(text);

    // Editing an existing message instead of sending a new one.
    final editing = _editing;
    if (editing != null) {
      final id = int.tryParse('${editing['id']}');
      try {
        final updated = await app.editChatMessage(
          widget.scheduleId,
          id ?? 0,
          text,
          mentions: mentions,
        );
        if (!mounted) return;
        final idx = _messages.indexWhere((m) => m['id'] == updated['id']);
        setState(() {
          if (idx >= 0) _messages[idx] = {..._messages[idx], ...updated};
          _input.clear();
          _editing = null;
          _mentionPicks.clear();
          _mentionQuery = null;
          _sending = false;
        });
        unawaited(_restoreDraft());
      } catch (e) {
        if (!mounted) return;
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }

    final replyId = _replyingTo == null
        ? null
        : int.tryParse('${_replyingTo!['id']}');
    final replyPreview = _replyPreviewOf(_replyingTo);
    final requestAck = _canModerate && _requestAck;
    // Optimistically render the message right away, then dispatch. On failure it
    // stays put with a "tap to retry" affordance instead of vanishing — key for
    // flaky connections on the bus/mountain.
    setState(() {
      _sending = false;
      _input.clear();
      _replyingTo = null;
      _mentionPicks.clear();
      _mentionQuery = null;
      _requestAck = false;
    });
    _enqueueText(
      text,
      replyId: replyId,
      mentions: mentions,
      replyPreview: replyPreview,
      requestAck: requestAck,
    );
    // ช่องพิมพ์ถูกล้างแล้ว listener จึงล้างคำเดาทิ้ง — ยกกลับมาจากข้อความที่
    // เพิ่งส่ง เพื่อให้คนที่พิมพ์รวดเดียวแล้วกดส่งยังได้คำตอบอยู่ดี
    _considerSuggestion(text);
  }

  /// Generates a per-message client token used to track an optimistic send from
  /// insertion → server ack (or failure), and to dedupe against poll/socket
  /// echoes of the same message.
  String _newClientToken() =>
      'llk-${DateTime.now().microsecondsSinceEpoch}-${_messages.length}';

  /// Builds the trimmed `reply_to` payload the quoted-reply UI expects from the
  /// message being replied to (so optimistic bubbles show the quote too).
  Map<String, dynamic>? _replyPreviewOf(Map<String, dynamic>? m) {
    if (m == null) return null;
    final user = m['user'] is Map
        ? Map<String, dynamic>.from(m['user'] as Map)
        : const <String, dynamic>{};
    final name = m['is_mine'] == true
        ? 'ตัวคุณเอง'
        : ((user['nickname']?.toString().isNotEmpty ?? false)
            ? user['nickname'].toString()
            : (user['name']?.toString() ?? 'ผู้ใช้'));
    return {
      'id': m['id'],
      'sender_name': name,
      'body': m['body'],
      'has_image': (m['image_url']?.toString().isNotEmpty ?? false),
      'has_audio': (m['audio_url']?.toString().isNotEmpty ?? false) ||
          (m['_local_audio_path']?.toString().isNotEmpty ?? false),
    };
  }

  /// Inserts an optimistic text message and kicks off its dispatch.
  void _enqueueText(
    String text, {
    int? replyId,
    List<int> mentions = const [],
    Map<String, dynamic>? replyPreview,
    bool requestAck = false,
  }) {
    final token = _newClientToken();
    final optimistic = <String, dynamic>{
      'client_token': token,
      'is_mine': true,
      'sender_role': 'customer',
      'body': text,
      'created_at': DateTime.now().toIso8601String(),
      'reply_to': ?replyPreview,
      '_pending': true,
      '_mentions': mentions,
      '_reply_to_id': ?replyId,
      if (requestAck) '_request_ack': true,
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();
    _dispatchOptimistic(token);
  }

  /// Sends (or re-sends) the optimistic message identified by [token]. Resolves
  /// to replacing the placeholder with the server message, or flagging it failed
  /// so the bubble offers a retry.
  Future<void> _dispatchOptimistic(String token) async {
    final startIdx = _messages.indexWhere((m) => m['client_token'] == token);
    if (startIdx < 0) return;
    setState(() {
      _messages[startIdx]['_pending'] = true;
      _messages[startIdx]['_failed'] = false;
    });
    final opt = _messages[startIdx];
    final app = context.read<AppProvider>();
    try {
      final Map<String, dynamic> server;
      final imagePath = opt['_local_image_path']?.toString();
      final audioPath = opt['_local_audio_path']?.toString();
      final replyId = int.tryParse('${opt['_reply_to_id']}');
      final stickerId = int.tryParse('${opt['_sticker_id']}');
      if (stickerId != null) {
        server = await app.sendChatSticker(
          widget.scheduleId,
          stickerId,
          replyToId: replyId,
        );
      } else if (audioPath != null && audioPath.isNotEmpty) {
        server = await app.sendChatVoice(
          widget.scheduleId,
          audioPath,
          durationMs: int.tryParse('${opt['audio_duration_ms']}') ?? 0,
          replyToId: replyId,
        );
      } else if (imagePath != null && imagePath.isNotEmpty) {
        server = await app.sendChatImage(
          widget.scheduleId,
          imagePath,
          body: opt['body']?.toString(),
          replyToId: replyId,
        );
      } else {
        server = await app.sendChatMessage(
          widget.scheduleId,
          opt['body']?.toString() ?? '',
          replyToId: replyId,
          mentions: List<int>.from(opt['_mentions'] ?? const []),
          requestAck: opt['_request_ack'] == true,
        );
      }
      if (!mounted) return;
      _replaceOptimistic(token, server);
      _refreshRoom();
      // ส่งถึงแล้ว ไฟล์ชั่วคราวหมดหน้าที่ (เว้นไว้ถ้ากำลังเล่นอยู่พอดี)
      final sentAudio = opt['_local_audio_path']?.toString();
      if (sentAudio != null &&
          ChatVoicePlayback.instance.currentKey != sentAudio) {
        deleteVoiceClip(sentAudio);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m['client_token'] == token);
        if (i >= 0) {
          _messages[i]['_pending'] = false;
          _messages[i]['_failed'] = true;
        }
      });
    }
  }

  /// Swaps the optimistic placeholder for the confirmed server message. If a
  /// poll/socket already delivered the same message (matched by server id), drop
  /// the placeholder instead of leaving a duplicate.
  void _replaceOptimistic(String token, Map<String, dynamic> server) {
    setState(() {
      final serverId = server['id'];
      final optIdx = _messages.indexWhere((m) => m['client_token'] == token);
      final existingIdx = serverId == null
          ? -1
          : _messages.indexWhere((m) => m['id'] == serverId);
      if (existingIdx >= 0 && existingIdx != optIdx) {
        if (optIdx >= 0) _messages.removeAt(optIdx);
      } else if (optIdx >= 0) {
        _messages[optIdx] = server;
      } else {
        _messages.add(server);
      }
    });
  }

  /// Matches the "@All" everyone-token (LINE-style). Word-boundary so a name
  /// like "@Allan" isn't mistaken for it. Case-insensitive.
  static final _allMentionPattern = RegExp(r'@all\b', caseSensitive: false);

  /// Mention ids still relevant to the final text — keep a pick only if its
  /// "@label" survived in the message the user actually sent. "@All" expands to
  /// every other member in the room.
  List<int> _activeMentionIds(String text) {
    final ids = <int>[];
    if (_allMentionPattern.hasMatch(text)) {
      for (final m in _members) {
        if (m['is_me'] == true) continue;
        final id = int.tryParse('${m['user_id'] ?? m['id']}');
        if (id != null) ids.add(id);
      }
    }
    for (final pick in _mentionPicks) {
      final label = pick['label']?.toString() ?? '';
      final id = int.tryParse('${pick['id']}');
      if (id != null && label.isNotEmpty && text.contains('@$label')) {
        ids.add(id);
      }
    }
    return ids.toSet().toList();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดรูปภาพได้')),
      );
      return;
    }
    if (picked == null || !mounted) return;

    final replyId = _replyingTo == null
        ? null
        : int.tryParse('${_replyingTo!['id']}');
    final replyPreview = _replyPreviewOf(_replyingTo);
    final token = _newClientToken();
    final optimistic = <String, dynamic>{
      'client_token': token,
      'is_mine': true,
      'sender_role': 'customer',
      'created_at': DateTime.now().toIso8601String(),
      '_local_image_path': picked.path,
      'reply_to': ?replyPreview,
      '_reply_to_id': ?replyId,
      '_pending': true,
    };
    setState(() {
      _messages.add(optimistic);
      _replyingTo = null;
    });
    _scrollToBottom();
    _dispatchOptimistic(token);
  }

  // ── ข้อความเสียง ───────────────────────────────────────────────────────

  Future<void> _startVoice() async {
    if (_sending || _editing != null || _voice.isRecording) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    final result = await _voice.start();
    if (!mounted) return;
    switch (result) {
      case VoiceStartResult.started:
        setState(() {});
      case VoiceStartResult.denied:
        _snack('อนุญาตให้แอปใช้ไมโครโฟนในการตั้งค่าเครื่องก่อน แล้วลองอีกครั้งนะครับ');
      case VoiceStartResult.failed:
        _snack('เริ่มอัดเสียงไม่ได้ ลองอีกครั้งนะครับ');
    }
  }

  Future<void> _finishVoice() async {
    final clip = await _voice.stop();
    if (!mounted) return;
    setState(() {});
    if (clip == null) {
      _snack('ข้อความเสียงสั้นไป — แตะไมค์ พูด แล้วกดส่งเมื่อพูดจบนะครับ');
      return;
    }
    HapticFeedback.mediumImpact();
    _sendVoiceClip(clip);
  }

  Future<void> _cancelVoice() async {
    HapticFeedback.selectionClick();
    await _voice.cancel();
    if (mounted) setState(() {});
  }

  /// แปะข้อความเสียงลงห้องทันที (เล่นจากไฟล์ในเครื่องได้เลย) แล้วอัปโหลดตามหลัง
  void _sendVoiceClip(VoiceClip clip) {
    final replyId = _replyingTo == null
        ? null
        : int.tryParse('${_replyingTo!['id']}');
    final replyPreview = _replyPreviewOf(_replyingTo);
    final token = _newClientToken();
    final optimistic = <String, dynamic>{
      'client_token': token,
      'is_mine': true,
      'sender_role': 'customer',
      'created_at': DateTime.now().toIso8601String(),
      '_local_audio_path': clip.path,
      'audio_duration_ms': clip.durationMs,
      'reply_to': ?replyPreview,
      '_reply_to_id': ?replyId,
      '_pending': true,
    };
    setState(() {
      _messages.add(optimistic);
      _replyingTo = null;
    });
    _scrollToBottom();
    _dispatchOptimistic(token);
  }

  @override
  void _snack(String message) {
    if (!mounted) return;
    AppSnack.show(context, message);
  }

  /// Captures the user's current GPS position and posts it as a Google Maps
  /// link — the most common need in a trip chat ("I'm here" / meeting points).
  /// Sent through the normal text path, so no backend change is required.
  Future<void> _shareLocation() async {
    final Position pos;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('กรุณาเปิดบริการตำแหน่ง (GPS) ก่อนแชร์');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
        return;
      }
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      _snack('ขอตำแหน่งไม่สำเร็จ ลองอีกครั้ง');
      return;
    }

    if (!mounted) return;

    final lat = pos.latitude.toStringAsFixed(6);
    final lng = pos.longitude.toStringAsFixed(6);
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final text = '📍 ตำแหน่งของฉัน\n$url';

    _enqueueText(text);
  }

  void _showImageSourceSheet() {
    if (_sending) return;
    showModalBottomSheet<void>(
      context: context,
      // เมนูยาวขึ้นตามเครื่องมือหน้างาน (โหวต/อาหาร/พักรถ/ห้องพัก) — เลื่อนได้
      // จะได้ไม่ล้นจอบนมือถือจอเล็ก
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text(
                    'ถ่ายรูป',
                    style: appFont(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text(
                    'เลือกจากคลังรูปภาพ',
                    style: appFont(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFE11D48),
                  ),
                  title: Text(
                    'แชร์ตำแหน่งของฉัน',
                    style: appFont(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'ส่งจุดที่คุณอยู่ตอนนี้เป็นลิงก์แผนที่',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _shareLocation();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.bar_chart_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    'สร้างโพล',
                    style: appFont(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'ให้เพื่อนร่วมทริปโหวตเลือกด้วยกัน',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _createPoll();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.how_to_vote_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    'โหวตตัดสิน',
                    style: appFont(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'เสียงแตก? ให้ทุกคนโหวตภายในไม่กี่นาที ระบบประกาศผลให้',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _createVote();
                  },
                ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.ramen_dining_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'รับออเดอร์อาหาร',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ลูกทริปพิมพ์เมนูบนรถ คุณได้รายการรวมไปสั่งร้าน',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openFoodRound();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.local_parking_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'พักรถ / นัดเวลากลับรถ',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'นับถอยหลัง + เช็คชื่อขึ้นรถ ระบบเตือนคนที่ยังไม่กลับ',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openRestStop();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.place_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'นัดรวมพลล่วงหน้า',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'เช่น พรุ่งนี้ 04:30 — เตือนคืนก่อนและก่อนเวลานัด',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openMeetup();
                    },
                  ),
                if (_canModerate && _room?['can_open_home_check'] == true)
                  ListTile(
                    leading: const Icon(
                      Icons.home_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'เช็คถึงบ้าน',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ส่งทุกคนลงรถแล้ว — ลูกทริปกด "ถึงบ้านแล้ว" คุณเห็นว่าใครยังไม่ถึง',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openHomeCheck();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.alarm_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'ปลุกรวม',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ทริปตีสี่ — ทุกคนกดตื่นแล้ว คุณเห็นว่าห้องไหนยังเงียบ',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openWakeup();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.terrain_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'เช็คพอยต์เส้นทางเดิน',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ใครถึงไหนแล้ว ใครอยู่ท้ายสุด + ขอพักถึงคุณคนเดียว',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openTrailCheck();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.favorite_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'เช็คอาการ (ยังไหวไหม)',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ทุกคนตอบสบาย/เหนื่อย/ไม่ไหว เห็นแค่ทีมงาน',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openWellnessCheck();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.airport_shuttle_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'จุดลงขากลับ',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ใครลงระหว่างทาง เรียงจุดส่งตามทาง เตือนก่อนถึง',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openDropoffCard();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.luggage_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'ฝากของลูกหาบ',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ชั่งกระเป๋า เลขป้ายต่อใบ คิดเงินตามกิโลให้เอง',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openPorterRound();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.savings_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'เก็บเงินหน้างาน',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ค่าเข้าอุทยาน ค่าลูกหาบ ทิปไกด์ — QR ต่อคน ติ๊กใครจ่ายแล้ว',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openCollection();
                    },
                  ),
                if (_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'สรุปยอดหน้างาน',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'เงินอยู่กับใครเท่าไร ใครยังค้าง — จบทริปกดส่งเงินให้บริษัท',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              OnsiteMoneyScreen(scheduleId: widget.scheduleId),
                        ),
                      );
                    },
                  ),
                if (!_canModerate)
                  ListTile(
                    leading: const Icon(
                      Icons.waving_hand_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'แนะนำตัวกับเพื่อนร่วมทริป',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'มาจากไหน เคยไปทริปแบบนี้ไหม — ขึ้นเป็นการ์ดของคุณ',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openIntro();
                    },
                  ),
                if (_contactsInfo['window_open'] == true ||
                    (int.tryParse('${_contactsInfo['incoming']}') ?? 0) > 0)
                  ListTile(
                    leading: Badge(
                      isLabelVisible:
                          (int.tryParse('${_contactsInfo['incoming']}') ?? 0) > 0,
                      label: Text('${_contactsInfo['incoming']}'),
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      'แลกคอนแทคกับเพื่อนร่วมทริป',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ขอ LINE/IG กัน — ต้องตกลงทั้งสองฝ่ายถึงจะเห็น',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openContacts();
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    _canModerate ? 'แจ้งของที่เจอ (ของหาย)' : 'ของหาย / ลืมของ',
                    style: appFont(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _canModerate
                        ? 'ถ่ายรูปของที่ลูกทริปลืมไว้ แจ้งทุกคนในทริป'
                        : 'ดูของที่ทีมงานเจอ ถ้าเป็นของคุณกด "ของฉัน"',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openLostItems(startPosting: _canModerate);
                  },
                ),
                if (_canModerate || _room?['has_rooms'] == true)
                  ListTile(
                    leading: const Icon(
                      Icons.bed_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      _canModerate ? 'จัดห้องพัก' : 'ห้องพัก',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _canModerate
                          ? 'จัดใครนอนห้องไหนกับใคร แล้วประกาศให้ทุกคน'
                          : 'ดูว่าคุณพักห้องไหนกับใคร',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TripRoomsScreen(
                            scheduleId: widget.scheduleId,
                            canManage: _canModerate,
                          ),
                        ),
                      );
                    },
                  ),
                if (!_canModerate && _privateChat != null)
                  ListTile(
                    leading: const Icon(
                      Icons.lock_person_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'ถามทีมงานแบบส่วนตัว',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ทีมงานเห็นคนเดียว ไม่ขึ้นในห้องรวม — สุขภาพ ค่าใช้จ่าย เรื่องไม่สบายใจ',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openPrivateChat();
                    },
                  ),
                if (!_canModerate && _canRequestStop) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.record_voice_over_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      _myStopKinds.isEmpty
                          ? 'บอกทีมงานแบบไม่บอกชื่อ'
                          : 'บอกทีมงานแล้ว ${_myStopKinds.length} เรื่อง',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ขอแวะห้องน้ำ · แอร์หนาว/ร้อน · ขับเร็วไป · ขอเบาเพลง',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _requestStop();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.medical_services_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(
                      'ขอยา / ของจำเป็น',
                      style: appFont(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'ยาแก้เมารถ ถุงอาเจียน พลาสเตอร์ — ทีมงานนำไปให้ที่นั่ง',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openSupplyRequest();
                    },
                  ),
                ],
                // รูปในห้องนี้ถูกลบพร้อมห้องแชทหลังจบทริป (PurgeEndedTripChatsJob
                // ฝั่งเซิร์ฟเวอร์ — ต้องแก้คู่กันถ้าเปลี่ยนจำนวนวัน) บอกตั้งแต่ตอนจะส่ง
                // ดีกว่าให้ลูกค้ามารู้ตอนที่รูปหายไปแล้ว
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppTheme.mutedText(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'รูปที่ส่งในห้องนี้จะถูกลบพร้อมห้องแชท 3 วันหลังจบทริป '
                          'อยากให้อยู่ถาวรลงในฟีดทริปได้ครับ',
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onScroll() {
    if (_scroll.position.pixels <= 80) _loadMore();
    final nearBottom = _isNearBottom();
    final shouldShow = !nearBottom;
    if (shouldShow != _showJumpButton) {
      setState(() => _showJumpButton = shouldShow);
    }
    if (nearBottom && _newWhileAway != 0) {
      setState(() => _newWhileAway = 0);
    }
  }

  /// Conservative auto-scroll: only treat the user as "at the bottom" if we
  /// actually know the scroll position. Returning `true` when there's no
  /// client (e.g. first frame) was causing surprise jumps when the keyboard
  /// opened on a long history.
  bool _isNearBottom() {
    if (!_scroll.hasClients) return false;
    return _scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 120;
  }

  @override
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _jumpToLatest() {
    setState(() => _newWhileAway = 0);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  /// True when [message] tags the current user via @mention.
  bool _mentionsMe(Map<String, dynamic> message) {
    final me = _myUserId;
    if (me == null) return false;
    final raw = message['mentions'];
    if (raw is! List) return false;
    return raw.any((e) => int.tryParse('$e') == me);
  }

  /// Messages that tag me and arrived after my last acknowledged mention —
  /// the queue behind the "@ ถูกแท็ก" jump chip, oldest first.
  List<Map<String, dynamic>> get _unreadMentions => _messages.where((m) {
        if (m['is_mine'] == true || m['is_deleted'] == true) return false;
        if (!_mentionsMe(m)) return false;
        return (int.tryParse('${m['id']}') ?? 0) > _mentionAckId;
      }).toList();

  /// Jump to the oldest unread mention of me and mark it acknowledged so the
  /// next tap advances to the one after it.
  void _jumpToNextMention() {
    final pending = _unreadMentions;
    if (pending.isEmpty) return;
    HapticFeedback.selectionClick();
    final target = pending.first;
    final id = int.tryParse('${target['id']}') ?? 0;
    setState(() => _mentionAckId = id);
    _scrollToMessage(id);
  }

  // ── Realtime signal handlers ──────────────────────────────────────────────

  void _onReadSignal(Map<String, dynamic> data) {
    final userId = int.tryParse('${data['user_id']}');
    final lastRead = int.tryParse('${data['last_read_message_id']}') ?? 0;
    final room = _room;
    if (userId == null || room == null) return;
    final members = (room['members'] as List?)?.cast<dynamic>();
    if (members == null) return;
    var changed = false;
    for (final raw in members) {
      if (raw is Map && int.tryParse('${raw['id']}') == userId) {
        final cur = int.tryParse('${raw['last_read_message_id']}') ?? 0;
        if (lastRead > cur) {
          raw['last_read_message_id'] = lastRead;
          changed = true;
        }
      }
    }
    if (changed) setState(() {});
  }

  void _onTypingSignal(Map<String, dynamic> data) {
    final userId = int.tryParse('${data['user_id']}');
    if (userId == null || userId == _myUserId) return;
    final name = data['name']?.toString() ?? 'สมาชิก';
    _typing[userId] = (name: name, until: DateTime.now().add(
      const Duration(seconds: 4),
    ));
    _ensureTypingSweeper();
    setState(() {});
  }

  void _ensureTypingSweeper() {
    _typingSweeper ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      _typing.removeWhere((_, v) => v.until.isBefore(now));
      if (mounted) setState(() {});
      if (_typing.isEmpty) {
        _typingSweeper?.cancel();
        _typingSweeper = null;
      }
    });
  }

  String? _typingLabel() {
    if (_typing.isEmpty) return null;
    final names = _typing.values.map((v) => v.name).toList();
    if (names.length == 1) return '${names.first} กำลังพิมพ์…';
    if (names.length == 2) return '${names[0]} และ ${names[1]} กำลังพิมพ์…';
    return '${names.length} คนกำลังพิมพ์…';
  }

  void _onJoinedSignal(Map<String, dynamic> data) {
    final userId = int.tryParse('${data['user_id']}');
    if (userId == null || userId == _myUserId) return;

    // Cooldown per person so re-opening the room doesn't spam everyone else.
    final now = DateTime.now();
    final lastShown = _joinedShownAt[userId];
    if (lastShown != null && now.difference(lastShown) < _joinedCooldown) return;
    _joinedShownAt[userId] = now;

    final name = data['name']?.toString() ?? 'สมาชิก';
    final role = data['role']?.toString() ?? 'customer';
    _joined[userId] = (
      name: name,
      role: role,
      until: now.add(const Duration(seconds: 4)),
    );
    _ensureJoinedSweeper();
    setState(() {});
  }

  void _ensureJoinedSweeper() {
    _joinedSweeper ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      _joined.removeWhere((_, v) => v.until.isBefore(now));
      if (mounted) setState(() {});
      if (_joined.isEmpty) {
        _joinedSweeper?.cancel();
        _joinedSweeper = null;
      }
    });
  }

  String? _joinedLabel() {
    if (_joined.isEmpty) return null;
    final entries = _joined.values.toList();
    if (entries.length == 1) {
      final one = entries.first;
      return _isStaffRole(one.role)
          ? 'ทีมงาน ${one.name} เข้าห้องแชทแล้ว'
          : '${one.name} เข้าห้องแชท';
    }
    final names = entries.map((v) => v.name).toList();
    if (names.length == 2) return '${names[0]} และ ${names[1]} เข้าห้องแชท';
    return '${names.length} คนเข้าห้องแชท';
  }

  /// True when anyone in the current notice is crew — the banner then reads as
  /// "ทีมงานมาแล้ว" rather than a regular traveller walking in.
  bool _joinedHasStaff() => _joined.values.any((v) => _isStaffRole(v.role));

  static bool _isStaffRole(String role) => role == 'staff' || role == 'admin';

  void _onReactionSignal(Map<String, dynamic> data) {
    final messageId = int.tryParse('${data['message_id']}');
    if (messageId == null) return;
    final reactions = data['reactions'] as List? ?? const [];
    final idx = _messages.indexWhere((m) => int.tryParse('${m['id']}') == messageId);
    if (idx == -1) return;
    setState(() => _messages[idx]['reactions'] = reactions);
  }

  void _onPinnedSignal(Map<String, dynamic> data) {
    setState(() => _setPins(data['pinned'], data['message']));
  }

  // ── Composer / message actions ────────────────────────────────────────────

  void _onInputChanged(String value) {
    _updateMentionQuery(value);

    // Throttle typing pings to at most one every 2.5s while actively typing.
    final now = DateTime.now();
    if (_lastTypingSentAt != null &&
        now.difference(_lastTypingSentAt!) < const Duration(milliseconds: 2500)) {
      return;
    }
    if (_input.text.trim().isEmpty) return;
    _lastTypingSentAt = now;
    context.read<AppProvider>().sendChatTyping(widget.scheduleId);
  }

  /// Detect an in-progress "@query" at the caret so the suggestion bar can
  /// offer room members. Active only when the last token starts with "@" and
  /// has no whitespace yet.
  void _updateMentionQuery(String value) {
    final sel = _input.selection.baseOffset;
    final caret = (sel >= 0 && sel <= value.length) ? sel : value.length;
    final upToCaret = value.substring(0, caret);
    final at = upToCaret.lastIndexOf('@');
    String? query;
    if (at >= 0) {
      final token = upToCaret.substring(at + 1);
      if (!token.contains(RegExp(r'\s'))) query = token;
    }
    if (query != _mentionQuery) {
      setState(() => _mentionQuery = query);
    }
  }

  /// Room members matching the active "@query" (excluding myself).
  List<Map<String, dynamic>> get _mentionSuggestions {
    final q = _mentionQuery;
    if (q == null) return const [];
    final lower = q.toLowerCase();
    return _members.where((m) {
      if (m['is_me'] == true) return false;
      final label = _mentionLabel(m).toLowerCase();
      return lower.isEmpty || label.contains(lower);
    }).take(6).toList();
  }

  String _mentionLabel(Map<String, dynamic> member) {
    final nick = member['nickname']?.toString().trim() ?? '';
    if (nick.isNotEmpty) return nick;
    final name = member['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'ผู้ใช้' : name.split(RegExp(r'\s+')).first;
  }

  /// Whether to offer the "@All" everyone-mention while typing "@…". Shown when
  /// there's at least one other member and the active query is a prefix of
  /// "all" (or empty), mirroring LINE's @All affordance.
  bool get _showAllMention {
    final q = _mentionQuery;
    if (q == null) return false;
    final hasOthers = _members.any((m) => m['is_me'] != true);
    if (!hasOthers) return false;
    final lower = q.toLowerCase();
    return lower.isEmpty || 'all'.startsWith(lower);
  }

  /// Replace the active "@query" with "@All " — tagging everyone in the room.
  /// No pick is recorded; [_activeMentionIds] expands the token on send.
  void _applyAllMention() {
    final value = _input.text;
    final sel = _input.selection.baseOffset;
    final caret = (sel >= 0 && sel <= value.length) ? sel : value.length;
    final upToCaret = value.substring(0, caret);
    final at = upToCaret.lastIndexOf('@');
    if (at < 0) return;

    final newPrefix = '${value.substring(0, at)}@All ';
    final newText = newPrefix + value.substring(caret);
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newPrefix.length),
    );
    setState(() => _mentionQuery = null);
  }

  /// Replace the active "@query" with "@label " and record the mention pick.
  void _applyMention(Map<String, dynamic> member) {
    final label = _mentionLabel(member);
    final id = int.tryParse('${member['user_id'] ?? member['id']}');
    final value = _input.text;
    final sel = _input.selection.baseOffset;
    final caret = (sel >= 0 && sel <= value.length) ? sel : value.length;
    final upToCaret = value.substring(0, caret);
    final at = upToCaret.lastIndexOf('@');
    if (at < 0) return;

    final newPrefix = '${value.substring(0, at)}@$label ';
    final newText = newPrefix + value.substring(caret);
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newPrefix.length),
    );
    setState(() {
      if (id != null) _mentionPicks.add({'id': id, 'label': label});
      _mentionQuery = null;
    });
  }

  Future<void> _toggleReaction(int messageId, String emoji) async {
    HapticFeedback.selectionClick();
    try {
      final reactions = await context
          .read<AppProvider>()
          .reactChatMessage(widget.scheduleId, messageId, emoji);
      if (!mounted) return;
      final idx = _messages
          .indexWhere((m) => int.tryParse('${m['id']}') == messageId);
      if (idx != -1) setState(() => _messages[idx]['reactions'] = reactions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // ── คำถามด่วน "ข้อมูลการเดินทางของฉัน" ───────────────────────────────────

  /// เปิดชีตจากแถบคำตอบอัตโนมัติ — เปิดแล้วถือว่าตอบไปแล้ว เก็บแถบได้
  Future<void> _openSuggestion(_QuickAsk ask) async {
    setState(() {
      _dismissedSuggestion = _suggestedFrom;
      _suggested = null;
    });
    await _openTripInfo(ask);
  }

  /// เปิดคำตอบของคำถามที่กด — โหลดข้อมูลครั้งแรกครั้งเดียวแล้วแคชไว้
  Future<void> _openTripInfo(_QuickAsk ask) async {
    HapticFeedback.selectionClick();

    // ตำแหน่งรถเปลี่ยนทุกนาที — ถามเรื่องรถหรือข้อมูลเก่าเกินนาทีให้ดึงใหม่เสมอ
    final stale = _tripInfoAt == null ||
        DateTime.now().difference(_tripInfoAt!) > const Duration(minutes: 1);
    if (_tripInfo == null || (ask == _QuickAsk.van && stale)) {
      try {
        final info = await context.read<AppProvider>().chatTripInfo(
          widget.scheduleId,
        );
        if (!mounted) return;
        setState(() {
          _tripInfo = info;
          _tripInfoAt = DateTime.now();
        });
      } catch (e) {
        _snack(e.toString());
        return;
      }
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => _TripInfoSheet(
        info: _tripInfo!,
        focus: ask,
        scheduleId: widget.scheduleId,
        tripTitle: _tripTitle,
        onTrack: _openTracking,
      ),
    );
  }

  /// แผนที่ติดตามรถของใบจองฉัน — ตัวเดียวกับหน้า "วันเดินทาง"
  Future<void> _openTracking() async {
    final ref = _tripInfo?['booking_ref']?.toString() ?? '';
    if (ref.isEmpty) {
      _snack('ยังไม่มีข้อมูลติดตามรถสำหรับรอบนี้');
      return;
    }
    final provider = context.read<TrackingProvider>();
    final token = context.read<AppProvider>().api.token;
    final navigator = Navigator.of(context);
    provider.stopTracking();
    await provider.startTracking(ref, authToken: token);
    if (!mounted) return;
    if (provider.errorMessage.isNotEmpty || provider.booking == null) {
      _snack(
        provider.errorMessage.isNotEmpty
            ? provider.errorMessage
            : 'ยังไม่มีข้อมูลติดตามรถสำหรับรอบนี้',
      );
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => const TrackingMapPage()));
  }

  /// สตาฟกดส่งสรุปการเดินทางเข้าห้อง — ตอบทุกคนพร้อมกันด้วยปุ่มเดียว
  Future<void> _sendTripSummary() async {
    HapticFeedback.mediumImpact();
    try {
      final message = await context.read<AppProvider>().postChatTripSummary(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// สตาฟกดส่งกำหนดการเข้าห้อง — คำถามที่ถูกถามซ้ำที่สุดรองจากจุดรับ
  Future<void> _sendTripItinerary() async {
    HapticFeedback.mediumImpact();
    try {
      final message = await context.read<AppProvider>().postChatTripItinerary(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
    } catch (e) {
      _snack(e.toString());
    }
  }

  // ── โพลในห้อง ────────────────────────────────────────────────────────────

  /// เปิดชีตสร้างโพล แล้วส่งขึ้นห้องเมื่อกรอกครบ
  Future<void> _createPoll() async {
    if (_sending) return;
    final draft = await showModalBottomSheet<_PollDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => const _CreatePollSheet(),
    );
    if (draft == null || !mounted) return;

    try {
      final message = await context.read<AppProvider>().createChatPoll(
        widget.scheduleId,
        question: draft.question,
        options: draft.options,
        allowMultiple: draft.allowMultiple,
        durationHours: draft.durationHours,
      );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// ลงคะแนน — อัปเดตการ์ดในห้องด้วย payload ที่เซิร์ฟเวอร์ตอบกลับ
  Future<void> _votePoll(int messageId, int pollId, List<int> optionIds) async {
    HapticFeedback.selectionClick();
    try {
      final result = await context.read<AppProvider>().voteChatPoll(
        widget.scheduleId,
        pollId,
        optionIds,
      );
      if (!mounted) return;
      _applyPoll(messageId, result['poll']);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _closePoll(int messageId, int pollId) async {
    try {
      final result = await context
          .read<AppProvider>()
          .closeChatPoll(widget.scheduleId, pollId);
      if (!mounted) return;
      _applyPoll(messageId, result['poll']);
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// Realtime: มีคนโหวต/ปิดโพล — ทับข้อมูลโพลบนการ์ดนั้น แต่คง "ข้อที่ฉันเลือก"
  /// ไว้ตามที่เครื่องนี้รู้ เพราะ payload ที่ broadcast มาไม่ผูกกับผู้ใช้คนไหน
  void _onPollSignal(Map<String, dynamic> data) {
    final messageId = int.tryParse('${data['message_id']}');
    if (messageId == null || data['poll'] is! Map) return;
    _applyPoll(messageId, data['poll'], fromBroadcast: true);
  }

  void _applyPoll(int messageId, dynamic poll, {bool fromBroadcast = false}) {
    if (poll is! Map || !mounted) return;
    _refreshTodos();
    final idx = _messages.indexWhere(
      (m) => int.tryParse('${m['id']}') == messageId,
    );
    if (idx < 0) return;

    final next = Map<String, dynamic>.from(poll);
    if (fromBroadcast) {
      // เติมมุมมองของผู้ใช้คนนี้กลับเข้าไปจาก voter_ids ที่แนบมากับแต่ละข้อ
      final mine = <int>[];
      final options = <Map<String, dynamic>>[];
      for (final o in (next['options'] as List? ?? [])) {
        final option = Map<String, dynamic>.from(o as Map);
        final votedByMe =
            _myUserId != null &&
            (option['voter_ids'] as List? ?? [])
                .map((v) => int.tryParse('$v'))
                .contains(_myUserId);
        option['voted_by_me'] = votedByMe;
        if (votedByMe) mine.add(int.tryParse('${option['id']}') ?? 0);
        options.add(option);
      }
      next['options'] = options;
      next['my_option_ids'] = mine;
    }

    setState(() => _messages[idx] = {..._messages[idx], 'poll': next});
  }

  /// เปิดชีตเริ่มโหวตตัดสิน แล้วส่งขึ้นห้อง
  Future<void> _createVote() async {
    if (_sending) return;
    final draft = await showModalBottomSheet<VoteDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => const CreateVoteSheet(),
    );
    if (draft == null || !mounted) return;

    try {
      final message = await context.read<AppProvider>().createChatPoll(
        widget.scheduleId,
        kind: 'vote',
        question: draft.question,
        options: draft.options,
        durationMinutes: draft.minutes,
      );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// ลูกทริปในห้อง (ไม่นับสตาฟ) — ตัวหารของ "โหวตแล้ว x/y" และรายชื่อคนที่ยังไม่โหวต/ไม่สั่ง
  List<Map<String, dynamic>> get _travellers => _members
      .where((m) => m['role'] != 'staff')
      .map((m) => {
            'id': int.tryParse('${m['id']}') ?? 0,
            'name': (m['nickname']?.toString().isNotEmpty ?? false)
                ? m['nickname'].toString()
                : (m['name']?.toString() ?? ''),
          })
      .toList();

  // ── รับออเดอร์อาหาร ──────────────────────────────────────────────────────

  @override
  Future<T?> _showSheet<T>(Widget sheet) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => sheet,
    );
  }

  /// สตาฟเปิดรอบรับออเดอร์ — การ์ดลงห้องและเด้งแจ้งทุกคน
  Future<void> _openFoodRound() async {
    final draft = await _showSheet<FoodRoundDraft>(const OpenFoodRoundSheet());
    if (draft == null || !mounted) return;

    try {
      final message = await context.read<AppProvider>().openChatFoodRound(
        widget.scheduleId,
        title: draft.title,
        note: draft.note,
        durationMinutes: draft.minutes,
      );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// สั่ง/แก้ออเดอร์ของตัวเอง
  Future<void> _orderFood(int messageId, Map<String, dynamic> round) async {
    final roundId = int.tryParse('${round['id']}') ?? 0;
    if (roundId == 0) return;
    final draft = await _showSheet<FoodOrderDraft>(
      FoodOrderSheet(round: round, existing: myFoodOrder(round, _myUserId)),
    );
    if (draft == null || !mounted) return;

    final app = context.read<AppProvider>();
    try {
      final result = draft.withdraw
          ? await app.withdrawMyFoodOrder(widget.scheduleId, roundId)
          : await app.saveMyFoodOrder(
              widget.scheduleId,
              roundId,
              items: draft.items,
              skipped: draft.skipped,
            );
      if (!mounted) return;
      _applyFood(messageId, result['food_round']);
      HapticFeedback.mediumImpact();
      _snack(draft.withdraw
          ? 'ลบออเดอร์แล้ว'
          : (draft.skipped ? 'บอกทีมงานแล้วว่ารอบนี้ไม่สั่ง' : 'ส่งออเดอร์แล้ว'));
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// รายการรวม — ทุกคนเปิดดูได้ สตาฟได้ปุ่มจดแทน/ลบ/ปิดรับเพิ่ม
  Future<void> _openFoodSummary(int messageId, Map<String, dynamic> round) async {
    final roundId = int.tryParse('${round['id']}') ?? 0;
    if (roundId == 0) return;
    final app = context.read<AppProvider>();

    _foodSheetMessageId = messageId;
    _foodSheetRound.value = round;
    _foodSheetDietary.value = const [];
    if (_canModerate) {
      app.loadFoodDietary(widget.scheduleId, roundId).then((alerts) {
        if (mounted && _foodSheetMessageId == messageId) {
          _foodSheetDietary.value = alerts;
        }
      }).catchError((_) {});
    }
    // socket หลุดเมื่อไรการ์ดจะไม่ขยับ — ระหว่างเปิดชีตค้างไว้ ดึงซ้ำเป็นระยะ
    _foodSheetRefresh?.cancel();
    _refreshMessage(messageId);
    _foodSheetRefresh = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshMessage(messageId),
    );

    Future<void> run(Future<Map<String, dynamic>> Function() call) async {
      try {
        final result = await call();
        if (mounted) _applyFood(messageId, result['food_round']);
      } catch (e) {
        _snack(e.toString());
      }
    }

    await _showSheet<void>(
      FoodRoundSummarySheet(
        round: _foodSheetRound,
        travellers: _travellers,
        canManage: _canModerate,
        myUserId: _myUserId,
        dietary: _canModerate ? _foodSheetDietary : null,
        onDeleteOrder: (orderId) =>
            run(() => app.deleteFoodOrder(widget.scheduleId, roundId, orderId)),
        onSetPaid: (orderId, paid) => run(
          () => app.setFoodOrderPaid(
            widget.scheduleId,
            roundId,
            orderId,
            paid: paid,
          ),
        ),
        onOpenBill: () async {
          final current = _foodSheetRound.value ?? round;
          final draft = await _showSheet<FoodBillDraft>(
            FoodBillSheet(round: current),
          );
          if (draft == null) return;
          await run(
            () => app.billChatFoodRound(
              widget.scheduleId,
              roundId,
              prices: draft.prices,
              promptPayId: draft.promptPayId,
              payeeName: draft.payeeName,
              notify: draft.notify,
            ),
          );
          if (draft.notify) _snack('ส่งยอดให้ทุกคนแล้ว');
        },
        onSetClosed: (close) => run(
          () => app.setChatFoodRoundClosed(widget.scheduleId, roundId, closed: close),
        ),
        onAddOnBehalf: () async {
          final current = _foodSheetRound.value ?? round;
          final draft = await _showSheet<FoodOrderDraft>(
            FoodOrderSheet(round: current, onBehalf: true),
          );
          if (draft == null || draft.name == null) return;
          await run(
            () => app.addFoodOrderOnBehalf(
              widget.scheduleId,
              roundId,
              name: draft.name!,
              items: draft.items,
            ),
          );
        },
      ),
    );

    _foodSheetRefresh?.cancel();
    _foodSheetRefresh = null;
    _foodSheetMessageId = null;
  }

  /// QR จ่ายค่าอาหารของฉัน → กด "โอนแล้ว" แจ้งทีมงาน
  Future<void> _payFood(int messageId, Map<String, dynamic> round) async {
    final roundId = int.tryParse('${round['id']}') ?? 0;
    final mine = myFoodOrder(round, _myUserId);
    if (roundId == 0 || mine == null || round['billing'] is! Map) return;

    final claimed = await _showSheet<bool>(
      FoodPaySheet(
        order: mine,
        billing: Map<String, dynamic>.from(round['billing'] as Map),
      ),
    );
    if (claimed == null || !mounted) return;
    try {
      final result = await context.read<AppProvider>().claimFoodPaid(
            widget.scheduleId,
            roundId,
            claimed: claimed,
          );
      if (!mounted) return;
      _applyFood(messageId, result['food_round']);
      _snack(claimed ? 'แจ้งทีมงานแล้ว รอเช็กยอดเข้า' : 'ถอนการแจ้งแล้ว');
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// ดึงข้อความการ์ดใบเดียวกลับมาใหม่ (after_id = id - 1 → ใบแรกคือใบนั้น)
  Future<void> _refreshMessage(int messageId) async {
    try {
      final data = await context
          .read<AppProvider>()
          .chatMessages(widget.scheduleId, afterId: messageId - 1);
      final fresh = (data['messages'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((m) => int.tryParse('${m['id']}') == messageId)
          .firstOrNull;
      if (fresh != null && fresh['food_round'] is Map) {
        _applyFood(messageId, fresh['food_round']);
      }
    } catch (_) {
      // เครือข่ายสะดุด — รอบถัดไปลองใหม่
    }
  }

  void _onFoodSignal(Map<String, dynamic> data) {
    final messageId = int.tryParse('${data['message_id']}');
    if (messageId == null || data['food_round'] is! Map) return;
    _applyFood(messageId, data['food_round']);
  }

  void _applyFood(int messageId, dynamic round) {
    if (round is! Map || !mounted) return;
    _refreshTodos();
    final next = Map<String, dynamic>.from(round);
    if (_foodSheetMessageId == messageId) _foodSheetRound.value = next;

    final idx = _messages.indexWhere(
      (m) => int.tryParse('${m['id']}') == messageId,
    );
    if (idx < 0) return;
    setState(() => _messages[idx] = {..._messages[idx], 'food_round': next});
  }

  // ── คำขอถึงทีมงาน: ไม่บอกชื่อ (ห้องน้ำ/แอร์/ความเร็ว/เพลง) + ขอยา/ของ ──────

  Map<String, dynamic> get _stopRequests => _room?['stop_requests'] is Map
      ? Map<String, dynamic>.from(_room!['stop_requests'] as Map)
      : const {};

  /// จำนวนที่ยังนับอยู่ต่อเรื่อง — เซิร์ฟเวอร์รุ่นก่อนมีแค่ pending (ห้องน้ำ)
  Map<String, int> get _stopCounts {
    final kinds = _stopRequests['kinds'];
    if (kinds is Map) {
      return {
        for (final e in kinds.entries) '${e.key}': int.tryParse('${e.value}') ?? 0,
      };
    }
    return {'toilet': int.tryParse('${_stopRequests['pending']}') ?? 0};
  }

  List<Map<String, dynamic>> get _stopKinds {
    final raw = _room?['stop_request_kinds'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return fallbackStopKinds;
  }

  List<Map<String, dynamic>> get _supplyItems =>
      (_room?['supply_items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  Set<String> get _myStopKinds {
    final raw = _room?['my_stop_requests'];
    if (raw is List) return {for (final k in raw) '$k'};
    return _room?['my_stop_request'] == true ? {'toilet'} : <String>{};
  }

  bool get _canRequestStop => _room?['can_request_stop'] == true;

  int get _supplyPending =>
      int.tryParse('${_room?['supply_requests_pending']}') ?? 0;

  void _setStopRequests(Map<String, dynamic> data) {
    if (!mounted || _room == null) return;
    setState(() {
      _room = {
        ..._room!,
        'stop_requests': {
          'pending': int.tryParse('${data['pending']}') ?? 0,
          'urgent': int.tryParse('${data['urgent']}') ?? 0,
          if (data['kinds'] is Map) 'kinds': data['kinds'],
        },
        if (data['mine_kinds'] is List) ...{
          'my_stop_requests': data['mine_kinds'],
          'my_stop_request':
              (data['mine_kinds'] as List).map((e) => '$e').contains('toilet'),
        },
      };
    });
  }

  /// สัญญาณจากห้อง (ไม่ผูกผู้ใช้) — เรื่องที่ทีมงานรับทราบแล้วนับเป็น 0
  /// ถ้าฉันขอเรื่องนั้นค้างไว้ แปลว่าของฉันก็ถูกตอบไปด้วย
  void _onStopRequestsSignal(Map<String, dynamic> data) {
    _setStopRequests(Map<String, dynamic>.from(data)..remove('mine'));
    final kinds = data['kinds'] is Map
        ? Map<String, dynamic>.from(data['kinds'] as Map)
        : {'toilet': data['pending']};
    final stillMine = _myStopKinds
        .where((k) => (int.tryParse('${kinds[k]}') ?? 0) > 0)
        .toList();
    if (stillMine.length != _myStopKinds.length && mounted && _room != null) {
      setState(() {
        _room = {
          ..._room!,
          'my_stop_requests': stillMine,
          'my_stop_request': stillMine.contains('toilet'),
        };
      });
    }
  }

  Future<void> _requestStop() async {
    final action = await _showSheet<AnonRequestAction>(
      AnonRequestSheet(kinds: _stopKinds, mine: _myStopKinds),
    );
    if (action == null || !mounted) return;
    final app = context.read<AppProvider>();
    try {
      final result = action.cancel
          ? await app.cancelChatStopRequest(
              widget.scheduleId,
              kind: action.kind,
            )
          : await app.requestChatStop(
              widget.scheduleId,
              urgent: action.urgent,
              kind: action.kind,
            );
      _setStopRequests(result);
      _snack(action.cancel ? 'ถอนแล้ว' : 'ส่งแล้ว ทีมงานไม่เห็นชื่อคุณ');
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// ทีมงานแตะเรื่องในแถบ — ห้องน้ำเลือกว่าจะแวะเมื่อไร เรื่องอื่นยืนยันแล้วรับทราบ
  Future<void> _acknowledgeStops(String kind) async {
    int? minutes;
    if (kind == 'toilet') {
      final picked = await _showSheet<int>(const AcknowledgeStopSheet());
      if (picked == null || !mounted) return;
      minutes = picked < 0 ? null : picked;
    } else {
      final meta = _stopKinds.firstWhere(
        (k) => k['key'] == kind,
        orElse: () => {'label': kind, 'emoji': ''},
      );
      final ok = await showConfirmDialog(
        context,
        title: '${meta['emoji']} ${meta['label']} ${_stopCounts[kind] ?? 0} คน',
        message:
            'จัดการแล้วกดรับทราบ ระบบบอกห้องและแจ้งคนที่ขอให้เอง (ไม่เอ่ยชื่อ)',
        icon: Icons.done_all_rounded,
        confirmLabel: 'รับทราบ',
        cancelLabel: 'ยังก่อน',
      );
      if (!ok || !mounted) return;
    }
    try {
      final result = await context.read<AppProvider>().acknowledgeChatStopRequests(
            widget.scheduleId,
            minutes: minutes,
            kind: kind,
          );
      _setStopRequests(result);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  // ── ขอยา / ของจำเป็น ────────────────────────────────────────────────────

  final _supplyQueue = ValueNotifier<Map<String, dynamic>?>(null);
  bool _supplyQueueOpen = false;

  Future<void> _openSupplyRequest() async {
    final app = context.read<AppProvider>();
    final items = _supplyItems;
    if (items.isEmpty) {
      _snack('อัปเดตห้องแชทไม่สำเร็จ ลองเปิดห้องใหม่อีกครั้ง');
      return;
    }
    await _showSheet<void>(
      SupplyRequestSheet(
        items: items,
        load: () => app.loadChatSupplies(widget.scheduleId),
        onSend: (item, passengerId, note) async {
          try {
            await app.requestChatSupply(
              widget.scheduleId,
              item: item,
              passengerId: passengerId,
              note: note,
            );
            _snack('ส่งคำขอแล้ว ทีมงานกำลังนำไปให้ครับ');
          } catch (e) {
            _snack(e.toString());
            rethrow;
          }
        },
        onCancel: (id) async {
          try {
            await app.cancelChatSupply(widget.scheduleId, id);
          } catch (e) {
            _snack(e.toString());
            rethrow;
          }
        },
      ),
    );
  }

  Future<void> _refreshSupplyQueue() async {
    try {
      final data = await context.read<AppProvider>().loadChatSupplies(
            widget.scheduleId,
          );
      if (!mounted) return;
      _supplyQueue.value = data;
      _setSupplyPending(int.tryParse('${data['pending']}') ?? 0);
    } catch (_) {
      // ไม่เป็นไร — สัญญาณครั้งหน้าหรือการเปิดใหม่ดึงให้อีกรอบ
    }
  }

  void _setSupplyPending(int pending) {
    if (!mounted || _room == null) return;
    setState(() => _room = {..._room!, 'supply_requests_pending': pending});
  }

  void _onSuppliesSignal(Map<String, dynamic> data) {
    if (!_canModerate) return;
    _setSupplyPending(int.tryParse('${data['pending']}') ?? 0);
    if (_supplyQueueOpen) _refreshSupplyQueue();
  }

  Future<void> _openSupplyQueue() async {
    final app = context.read<AppProvider>();
    _supplyQueue.value = null;
    _supplyQueueOpen = true;
    _refreshSupplyQueue();

    Future<void> run(Future<void> Function() call) async {
      try {
        await call();
      } catch (e) {
        _snack(e.toString());
      }
      await _refreshSupplyQueue();
    }

    await _showSheet<void>(
      SupplyQueueSheet(
        data: _supplyQueue,
        onDeliver: (id) =>
            run(() => app.deliverChatSupply(widget.scheduleId, id)),
        onDecline: (id, note) =>
            run(() => app.declineChatSupply(widget.scheduleId, id, note: note)),
      ),
    );
    _supplyQueueOpen = false;
  }

  Future<void> _openRestStop() async {
    final draft = await _showSheet<RestStopDraft>(const OpenRestStopSheet());
    if (draft == null || !mounted) return;
    try {
      final message = await context.read<AppProvider>().openChatRestStop(
            widget.scheduleId,
            minutes: draft.minutes,
            place: draft.place,
          );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  // ── ของหาย ───────────────────────────────────────────────────────────────

  Future<void> _openLostItems({bool startPosting = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LostItemsScreen(
          scheduleId: widget.scheduleId,
          startPosting: startPosting,
        ),
      ),
    );
    // กลับมาจากหน้าของหาย — สถานะการ์ด (มีเจ้าของ/คืนแล้ว) อาจเปลี่ยนไประหว่างนั้น
    // ดึงรายการของรอบนี้แล้วทับการ์ดที่ตรงกัน (เผื่อ socket หลุด)
    if (!mounted) return;
    try {
      final data = await context.read<AppProvider>().loadLostItems(
            scheduleId: widget.scheduleId,
          );
      for (final raw in (data['items'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final messageId = int.tryParse('${item['message_id']}');
        if (messageId != null) {
          _onLostItemSignal({'message_id': messageId, 'lost_item': item});
        }
      }
    } catch (_) {
      // ไม่เป็นไร — realtime หรือการเปิดห้องครั้งหน้าจะอัปเดตให้เอง
    }
  }

  void _onLostItemSignal(Map<String, dynamic> data) {
    final messageId = int.tryParse('${data['message_id']}');
    if (messageId == null || data['lost_item'] is! Map || !mounted) return;
    final idx = _messages.indexWhere(
      (m) => int.tryParse('${m['id']}') == messageId,
    );
    if (idx < 0) return;
    setState(
      () => _messages[idx] = {
        ..._messages[idx],
        'lost_item': Map<String, dynamic>.from(data['lost_item'] as Map),
      },
    );
  }

  // ── เก็บเงินหน้างาน ──────────────────────────────────────────────────────

  Future<void> _openCollection() async {
    final app = context.read<AppProvider>();
    List<Map<String, dynamic>> roster;
    try {
      roster = await app.loadChatRoster(widget.scheduleId);
    } catch (e) {
      _snack(e.toString());
      return;
    }
    if (!mounted) return;
    if (roster.isEmpty) {
      _snack('ยังไม่มีผู้เดินทางที่ยืนยันแล้วในรอบนี้');
      return;
    }
    final draft = await _showSheet<CollectionDraft>(
      OpenCollectionSheet(roster: roster),
    );
    if (draft == null || !mounted) return;
    try {
      final message = await app.openChatCollection(
        widget.scheduleId,
        title: draft.title,
        amount: draft.amount,
        note: draft.note,
        passengerIds: draft.passengerIds,
        promptPayId: draft.promptPayId,
        payeeName: draft.payeeName,
      );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _payCollection(int messageId, Map<String, dynamic> c) async {
    final id = int.tryParse('${c['id']}') ?? 0;
    if (id == 0) return;
    final claimed = await showCollectionPaySheet(context, c, _myUserId);
    if (claimed == null || !mounted) return;
    final app = context.read<AppProvider>();

    // แจ้งโอนต้องมีสลิป — ทีมงานยืนยันยอดโอนได้เฉพาะคนที่แนบ (กันกดโอนแล้วลอยๆ)
    String? slipPath;
    if (claimed) {
      final XFile? picked;
      try {
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2000,
          imageQuality: 90,
        );
      } catch (_) {
        _snack('เปิดคลังรูปไม่ได้ ลองใหม่อีกครั้งครับ');
        return;
      }
      if (picked == null || !mounted) return;
      slipPath = picked.path;
      _snack('กำลังส่งสลิป…');
    }

    try {
      final result = slipPath != null
          ? await app.claimChatCollection(
              widget.scheduleId,
              id,
              slipPath: slipPath,
            )
          : await app.withdrawChatCollectionClaim(widget.scheduleId, id);
      if (!mounted) return;
      _applyCollection(messageId, result['collection']);
      _snack(
        claimed ? 'ส่งสลิปแล้ว รอทีมงานเช็กยอดเข้า' : 'ถอนการแจ้งแล้ว',
      );
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _openCollectionList(int messageId, Map<String, dynamic> c) async {
    final id = int.tryParse('${c['id']}') ?? 0;
    if (id == 0) return;
    final app = context.read<AppProvider>();
    _collectionSheetMessageId = messageId;
    _collectionSheet.value = c;

    Future<void> run(Future<Map<String, dynamic>> Function() call) async {
      try {
        final result = await call();
        if (mounted) _applyCollection(messageId, result['collection']);
      } catch (e) {
        _snack(e.toString());
      }
    }

    await _showSheet<void>(
      CollectionListSheet(
        collection: _collectionSheet,
        canManage: _canModerate,
        onSetPaid: (ids, paid, method, reason) => run(
          () => app.setChatCollectionPaid(
            widget.scheduleId,
            id,
            passengerIds: ids,
            paid: paid,
            method: method,
            reason: reason,
          ),
        ),
        onLoadSlip: (passengerId) =>
            app.loadChatCollectionSlipUrl(widget.scheduleId, id, passengerId),
        onSetClosed: (close) => run(
          () => app.setChatCollectionClosed(widget.scheduleId, id, closed: close),
        ),
        onEditPayers: () async {
          List<Map<String, dynamic>> roster;
          try {
            roster = await app.loadChatRoster(widget.scheduleId);
          } catch (e) {
            _snack(e.toString());
            return;
          }
          if (!mounted) return;
          final current = _collectionSheet.value ?? c;
          final picked = await _showSheet<List<int>>(
            CollectionPayersSheet(
              roster: roster,
              selected: {
                for (final d in (current['dues'] as List? ?? const []))
                  if (d is Map) int.tryParse('${d['passenger_id']}') ?? 0,
              },
            ),
          );
          if (picked == null) return;
          await run(
            () => app.setChatCollectionPayers(widget.scheduleId, id, picked),
          );
        },
      ),
    );

    _collectionSheetMessageId = null;
  }

  void _onCollectionSignal(Map<String, dynamic> data) {
    final messageId = int.tryParse('${data['message_id']}');
    if (messageId == null || data['collection'] is! Map) return;
    _applyCollection(messageId, data['collection']);
  }

  void _applyCollection(int messageId, dynamic c) {
    if (c is! Map || !mounted) return;
    _refreshTodos();
    final next = Map<String, dynamic>.from(c);
    if (_collectionSheetMessageId == messageId) _collectionSheet.value = next;

    final idx = _messages.indexWhere(
      (m) => int.tryParse('${m['id']}') == messageId,
    );
    if (idx < 0) return;
    setState(() => _messages[idx] = {..._messages[idx], 'collection': next});
  }

  Future<void> _openMeetup() async {
    final draft = await _showSheet<MeetupDraft>(const OpenMeetupSheet());
    if (draft == null || !mounted) return;
    try {
      final message = await context.read<AppProvider>().openChatRestStop(
            widget.scheduleId,
            meetAt: draft.meetAt,
            place: draft.place,
          );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  // ── ถามทีมงานแบบส่วนตัว ────────────────────────────────────────────────

  /// สรุปจากเซิร์ฟเวอร์ (null = ผู้ใช้นี้ไม่มีสิทธิ์ใช้) — ลูกทริป: unread + staff,
  /// ทีมงาน: unread_threads
  Map<String, dynamic>? get _privateChat => _room?['private_chat'] is Map
      ? Map<String, dynamic>.from(_room!['private_chat'] as Map)
      : null;

  /// ป้ายบนปุ่ม — ลูกทริปนับข้อความจากทีมงาน ทีมงานนับคนที่รอคำตอบ
  int get _privateBadge {
    final p = _privateChat;
    if (p == null) return 0;
    return int.tryParse('${p[_canModerate ? 'unread_threads' : 'unread']}') ??
        0;
  }

  Future<void> _openPrivateChat() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _canModerate
            ? ChatPrivateInboxScreen(
                scheduleId: widget.scheduleId,
                tripTitle: widget.title,
              )
            : ChatPrivateScreen(
                scheduleId: widget.scheduleId,
                tripTitle: widget.title,
              ),
      ),
    );
    // กลับมาแล้วป้ายต้องตรงกับที่เพิ่งอ่านไป
    if (mounted) _refreshRoom(force: true);
  }

  /// ทีมงานเปิดการ์ด "ถึงบ้านแล้ว" — ยืนยันก่อน เพราะเด้งแจ้งเตือนถึงทุกคนในทริป
  Future<void> _openHomeCheck() async {
    final ok = await showConfirmDialog(
      context,
      title: 'เปิดเช็คถึงบ้าน?',
      message:
          'ทุกคนจะได้แจ้งเตือนให้กด "ถึงบ้านแล้ว" เมื่อถึงบ้าน ครบทุกคนการ์ดปิดเอง '
          'ใครยังไม่กดใน 2 ชั่วโมงระบบเตือนเขาอีกครั้ง (ไม่เด้งกลางดึก) และบอกคุณว่าเหลือใคร',
      icon: Icons.home_outlined,
      confirmLabel: 'เปิดเลย',
    );
    if (!ok || !mounted) return;
    try {
      final message = await context.read<AppProvider>().openChatRestStop(
            widget.scheduleId,
            kind: 'home',
          );
      if (!mounted) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
      _markRead();
      // เปิดไปแล้วซ่อนเมนูนี้ (มีได้ใบเดียว) — ดึงข้อมูลห้องใหม่ทันที
      _refreshRoom(force: true);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _boardRestStop(
    int messageId,
    Map<String, dynamic> stop,
    List<int> passengerIds,
    bool boarded,
  ) async {
    final stopId = int.tryParse('${stop['id']}') ?? 0;
    if (stopId == 0 || passengerIds.isEmpty) return;
    try {
      final result = await context.read<AppProvider>().boardChatRestStop(
            widget.scheduleId,
            stopId,
            passengerIds: passengerIds,
            boarded: boarded,
          );
      if (!mounted) return;
      _applyRestStop(messageId, result['rest_stop']);
      if (boarded) HapticFeedback.mediumImpact();
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// รายชื่อเช็คชื่อ — ทีมงานติ๊กแทน/ขยายเวลา/ออกรถ ลูกทริปดูได้
  Future<void> _openRestRoll(int messageId, Map<String, dynamic> stop) async {
    final stopId = int.tryParse('${stop['id']}') ?? 0;
    if (stopId == 0) return;
    final app = context.read<AppProvider>();

    _restSheetMessageId = messageId;
    _restSheetStop.value = stop;
    // ทีมงานต้องได้เบอร์โทร (ไม่มากับการ์ดที่กระจายทั้งห้อง) และค่าล่าสุดถ้า socket หลุด
    app.getChatRestStop(widget.scheduleId, stopId).then((r) {
      if (mounted) _applyRestStop(messageId, r['rest_stop']);
    }).catchError((_) {});

    Future<void> run(Future<Map<String, dynamic>> Function() call) async {
      try {
        final result = await call();
        if (mounted) _applyRestStop(messageId, result['rest_stop']);
      } catch (e) {
        _snack(e.toString());
      }
    }

    await _showSheet<void>(
      RestStopRollSheet(
        stop: _restSheetStop,
        canManage: _canModerate,
        onToggle: (id, boarded) => run(
          () => app.boardChatRestStop(
            widget.scheduleId,
            stopId,
            passengerIds: [id],
            boarded: boarded,
          ),
        ),
        onExtend: (m) =>
            run(() => app.extendChatRestStop(widget.scheduleId, stopId, m)),
        onDepart: () =>
            run(() => app.departChatRestStop(widget.scheduleId, stopId)),
      ),
    );

    _restSheetMessageId = null;
  }

  void _onRestStopSignal(Map<String, dynamic> data) {
    final messageId = int.tryParse('${data['message_id']}');
    if (messageId == null || data['rest_stop'] is! Map) return;
    _applyRestStop(messageId, data['rest_stop']);
  }

  void _applyRestStop(int messageId, dynamic stop) {
    if (stop is! Map || !mounted) return;
    _refreshTodos();
    final next = Map<String, dynamic>.from(stop);
    if (_restSheetMessageId == messageId) _restSheetStop.value = next;
    // ปลุกรวม: ตื่นครบ/เลื่อนเวลา/ปิดการ์ด = ย้ายหรือยกเลิกปลุกในเครื่อง
    if (next['kind'] == 'wakeup') {
      unawaited(WakeAlarmService.instance.sync(next, _myUserId));
    }

    final idx = _messages.indexWhere(
      (m) => int.tryParse('${m['id']}') == messageId,
    );
    if (idx < 0) return;
    setState(() => _messages[idx] = {..._messages[idx], 'rest_stop': next});
  }

  /// ปุ่ม "ทักทาย" บนการ์ดแนะนำทีมงาน — เติมคำทักลงช่องพิมพ์ให้แก้ต่อแล้วส่งเอง
  /// (ไม่ส่งแทน) ถ้าพิมพ์อะไรค้างไว้อยู่แล้วจะไม่ทับของเดิม
  void _greet(String greeting) {
    if (_input.text.trim().isEmpty) {
      _input.value = TextEditingValue(
        text: greeting,
        selection: TextSelection.collapsed(offset: greeting.length),
      );
    }
    _inputFocus.requestFocus();
  }

  void _startReply(Map<String, dynamic> message) {
    setState(() => _replyingTo = message);
    FocusScope.of(context).requestFocus(FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  /// Realtime: an existing message was edited or deleted — replace it in place.
  void _onMessageUpdated(Map<String, dynamic> data) {
    final id = data['id'];
    if (id == null || !mounted) return;
    final idx = _messages.indexWhere((m) => m['id'] == id);
    if (idx < 0) return;
    setState(() => _messages[idx] = {..._messages[idx], ...data});
  }

  void _startEdit(Map<String, dynamic> message) {
    // เก็บร่างที่พิมพ์ค้างไว้ก่อนช่องพิมพ์ถูกแทนด้วยข้อความที่จะแก้
    if (_draftSave?.isActive ?? false) {
      _draftSave!.cancel();
      unawaited(_saveDraftNow());
    }
    setState(() {
      _editing = message;
      _replyingTo = null;
      _mentionPicks.clear();
      _input.text = message['body']?.toString() ?? '';
      _input.selection = TextSelection.fromPosition(
        TextPosition(offset: _input.text.length),
      );
    });
    FocusScope.of(context).requestFocus(_inputFocus);
  }

  void _cancelEdit() {
    setState(() {
      // ล้างช่องก่อนออกจากโหมดแก้ไข — ไม่งั้นการล้างถูกนับเป็น "ร่างว่าง" แล้วร่างเดิมหาย
      _input.clear();
      _editing = null;
      _mentionPicks.clear();
      _mentionQuery = null;
    });
    unawaited(_restoreDraft());
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final id = int.tryParse('${message['id']}');
    if (id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'ลบข้อความนี้?',
      message: 'การลบไม่สามารถย้อนกลับได้',
      tone: ConfirmTone.danger,
      confirmLabel: 'ลบ',
    );
    if (!confirmed || !mounted) return;
    try {
      final updated = await context
          .read<AppProvider>()
          .deleteChatMessage(widget.scheduleId, id);
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m['id'] == id);
      if (idx >= 0) setState(() => _messages[idx] = {..._messages[idx], ...updated});
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  // ── แนะนำตัว / วันเกิด / แลกคอนแทค ──────────────────────────────────────

  void _onSystemCta(String cta) {
    switch (cta) {
      case 'intro':
        _openIntro();
      case 'contacts':
        _openContacts();
    }
  }

  Map<String, dynamic> get _contactsInfo => _room?['contacts'] is Map
      ? Map<String, dynamic>.from(_room!['contacts'] as Map)
      : const {};

  /// ดึงข้อความหนึ่งใบใหม่จากเซิร์ฟเวอร์ (ของที่ฉันเพิ่งโพสต์/แก้ผ่าน endpoint อื่น)
  Future<void> _reloadMessage(int messageId) async {
    try {
      final data = await context.read<AppProvider>().chatMessages(
        widget.scheduleId,
        afterId: messageId - 1,
      );
      final fresh = (data['messages'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => int.tryParse('${m['id']}') == messageId)
          .toList();
      if (!mounted || fresh.isEmpty) return;
      final idx = _messages.indexWhere((m) => int.tryParse('${m['id']}') == messageId);
      if (idx >= 0) {
        setState(() => _messages[idx] = fresh.first);
      } else {
        _ingest(fresh);
        _scrollToBottom();
      }
    } catch (_) {
      // รอบโพลถัดไปเก็บให้เอง
    }
  }

  Future<void> _openIntro() async {
    final app = context.read<AppProvider>();
    Map<String, dynamic>? current;
    try {
      final mine = await app.chatMyIntro(widget.scheduleId);
      if (mine['intro'] is Map) current = Map<String, dynamic>.from(mine['intro'] as Map);
    } catch (_) {
      // โหลดของเดิมไม่ได้ก็เริ่มฟอร์มว่าง
    }
    if (!mounted) return;
    final draft = await _showSheet<IntroDraft>(ChatIntroSheet(initial: current));
    if (draft == null || !mounted) return;
    try {
      final res = await app.saveChatIntro(
        widget.scheduleId,
        hometown: draft.hometown,
        experience: draft.experience,
        note: draft.note,
      );
      final id = int.tryParse('${res['message_id']}');
      if (id != null) await _reloadMessage(id);
      _snack(current == null ? 'แนะนำตัวแล้ว 👋' : 'แก้การ์ดแนะนำตัวแล้ว');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _openContacts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripContactsScreen(scheduleId: widget.scheduleId)),
    );
    if (mounted) _refreshRoom(force: true);
  }

  Future<void> _openBirthdays() async {
    final app = context.read<AppProvider>();
    await _showSheet<void>(
      BirthdaySheet(
        load: () => app.chatBirthdays(widget.scheduleId),
        onGreet: (pid) async {
          final items = await app.greetChatBirthday(widget.scheduleId, pid);
          unawaited(_poll());
          return items;
        },
      ),
    );
    if (mounted) _refreshRoom(force: true);
  }

  // ── "รอคุณอยู่" ─────────────────────────────────────────────────────────

  @override
  void _refreshTodos({bool immediate = false}) {
    _todoDebounce?.cancel();
    if (immediate) {
      _fetchTodos();
      return;
    }
    _todoDebounce = Timer(const Duration(milliseconds: 1200), _fetchTodos);
  }

  Future<void> _fetchTodos() async {
    if (!mounted) return;
    if (_todoFetching) {
      // มีการเปลี่ยนระหว่างดึง — ดึงซ้ำอีกรอบหลังเสร็จ จะได้ไม่ค้างค่าเก่า
      _todoAgain = true;
      return;
    }
    _todoFetching = true;
    try {
      final raw = await context.read<AppProvider>().chatTodos(widget.scheduleId);
      if (!mounted) return;
      setState(() => _todos = ChatTodo.parseList(raw));
    } catch (_) {
      // แถบนี้เป็นทางลัด — ดึงไม่ได้ก็ใช้ค่าเดิมไป รอบหน้าลองใหม่
    } finally {
      _todoFetching = false;
      if (_todoAgain && mounted) {
        _todoAgain = false;
        _refreshTodos();
      }
    }
  }

  Future<void> _openSearch() async {
    HapticFeedback.selectionClick();
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => _ChatSearchScreen(scheduleId: widget.scheduleId)),
    );
    if (id != null && mounted) _jumpToMessage(id);
  }

  Future<void> _openTodos() async {
    final picked = await showModalBottomSheet<ChatTodo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => ChatTodoSheet(todos: _todos),
    );
    if (picked != null && mounted) _jumpToMessage(picked.messageId);
  }

  /// ไปที่ข้อความ — ถ้ายังไม่ได้โหลด (เก่ากว่าที่เลื่อนถึง) โหลดย้อนไปถึงมันก่อน
  /// แบบต่อเนื่องไม่มีรู แล้วค่อยเลื่อนไปไฮไลต์
  Future<void> _jumpToMessage(int messageId) async {
    bool loaded() =>
        _messages.any((m) => int.tryParse('${m['id']}') == messageId);

    if (loaded()) {
      _scrollToMessage(messageId);
      return;
    }
    if (_jumping || _messages.isEmpty) return;

    final oldest = _messages
        .map((m) => int.tryParse('${m['id']}') ?? 0)
        .where((id) => id > 0)
        .fold<int>(0, (min, id) => min == 0 || id < min ? id : min);
    if (oldest == 0 || messageId >= oldest) {
      _toast('ข้อความนี้ถูกลบไปแล้ว');
      return;
    }

    setState(() => _jumping = true);
    final app = context.read<AppProvider>();
    try {
      final data = await app.chatMessages(
        widget.scheduleId,
        beforeId: oldest,
        sinceId: messageId,
      );
      final older = (data['messages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => !_messages.any((e) => e['id'] == m['id']))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, older);
        _hasMore = data['has_more'] == true;
      });
      _hydrateTools(older);
      // ข้อความถูกซ่อน/ลบ หรือช่วงยาวเกินเพดาน — บอกตรง ๆ ดีกว่าเลื่อนไปผิดที่
      if (!loaded()) {
        _toast('หาข้อความนี้ไม่เจอแล้ว อาจถูกลบไป');
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToMessage(messageId);
      });
    } catch (_) {
      if (mounted) _toast('โหลดข้อความไม่สำเร็จ ลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _jumping = false);
    }
  }

  // ── "รับทราบ" ใต้ประกาศ ───────────────────────────────────────────────

  void _applyAck(int messageId, dynamic ack) {
    final idx = _messages.indexWhere((m) => int.tryParse('${m['id']}') == messageId);
    if (idx < 0 || !mounted) return;
    setState(() {
      _messages[idx] = {
        ..._messages[idx],
        'ack': mergeAck(_messages[idx]['ack'], ack),
      };
    });
  }

  void _onAckSignal(Map<String, dynamic> data) {
    final id = int.tryParse('${data['message_id']}');
    if (id == null) return;
    _applyAck(id, data['ack']);
    _refreshTodos();
  }

  Future<void> _ackMessage(int messageId) async {
    if (!_ackBusy.add(messageId)) return;
    setState(() {});
    try {
      final res = await context.read<AppProvider>().ackChatMessage(
        widget.scheduleId,
        messageId,
      );
      _applyAck(messageId, res['ack']);
      _refreshTodos();
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      _ackBusy.remove(messageId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _requestAckFor(Map<String, dynamic> message) async {
    final id = int.tryParse('${message['id']}');
    if (id == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'ขอให้ทุกคนกดรับทราบ?',
      message: 'ลูกทริปจะได้แจ้งเตือนและเห็นปุ่ม "รับทราบ" ใต้ข้อความนี้ '
          'คุณดูได้ว่าใครยังไม่กด แล้วสะกิดเฉพาะคนนั้น',
      confirmLabel: 'ขอให้กดรับทราบ',
      icon: Icons.task_alt_rounded,
    );
    if (!ok || !mounted) return;
    try {
      final res = await context.read<AppProvider>().requestChatAck(
        widget.scheduleId,
        id,
      );
      _applyAck(id, res['ack']);
      _toast('ขอให้ทุกคนกดรับทราบแล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  Future<void> _openAckDetail(int messageId) async {
    final app = context.read<AppProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => ChatAckDetailSheet(
        load: () async {
          final res = await app.chatAckDetail(widget.scheduleId, messageId);
          _applyAck(messageId, res['ack']);
          return res;
        },
        onNudge: () async {
          final res = await app.nudgeChatAck(widget.scheduleId, messageId);
          _applyAck(messageId, res['ack']);
          return res;
        },
        onCancel: () async {
          await app.cancelChatAckRequest(widget.scheduleId, messageId);
          _applyAck(messageId, null);
        },
      ),
    );
  }

  Future<void> _pinMessage(Map<String, dynamic> message) async {
    final id = int.tryParse('${message['id']}');
    if (id == null) return;
    try {
      final res = await context
          .read<AppProvider>()
          .pinChatMessage(widget.scheduleId, id);
      if (!mounted) return;
      setState(() {
        _setPins(res['pinned_messages'], res['pinned_message']);
        _pinIndex = 0;
      });
      _toast('ปักหมุดข้อความแล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  Future<void> _unpinMessage(int id) async {
    try {
      final res = await context.read<AppProvider>().unpinChatMessage(widget.scheduleId, id);
      if (!mounted) return;
      setState(() => _setPins(res['pinned_messages'], res['pinned_message']));
      _toast('ปลดหมุดข้อความแล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  void _toast(String text) {
    AppSnack.show(context, text);
  }

  GlobalKey _keyFor(int messageId) =>
      _messageKeys.putIfAbsent(messageId, () => GlobalKey());

  /// Scrolls to a message already loaded in the list (e.g. tapping a reply
  /// quote or the mention chip). Anchors precisely with [Scrollable.ensureVisible]
  /// when the target widget is built; otherwise approximates the jump first and
  /// anchors on the next frame once the target lays out.
  @override
  void _scrollToMessage(int messageId) {
    final idx =
        _messages.indexWhere((m) => int.tryParse('${m['id']}') == messageId);
    if (idx == -1 || !_scroll.hasClients) return;

    final ctx = _messageKeys[messageId]?.currentContext;
    if (ctx != null) {
      _anchorOn(ctx);
      _flashMessage(messageId);
      return;
    }

    // Off-screen and not yet built — jump proportionally to bring it into range,
    // then anchor precisely once it's laid out.
    final ratio = _messages.isEmpty ? 1.0 : idx / _messages.length;
    final target = (_scroll.position.maxScrollExtent * ratio)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final built = _messageKeys[messageId]?.currentContext;
      if (built != null) {
        _anchorOn(built);
        _flashMessage(messageId);
      }
    });
  }

  void _anchorOn(BuildContext ctx) {
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: 0.3,
    );
  }

  /// Briefly outlines a message after jumping to it so the eye can find it.
  void _flashMessage(int messageId) {
    _highlightTimer?.cancel();
    setState(() => _highlightId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightId = 0);
    });
  }

  void _openMessageMenu(Map<String, dynamic> message) {
    final role = message['sender_role']?.toString() ?? 'customer';
    // ข้อความระบบ: ทีมงานกดค้างได้เพื่อขอให้กดรับทราบ/ปักหมุด — ลูกทริปไม่มีเมนู
    final isSystem = role == 'system';
    if ((isSystem && !_canModerate) || message['is_deleted'] == true) return;
    // Optimistic messages (still sending / failed) aren't actionable yet.
    if (message['_pending'] == true || message['_failed'] == true) return;
    HapticFeedback.mediumImpact();
    final body = message['body']?.toString() ?? '';
    final messageId = int.tryParse('${message['id']}') ?? 0;
    final isMine = message['is_mine'] == true;
    final hasImage = (message['image_url']?.toString() ?? '').isNotEmpty;
    // body ของสติกเกอร์เป็นแค่ข้อความสำรอง — คัดลอก/แก้ไขไม่มีความหมาย
    final isSticker = message['sticker'] is Map;
    final canEdit = !isSystem && isMine && body.isNotEmpty && !hasImage && !isSticker;
    final canDelete = !isSystem && (isMine || _canModerate);
    final hasAck = message['ack'] is Map;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Quick emoji reaction row
            if (!isSystem)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final emoji in _reactionEmojis)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _toggleReaction(messageId, emoji);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(emoji, style: const TextStyle(fontSize: AppText.sizeHero)),
                      ),
                    ),
                ],
              ),
            ),
            if (!isSystem)
              Divider(color: AppTheme.border(context).withValues(alpha: 0.5)),
            if (!isSystem)
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text('ตอบกลับ',
                  style: appFont(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _startReply(message);
              },
            ),
            if (body.isNotEmpty && !isSticker)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text('คัดลอก',
                    style: appFont(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _copyMessage(body);
                },
              ),
            if (_canModerate && hasAck)
              ListTile(
                leading: const Icon(Icons.task_alt_rounded),
                title: Text('ดูว่าใครยังไม่กดรับทราบ',
                    style: appFont(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAckDetail(messageId);
                },
              )
            else if (_canModerate && messageId > 0)
              ListTile(
                leading: const Icon(Icons.task_alt_rounded),
                title: Text('ขอให้ทุกคนกดรับทราบ',
                    style: appFont(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'ลูกทริปได้แจ้งเตือน คุณเห็นว่าใครยังไม่กด',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _requestAckFor(message);
                },
              ),
            if (_canModerate) ...[
              if (_isPinned(messageId))
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined),
                  title: Text('ปลดหมุด',
                      style: appFont(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _unpinMessage(messageId);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.push_pin_rounded),
                  title: Text('ปักหมุด',
                      style: appFont(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pinMessage(message);
                  },
                ),
            ],
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text('แก้ไข',
                    style: appFont(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startEdit(message);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.errorColor),
                title: Text('ลบ',
                    style: appFont(
                        fontWeight: FontWeight.w600, color: AppTheme.errorColor)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteMessage(message);
                },
              ),
            // รายงาน/บล็อก มีเฉพาะข้อความของคนอื่น — รายงานตัวเองไม่มีความหมาย
            if (!isMine && !isSystem)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('รายงาน หรือบล็อกผู้ส่ง',
                    style: appFont(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openModerationSheet(message);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// รายงานข้อความ หรือบล็อกคนส่ง — เมื่อบล็อกสำเร็จให้ข้อความของเขาหายจาก
  /// ห้องทันที ไม่ต้องรอโหลดรอบใหม่
  void _openModerationSheet(Map<String, dynamic> message) {
    final messageId = int.tryParse('${message['id']}') ?? 0;
    final author = message['user'] is Map
        ? Map<String, dynamic>.from(message['user'] as Map)
        : <String, dynamic>{};
    final authorId = int.tryParse('${author['id']}');
    final authorName =
        (author['nickname']?.toString().trim().isNotEmpty ?? false)
            ? author['nickname'].toString()
            : author['name']?.toString() ?? '';

    ModerationSheet.open(
      context,
      type: ModerationSheet.typeChatMessage,
      id: messageId,
      authorId: authorId,
      authorName: authorName,
      contentLabel: 'ข้อความนี้',
      onHidden: () {
        if (!mounted || authorId == null) return;
        setState(() {
          _messages.removeWhere((m) {
            final u = m['user'];
            return u is Map && int.tryParse('${u['id']}') == authorId;
          });
        });
      },
    );
  }

  // ── Room metadata accessors ───────────────────────────────────────────────

  List<Map<String, dynamic>> get _members => (_room?['members'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  int get _memberCount {
    final raw = _room?['member_count'];
    final n = int.tryParse('$raw');
    if (n != null) return n;
    return _members.length;
  }

  Map<String, dynamic>? get _vehicle =>
      _room?['vehicle'] is Map
          ? Map<String, dynamic>.from(_room!['vehicle'] as Map)
          : null;

  // Trip-info shortcuts surfaced in the room-info sheet (weather / pickup /
  // itinerary), sourced from the room payload — see ChatController@room.
  Map<String, dynamic>? get _weather => _room?['weather'] is Map
      ? Map<String, dynamic>.from(_room!['weather'] as Map)
      : null;

  List<Map<String, dynamic>> get _pickupPoints =>
      (_room?['pickup_points'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  bool get _hasItinerary => _room?['has_itinerary'] == true;

  /// คนที่ผู้ร่วมทริปโทรหาได้ — สตาฟ/ทีมงานประจำรอบ แล้วต่อด้วยคนขับ
  ///
  /// เอาเฉพาะคนที่มีเบอร์จริง เพราะแถบนี้มีไว้ให้ "กดโทร" การโชว์คนที่โทรไม่ได้
  /// ทำให้แถบยาวขึ้นโดยไม่ได้อะไร (ดูว่าใครอยู่ในห้องดูได้จากชีตสมาชิกอยู่แล้ว)
  List<_ChatContact> get _contacts {
    final list = <_ChatContact>[];

    for (final m in _members) {
      if (m['is_me'] == true) continue;
      final role = m['role']?.toString() ?? 'customer';
      if (role != 'staff' && role != 'admin') continue;
      final phone = m['phone']?.toString().trim() ?? '';
      if (phone.isEmpty) continue;

      final nickname = m['nickname']?.toString().trim() ?? '';
      list.add(
        _ChatContact(
          name: nickname.isNotEmpty ? nickname : (m['name']?.toString() ?? 'สตาฟ'),
          roleLabel: role == 'admin' ? 'ทีมงาน' : 'สตาฟประจำรอบ',
          phone: phone,
          avatarUrl: ApiConfig.mediaUrl(m['avatar_url']),
          kind: _ContactKind.staff,
        ),
      );
    }

    final driverPhone = _vehicle?['driver_phone']?.toString().trim() ?? '';
    final driverName = _vehicle?['driver_name']?.toString().trim() ?? '';
    if (driverPhone.isNotEmpty) {
      list.add(
        _ChatContact(
          name: driverName.isEmpty ? 'คนขับ' : driverName,
          roleLabel: _vehicleName.isEmpty ? 'คนขับ' : 'คนขับ · $_vehicleName',
          phone: driverPhone,
          avatarUrl: ApiConfig.mediaUrl(_vehicle?['driver_photo']),
          kind: _ContactKind.driver,
        ),
      );
    }

    return list;
  }

  String get _tripTitle {
    final fromWidget = widget.title?.trim() ?? '';
    if (fromWidget.isNotEmpty) return fromWidget;
    final sched = _room?['schedule'];
    if (sched is Map) return sched['trip_title']?.toString() ?? '';
    return '';
  }

  String get _vehicleName => _vehicle?['name']?.toString().trim() ?? '';

  String _subtitle() {
    if (_room == null) return 'ลูกค้า · สตาฟ · ทีมงาน';
    final parts = <String>['สมาชิก $_memberCount คน'];
    if (_vehicleName.isNotEmpty) parts.add(_vehicleName);
    return parts.join(' · ');
  }

  /// How many *other* members have read up to [messageId] — the denominator for
  /// LINE-style "อ่านแล้ว N" receipts on the current user's own messages.
  int _readCountFor(int messageId) {
    if (messageId <= 0) return 0;
    var count = 0;
    for (final m in _members) {
      if (m['is_me'] == true) continue;
      final lastRead = int.tryParse('${m['last_read_message_id']}') ?? 0;
      if (lastRead >= messageId) count++;
    }
    return count;
  }

  void _showRoomInfo() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => _RoomInfoSheet(
        vehicle: _vehicle,
        members: _members,
        memberCount: _memberCount,
        scheduleId: widget.scheduleId,
        tripTitle: _tripTitle,
        weather: _weather,
        pickupPoints: _pickupPoints,
        hasItinerary: _hasItinerary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ปุ่มย้อนกลับขณะแผงสติกเกอร์เปิด = ปิดแผง (แบบคีย์บอร์ด) ไม่ใช่ออกจากห้อง
    return PopScope(
      canPop: !_stickerPanelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stickerPanelOpen) {
          setState(() => _stickerPanelOpen = false);
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.chatCanvas(context),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: InkWell(
          onTap: _room == null ? null : _showRoomInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title ?? 'แชทกลุ่มทริป',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppTheme.appBarTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _subtitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_privateChat != null)
            IconButton(
              tooltip: _canModerate
                  ? 'ข้อความส่วนตัวจากลูกทริป'
                  : 'ถามทีมงานแบบส่วนตัว',
              onPressed: _openPrivateChat,
              icon: Badge(
                isLabelVisible: _privateBadge > 0,
                label: Text('$_privateBadge'),
                backgroundColor: AppTheme.errorColor,
                child: const Icon(Icons.lock_person_rounded),
              ),
            ),
          IconButton(
            tooltip: 'ค้นหาในห้อง',
            onPressed: _loading ? null : _openSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'การแจ้งเตือน: ${_notifyLevel.label}',
            onPressed: _room == null || _savingNotify ? null : _openNotifySettings,
            icon: Icon(_notifyLevel.icon),
          ),
          IconButton(
            tooltip: 'สมาชิกในห้อง',
            onPressed: _room == null ? null : _showRoomInfo,
            icon: Badge(
              isLabelVisible: _memberCount > 0,
              label: Text('$_memberCount'),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.groups_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // แถบติดต่อปักไว้ใต้ AppBar (แบบ Line Man) — สตาฟ/คนขับพร้อมปุ่มโทร
          // อยู่เหนือข้อความที่ปักหมุด เพราะ "โทรหาใครสักคน" เร่งด่วนกว่าเสมอ
          if (_contacts.isNotEmpty) _ContactBar(contacts: _contacts),
          // คำขอถึงทีมงาน — เห็นเฉพาะทีมงาน: เรื่องไม่บอกชื่อเป็นตัวเลข + คิวขอยา/ของ
          if (_canModerate)
            StaffRequestBanner(
              kinds: _stopKinds,
              counts: _stopCounts,
              urgentToilet: int.tryParse('${_stopRequests['urgent']}') ?? 0,
              supplyPending: _supplyPending,
              onKind: _acknowledgeStops,
              onSupplies: _openSupplyQueue,
            ),
          if (_canModerate &&
              (int.tryParse('${_room?['birthdays_pending']}') ?? 0) > 0)
            BirthdayStaffBanner(
              count: int.tryParse('${_room?['birthdays_pending']}') ?? 0,
              onOpen: _openBirthdays,
            ),
          if (_pins.isNotEmpty)
            _PinnedBanner(
              pinned: _pins[_pinIndex.clamp(0, _pins.length - 1)],
              index: _pinIndex.clamp(0, _pins.length - 1),
              count: _pins.length,
              canModerate: _canModerate,
              onTap: () {
                final shown = _pins[_pinIndex.clamp(0, _pins.length - 1)];
                final id = int.tryParse('${shown['id']}');
                // แตะครั้งต่อไปพาไปหมุดถัดไป (แบบ Telegram) — วนกลับอันแรก
                setState(() => _pinIndex = (_pinIndex + 1) % _pins.length);
                if (id != null) _jumpToMessage(id);
              },
              onUnpin: _canModerate
                  ? () {
                      final id = int.tryParse(
                        '${_pins[_pinIndex.clamp(0, _pins.length - 1)]['id']}',
                      );
                      if (id != null) _unpinMessage(id);
                    }
                  : null,
            ),
          if (!_loading && _showQuietSuggest)
            _QuietSuggestBanner(
              onAccept: _acceptQuietSuggest,
              onDismiss: _dismissQuietSuggest,
            ),
          if (!_loading && _todos.isNotEmpty)
            ChatTodoBar(
              todos: _todos,
              onOpen: (t) => _jumpToMessage(t.messageId),
              onOpenAll: _openTodos,
            ),
          Expanded(
            child: Stack(
              children: [
                _buildBody(),
                if (!_loading && _unreadMentions.isNotEmpty)
                  Positioned(
                    left: 14,
                    top: 12,
                    child: _MentionJumpChip(
                      count: _unreadMentions.length,
                      onTap: _jumpToNextMention,
                    ),
                  ),
                if (_showJumpButton)
                  Positioned(
                    right: 14,
                    bottom: 12,
                    child: _JumpToLatestButton(
                      newCount: _newWhileAway,
                      onTap: _jumpToLatest,
                    ),
                  ),
                if (_joinedLabel() != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 12,
                    child: Center(
                      child: _JoinedBanner(
                        label: _joinedLabel()!,
                        isStaff: _joinedHasStaff(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_typingLabel() != null) _TypingIndicator(label: _typingLabel()!),
          // แถบคำตอบอัตโนมัติ — ขึ้นแทนแถบชิปเมื่อข้อความที่พิมพ์/เพิ่งส่งเข้าข้อ
          // ที่แอปตอบได้ ใช้สลอตเดียวกันเพื่อไม่ให้ห้องแชทเสียพื้นที่เพิ่ม
          if (!_loading && _error == null && _suggested != null)
            _QuickAskSuggestion(
              ask: _suggested!,
              answer: QuickAskAnswer.line(_suggested!.topic, _tripInfo),
              onOpen: () => _openSuggestion(_suggested!),
              onDismiss: _dismissSuggestion,
            ),
          // ปุ่มคำถามด่วน — คำถามที่ถูกถามซ้ำที่สุดในห้อง กดแล้วได้คำตอบทันที
          // (ตอบเฉพาะคนกด ไม่โพสต์ลงห้อง) ซ่อนตอนกำลังพิมพ์เพื่อไม่กินพื้นที่
          if (!_loading && _error == null && !_isComposing && _suggested == null)
            _QuickAskBar(
              canModerate: _canModerate,
              hasItinerary: _hasItinerary,
              tripLive: _room?['trip_live'] == true,
              onAsk: _openTripInfo,
              onSendSummary: _sendTripSummary,
              onSendItinerary: _sendTripItinerary,
            ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppTheme.mutedText(context), size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: Text(
                  'ลองอีกครั้ง',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'ยังไม่มีข้อความ',
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'เริ่มทักทายเพื่อนร่วมทริปได้เลย',
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = _buildItems();

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      itemCount: items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loadingMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return items[index - (_loadingMore ? 1 : 0)];
      },
    );
  }

  /// Builds the flat widget list for the message ListView, weaving in date
  /// separators and computing grouping flags so consecutive messages from the
  /// same sender within [_groupGap] collapse into one visual unit.
  List<Widget> _buildItems() {
    final items = <Widget>[];
    final travellers = _travellers;
    DateTime? lastDay;
    var unreadDividerShown = false;

    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final at = _parseTime(m['created_at']);
      final day = at == null ? null : DateTime(at.year, at.month, at.day);

      if (day != null && (lastDay == null || day != lastDay)) {
        items.add(_DateSeparator(day: day));
        lastDay = day;
      }

      // "ข้อความใหม่" divider before the first message that arrived after our
      // last read marker (and isn't our own send).
      final mId = int.tryParse('${m['id']}') ?? 0;
      if (!unreadDividerShown &&
          _unreadBoundaryLocked &&
          _unreadBoundaryId > 0 &&
          mId > _unreadBoundaryId &&
          m['is_mine'] != true) {
        items.add(const _UnreadDivider());
        unreadDividerShown = true;
      }

      final role = m['sender_role']?.toString() ?? 'customer';

      // System messages render as a centered pill, never as a chat bubble —
      // they're notices (e.g. "เจ้าหน้าที่เข้าร่วมแชท"), not conversation.
      if (role == 'system') {
        final system = _SystemMessage(
          message: m,
          myUserId: _myUserId,
          onGreet: _greet,
          canModerate: _canModerate,
          highlight: mId > 0 && mId == _highlightId,
          ackBusy: _ackBusy.contains(mId),
          onAck: () => _ackMessage(mId),
          onOpenAck: () => _openAckDetail(mId),
          onLongPress: _canModerate ? () => _openMessageMenu(m) : null,
          onCta: _onSystemCta,
        );
        // คีย์ไว้เหมือนบับเบิล — แถบ "รอคุณอยู่" กระโดดมาที่ประกาศระบบได้
        items.add(mId > 0 ? KeyedSubtree(key: _keyFor(mId), child: system) : system);
        continue;
      }

      final prev = _previousSameAuthor(i);
      final next = _nextSameAuthor(i);
      final isFirstInGroup = prev == null;
      final isLastInGroup = next == null;

      // LINE-style read receipt: only on the last bubble of my own group, to
      // avoid stamping every line. Counts other members who've read this far.
      final isMine = m['is_mine'] == true;
      final readByCount = (isMine && isLastInGroup)
          ? _readCountFor(mId)
          : 0;

      final pending = m['_pending'] == true;
      final failed = m['_failed'] == true;
      final token = m['client_token']?.toString();

      final bubble = _MessageBubble(
        message: m,
        showAuthor: isFirstInGroup,
        showAvatar: isLastInGroup,
        showTimestamp: isLastInGroup,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
        readByCount: readByCount,
        myUserId: _myUserId,
        mentionsMe: _mentionsMe(m),
        highlight: mId > 0 && mId == _highlightId,
        pending: pending,
        failed: failed,
        onRetry: (failed && token != null)
            ? () => _dispatchOptimistic(token)
            : null,
        onCopy: _copyMessage,
        onLongPress: () => _openMessageMenu(m),
        onSwipeReply: () => _startReply(m),
        onReplyTap: _scrollToMessage,
        onReactionTap: (emoji) => _toggleReaction(mId, emoji),
        canModerate: _canModerate,
        onVote: (pollId, optionIds) => _votePoll(mId, pollId, optionIds),
        onClosePoll: (pollId) => _closePoll(mId, pollId),
        travellers: travellers,
        onOrderFood: (round) => _orderFood(mId, round),
        onPayFood: (round) => _payFood(mId, round),
        onOpenFoodSummary: (round) => _openFoodSummary(mId, round),
        onBoardRestStop: (stop, ids, boarded) =>
            _boardRestStop(mId, stop, ids, boarded),
        onOpenRestRoll: (stop) => _openRestRoll(mId, stop),
        onPayCollection: (c) => _payCollection(mId, c),
        onOpenCollection: (c) => _openCollectionList(mId, c),
        onOpenLostItems: () => _openLostItems(),
        ackBusy: _ackBusy.contains(mId),
        onAck: () => _ackMessage(mId),
        onOpenAck: () => _openAckDetail(mId),
        onEditIntro: _openIntro,
        tools: _BubbleTools(
          onTrailReach: (t, ids, index) => _reachTrail(mId, t, ids, index),
          onTrailHelp: (t) => _askTrailHelp(mId, t),
          onTrailCancelHelp: (t) => _cancelTrailHelp(mId, t),
          onOpenTrail: (t) => _openTrailBoard(mId, t),
          onWellnessAnswer: (w, a) => _answerWellness(mId, w, [a]),
          onOpenWellnessAnswer: (w, status) =>
              _openWellnessAnswer(mId, w, status),
          onOpenWellnessStaff: (w) => _openWellnessStaff(mId, w),
          onChooseDropoff: (d) => _chooseDropoff(mId, d),
          onOpenDropoffStaff: (d) => _openDropoffStaff(mId, d),
          onRegisterPorter: (p) => _registerPorter(mId, p),
          onOpenPorter: (p) => _openPorterManage(mId, p),
        ),
      );

      // Keyed so jumps can anchor exactly on this bubble (see _scrollToMessage).
      items.add(mId > 0
          ? KeyedSubtree(key: _keyFor(mId), child: bubble)
          : bubble);
    }

    return items;
  }

  /// Returns the previous message if it's from the same sender and within
  /// the grouping window, else null.
  Map<String, dynamic>? _previousSameAuthor(int index) {
    if (index == 0) return null;
    final cur = _messages[index];
    final prev = _messages[index - 1];
    if (!_isSameSender(prev, cur)) return null;
    if (_minutesBetween(prev, cur) > _groupGap.inMinutes) return null;
    if (prev['sender_role']?.toString() == 'system') return null;
    return prev;
  }

  Map<String, dynamic>? _nextSameAuthor(int index) {
    if (index >= _messages.length - 1) return null;
    final cur = _messages[index];
    final next = _messages[index + 1];
    if (!_isSameSender(cur, next)) return null;
    if (_minutesBetween(cur, next) > _groupGap.inMinutes) return null;
    if (next['sender_role']?.toString() == 'system') return null;
    return next;
  }

  bool _isSameSender(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['is_mine'] == true && b['is_mine'] == true) return true;
    if (a['is_mine'] == true || b['is_mine'] == true) {
      return a['is_mine'] == b['is_mine'];
    }
    final userA = (a['user'] is Map ? (a['user'] as Map)['id'] : null)
        ?.toString();
    final userB = (b['user'] is Map ? (b['user'] as Map)['id'] : null)
        ?.toString();
    return userA != null && userA == userB;
  }

  int _minutesBetween(Map<String, dynamic> a, Map<String, dynamic> b) {
    final da = _parseTime(a['created_at']);
    final db = _parseTime(b['created_at']);
    if (da == null || db == null) return 9999;
    return db.difference(da).inMinutes.abs();
  }

  void _copyMessage(String body) {
    if (body.isEmpty) return;
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: body));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'คัดลอกข้อความแล้ว',
          style: appFont(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
      ),
    );
  }

  /// Member suggestion strip shown above the composer while typing "@…".
  Widget _buildMentionBar() {
    final suggestions = _mentionSuggestions;
    final showAll = _showAllMention;
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 58),
      decoration: BoxDecoration(
        // Use the elevated surface (not subtleSurface, which matches the chat
        // background in light mode and made this strip blend in / disappear).
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(color: AppTheme.border(context)),
        ),
      ),
      child: (suggestions.isEmpty && !showAll)
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: Row(
                children: [
                  Icon(Icons.alternate_email_rounded,
                      size: 16, color: AppTheme.mutedText(context)),
                  const SizedBox(width: 8),
                  Text(
                    'ไม่มีสมาชิกให้แท็ก',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        itemCount: suggestions.length + (showAll ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          // "@All" everyone-mention pinned to the front of the strip.
          if (showAll && i == 0) {
            return InkWell(
              onTap: _applyAllMention,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 5),
                    Text('@All',
                        style: appFont(
                            fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 4),
                    Text('ทุกคน',
                        style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            );
          }
          final m = suggestions[i - (showAll ? 1 : 0)];
          final label = _mentionLabel(m);
          return InkWell(
            onTap: () => _applyMention(m),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                // Emerald-tinted pill so each name stands out clearly against
                // the strip and reads as a tappable mention.
                color: AppTheme.primaryColor
                    .withValues(alpha: isDark ? 0.24 : 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('@',
                      style: appFont(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w800)),
                  Text(label,
                      style: appFont(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor)),
                  if (m['role'] == 'staff') ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        size: 13, color: AppTheme.primaryColor),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    // Decoration sits on the outer box and the home-indicator inset is padded
    // inside it — wrapping the whole composer in a SafeArea would lift it off
    // the screen edge and leave page background showing underneath.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mentionQuery != null) _buildMentionBar(),
            if (_mentionQuery == null &&
                _editing == null &&
                !_voice.isRecording &&
                _stickerSuggestions.isNotEmpty)
              StickerSuggestionBar(
                stickers: _stickerSuggestions,
                onPick: (s) => _sendSticker(s, fromSuggestion: true),
                onDismiss: _dismissStickerSuggestions,
              ),
            if (_canModerate &&
                _isComposing &&
                _editing == null &&
                !_voice.isRecording)
              AckRequestToggle(
                value: _requestAck,
                onChanged: (v) => setState(() => _requestAck = v),
              ),
            if (_editing != null)
              _EditPreviewBar(
                message: _editing!,
                onCancel: _cancelEdit,
              ),
            if (_replyingTo != null)
              _ReplyPreviewBar(
                message: _replyingTo!,
                onCancel: _cancelReply,
              ),
            if (_voice.isRecording)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: ChatVoiceRecordingBar(
                  controller: _voice,
                  onCancel: _cancelVoice,
                  onSend: _finishVoice,
                ),
              )
            else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _sending ? null : _showImageSourceSheet,
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 26,
                      color: _sending
                          ? AppTheme.mutedText(context)
                          : AppTheme.primaryColor,
                    ),
                    tooltip: 'ส่งรูปภาพ',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      onChanged: _onInputChanged,
                      textInputAction: TextInputAction.newline,
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  // ปุ่มสติกเกอร์ในช่องพิมพ์ (แบบ LINE) — แก้ข้อความอยู่ไม่ต้องมี
                  suffixIcon: _editing != null
                      ? null
                      : IconButton(
                          onPressed: _sending ? null : _toggleStickerPanel,
                          tooltip: _stickerPanelOpen ? 'เปิดคีย์บอร์ด' : 'สติกเกอร์',
                          icon: Icon(
                            _stickerPanelOpen
                                ? Icons.keyboard_rounded
                                : Icons.emoji_emotions_outlined,
                            size: 22,
                            color: _stickerPanelOpen
                                ? AppTheme.primaryColor
                                : AppTheme.mutedText(context),
                          ),
                        ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  hintStyle: appFont(
                    color: AppTheme.mutedText(context),
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w500,
                  ),
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.subtleSurface(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ยังไม่ได้พิมพ์อะไร = ปุ่มไมค์ (แบบ LINE) พิมพ์แล้วกลายเป็นปุ่มส่ง
            if (!_isComposing && _editing == null && !_sending)
              ChatVoiceMicButton(onTap: _startVoice)
            else
            Material(
              color: AppTheme.primaryColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
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
            if (_stickerPanelOpen && !_voice.isRecording && _editing == null)
              ChatStickerPanel(
                packs: _stickerPacks,
                recentIds: _recentStickerIds,
                loading: _stickersLoading,
                error: _stickersError,
                onRetry: () => _loadStickers(force: true),
                onSend: _sendSticker,
              ),
          ],
        ),
      ),
    );
  }
}

DateTime? _parseTime(dynamic raw) {
  final text = raw?.toString();
  if (text == null) return null;
  return DateTime.tryParse(text)?.toLocal();
}

/// Apple-style date divider: a centered tinted pill containing "วันนี้",
/// "เมื่อวาน", a weekday name within the past week, or a full date for older
/// conversations.
class _DateSeparator extends StatelessWidget {
  final DateTime day;

  const _DateSeparator({required this.day});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'วันนี้';
    if (diff == 1) return 'เมื่อวาน';
    if (diff > 1 && diff < 7) {
      const weekdays = [
        'วันจันทร์',
        'วันอังคาร',
        'วันพุธ',
        'วันพฤหัสบดี',
        'วันศุกร์',
        'วันเสาร์',
        'วันอาทิตย์',
      ];
      return weekdays[day.weekday - 1];
    }
    const months = [
      '',
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
    return '${day.day} ${months[day.month]} ${day.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.mutedText(context).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Text(
            _label(),
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// ข้อความจากระบบ (role == system)
///
/// ประกาศสั้น ๆ ("เจ้าหน้าที่เข้าร่วมแชท") ยังเป็นป้ายกลางจอเหมือนเดิม ส่วน
/// ข้อความอัตโนมัติตามไทม์ไลน์ทริป (สรุปจุดรับ/เตรียมของ/อากาศ) เป็นข้อความยาว
/// หลายบรรทัด จึงเรนเดอร์เป็นการ์ดชิดซ้ายให้อ่านเป็นย่อหน้าได้จริง
class _SystemMessage extends StatelessWidget {
  final Map<String, dynamic> message;
  final int? myUserId;
  final ValueChanged<String>? onGreet;
  final bool canModerate;
  final bool highlight;
  final bool ackBusy;
  final VoidCallback? onAck;
  final VoidCallback? onOpenAck;

  /// ทีมงานกดค้าง → เมนู (ขอให้กดรับทราบ / ปักหมุด) — ลูกทริปไม่มีเมนู
  final VoidCallback? onLongPress;

  /// ปุ่มชวนบนข้อความระบบ (cta = intro | contacts)
  final ValueChanged<String>? onCta;

  const _SystemMessage({
    required this.message,
    this.myUserId,
    this.onGreet,
    this.canModerate = false,
    this.highlight = false,
    this.ackBusy = false,
    this.onAck,
    this.onOpenAck,
    this.onLongPress,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final body = message['body']?.toString() ?? '';
    if (body.isEmpty) return const SizedBox.shrink();
    final child = _content(context, body);
    if (onLongPress == null) return child;

    return GestureDetector(
      onLongPress: onLongPress,
      child: child,
    );
  }

  Widget _content(BuildContext context, String body) {
    final ack = message['ack'] is Map
        ? Map<String, dynamic>.from(message['ack'] as Map)
        : null;

    // แนะนำทีมงานประจำรอบ — การ์ดรูป/ชื่อเล่น/ป่าที่เคยเดิน แทนข้อความล้วน
    final intro = message['staff_intro'];
    if (intro is Map) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: StaffIntroCard(
          intro: Map<String, dynamic>.from(intro),
          myUserId: myUserId,
          onGreet: onGreet,
          trailing: _systemTime(message),
        ),
      );
    }

    final cta = message['cta']?.toString();
    final ctaLabel = switch (cta) {
      'intro' => 'แนะนำตัว',
      'contacts' => 'แลกคอนแทค',
      _ => null,
    };
    // ประกาศที่ต้องกดรับทราบ/มีปุ่มชวนเป็นการ์ดเสมอ — ป้ายเม็ดยาไม่มีที่ให้วางปุ่ม
    final isNotice = ack == null &&
        ctaLabel == null &&
        !body.contains('\n') &&
        body.characters.length <= 90;

    if (isNotice) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      );
    }

    // แยกหัวเรื่อง (บรรทัดแรก) ออกจากรายละเอียด — สแกนหาข้อมูลได้เร็วกว่าก้อนเดียว
    final lines = body.split('\n');
    final heading = lines.first.trim();
    final rest = lines.skip(1).join('\n').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(
            alpha: AppTheme.isDark(context) ? 0.12 : 0.06,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: highlight ? 0.9 : 0.18),
            width: highlight ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ข้อความจากทีมงาน',
                  style: appFont(
                    fontSize: AppText.sizeMicro,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Text(
                  _systemTime(message),
                  style: appFont(
                    fontSize: AppText.sizeMicro,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              heading,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
                letterSpacing: -0.1,
                height: 1.35,
              ),
            ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 5),
              // เบอร์โทรในสรุปทีมงาน/คนขับต้องกดโทรได้ ไม่ใช่ให้ลูกค้าจดเอง
              _SystemBodyText(
                text: rest,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurface(context).withValues(alpha: 0.86),
                  height: 1.55,
                ),
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onCta!(cta!);
                },
                icon: Icon(
                  cta == 'intro' ? Icons.waving_hand_rounded : Icons.handshake_rounded,
                  size: 16,
                ),
                label: Text(ctaLabel, style: appFont(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
            ],
            if (ack != null && onAck != null && onOpenAck != null) ...[
              const SizedBox(height: 10),
              ChatAckBar(
                ack: ack,
                canManage: canModerate,
                busy: ackBusy,
                onAck: onAck!,
                onOpenDetail: onOpenAck!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _systemTime(Map<String, dynamic> message) {
    final dt = _parseTime(message['created_at']);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// ข้อความระบบที่มีเบอร์โทร (สรุปทีมงาน/คนขับก่อนวันเดินทาง) — ทำเบอร์ให้กดโทรได้
/// แทนที่จะต้องจดใส่กระดาษหรือคัดลอกทีละตัว
///
/// Stateful เหมือน [_MessageText] เพราะ [TapGestureRecognizer] ต้องถูก dispose
class _SystemBodyText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _SystemBodyText({required this.text, required this.style});

  @override
  State<_SystemBodyText> createState() => _SystemBodyTextState();
}

class _SystemBodyTextState extends State<_SystemBodyText> {
  /// เบอร์ไทย 9–10 หลักที่ขึ้นต้นด้วย 0 คั่นด้วยขีดหรือเว้นวรรคได้
  /// (กันชนกับตัวเลขอื่นในข้อความด้วยการห้ามมีหลักต่อท้าย/นำหน้า)
  static final _phonePattern = RegExp(
    r'(?<!\d)0\d{1,2}[-\s]?\d{3}[-\s]?\d{3,4}(?!\d)',
  );

  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _build();
  }

  @override
  void didUpdateWidget(_SystemBodyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _spans = _build();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _call(String phone) async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    try {
      await launchUrl(uri);
    } catch (_) {
      // เครื่องที่โทรออกไม่ได้ (แท็บเล็ต/อีมูเลเตอร์) — ปล่อยผ่านเงียบ ๆ
    }
  }

  List<InlineSpan> _build() {
    _disposeRecognizers();
    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;

    for (final match in _phonePattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }

      final phone = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _call(phone);
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: phone,
        style: widget.style.copyWith(
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
          decoration: TextDecoration.underline,
          decorationColor: AppTheme.primaryColor.withValues(alpha: 0.5),
        ),
        recognizer: recognizer,
      ));

      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: _spans), style: widget.style);
  }
}

/// คำถามที่ลูกค้าถามซ้ำที่สุดในห้องแชท — ใช้เป็นทั้งป้ายปุ่มและหัวข้อคำตอบ
enum _QuickAsk {
  itinerary(QuickAskTopic.itinerary, 'กำหนดการ', 'กำหนดการ', Icons.route_rounded),
  van(
    QuickAskTopic.van,
    'รถถึงไหนแล้ว',
    'ตำแหน่งรถ',
    Icons.directions_bus_rounded,
  ),
  time(QuickAskTopic.time, 'ขึ้นรถกี่โมง', 'เวลาขึ้นรถ', Icons.schedule_rounded),
  place(QuickAskTopic.place, 'จุดรับที่ไหน', 'จุดรับ', Icons.pin_drop_rounded),
  vehicle(
    QuickAskTopic.vehicle,
    'ทะเบียนรถ',
    'ข้อมูลรถ',
    Icons.airport_shuttle_rounded,
  ),
  contact(QuickAskTopic.contact, 'เบอร์ติดต่อ', 'เบอร์ติดต่อ', Icons.phone_rounded);

  final QuickAskTopic topic;

  /// คำบนชิป — รูปคำถาม เพราะผู้ใช้เป็นคนกดถาม
  final String label;

  /// คำบนแถบคำตอบอัตโนมัติ — รูปคำนาม เพราะแอปเป็นฝ่ายยื่นให้
  final String hint;

  final IconData icon;

  const _QuickAsk(this.topic, this.label, this.hint, this.icon);

  static _QuickAsk forTopic(QuickAskTopic topic) =>
      values.firstWhere((ask) => ask.topic == topic);
}

/// แถบคำตอบอัตโนมัติ — ขึ้นเองเมื่อข้อความที่กำลังพิมพ์หรือเพิ่งส่งเข้าข้อที่แอป
/// ตอบได้ ยกคำตอบมาให้อ่านตรงนั้นเลย แตะเพื่อดูฉบับเต็มในชีต
///
/// ขึ้นเฉพาะเครื่องคนถาม ไม่มีอะไรถูกโพสต์ลงห้อง — เดาผิดจึงไม่มีใครเห็นนอกจาก
/// คนที่ปัดมันทิ้งได้อยู่แล้ว
class _QuickAskSuggestion extends StatelessWidget {
  final _QuickAsk ask;
  final String? answer;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _QuickAskSuggestion({
    required this.ask,
    required this.answer,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 6, 9),
            child: Row(
              children: [
                Icon(ask.icon, size: 17, color: AppTheme.primaryColor),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        answer ?? 'ดู${ask.hint}ของรอบนี้',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      Text(
                        'แตะเพื่อดู${ask.hint}ทั้งหมด',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'ปิด',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// แถบปุ่มคำถามด่วนเหนือช่องพิมพ์ — ทางลัดที่เร็วกว่าพิมพ์ถามสตาฟ
///
/// สตาฟ/ทีมงานจะเห็นปุ่มเพิ่มอีกหนึ่งปุ่มสำหรับโพสต์สรุปให้ทั้งห้องรวดเดียว
class _QuickAskBar extends StatelessWidget {
  final bool canModerate;
  final bool hasItinerary;
  final bool tripLive;
  final ValueChanged<_QuickAsk> onAsk;
  final Future<void> Function() onSendSummary;
  final Future<void> Function() onSendItinerary;

  const _QuickAskBar({
    required this.canModerate,
    required this.hasItinerary,
    required this.tripLive,
    required this.onAsk,
    required this.onSendSummary,
    required this.onSendItinerary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        children: [
          for (final ask in _QuickAsk.values) ...[
            // รอบที่ยังไม่มีกำหนดการ (ทั้งของรอบและของทริป) ไม่ต้องมีปุ่มให้กดค้าง
            // "รถถึงไหนแล้ว" มีความหมายเฉพาะวันเดินทาง (ช่วงเดียวกับการ์ดหน้าจอล็อก)
            if ((ask != _QuickAsk.itinerary || hasItinerary) &&
                (ask != _QuickAsk.van || tripLive)) ...[
              _QuickAskChip(
                icon: ask.icon,
                label: ask.label,
                onTap: () => onAsk(ask),
              ),
              const SizedBox(width: 8),
            ],
          ],
          if (canModerate && hasItinerary) ...[
            _QuickAskChip(
              icon: Icons.route_rounded,
              label: 'ส่งกำหนดการ',
              filled: true,
              onTap: onSendItinerary,
            ),
            const SizedBox(width: 8),
          ],
          if (canModerate)
            _QuickAskChip(
              icon: Icons.campaign_rounded,
              label: 'ส่งสรุปให้ทุกคน',
              filled: true,
              onTap: onSendSummary,
            ),
        ],
      ),
    );
  }
}

class _QuickAskChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _QuickAskChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppTheme.onSurface(context);

    return Material(
      color: filled
          ? AppTheme.primaryColor
          : AppTheme.subtleSurface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: filled
                ? null
                : Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: filled ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// คำตอบของคำถามด่วน — ตอบครบทั้ง 4 ข้อในชีตเดียว โดยไฮไลต์ข้อที่กดถามมา
/// (ตอบเฉพาะคนกด ไม่โพสต์ลงห้อง จะได้ไม่รบกวนเพื่อนร่วมทริป)
class _TripInfoSheet extends StatelessWidget {
  final Map<String, dynamic> info;
  final _QuickAsk focus;
  final int scheduleId;
  final String tripTitle;
  final Future<void> Function() onTrack;

  const _TripInfoSheet({
    required this.info,
    required this.focus,
    required this.scheduleId,
    required this.tripTitle,
    required this.onTrack,
  });

  Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    HapticFeedback.selectionClick();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เปิดลิงก์ไม่ได้')));
    }
  }

  void _openItinerary(BuildContext context) {
    HapticFeedback.selectionClick();
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(
      builder: (_) => ScheduleItineraryScreen(
        scheduleId: scheduleId,
        tripTitle: tripTitle,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _map(info['pickup']);
    final vehicle = _map(info['vehicle']);
    final driver = _map(info['driver']);
    final staff = (info['staff'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final itinerary = _map(info['itinerary']);
    final itineraryItems = (itinerary?['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final itineraryTotal =
        int.tryParse('${itinerary?['total']}') ?? itineraryItems.length;

    final pickupTime = _text(pickup?['time']);
    final pickupWhere = _text(pickup?['location']) ?? _text(pickup?['label']);
    final mapUrl = _text(pickup?['map_url']);
    final plate = _text(vehicle?['license_plate']);
    final vehicleName = _text(vehicle?['name']);
    final vehicleColor = _text(vehicle?['color']);
    final live = _map(info['live']);
    final canTrack = live?['can_track'] == true;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ข้อมูลการเดินทางของคุณ',
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_text(info['departure_label']) != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ออกเดินทาง ${_text(info['departure_label'])}',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  // ตำแหน่งรถ — ขึ้นเฉพาะวันเดินทาง (หรือเมื่อถามเรื่องนี้ตรง ๆ)
                  if (live != null || focus == _QuickAsk.van)
                    _TripInfoBlock(
                      ask: _QuickAsk.van,
                      highlight: focus == _QuickAsk.van,
                      answer: _text(live?['headline']),
                      pending:
                          'ดูตำแหน่งรถได้ในวันเดินทาง ทีมงานจะแจ้งเมื่อรถออกครับ',
                      detail: _text(live?['detail']),
                      actionIcon: Icons.map_rounded,
                      actionLabel: canTrack ? 'ดูรถบนแผนที่' : null,
                      onAction: canTrack
                          ? () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop();
                              onTrack();
                            }
                          : null,
                    ),
                  _TripInfoBlock(
                    ask: _QuickAsk.itinerary,
                    highlight: focus == _QuickAsk.itinerary,
                    answer: itineraryItems.isEmpty
                        ? null
                        : 'ทั้งหมด $itineraryTotal รายการ',
                    pending: 'ทีมงานจะลงกำหนดการให้ก่อนเดินทางครับ',
                    actionIcon: Icons.route_rounded,
                    actionLabel:
                        itineraryItems.isEmpty ? null : 'ดูกำหนดการทั้งหมด',
                    onAction: itineraryItems.isEmpty
                        ? null
                        : () => _openItinerary(context),
                    children: [
                      for (final item
                          in itineraryItems.take(_itineraryPreviewCount))
                        _TripInfoItineraryRow(
                          time: _text(item['time']),
                          title: _text(item['title']) ?? '',
                        ),
                      if (itineraryTotal > _itineraryPreviewCount)
                        _TripInfoItineraryRow(
                          time: null,
                          title:
                              'และอีก ${itineraryTotal - _itineraryPreviewCount} รายการ',
                          muted: true,
                        ),
                    ],
                  ),
                  _TripInfoBlock(
                    ask: _QuickAsk.time,
                    highlight: focus == _QuickAsk.time,
                    answer: pickupTime != null
                        ? '$pickupTime น.'
                        : (_text(info['departs_at']) != null
                              ? 'รถออกตามเวลาในใบจอง'
                              : null),
                    pending: 'ทีมงานจะยืนยันเวลาขึ้นรถให้ก่อนเดินทางครับ',
                    detail: pickupWhere == null ? null : 'ที่ $pickupWhere',
                  ),
                  _TripInfoBlock(
                    ask: _QuickAsk.place,
                    highlight: focus == _QuickAsk.place,
                    answer: pickupWhere,
                    pending: 'ทีมงานจะยืนยันจุดรับให้ก่อนเดินทางครับ',
                    detail: _text(pickup?['notes']),
                    actionIcon: Icons.map_rounded,
                    actionLabel: mapUrl == null ? null : 'เปิดแผนที่',
                    onAction: mapUrl == null
                        ? null
                        : () {
                            final uri = Uri.tryParse(mapUrl);
                            if (uri != null) _launch(context, uri);
                          },
                  ),
                  _TripInfoBlock(
                    ask: _QuickAsk.vehicle,
                    highlight: focus == _QuickAsk.vehicle,
                    answer: plate == null ? null : 'ทะเบียน $plate',
                    pending: 'ทีมงานจะยืนยันรถและทะเบียนให้ก่อนเดินทาง 1 วันครับ',
                    detail: [
                      ?vehicleName,
                      if (vehicleColor != null) 'สี$vehicleColor',
                    ].join(' · ').trim().isEmpty
                        ? null
                        : [
                            ?vehicleName,
                            if (vehicleColor != null) 'สี$vehicleColor',
                          ].join(' · '),
                  ),
                  _TripInfoBlock(
                    ask: _QuickAsk.contact,
                    highlight: focus == _QuickAsk.contact,
                    answer: null,
                    pending:
                        'ทีมงานจะแจ้งเบอร์คนขับและสตาฟประจำรอบให้ก่อนเดินทางครับ',
                    children: [
                      if (driver != null)
                        _TripInfoContactRow(
                          role: 'คนขับ',
                          name: _text(driver['name']) ?? 'คนขับ',
                          phone: _text(driver['phone']),
                          onCall: _text(driver['phone']) == null
                              ? null
                              : () => _launch(
                                  context,
                                  Uri(
                                    scheme: 'tel',
                                    path: _text(driver['phone']),
                                  ),
                                ),
                        ),
                      for (final member in staff)
                        _TripInfoContactRow(
                          role: 'สตาฟประจำรอบ',
                          name: _text(member['name']) ?? 'สตาฟ',
                          phone: _text(member['phone']),
                          onCall: _text(member['phone']) == null
                              ? null
                              : () => _launch(
                                  context,
                                  Uri(
                                    scheme: 'tel',
                                    path: _text(member['phone']),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// พรีวิวกำหนดการในชีตกี่รายการ — ที่เหลือกด "ดูกำหนดการทั้งหมด" ต่อ
/// (ชีตนี้ตอบ 5 คำถามในจอเดียว บล็อกเดียวยาวเกินก็ดันข้ออื่นตกจอ)
const int _itineraryPreviewCount = 5;

/// หนึ่งรายการกำหนดการแบบย่อในชีตคำตอบ — เวลา + หัวข้อ บรรทัดเดียว
class _TripInfoItineraryRow extends StatelessWidget {
  final String? time;
  final String title;
  final bool muted;

  const _TripInfoItineraryRow({
    required this.time,
    required this.title,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              time ?? '',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
                color: muted
                    ? AppTheme.mutedText(context)
                    : AppTheme.onSurface(context),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// หนึ่งคำถาม-คำตอบในชีต — ข้อที่ถูกกดถามจะถูกไฮไลต์ไว้
class _TripInfoBlock extends StatelessWidget {
  final _QuickAsk ask;
  final bool highlight;
  final String? answer;
  final String pending;
  final String? detail;
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;

  const _TripInfoBlock({
    required this.ask,
    required this.highlight,
    required this.answer,
    required this.pending,
    this.detail,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    // มีรายชื่อให้โทร (คนขับ/สตาฟ) ก็ถือว่าตอบได้แล้ว แม้จะไม่มีข้อความคำตอบ
    final hasAnswerText = answer != null && answer!.trim().isNotEmpty;
    final known = hasAnswerText || children.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: highlight
              ? AppTheme.primaryColor.withValues(alpha: 0.35)
              : AppTheme.border(context),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ask.icon, size: 15, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                ask.label,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (hasAnswerText)
            Text(
              answer!,
              style: appFont(
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
                height: 1.3,
              ),
            ),
          if (!known)
            Text(
              pending,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
                height: 1.4,
              ),
            ),
          if (hasAnswerText && detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
                height: 1.4,
              ),
            ),
          ],
          for (final child in children) child,
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          actionIcon,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          actionLabel!,
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// แถวคนที่โทรหาได้ในชีตคำตอบ (คนขับ / สตาฟ)
class _TripInfoContactRow extends StatelessWidget {
  final String role;
  final String name;
  final String? phone;
  final VoidCallback? onCall;

  const _TripInfoContactRow({
    required this.role,
    required this.name,
    required this.phone,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
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
                Text(
                  phone == null ? role : '$role · $phone',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          if (onCall != null)
            Material(
              color: AppTheme.primaryColor,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onCall,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(
                    Icons.phone_rounded,
                    size: 17,
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

/// การ์ดโพลในห้องแชท — คำถาม ตัวเลือกพร้อมแถบผลโหวต และปุ่มปิดโหวต
///
/// แตะที่ตัวเลือกเพื่อโหวต/ถอนโหวต (โพลเลือกข้อเดียวจะย้ายคะแนนให้เอง) ผลโหวต
/// เปิดให้ทุกคนเห็นตลอด เพราะทริปกลุ่มต้องเห็นภาพรวมถึงจะนัดกันได้
///
/// kind = vote ("โหวตตัดสิน") เพิ่ม: นับ "โหวตแล้ว x/y คน" เทียบลูกทริปในห้อง
/// รายชื่อคนที่ยังไม่โหวต และแถบผลเสียงข้างมากเมื่อปิด (ตรงกับข้อความประกาศผล)
class _PollCard extends StatelessWidget {
  final Map<String, dynamic> poll;
  final int? myUserId;
  final bool canClose;
  final void Function(int pollId, List<int> optionIds) onVote;
  final ValueChanged<int> onClose;
  final List<Map<String, dynamic>> travellers;

  const _PollCard({
    required this.poll,
    required this.myUserId,
    required this.canClose,
    required this.onVote,
    required this.onClose,
    this.travellers = const [],
  });

  int get _pollId => int.tryParse('${poll['id']}') ?? 0;

  bool get _isVote => poll['kind'] == 'vote';

  /// เลยเวลาปิดแล้วถือว่าปิด แม้ยังไม่ได้รับสัญญาณจากเซิร์ฟเวอร์ (socket หลุด)
  bool get _isClosed {
    if (poll['is_closed'] == true) return true;
    final at = DateTime.tryParse('${poll['closes_at'] ?? ''}');
    return at != null && at.isBefore(DateTime.now());
  }

  Set<int> get _voterIds => {
        for (final o in _options)
          for (final v in (o['voter_ids'] as List? ?? const []))
            ?int.tryParse('$v'),
      };

  Map<String, dynamic>? get _result =>
      poll['result'] is Map ? Map<String, dynamic>.from(poll['result'] as Map) : null;

  bool get _allowMultiple => poll['allow_multiple'] == true;

  List<int> get _myOptionIds => (poll['my_option_ids'] as List? ?? const [])
      .map((e) => int.tryParse('$e'))
      .whereType<int>()
      .toList();

  List<Map<String, dynamic>> get _options => (poll['options'] as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  /// "ปิดใน 2 ชม." / "ปิดใน 15 นาที" — บอกจังหวะให้คนที่ยังไม่โหวตรู้ว่าเหลือเวลาเท่าไร
  String? _closesInLabel() {
    if (_isClosed) return null;
    final raw = poll['closes_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final at = DateTime.tryParse(raw)?.toLocal();
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    if (left.isNegative) return null;
    if (left.inHours >= 24) return 'ปิดใน ${left.inDays + 1} วัน';
    if (left.inHours >= 1) return 'ปิดใน ${left.inHours} ชม.';
    return 'ปิดใน ${left.inMinutes + 1} นาที';
  }

  void _tap(Map<String, dynamic> option) {
    if (_isClosed) return;
    final id = int.tryParse('${option['id']}');
    if (id == null || _pollId == 0) return;

    final current = _myOptionIds;
    final List<int> next;
    if (_allowMultiple) {
      next = current.contains(id)
          ? (current.where((e) => e != id).toList())
          : ([...current, id]);
    } else {
      // เลือกข้อเดิมซ้ำ = ถอนโหวต, เลือกข้ออื่น = ย้ายคะแนน
      next = current.contains(id) ? <int>[] : [id];
    }
    onVote(_pollId, next);
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final voterCount = int.tryParse('${poll['voter_count']}') ?? 0;
    final closesIn = _closesInLabel();

    // โหวตตัดสิน: นับเทียบลูกทริปในห้อง เพื่อให้เห็นว่ายังขาดใคร
    final voterIds = _voterIds;
    final pendingNames = _isVote
        ? travellers
            .where((t) => !voterIds.contains(t['id']))
            .map((t) => t['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList()
        : const <String>[];
    final votedTravellers = travellers.where((t) => voterIds.contains(t['id'])).length;

    final meta = <String>[
      if (_isVote) 'โหวตตัดสิน',
      if (_allowMultiple) 'เลือกได้หลายข้อ',
      if (_isVote && travellers.isNotEmpty)
        'โหวตแล้ว $votedTravellers/${travellers.length} คน'
      else
        voterCount > 0 ? 'โหวตแล้ว $voterCount คน' : 'ยังไม่มีใครโหวต',
      if (_isClosed) 'ปิดโหวตแล้ว' else ?closesIn,
    ];

    final result = _isVote && _isClosed ? _result : null;
    final winnerLabel = result?['status'] == 'winner'
        ? result!['winner_label']?.toString()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              (_isClosed || _isVote) ? Icons.how_to_vote_rounded : Icons.bar_chart_rounded,
              size: 17,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                poll['question']?.toString() ?? '',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  letterSpacing: -0.1,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          meta.join(' · '),
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w600,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 10),
        for (final option in options) ...[
          _PollOptionRow(
            option: option,
            voterCount: voterCount,
            closed: _isClosed,
            isWinner: winnerLabel != null && option['label']?.toString() == winnerLabel,
            onTap: () => _tap(option),
          ),
          const SizedBox(height: 6),
        ],
        if (result != null) ...[
          _VoteResultBanner(result: result),
          const SizedBox(height: 6),
        ] else if (_isVote && !_isClosed && pendingNames.isNotEmpty) ...[
          Text(
            'ยังไม่โหวต: ${pendingNames.take(6).join(', ')}'
            '${pendingNames.length > 6 ? ' และอีก ${pendingNames.length - 6} คน' : ''}',
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.mutedText(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (canClose && !_isClosed) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (_pollId != 0) onClose(_pollId);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: AppTheme.mutedText(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'ปิดโหวต',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// หนึ่งตัวเลือกในโพล — แถบพื้นหลังยาวตามสัดส่วนคะแนน อ่านผลได้โดยไม่ต้องคิดเลข
class _PollOptionRow extends StatelessWidget {
  final Map<String, dynamic> option;
  final int voterCount;
  final bool closed;
  final bool isWinner;
  final VoidCallback onTap;

  const _PollOptionRow({
    required this.option,
    required this.voterCount,
    required this.closed,
    this.isWinner = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final votes = int.tryParse('${option['vote_count']}') ?? 0;
    final mine = option['voted_by_me'] == true;
    final ratio = voterCount == 0 ? 0.0 : (votes / voterCount).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    final border = mine
        ? AppTheme.primaryColor.withValues(alpha: 0.55)
        : AppTheme.border(context);

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: closed ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: border, width: mine ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // แถบผลโหวตอยู่หลังข้อความ
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio == 0 ? 0.0001 : ratio,
                  child: Container(
                    color: AppTheme.primaryColor.withValues(
                      alpha: mine ? 0.20 : 0.10,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (isWinner) ...[
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 16,
                        color: AppTheme.warningColor,
                      ),
                      const SizedBox(width: 6),
                    ] else if (mine) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        option['label']?.toString() ?? '',
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: mine ? FontWeight.w800 : FontWeight.w600,
                          color: AppTheme.onSurface(context),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      votes == 0 ? '—' : '$votes · $percent%',
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แถบผลโหวตตัดสินใต้ตัวเลือก — ข้อความเดียวกับที่ระบบประกาศเข้าห้อง
class _VoteResultBanner extends StatelessWidget {
  final Map<String, dynamic> result;

  const _VoteResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final status = result['status']?.toString();
    final winnerVotes = int.tryParse('${result['winner_votes']}') ?? 0;
    final total = int.tryParse('${result['total_votes']}') ?? 0;
    final tied = (result['tied_labels'] as List? ?? const []).join(' / ');

    final (icon, text) = switch (status) {
      'winner' => (
          Icons.emoji_events_rounded,
          'ผลโหวต: ${result['winner_label']} ($winnerVotes จาก $total เสียง)',
        ),
      'tie' => (Icons.balance_rounded, 'เสมอกัน ($tied) — ให้ทีมงานช่วยตัดสิน'),
      _ => (Icons.info_outline_rounded, 'ปิดโหวตแล้ว ไม่มีใครโหวต'),
    };

    final accent = status == 'winner' ? AppTheme.primaryColor : AppTheme.warningColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ผลลัพธ์จากชีตสร้างโพล
class _PollDraft {
  final String question;
  final List<String> options;
  final bool allowMultiple;
  final int? durationHours;

  const _PollDraft({
    required this.question,
    required this.options,
    required this.allowMultiple,
    required this.durationHours,
  });
}

/// ชีตสร้างโพล — คำถาม + ตัวเลือก 2–6 ข้อ + เลือกได้หลายข้อ + เวลาปิดโหวต
class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet();

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  static const _maxOptions = 6;

  final _question = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultiple = false;
  int? _durationHours;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit {
    if (_question.text.trim().isEmpty) return false;
    final filled = _options
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toSet();
    return filled.length >= 2;
  }

  void _addOption() {
    if (_options.length >= _maxOptions) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    setState(() => _options.removeAt(index).dispose());
  }

  void _submit() {
    final options = _options
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    HapticFeedback.selectionClick();
    Navigator.pop(
      context,
      _PollDraft(
        question: _question.text.trim(),
        options: options,
        allowMultiple: _allowMultiple,
        durationHours: _durationHours,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded,
                        size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'สร้างโพล',
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SheetCloseButton(),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    TextField(
                      controller: _question,
                      autofocus: true,
                      maxLength: 200,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'คำถาม เช่น แวะกินข้าวเย็นที่ไหนดี',
                        hintStyle: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedText(context),
                        ),
                        filled: true,
                        fillColor: AppTheme.subtleSurface(context),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          borderSide: BorderSide(color: AppTheme.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          borderSide: BorderSide(color: AppTheme.border(context)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _PollSheetLabel(label: 'ตัวเลือก'),
                    for (var i = 0; i < _options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _options[i],
                                maxLength: 100,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                                style: appFont(
                                  fontSize: AppText.sizeBody,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onSurface(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'ตัวเลือกที่ ${i + 1}',
                                  hintStyle: appFont(
                                    fontSize: AppText.sizeBody,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.mutedText(context),
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: AppTheme.subtleSurface(context),
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    borderSide: BorderSide(
                                      color: AppTheme.border(context),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    borderSide: BorderSide(
                                      color: AppTheme.border(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_options.length > 2)
                              IconButton(
                                tooltip: 'ลบตัวเลือกนี้',
                                onPressed: () => _removeOption(i),
                                icon: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 20,
                                  color: AppTheme.mutedText(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_options.length < _maxOptions)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addOption,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'เพิ่มตัวเลือก',
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _allowMultiple,
                      onChanged: (v) => setState(() => _allowMultiple = v),
                      title: Text(
                        'เลือกได้หลายข้อ',
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ),
                    const _PollSheetLabel(label: 'ปิดโหวตอัตโนมัติ'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final option in const [
                          (null, 'ไม่กำหนด'),
                          (3, '3 ชม.'),
                          (12, '12 ชม.'),
                          (24, '1 วัน'),
                        ])
                          ChoiceChip(
                            label: Text(
                              option.$2,
                              style: appFont(
                                fontSize: AppText.sizeLabel,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selected: _durationHours == option.$1,
                            onSelected: (_) =>
                                setState(() => _durationHours = option.$1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: Text(
                      'ส่งโพลเข้าห้อง',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollSheetLabel extends StatelessWidget {
  final String label;

  const _PollSheetLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}

/// Renders a message body with "@mention" tokens bolded and URLs turned into
/// tappable links. Stateful so the link [TapGestureRecognizer]s it creates are
/// disposed properly instead of leaking on every rebuild.
class _MessageText extends StatefulWidget {
  final String text;
  final Color color;
  final bool isEdited;

  const _MessageText({
    required this.text,
    required this.color,
    required this.isEdited,
  });

  @override
  State<_MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<_MessageText> {
  // URL (http/https or bare www.) or @mention.
  static final _pattern = RegExp(
    r'((?:https?:\/\/|www\.)[^\s]+|@[^\s@]+)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _build();
  }

  @override
  void didUpdateWidget(_MessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.color != widget.color ||
        oldWidget.isEdited != widget.isEdited) {
      _spans = _build();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(String raw) async {
    var url = raw;
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best effort — silently ignore an unlaunchable link.
    }
  }

  List<InlineSpan> _build() {
    _disposeRecognizers();
    final text = widget.text;
    final fg = widget.color;
    // On the emerald "own message" bubble the accent blends in, so keep the
    // bubble's own colour there; use accents only on light bubbles.
    final onColoured = fg.computeLuminance() > 0.6;
    final mentionColor = onColoured ? fg : AppTheme.primaryColor;
    final linkColor = onColoured ? fg : const Color(0xFF2563EB);

    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      var token = match.group(0)!;
      if (token.startsWith('@')) {
        spans.add(TextSpan(
          text: token,
          style: appFont(fontWeight: FontWeight.w800, color: mentionColor),
        ));
      } else {
        // Don't swallow trailing punctuation into the link.
        var trailing = '';
        while (token.isNotEmpty &&
            '.,!?)]}"\''.contains(token[token.length - 1])) {
          trailing = token[token.length - 1] + trailing;
          token = token.substring(0, token.length - 1);
        }
        final recognizer = TapGestureRecognizer()..onTap = () => _open(token);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: token,
          style: appFont(
            fontWeight: FontWeight.w600,
            color: linkColor,
          ).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withValues(alpha: 0.6),
          ),
          recognizer: recognizer,
        ));
        if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    if (widget.isEdited) {
      spans.add(TextSpan(
        text: '  แก้ไขแล้ว',
        style: appFont(
          fontSize: AppText.sizeCaption,
          color: fg.withValues(alpha: 0.55),
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
        ),
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _spans),
      style: appFont(
        fontSize: AppText.sizeSubtitle,
        height: 1.45,
        color: widget.color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool showAuthor;
  final bool showAvatar;
  final bool showTimestamp;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final int readByCount;
  final int? myUserId;
  final bool mentionsMe;
  final bool highlight;
  final bool pending;
  final bool failed;
  final VoidCallback? onRetry;
  final ValueChanged<String> onCopy;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;
  final ValueChanged<int> onReplyTap;
  final ValueChanged<String> onReactionTap;
  final bool canModerate;
  final void Function(int pollId, List<int> optionIds) onVote;
  final ValueChanged<int> onClosePoll;
  final List<Map<String, dynamic>> travellers;
  final ValueChanged<Map<String, dynamic>> onOrderFood;
  final ValueChanged<Map<String, dynamic>> onOpenFoodSummary;
  final ValueChanged<Map<String, dynamic>> onPayFood;
  final void Function(Map<String, dynamic> stop, List<int> ids, bool boarded)
      onBoardRestStop;
  final ValueChanged<Map<String, dynamic>> onOpenRestRoll;
  final ValueChanged<Map<String, dynamic>> onPayCollection;
  final ValueChanged<Map<String, dynamic>> onOpenCollection;
  final VoidCallback onOpenLostItems;
  final bool ackBusy;
  final VoidCallback onAck;
  final VoidCallback onOpenAck;
  final VoidCallback onEditIntro;
  final _BubbleTools tools;

  const _MessageBubble({
    required this.message,
    required this.showAuthor,
    required this.showAvatar,
    required this.showTimestamp,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.readByCount,
    required this.myUserId,
    required this.mentionsMe,
    required this.highlight,
    required this.pending,
    required this.failed,
    required this.onRetry,
    required this.onCopy,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.onReplyTap,
    required this.onReactionTap,
    required this.canModerate,
    required this.onVote,
    required this.onClosePoll,
    required this.travellers,
    required this.onOrderFood,
    required this.onOpenFoodSummary,
    required this.onPayFood,
    required this.onBoardRestStop,
    required this.onOpenRestRoll,
    required this.onPayCollection,
    required this.onOpenCollection,
    required this.onOpenLostItems,
    required this.ackBusy,
    required this.onAck,
    required this.onOpenAck,
    required this.onEditIntro,
    required this.tools,
  });

  static const _roleLabels = {
    'customer': 'ลูกค้า',
    'staff': 'สตาฟ',
    'admin': 'ทีมงาน',
    'system': 'ระบบ',
  };

  String _timeText() {
    final dt = _parseTime(message['created_at']);
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message['is_mine'] == true;
    final role = message['sender_role']?.toString() ?? 'customer';
    final user = message['user'] is Map
        ? Map<String, dynamic>.from(message['user'] as Map)
        : <String, dynamic>{};
    final author = (user['nickname']?.toString().isNotEmpty ?? false)
        ? user['nickname'].toString()
        : (user['name']?.toString() ?? 'ผู้ใช้');
    final avatarUrl = ApiConfig.mediaUrl(user['avatar_url']);
    final tierBadge = TierBadge.fromUser(user, compact: true);

    final isDeleted = message['is_deleted'] == true;
    final isEdited = message['edited_at'] != null;
    // การ์ดโพลใช้พื้นที่มากกว่าข้อความ และต้องอ่านแถบผลโหวตออกทั้งฝั่งเราและฝั่งเขา
    // จึงกว้างกว่าบับเบิลปกติและใช้พื้นหลังกลาง ๆ แทนสีของผู้ส่ง
    final poll = (!isDeleted && message['poll'] is Map)
        ? Map<String, dynamic>.from(message['poll'] as Map)
        : null;
    // การ์ดรับออเดอร์อาหารใช้กติกาเดียวกับการ์ดโพล (กว้าง + พื้นกลาง)
    final foodRound = (!isDeleted && message['food_round'] is Map)
        ? Map<String, dynamic>.from(message['food_round'] as Map)
        : null;
    final restStop = (!isDeleted && message['rest_stop'] is Map)
        ? Map<String, dynamic>.from(message['rest_stop'] as Map)
        : null;
    final collection = (!isDeleted && message['collection'] is Map)
        ? Map<String, dynamic>.from(message['collection'] as Map)
        : null;
    final lostItem = (!isDeleted && message['lost_item'] is Map)
        ? Map<String, dynamic>.from(message['lost_item'] as Map)
        : null;
    Map<String, dynamic>? card(String key) =>
        (!isDeleted && message[key] is Map)
            ? Map<String, dynamic>.from(message[key] as Map)
            : null;
    final trail = card('trail_check');
    final wellness = card('wellness');
    final dropoff = card('dropoff');
    final porter = card('porter');
    // สติกเกอร์ลอยบนพื้นห้องแบบ LINE — ไม่มีกรอบบับเบิล
    final sticker = card('sticker');
    // การ์ดแนะนำตัว — วาดแทนข้อความสำรองใน body
    final intro = card('intro');
    final isCard = intro != null ||
        poll != null ||
        foodRound != null ||
        restStop != null ||
        collection != null ||
        lostItem != null ||
        trail != null ||
        wellness != null ||
        dropoff != null ||
        porter != null;
    final body = message['body']?.toString() ?? '';
    final imageUrl = isDeleted ? '' : ApiConfig.mediaUrl(message['image_url']);
    // A locally-picked image shown while an optimistic send is in flight (before
    // the server returns its hosted URL).
    final localImagePath =
        isDeleted ? '' : (message['_local_image_path']?.toString() ?? '');
    final hasText = !isDeleted && !isCard && sticker == null && body.isNotEmpty;
    final hasImage = imageUrl.isNotEmpty;
    final hasLocalImage = imageUrl.isEmpty && localImagePath.isNotEmpty;
    // ข้อความเสียง — ระหว่างอัปโหลดเล่นจากไฟล์ในเครื่อง ส่งถึงแล้วเล่นจากเซิร์ฟเวอร์
    final audioUrl = isDeleted ? '' : ApiConfig.mediaUrl(message['audio_url']);
    final localAudioPath =
        isDeleted ? '' : (message['_local_audio_path']?.toString() ?? '');
    final hasVoice =
        !isCard && (audioUrl.isNotEmpty || localAudioPath.isNotEmpty);

    final replyTo = message['reply_to'] is Map
        ? Map<String, dynamic>.from(message['reply_to'] as Map)
        : null;
    final reactions = (message['reactions'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final ack = card('ack');

    final isDark = AppTheme.isDark(context);
    // บับเบิลฝั่งคนอื่นเป็นเทาอ่อนบนพื้นห้องสีขาว (โหมดมืดกลับกัน) — คู่สีนี้
    // อยู่ใน AppTheme เพราะพื้นห้องกับบับเบิลต้องขยับไปด้วยกันเสมอ
    final neutralBg = AppTheme.chatIncomingBubble(context);
    final bg = sticker != null
        ? Colors.transparent
        : (isMine && !isCard)
            ? AppTheme.primaryColor
            : neutralBg;
    final fg = (isMine && !isCard)
        ? Colors.white
        : AppTheme.onSurface(context);

    // iMessage-style asymmetric corners: the "tail" corner (bottom on the
    // sender's side) tightens on the last bubble of a group so the cluster
    // reads as a single utterance.
    const r = Radius.circular(AppTheme.radiusMd);
    const rTight = Radius.circular(AppTheme.radiusXs);
    final shape = isMine
        ? BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: r,
            bottomRight: isLastInGroup ? rTight : r,
          )
        : BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: isLastInGroup ? rTight : r,
            bottomRight: r,
          );

    final content = Padding(
      // Grouped messages sit tighter; the gap before a new sender opens up.
      // ช่องว่างก้อนต่อก้อนคือสิ่งที่บอกว่า "คนละคนพูด" — ถ้าแคบเกินไปทั้งห้อง
      // อ่านเป็นพืดเดียว จังหวะที่ใช้: ในกลุ่มเดียวกัน 5 / ข้ามผู้พูด 16
      padding: EdgeInsets.only(top: isFirstInGroup ? 16 : 5, bottom: 0),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            SizedBox(
              width: 34,
              child: showAvatar
                  ? _Avatar(url: avatarUrl, name: author)
                  : const SizedBox.shrink(),
            ),
          if (!isMine) const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.sizeOf(context).width * (isCard ? 0.86 : 0.74),
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showAuthor && !isMine) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            author,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface(context),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _RoleTag(role: role),
                        if (tierBadge != null) ...[
                          const SizedBox(width: 4),
                          tierBadge,
                        ],
                      ],
                    ),
                  ),
                ],
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    padding: sticker != null
                        ? EdgeInsets.zero
                        : (hasImage || hasLocalImage) && !hasText
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.fromLTRB(14, 11, 14, 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: shape,
                      // Outline the bubble when this message tags me (LINE-style
                      // mention highlight) or when we just jumped to it.
                      // นอกเหนือจากนั้นบับเบิลที่ไม่ใช่สีทึบของเราได้เส้นขอบบาง ๆ
                      // ให้เห็นขอบก้อนข้อความชัดบนพื้นห้องที่สีใกล้กัน
                      border: (mentionsMe && !isMine) || highlight
                          ? Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.9),
                              width: 1.5,
                            )
                          : (isMine && !isCard) || sticker != null
                          ? null
                          : Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : AppTheme.border(context).withValues(
                                      alpha: 0.65,
                                    ),
                            ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (replyTo != null) ...[
                          _QuotedReply(
                            reply: replyTo,
                            // สติกเกอร์ไม่มีพื้นสีของเรา — ใช้แบบพื้นกลางให้อ่านออก
                            isMine: isMine && sticker == null,
                            onTap: () {
                              final rid = int.tryParse('${replyTo['id']}');
                              if (rid != null) onReplyTap(rid);
                            },
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (hasImage) ...[
                          _ChatImage(url: imageUrl),
                          if (hasText) const SizedBox(height: 6),
                        ] else if (hasLocalImage) ...[
                          _LocalChatImage(path: localImagePath),
                          if (hasText) const SizedBox(height: 6),
                        ],
                        if (isDeleted)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block_rounded,
                                  size: 14,
                                  color: fg.withValues(alpha: 0.6)),
                              const SizedBox(width: 5),
                              Text(
                                'ข้อความนี้ถูกลบ',
                                style: appFont(
                                  fontSize: AppText.sizeBody,
                                  height: 1.4,
                                  color: fg.withValues(alpha: 0.6),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        else if (intro != null)
                          ChatIntroCard(
                            intro: intro,
                            name: author,
                            isMine: isMine,
                            onEdit: isMine ? onEditIntro : null,
                          )
                        else if (sticker != null)
                          ChatStickerImage(
                            url: sticker['url']?.toString() ?? '',
                            size: 132,
                            label: sticker['label']?.toString(),
                          )
                        else if (poll != null)
                          _PollCard(
                            poll: poll,
                            myUserId: myUserId,
                            canClose:
                                canModerate ||
                                (myUserId != null &&
                                    myUserId ==
                                        int.tryParse('${poll['created_by_id']}')),
                            onVote: onVote,
                            onClose: onClosePoll,
                            travellers: travellers,
                          )
                        else if (lostItem != null)
                          ChatLostItemCard(
                            item: lostItem,
                            myUserId: myUserId,
                            onOpen: onOpenLostItems,
                          )
                        else if (collection != null)
                          ChatCollectionCard(
                            collection: collection,
                            myUserId: myUserId,
                            canManage: canModerate,
                            onPay: () => onPayCollection(collection),
                            onOpenList: () => onOpenCollection(collection),
                          )
                        else if (trail != null)
                          ChatTrailCheckCard(
                            trail: trail,
                            myUserId: myUserId,
                            canManage: canModerate,
                            onReach: (ids, index) =>
                                tools.onTrailReach(trail, ids, index),
                            onHelp: () => tools.onTrailHelp(trail),
                            onCancelHelp: () => tools.onTrailCancelHelp(trail),
                            onOpenBoard: () => tools.onOpenTrail(trail),
                          )
                        else if (wellness != null)
                          ChatWellnessCard(
                            wellness: wellness,
                            canManage: canModerate,
                            onAnswer: (a) => tools.onWellnessAnswer(wellness, a),
                            onOpenAnswer: (status) =>
                                tools.onOpenWellnessAnswer(wellness, status),
                            onOpenStaff: () =>
                                tools.onOpenWellnessStaff(wellness),
                          )
                        else if (dropoff != null)
                          ChatDropoffCard(
                            dropoff: dropoff,
                            canManage: canModerate,
                            onChoose: () => tools.onChooseDropoff(dropoff),
                            onOpenStaff: () => tools.onOpenDropoffStaff(dropoff),
                          )
                        else if (porter != null)
                          ChatPorterCard(
                            porter: porter,
                            myUserId: myUserId,
                            canManage: canModerate,
                            onRegister: () => tools.onRegisterPorter(porter),
                            onOpen: () => tools.onOpenPorter(porter),
                          )
                        else if (restStop != null)
                          ChatRestStopCard(
                            stop: restStop,
                            myUserId: myUserId,
                            canManage: canModerate,
                            onBoard: (ids, boarded) =>
                                onBoardRestStop(restStop, ids, boarded),
                            onOpenRoll: () => onOpenRestRoll(restStop),
                          )
                        else if (foodRound != null)
                          ChatFoodRoundCard(
                            round: foodRound,
                            myUserId: myUserId,
                            onOrder: () => onOrderFood(foodRound),
                            onOpenSummary: () => onOpenFoodSummary(foodRound),
                            onPay: () => onPayFood(foodRound),
                          )
                        else if (hasVoice)
                          ChatVoiceBubble(
                            url: audioUrl.isEmpty ? null : audioUrl,
                            localPath: audioUrl.isEmpty ? localAudioPath : null,
                            durationMs: int.tryParse(
                                  '${message['audio_duration_ms']}',
                                ) ??
                                0,
                            foreground: fg,
                          )
                        else if (hasText)
                          _MessageText(
                            text: body,
                            color: fg,
                            isEdited: isEdited,
                          ),
                      ],
                    ),
                  ),
                ),
                if (ack != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.only(left: isMine ? 0 : 4, right: isMine ? 4 : 0),
                    child: ChatAckBar(
                      ack: ack,
                      canManage: canModerate,
                      busy: ackBusy,
                      onAck: onAck,
                      onOpenDetail: onOpenAck,
                    ),
                  ),
                ],
                if (reactions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _ReactionChips(
                    reactions: reactions,
                    myUserId: myUserId,
                    onTap: onReactionTap,
                  ),
                ],
                if (isMine && failed) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onRetry,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 13,
                            color: AppTheme.errorColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ส่งไม่สำเร็จ · แตะเพื่อลองใหม่',
                            style: appFont(
                              fontSize: AppText.sizeMicro,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (isMine && pending) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: AppTheme.mutedText(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'กำลังส่ง…',
                          style: appFont(
                            fontSize: AppText.sizeMicro,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (showTimestamp) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(
                      left: isMine ? 0 : 12,
                      right: isMine ? 4 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LINE-style read receipt sits before the timestamp on
                        // the sender's own messages.
                        if (isMine && readByCount > 0) ...[
                          Icon(
                            Icons.done_all_rounded,
                            size: 12,
                            color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'อ่าน $readByCount',
                            style: appFont(
                              fontSize: AppText.sizeMicro,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _timeText(),
                          style: appFont(
                            fontSize: AppText.sizeMicro,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Deleted notices and in-flight/failed optimistic sends aren't repliable,
    // so skip the swipe affordance there.
    if (isDeleted || pending || failed) return content;

    // Swipe-right to reply (LINE/iMessage style). confirmDismiss returns false
    // so the bubble springs back instead of actually dismissing.
    return Dismissible(
      key: ValueKey('swipe-${message['id'] ?? message['client_token']}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.25},
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        onSwipeReply();
        return false;
      },
      background: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.reply_rounded,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ),
      child: content,
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final String name;

  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      color: AppTheme.primaryColor.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: appFont(
          fontSize: AppText.sizeBody,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
        ),
      ),
    );
    final avatar = ClipOval(
      child: SizedBox(
        width: 34,
        height: 34,
        child: url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
    // Only open the viewer when there is a real photo to enlarge — tapping
    // the initial-letter placeholder has nothing useful to show.
    if (url.isEmpty) return avatar;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ImageViewer(url: url, title: name),
          ),
        );
      },
      child: avatar,
    );
  }
}

class _ChatImage extends StatelessWidget {
  final String url;

  const _ChatImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _ImageViewer(url: url)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              width: 200,
              height: 150,
              color: AppTheme.subtleSurface(context),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, _, _) => Container(
              width: 200,
              height: 120,
              color: AppTheme.subtleSurface(context),
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_rounded,
                  color: AppTheme.mutedText(context)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Local file preview shown inside an optimistic image bubble before the server
/// returns the hosted URL. Mirrors [_ChatImage]'s framing but reads from disk.
class _LocalChatImage extends StatelessWidget {
  final String path;

  const _LocalChatImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 200,
            height: 120,
            color: AppTheme.subtleSurface(context),
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_rounded,
                color: AppTheme.mutedText(context)),
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String url;
  final String? title;

  /// เปิดจากคลังรูปของห้อง — มีปุ่ม "ไปที่ข้อความ" (ปิดแล้วคืน true)
  final bool onGoToMessage;

  const _ImageViewer({required this.url, this.title, this.onGoToMessage = false});

  /// Downloads the photo to a temp file and opens the OS share sheet, where
  /// "Save Image" / "บันทึกรูปภาพ" writes it to the device gallery.
  Future<void> _saveOrShare(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) throw Exception('download failed');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/llk_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(resp.bodyBytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('บันทึกรูปไม่สำเร็จ ลองอีกครั้ง',
              style: appFont(fontWeight: FontWeight.w600)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Floating close button over the photo, iOS Photos style.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'ปิด',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (onGoToMessage)
            IconButton(
              icon: const Icon(Icons.forum_outlined),
              tooltip: 'ไปที่ข้อความ',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'บันทึก / แชร์',
            onPressed: () => _saveOrShare(context),
          ),
        ],
        title: title == null || title!.trim().isEmpty
            ? null
            : Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
      ),
      // Stack so tapping the surrounding black area dismisses, while
      // gestures on the image itself are absorbed by InteractiveViewer for
      // pan and pinch-zoom.
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the room roster and the assigned vehicle — opened from the
/// chat app bar. Mirrors LINE's "members" panel.
class _RoomInfoSheet extends StatelessWidget {
  final Map<String, dynamic>? vehicle;
  final List<Map<String, dynamic>> members;
  final int memberCount;
  final int scheduleId;
  final String tripTitle;
  final Map<String, dynamic>? weather;
  final List<Map<String, dynamic>> pickupPoints;
  final bool hasItinerary;

  const _RoomInfoSheet({
    required this.vehicle,
    required this.members,
    required this.memberCount,
    required this.scheduleId,
    required this.tripTitle,
    required this.weather,
    required this.pickupPoints,
    required this.hasItinerary,
  });

  bool get _hasAnyShortcut =>
      hasItinerary ||
      pickupPoints.isNotEmpty ||
      (weather?.isNotEmpty ?? false);

  void _openItinerary(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(
      builder: (_) => ScheduleItineraryScreen(
        scheduleId: scheduleId,
        tripTitle: tripTitle,
      ),
    ));
  }

  void _openPickups(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => _PickupPointsSheet(points: pickupPoints),
    );
  }

  void _openWeather(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_cloudy_rounded,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'อากาศวันเดินทาง',
                    style: appFont(
                      fontSize: AppText.sizeSubtitle,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              WeatherCard(weather: weather!, compact: false),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Staff first, then everyone else — staff are the trip leads.
    final sorted = [...members]..sort((a, b) {
      int rank(Map<String, dynamic> m) => m['role'] == 'staff' ? 0 : 1;
      return rank(a).compareTo(rank(b));
    });

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'สมาชิกในห้อง',
                    style: appFont(
                      fontSize: AppText.sizeSubtitle,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$memberCount คน',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  if (_hasAnyShortcut) ...[
                    Row(
                      children: [
                        if (hasItinerary)
                          Expanded(
                            child: _TripInfoAction(
                              icon: Icons.route_rounded,
                              label: 'กำหนดการ',
                              onTap: () => _openItinerary(context),
                            ),
                          ),
                        if (hasItinerary && pickupPoints.isNotEmpty)
                          const SizedBox(width: 10),
                        if (pickupPoints.isNotEmpty)
                          Expanded(
                            child: _TripInfoAction(
                              icon: Icons.pin_drop_rounded,
                              label: 'จุดรับ',
                              onTap: () => _openPickups(context),
                            ),
                          ),
                        if ((hasItinerary || pickupPoints.isNotEmpty) &&
                            (weather?.isNotEmpty ?? false))
                          const SizedBox(width: 10),
                        if (weather?.isNotEmpty ?? false)
                          Expanded(
                            child: _TripInfoAction(
                              icon: Icons.wb_cloudy_rounded,
                              label: 'อากาศ',
                              onTap: () => _openWeather(context),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (vehicle != null) ...[
                    _VehicleCard(vehicle: vehicle!),
                    const SizedBox(height: 14),
                  ],
                  for (final m in sorted) _MemberTile(member: m),
                  if (sorted.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'ยังไม่มีข้อมูลสมาชิก',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// เลือกระดับการแจ้งเตือนของห้อง — คืนค่าที่เลือก (ปิดชีตเฉย ๆ = null)
class _NotifyLevelSheet extends StatelessWidget {
  final ChatNotifyLevel current;

  /// วันที่ "เงียบไว้ก่อน" จะกลับมาแจ้งทุกข้อความ (เมื่อเลือกไว้และยังไม่ถึง)
  final DateTime? wakesOn;

  const _NotifyLevelSheet({required this.current, this.wakesOn});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text(
                'การแจ้งเตือนห้องนี้',
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'ข้อความที่มาติด ๆ กันจะรวมเป็นแจ้งเตือนเดียว · ประกาศจากทีมงาน แจ้งเตือนรถ และ SOS ยังส่งถึงคุณตามปกติ',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ),
            for (final level in ChatNotifyLevel.values)
              _NotifyLevelOption(
                level: level,
                selected: level == current,
                note: level == ChatNotifyLevel.untilTrip &&
                        level == current &&
                        wakesOn != null
                    ? 'กลับมาแจ้งทุกข้อความวันที่ ${thaiDateShort(wakesOn!)}'
                    : null,
                onTap: () => Navigator.of(context).pop(level),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotifyLevelOption extends StatelessWidget {
  final ChatNotifyLevel level;
  final bool selected;
  final String? note;
  final VoidCallback onTap;

  const _NotifyLevelOption({
    required this.level,
    required this.selected,
    required this.onTap,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppTheme.primaryColor : AppTheme.mutedText(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryColor.withValues(alpha: 0.5)
                    : AppTheme.mutedText(context).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(level.icon, size: 22, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.label,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        level.description,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                      if (note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          note!,
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat quick-action tile for the trip-info shortcuts row (กำหนดการ/จุดรับ/อากาศ).
class _TripInfoAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TripInfoAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppTheme.primaryColor),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing the round's pickup points with time, note and a map link.
class _PickupPointsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> points;

  const _PickupPointsSheet({required this.points});

  String _t(dynamic v) => v?.toString().trim() ?? '';

  Future<void> _openMap(BuildContext context, Map<String, dynamic> p) async {
    final mapUrl = _t(p['map_url']);
    final lat = p['latitude'];
    final lng = p['longitude'];
    final Uri? uri;
    if (mapUrl.isNotEmpty) {
      uri = Uri.tryParse(mapUrl);
    } else if (lat != null && lng != null) {
      uri = Uri.tryParse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    } else {
      uri = null;
    }
    final messenger = ScaffoldMessenger.of(context);
    // A dead tap on "จุดรับ" the morning of the trip is the worst time to leave
    // someone guessing whether the app heard them.
    void fail() => messenger.showSnackBar(
      const SnackBar(content: Text('เปิดแผนที่ไม่ได้ กรุณาลองใหม่')),
    );
    if (uri == null) {
      fail();
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) fail();
    } catch (_) {
      fail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop_rounded,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'จุดรับ-ส่ง',
                    style: appFont(
                      fontSize: AppText.sizeSubtitle,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: points.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = points[i];
                  final region = _t(p['region_label']);
                  final location = _t(p['pickup_location']);
                  final time = _t(p['pickup_time']);
                  final notes = _t(p['notes']);
                  final hasMap = _t(p['map_url']).isNotEmpty ||
                      (p['latitude'] != null && p['longitude'] != null);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.subtleSurface(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                region.isEmpty ? location : region,
                                style: appFont(
                                  fontSize: AppText.sizeBody,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.onSurface(context),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (time.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.schedule_rounded,
                                        size: 13,
                                        color: AppTheme.primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      time,
                                      style: appFont(
                                        fontSize: AppText.sizeCaption,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (region.isNotEmpty && location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            location,
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedText(context),
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            notes,
                            style: appFont(
                              fontSize: AppText.sizeLabel,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedText(context),
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (hasMap) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _openMap(context, p),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.map_rounded,
                                    size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 5),
                                Text(
                                  'เปิดแผนที่',
                                  style: appFont(
                                    fontSize: AppText.sizeLabel,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const _VehicleCard({required this.vehicle});

  String _t(dynamic v) => v?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final name = _t(vehicle['name']);
    final plate = _t(vehicle['license_plate']);
    final driverName = _t(vehicle['driver_name']);
    final driverPhone = _t(vehicle['driver_phone']);

    final meta = [
      if (_t(vehicle['type']).isNotEmpty) _t(vehicle['type']),
      if (plate.isNotEmpty) plate,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
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
                  name.isEmpty ? 'รถประจำรอบ' : name,
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                    letterSpacing: -0.1,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                if (driverName.isNotEmpty)
                  Text(
                    'คนขับ: $driverName',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
              ],
            ),
          ),
          if (driverPhone.isNotEmpty)
            IconButton(
              tooltip: 'โทรหาคนขับ',
              onPressed: () => launchUrl(Uri.parse('tel:$driverPhone')),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;

  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final name = (member['nickname']?.toString().isNotEmpty ?? false)
        ? member['nickname'].toString()
        : (member['name']?.toString() ?? 'ผู้ใช้');
    final role = member['role']?.toString() ?? 'customer';
    final tierBadge = TierBadge.fromUser(member, compact: true);
    final isMe = member['is_me'] == true;
    final avatarUrl = ApiConfig.mediaUrl(member['avatar_url']);
    // Staff/admin expose a phone so travellers can reach their guide (customer
    // numbers are never sent — see ChatController@room).
    final phone = member['phone']?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _Avatar(url: avatarUrl, name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(คุณ)',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RoleTag(role: role, alwaysShow: true),
          if (tierBadge != null) ...[const SizedBox(width: 4), tierBadge],
          if (phone.isNotEmpty && !isMe) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'โทรหา$name',
              visualDensity: VisualDensity.compact,
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_rounded,
                    color: AppTheme.primaryColor, size: 16),
              ),
            ),
          ],
          // ทีมงานบล็อกไม่ได้ (ฝั่งเซิร์ฟเวอร์ก็ปฏิเสธ) — ปุ่มจึงมีเฉพาะลูกค้าด้วยกัน
          if (!isMe && role == 'customer') _blockButton(context, name),
        ],
      ),
    );
  }

  Widget _blockButton(BuildContext context, String name) {
    final userId = int.tryParse('${member['id']}');
    if (userId == null) return const SizedBox.shrink();

    final isBlocked = member['is_blocked'] == true ||
        context.watch<AppProvider>().isBlocked(userId);

    return IconButton(
      tooltip: isBlocked ? 'เลิกบล็อก$name' : 'บล็อก$name',
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        final app = context.read<AppProvider>();
        if (isBlocked) {
          try {
            await app.unblockUser(userId);
            if (context.mounted) AppSnack.show(context, 'เลิกบล็อก$nameแล้ว');
          } catch (e) {
            if (context.mounted) {
              AppSnack.error(context, e.toString().replaceFirst('Exception: ', ''));
            }
          }
          return;
        }
        await ModerationSheet.confirmBlock(context, userId: userId, name: name);
      },
      icon: Icon(
        isBlocked ? Icons.block_flipped : Icons.block_rounded,
        size: 18,
        color: isBlocked
            ? AppTheme.errorColor
            : AppTheme.mutedText(context).withValues(alpha: 0.7),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  final String role;
  final bool alwaysShow;

  const _RoleTag({required this.role, this.alwaysShow = false});

  @override
  Widget build(BuildContext context) {
    // In message bubbles a customer tag is noise; in the roster we always tag.
    if (role == 'customer' && !alwaysShow) return const SizedBox.shrink();
    final color = role == 'admin'
        ? const Color(0xFFB45309)
        : role == 'staff'
            ? const Color(0xFF0E7490)
            : AppTheme.mutedText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        _MessageBubble._roleLabels[role] ?? role,
        style: appFont(
          fontSize: AppText.sizeMicro,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned announcement banner
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedBanner extends StatelessWidget {
  final Map<String, dynamic> pinned;
  final int index;
  final int count;
  final bool canModerate;
  final VoidCallback onTap;
  final VoidCallback? onUnpin;

  const _PinnedBanner({
    required this.pinned,
    required this.canModerate,
    required this.onTap,
    this.index = 0,
    this.count = 1,
    this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final body = pinned['body']?.toString().trim() ?? '';
    final hasImage = (pinned['image_url']?.toString().isNotEmpty ?? false);
    final senderName = pinned['sender_name']?.toString() ?? '';
    final preview = body.isNotEmpty
        ? body
        : (hasImage ? 'รูปภาพ' : 'ข้อความที่ปักหมุด');

    return Material(
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppTheme.border(context).withValues(alpha: 0.5),
              ),
              left: const BorderSide(color: AppTheme.primaryColor, width: 3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.push_pin_rounded,
                  size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        count > 1 ? 'ปักหมุด ${index + 1}/$count' : 'ปักหมุด',
                        if (senderName.isNotEmpty) senderName,
                      ].join(' · '),
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (canModerate && onUnpin != null)
                IconButton(
                  tooltip: 'ปลดหมุด',
                  visualDensity: VisualDensity.compact,
                  onPressed: onUnpin,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.mutedText(context)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quoted reply (inside a bubble)
// ─────────────────────────────────────────────────────────────────────────────

class _QuotedReply extends StatelessWidget {
  final Map<String, dynamic> reply;
  final bool isMine;
  final VoidCallback onTap;

  const _QuotedReply({
    required this.reply,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = reply['sender_name']?.toString() ?? 'ผู้ใช้';
    final body = reply['body']?.toString().trim() ?? '';
    final hasImage = reply['has_image'] == true;
    final preview = body.isNotEmpty
        ? body
        : (reply['has_audio'] == true
              ? '🎤 ข้อความเสียง'
              : (hasImage ? '📷 รูปภาพ' : ''));

    // On my (primary-colored) bubbles use translucent white; on others a tint.
    final barColor = isMine ? Colors.white.withValues(alpha: 0.8) : AppTheme.primaryColor;
    final bgColor = isMine
        ? Colors.white.withValues(alpha: 0.16)
        : AppTheme.primaryColor.withValues(alpha: 0.08);
    final textColor = isMine ? Colors.white : AppTheme.onSurface(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          border: Border(left: BorderSide(color: barColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w800,
                color: textColor.withValues(alpha: 0.9),
              ),
            ),
            if (preview.isNotEmpty)
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reaction chips (below a bubble)
// ─────────────────────────────────────────────────────────────────────────────

class _ReactionChips extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final int? myUserId;
  final ValueChanged<String> onTap;

  const _ReactionChips({
    required this.reactions,
    required this.myUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final r in reactions)
          _ReactionChip(
            emoji: r['emoji']?.toString() ?? '',
            count: int.tryParse('${r['count']}') ?? 0,
            mine: (r['user_ids'] as List? ?? const [])
                .map((e) => int.tryParse('$e'))
                .contains(myUserId),
            onTap: () => onTap(r['emoji']?.toString() ?? ''),
          ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = mine ? AppTheme.primaryColor : AppTheme.mutedText(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: mine
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: mine
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: AppText.sizeLabel)),
            if (count > 1) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reply preview bar (above the composer)
// ─────────────────────────────────────────────────────────────────────────────

class _ReplyPreviewBar extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onCancel;

  const _ReplyPreviewBar({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final user = message['user'] is Map
        ? Map<String, dynamic>.from(message['user'] as Map)
        : <String, dynamic>{};
    final name = message['is_mine'] == true
        ? 'ตัวคุณเอง'
        : ((user['nickname']?.toString().isNotEmpty ?? false)
            ? user['nickname'].toString()
            : (user['name']?.toString() ?? 'ผู้ใช้'));
    final body = message['body']?.toString().trim() ?? '';
    final hasImage = (message['image_url']?.toString().isNotEmpty ?? false);
    final hasAudio = (message['audio_url']?.toString().isNotEmpty ?? false) ||
        (message['_local_audio_path']?.toString().isNotEmpty ?? false);
    final preview = body.isNotEmpty
        ? body
        : (hasAudio ? '🎤 ข้อความเสียง' : (hasImage ? '📷 รูปภาพ' : ''));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        border: const Border(
          left: BorderSide(color: AppTheme.primaryColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded,
              size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ตอบกลับ $name',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ยกเลิก',
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: Icon(Icons.close_rounded,
                size: 18, color: AppTheme.mutedText(context)),
          ),
        ],
      ),
    );
  }
}

/// Banner above the composer while editing an existing message.
class _EditPreviewBar extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onCancel;

  const _EditPreviewBar({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final body = message['body']?.toString().trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        border: const Border(
          left: BorderSide(color: Color(0xFFD97706), width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'กำลังแก้ไขข้อความ',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD97706),
                  ),
                ),
                if (body.isNotEmpty)
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ยกเลิก',
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: Icon(Icons.close_rounded,
                size: 18, color: AppTheme.mutedText(context)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator + jump-to-latest + unread divider
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final String label;

  const _TypingIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.surface(context),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ชวนให้เงียบห้องไว้ก่อน — ห้องของรอบที่อีกนานกว่าจะเดินทาง (เกิน 14 วัน)
class _QuietSuggestBanner extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _QuietSuggestBanner({required this.onAccept, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        border: Border(bottom: BorderSide(color: AppTheme.border(context))),
      ),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, size: 18, color: AppTheme.mutedText(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ทริปนี้อีกนาน เงียบห้องไว้ก่อนไหม? แจ้งเฉพาะทีมงาน แล้วเปิดเองตอน 3 วันก่อนเดินทาง',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          TextButton(
            onPressed: onAccept,
            child: Text(
              'เงียบไว้ก่อน',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            tooltip: 'ไม่ต้อง',
            icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.mutedText(context)),
          ),
        ],
      ),
    );
  }
}

class _JumpToLatestButton extends StatelessWidget {
  final int newCount;
  final VoidCallback onTap;

  const _JumpToLatestButton({required this.newCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      shape: const CircleBorder(),
      color: AppTheme.surface(context),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Badge(
            isLabelVisible: newCount > 0,
            label: Text(newCount > 99 ? '99+' : '$newCount'),
            backgroundColor: AppTheme.primaryColor,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.onSurface(context),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating "you were mentioned" pill (LINE-style). Tap to hop to the oldest
/// unread @mention of the current user.
class _MentionJumpChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MentionJumpChip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.alternate_email_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                count > 1 ? 'ถูกแท็ก $count' : 'ถูกแท็ก',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Transient floating notice shown when a member opens the room — fades in at
/// the top of the message area and auto-clears after a few seconds. Crew get a
/// distinct colour and icon: "ทีมงานอยู่ในห้องแล้ว" is the one arrival that
/// changes what a traveller does next (ask now, get an answer now).
class _JoinedBanner extends StatelessWidget {
  final String label;
  final bool isStaff;

  const _JoinedBanner({required this.label, this.isStaff = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 220),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            // Cyan-700 matches the staff tag used on bubbles and the roster.
            color: (isStaff ? const Color(0xFF0E7490) : AppTheme.primaryColor)
                .withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStaff
                    ? Icons.support_agent_rounded
                    : Icons.waving_hand_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'ข้อความใหม่',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// สตาฟ/ทีมงาน กับ คนขับ แยกกลุ่มกันในชีตรายชื่อ เพราะเป็นคนละหน้าที่
enum _ContactKind { staff, driver }

/// คนที่กดโทรได้จากแถบด้านบนแชท (สตาฟ / ทีมงาน / คนขับ)
class _ChatContact {
  final String name;
  final String roleLabel;
  final String phone;
  final String avatarUrl;
  final _ContactKind kind;

  const _ChatContact({
    required this.name,
    required this.roleLabel,
    required this.phone,
    required this.avatarUrl,
    required this.kind,
  });
}

/// โทรหาผู้ติดต่อ — ใช้ร่วมกันระหว่างแถบด้านบนและชีตรายชื่อ
Future<void> _callContact(BuildContext context, _ChatContact contact) async {
  HapticFeedback.selectionClick();
  final uri = Uri.parse('tel:${contact.phone}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('โทรออกไม่ได้ เบอร์ ${contact.phone}')),
    );
  }
}

/// สีและไอคอนกำกับบทบาท — สตาฟกับคนขับทำคนละหน้าที่ คนที่กำลังรีบโทรต้องแยก
/// ออกจากกันได้ตั้งแต่ยังไม่ทันอ่านชื่อ (สตาฟ = สีแบรนด์, คนขับ = สีน้ำเงิน)
IconData _contactKindIcon(_ContactKind kind) =>
    kind == _ContactKind.staff
    ? Icons.verified_user_rounded
    : Icons.directions_bus_rounded;

Color _contactKindColor(_ContactKind kind) => kind == _ContactKind.staff
    ? AppTheme.primaryColor
    : AppTheme.infoColor;

/// รูปผู้ติดต่อพร้อมตราบทบาทมุมล่างขวา
class _ContactAvatarBadge extends StatelessWidget {
  final _ChatContact contact;
  final double size;

  const _ContactAvatarBadge({required this.contact, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final tint = _contactKindColor(contact.kind);
    final initial = contact.name.trim().isEmpty
        ? '?'
        : contact.name.trim()[0].toUpperCase();
    final fallback = Container(
      alignment: Alignment.center,
      color: tint.withValues(alpha: 0.14),
      child: Text(
        initial,
        style: appFont(
          fontSize: AppText.sizeSubtitle,
          fontWeight: FontWeight.w800,
          color: tint,
        ),
      ),
    );
    final badge = size * 0.42;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: contact.avatarUrl.isEmpty
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: contact.avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => fallback,
                      errorWidget: (_, _, _) => fallback,
                    ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badge,
              height: badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surface(context), width: 2),
              ),
              child: Icon(
                _contactKindIcon(contact.kind),
                size: badge * 0.56,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ชิปบอกบทบาท — สั้น อ่านจบในตาเดียว ใช้ทั้งบนแถบและในชีต
class _ContactRoleChip extends StatelessWidget {
  final _ChatContact contact;

  const _ContactRoleChip({required this.contact});

  @override
  Widget build(BuildContext context) {
    final tint = _contactKindColor(contact.kind);
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        contact.roleLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: appFont(
          fontSize: AppText.sizeMicro,
          fontWeight: FontWeight.w800,
          color: isDark ? tint : Color.lerp(tint, Colors.black, 0.20)!,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// ปุ่มโทรวงกลมทึบ — พื้นที่แตะ 44 ตามขนาดขั้นต่ำที่นิ้วโป้งพลาดยาก
class _ContactCallButton extends StatelessWidget {
  final _ChatContact contact;
  final VoidCallback onCall;
  final double size;

  const _ContactCallButton({
    required this.contact,
    required this.onCall,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onCall,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: 'โทรหา${contact.name}',
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.phone_rounded,
              color: Colors.white,
              size: size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}

/// แถบติดต่อที่ปักอยู่ใต้ AppBar ตลอดเวลา
///
/// คนเดียว = การ์ดเต็มความกว้าง กดโทรได้จากตรงนั้นเลย
/// หลายคน = แถวสรุปแถวเดียว (รูปซ้อนกัน + จำนวนสตาฟ/คนขับ) แตะแล้วเปิดชีตรายชื่อ
/// ทั้งหมด — ไม่ใช้เลื่อนแนวนอน เพราะคนที่ต้องโทรหาอาจซ่อนอยู่นอกจอโดยไม่รู้ตัว
///
/// แถบนี้แย่งพื้นที่จากข้อความในห้อง จึงยอมสูงได้แค่การ์ดใบเดียว: ทุกอย่างที่
/// เพิ่มเข้ามาต้องอยู่ในแถวเดิม ไม่ใช่แถวใหม่
class _ContactBar extends StatelessWidget {
  final List<_ChatContact> contacts;

  const _ContactBar({required this.contacts});

  void _openSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => _ContactSheet(contacts: contacts),
    );
  }

  /// "สตาฟ 2 คน · คนขับ 1 คน" — บอกองค์ประกอบทีมให้ครบตั้งแต่ยังไม่เปิดชีต
  String _summary() {
    final staff = contacts.where((c) => c.kind == _ContactKind.staff).length;
    final drivers = contacts.length - staff;
    final parts = <String>[
      if (staff > 0) 'สตาฟ $staff คน',
      if (drivers > 0) 'คนขับ $drivers คน',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final single = contacts.length == 1 ? contacts.first : null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.border(context), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Material(
        color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: single != null
              ? () => _callContact(context, single)
              : () => _openSheet(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(
                  alpha: isDark ? 0.28 : 0.18,
                ),
              ),
            ),
            child: single != null
                ? _ContactCard(
                    contact: single,
                    onCall: () => _callContact(context, single),
                  )
                : Row(
                    children: [
                      _ContactAvatarStack(contacts: contacts),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ทีมงานประจำรอบนี้',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontSize: AppText.sizeBody,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface(context),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _summary(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontSize: AppText.sizeCaption,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mutedText(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ปุ่มนี้ไม่ได้โทรทันที (ยังไม่รู้ว่าจะโทรหาใคร) คำบนปุ่ม
                      // จึงต้องเป็น "ดูเบอร์" ไม่ใช่ "โทร"
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ดูเบอร์',
                              style: appFont(
                                fontSize: AppText.sizeLabel,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// รูปสตาฟ/คนขับซ้อนกันแบบทีม — เกิน 3 คนตัดเป็น "+N" ไม่ให้แถวยืด
class _ContactAvatarStack extends StatelessWidget {
  final List<_ChatContact> contacts;

  const _ContactAvatarStack({required this.contacts});

  static const double _size = 32;
  static const double _overlap = 21;

  @override
  Widget build(BuildContext context) {
    final shown = contacts.take(3).toList();
    final extra = contacts.length - shown.length;
    final slots = shown.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      width: _overlap * (slots - 1) + _size,
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * _overlap,
              child: _StackedAvatar(contact: shown[i]),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * _overlap,
              child: Container(
                width: _size,
                height: _size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surface(context), width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// รูปเดี่ยวในกองซ้อน — ขอบสีพื้นหลังคั่นให้เห็นว่าเป็นคนละคน
class _StackedAvatar extends StatelessWidget {
  final _ChatContact contact;

  const _StackedAvatar({required this.contact});

  @override
  Widget build(BuildContext context) {
    // สีตามบทบาท — ในกองซ้อนที่ไม่มีชื่อกำกับ สีคือสิ่งเดียวที่บอกว่าคนไหน
    // เป็นคนขับ (เทียบกับตราบทบาทบนการ์ดคนเดียวและในชีต)
    final tint = _contactKindColor(contact.kind);
    final initial = contact.name.trim().isEmpty
        ? '?'
        : contact.name.trim()[0].toUpperCase();
    final fallback = Container(
      alignment: Alignment.center,
      color: tint.withValues(alpha: 0.14),
      child: Text(
        initial,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );

    return Container(
      width: _ContactAvatarStack._size,
      height: _ContactAvatarStack._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.surface(context), width: 2),
      ),
      child: ClipOval(
        child: contact.avatarUrl.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: contact.avatarUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// ชีตรายชื่อคนที่โทรหาได้ — แยกหัวข้อสตาฟ/คนขับ เห็นครบทุกคนในหน้าเดียว
class _ContactSheet extends StatelessWidget {
  final List<_ChatContact> contacts;

  const _ContactSheet({required this.contacts});

  @override
  Widget build(BuildContext context) {
    final staff = contacts
        .where((c) => c.kind == _ContactKind.staff)
        .toList();
    final drivers = contacts
        .where((c) => c.kind == _ContactKind.driver)
        .toList();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.mutedText(context).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'เบอร์ติดต่อในทริป',
                    style: appFont(
                      fontSize: AppText.sizeSubtitle,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${contacts.length} คน',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  if (staff.isNotEmpty) ...[
                    const _ContactGroupLabel(label: 'สตาฟและทีมงาน'),
                    for (final c in staff) _ContactSheetTile(contact: c),
                  ],
                  if (drivers.isNotEmpty) ...[
                    if (staff.isNotEmpty) const SizedBox(height: 14),
                    const _ContactGroupLabel(label: 'คนขับรถ'),
                    for (final c in drivers) _ContactSheetTile(contact: c),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactGroupLabel extends StatelessWidget {
  final String label;

  const _ContactGroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}

/// หนึ่งคนในชีต — แตะที่แถวหรือปุ่มก็โทรออกเหมือนกัน
class _ContactSheetTile extends StatelessWidget {
  final _ChatContact contact;

  const _ContactSheetTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: () => _callContact(context, contact),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                _ContactAvatarBadge(contact: contact, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _ContactRoleChip(contact: contact),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_in_talk_rounded,
                            size: 12,
                            color: AppTheme.mutedText(context),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              contact.phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontSize: AppText.sizeCaption,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.mutedText(context),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ContactCallButton(
                  contact: contact,
                  onCall: () => _callContact(context, contact),
                  size: 42,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// การ์ดผู้ติดต่อคนเดียว — ชื่อ + บทบาท + เบอร์ ครบในแถวเดียว
///
/// แตะที่การ์ดทั้งใบก็โทรออกได้เหมือนกดปุ่ม (แถบข้างบนส่ง onTap มาให้แล้ว)
/// ปุ่มวงกลมยังอยู่เพราะเป็นสิ่งที่ตาไปหยุดก่อน และบอกว่าการ์ดนี้ "กดได้"
class _ContactCard extends StatelessWidget {
  final _ChatContact contact;
  final VoidCallback onCall;

  const _ContactCard({required this.contact, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ContactAvatarBadge(contact: contact),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: _ContactRoleChip(contact: contact)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.phone_in_talk_rounded,
                    size: 12,
                    color: AppTheme.mutedText(context),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      contact.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mutedText(context),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _ContactCallButton(contact: contact, onCall: onCall),
      ],
    );
  }
}
