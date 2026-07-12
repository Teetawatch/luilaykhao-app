import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/weather_card.dart';
import 'schedule_itinerary_screen.dart';

/// Group chat room for a trip schedule. Members are the customers booked on
/// the schedule, the assigned staff, and admins. Real-time via Reverb.
class ChatScreen extends StatefulWidget {
  final int scheduleId;
  final String? title;

  const ChatScreen({super.key, required this.scheduleId, this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
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

  final List<Map<String, dynamic>> _messages = [];
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

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

  // Pinned announcement, kept in sync with room load + chat.pinned broadcasts.
  Map<String, dynamic>? _pinned;

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

  // Transient "X เข้าห้องแชท" notices — userId → (name, expiry), swept like typing.
  final Map<int, ({String name, DateTime until})> _joined = {};
  Timer? _joinedSweeper;

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

  bool _canModerate = false;
  List<String> _reactionEmojis = const ['👍', '❤️', '😂', '😮', '😢', '🙏'];
  int? _myUserId;

  // Per-message keys so reply-quote and mention jumps can precisely anchor the
  // target via Scrollable.ensureVisible instead of a scroll-ratio guess.
  final Map<int, GlobalKey> _messageKeys = {};
  // Message briefly highlighted after a jump, to confirm where we landed.
  int _highlightId = 0;
  Timer? _highlightTimer;

  VoidCallback? _signalsDisposer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _typingSweeper?.cancel();
    _joinedSweeper?.cancel();
    _highlightTimer?.cancel();
    _disposer?.call();
    _signalsDisposer?.call();
    _input.dispose();
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
    } else {
      _stopPolling();
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
    );
    // Let the rest of the room know we've entered, so they see a brief notice.
    app.sendChatJoin(widget.scheduleId);
    _startPolling();
  }

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
      _scrollToBottom();
      _markRead();
      _refreshRoom(force: true);
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
    try {
      final room = await context.read<AppProvider>().chatRoom(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _room = room;
        _pinned = room['pinned_message'] is Map
            ? Map<String, dynamic>.from(room['pinned_message'] as Map)
            : null;
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
    final fresh = incoming.where((m) {
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
    _markRead();
    if (wasAtBottom) _scrollToBottom();
  }

  void _markRead() {
    if (!_isForeground) return;
    context.read<AppProvider>().markChatRead(widget.scheduleId);
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
          _editing = null;
          _input.clear();
          _mentionPicks.clear();
          _mentionQuery = null;
          _sending = false;
        });
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
    // Optimistically render the message right away, then dispatch. On failure it
    // stays put with a "tap to retry" affordance instead of vanishing — key for
    // flaky connections on the bus/mountain.
    setState(() {
      _sending = false;
      _input.clear();
      _replyingTo = null;
      _mentionPicks.clear();
      _mentionQuery = null;
    });
    _enqueueText(
      text,
      replyId: replyId,
      mentions: mentions,
      replyPreview: replyPreview,
    );
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
    };
  }

  /// Inserts an optimistic text message and kicks off its dispatch.
  void _enqueueText(
    String text, {
    int? replyId,
    List<int> mentions = const [],
    Map<String, dynamic>? replyPreview,
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
      final replyId = int.tryParse('${opt['_reply_to_id']}');
      if (imagePath != null && imagePath.isNotEmpty) {
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
        );
      }
      if (!mounted) return;
      _replaceOptimistic(token, server);
      _refreshRoom();
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
                color: Color(0xFFDC2626),
              ),
              title: Text(
                'แชร์ตำแหน่งของฉัน',
                style: appFont(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'ส่งจุดที่คุณอยู่ตอนนี้เป็นลิงก์แผนที่',
                style: appFont(
                  fontSize: 12,
                  color: AppTheme.mutedText(context),
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareLocation();
              },
            ),
            const SizedBox(height: 8),
          ],
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
    final name = data['name']?.toString() ?? 'สมาชิก';
    _joined[userId] = (
      name: name,
      until: DateTime.now().add(const Duration(seconds: 4)),
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
    final names = _joined.values.map((v) => v.name).toList();
    if (names.length == 1) return '${names.first} เข้าห้องแชท';
    if (names.length == 2) return '${names[0]} และ ${names[1]} เข้าห้องแชท';
    return '${names.length} คนเข้าห้องแชท';
  }

  void _onReactionSignal(Map<String, dynamic> data) {
    final messageId = int.tryParse('${data['message_id']}');
    if (messageId == null) return;
    final reactions = data['reactions'] as List? ?? const [];
    final idx = _messages.indexWhere((m) => int.tryParse('${m['id']}') == messageId);
    if (idx == -1) return;
    setState(() => _messages[idx]['reactions'] = reactions);
  }

  void _onPinnedSignal(Map<String, dynamic> data) {
    final msg = data['message'];
    setState(() {
      _pinned = msg is Map ? Map<String, dynamic>.from(msg) : null;
    });
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
      _editing = null;
      _input.clear();
      _mentionPicks.clear();
      _mentionQuery = null;
    });
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final id = int.tryParse('${message['id']}');
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ลบข้อความ', style: appFont(fontWeight: FontWeight.w800)),
        content: Text('ต้องการลบข้อความนี้ใช่ไหม? การลบไม่สามารถย้อนกลับได้',
            style: appFont()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: appFont(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ลบ', style: appFont(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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

  Future<void> _pinMessage(Map<String, dynamic> message) async {
    final id = int.tryParse('${message['id']}');
    if (id == null) return;
    try {
      final pinned = await context
          .read<AppProvider>()
          .pinChatMessage(widget.scheduleId, id);
      if (!mounted) return;
      setState(() => _pinned = pinned);
      _toast('ปักหมุดข้อความแล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  Future<void> _unpinMessage() async {
    final id = int.tryParse('${_pinned?['id']}');
    if (id == null) return;
    try {
      await context.read<AppProvider>().unpinChatMessage(widget.scheduleId, id);
      if (!mounted) return;
      setState(() => _pinned = null);
      _toast('ปลดหมุดข้อความแล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: appFont(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  GlobalKey _keyFor(int messageId) =>
      _messageKeys.putIfAbsent(messageId, () => GlobalKey());

  /// Scrolls to a message already loaded in the list (e.g. tapping a reply
  /// quote or the mention chip). Anchors precisely with [Scrollable.ensureVisible]
  /// when the target widget is built; otherwise approximates the jump first and
  /// anchors on the next frame once the target lays out.
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
    if (role == 'system' || message['is_deleted'] == true) return;
    // Optimistic messages (still sending / failed) aren't actionable yet.
    if (message['_pending'] == true || message['_failed'] == true) return;
    HapticFeedback.mediumImpact();
    final body = message['body']?.toString() ?? '';
    final messageId = int.tryParse('${message['id']}') ?? 0;
    final isMine = message['is_mine'] == true;
    final hasImage = (message['image_url']?.toString() ?? '').isNotEmpty;
    final canEdit = isMine && body.isNotEmpty && !hasImage;
    final canDelete = isMine || _canModerate;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Quick emoji reaction row
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
                        child: Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
            ),
            Divider(color: AppTheme.border(context).withValues(alpha: 0.5)),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text('ตอบกลับ',
                  style: appFont(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _startReply(message);
              },
            ),
            if (body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text('คัดลอก',
                    style: appFont(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _copyMessage(body);
                },
              ),
            if (_canModerate) ...[
              if (int.tryParse('${_pinned?['id']}') == messageId)
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined),
                  title: Text('ปลดหมุด',
                      style: appFont(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _unpinMessage();
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
            const SizedBox(height: 8),
          ],
        ),
      ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
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
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                _subtitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),
        actions: [
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
          if (_pinned != null)
            _PinnedBanner(
              pinned: _pinned!,
              canModerate: _canModerate,
              onTap: () {
                final id = int.tryParse('${_pinned?['id']}');
                if (id != null) _scrollToMessage(id);
              },
              onUnpin: _canModerate ? _unpinMessage : null,
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
                    child: Center(child: _JoinedBanner(label: _joinedLabel()!)),
                  ),
              ],
            ),
          ),
          if (_typingLabel() != null) _TypingIndicator(label: _typingLabel()!),
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
                  fontSize: 13,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'ลองอีกครั้ง',
                  style: appFont(
                    fontSize: 13.5,
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
                  borderRadius: BorderRadius.circular(20),
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
                  fontSize: 15,
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
                  fontSize: 13.5,
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
        items.add(_SystemMessage(message: m));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      fontSize: 13.5,
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
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(999),
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
                            fontSize: 12,
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
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                // Emerald-tinted pill so each name stands out clearly against
                // the strip and reads as a tappable mention.
                color: AppTheme.primaryColor
                    .withValues(alpha: isDark ? 0.24 : 0.10),
                borderRadius: BorderRadius.circular(999),
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
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border(
            top: BorderSide(
              color: AppTheme.border(context).withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mentionQuery != null) _buildMentionBar(),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  hintStyle: appFont(
                    color: AppTheme.mutedText(context),
                    fontSize: 15,
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
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _label(),
            style: appFont(
              fontSize: 11.5,
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

/// Centered notice (role == system) — e.g. "เจ้าหน้าที่เข้าร่วมแชท".
class _SystemMessage extends StatelessWidget {
  final Map<String, dynamic> message;

  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final body = message['body']?.toString() ?? '';
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
              letterSpacing: -0.1,
            ),
          ),
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
          fontSize: 11,
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
        fontSize: 15,
        height: 1.4,
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

    final isDeleted = message['is_deleted'] == true;
    final isEdited = message['edited_at'] != null;
    final body = message['body']?.toString() ?? '';
    final imageUrl = isDeleted ? '' : ApiConfig.mediaUrl(message['image_url']);
    // A locally-picked image shown while an optimistic send is in flight (before
    // the server returns its hosted URL).
    final localImagePath =
        isDeleted ? '' : (message['_local_image_path']?.toString() ?? '');
    final hasText = !isDeleted && body.isNotEmpty;
    final hasImage = imageUrl.isNotEmpty;
    final hasLocalImage = imageUrl.isEmpty && localImagePath.isNotEmpty;

    final replyTo = message['reply_to'] is Map
        ? Map<String, dynamic>.from(message['reply_to'] as Map)
        : null;
    final reactions = (message['reactions'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final isDark = AppTheme.isDark(context);
    final bg = isMine
        ? AppTheme.primaryColor
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF1F3F4));
    final fg = isMine ? Colors.white : AppTheme.onSurface(context);

    // iMessage-style asymmetric corners: the "tail" corner (bottom on the
    // sender's side) tightens on the last bubble of a group so the cluster
    // reads as a single utterance.
    const r = Radius.circular(18);
    const rTight = Radius.circular(6);
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
      padding: EdgeInsets.only(top: isFirstInGroup ? 8 : 2, bottom: 0),
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
              maxWidth: MediaQuery.sizeOf(context).width * 0.74,
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showAuthor && !isMine) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            author,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface(context),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _RoleTag(role: role),
                      ],
                    ),
                  ),
                ],
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    padding: (hasImage || hasLocalImage) && !hasText
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: shape,
                      // Outline the bubble when this message tags me (LINE-style
                      // mention highlight) or when we just jumped to it.
                      border: (mentionsMe && !isMine) || highlight
                          ? Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.9),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (replyTo != null) ...[
                          _QuotedReply(
                            reply: replyTo,
                            isMine: isMine,
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
                                  fontSize: 14,
                                  height: 1.4,
                                  color: fg.withValues(alpha: 0.6),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                if (reactions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _ReactionChips(
                    reactions: reactions,
                    myUserId: myUserId,
                    onTap: onReactionTap,
                  ),
                ],
                if (isMine && failed) ...[
                  const SizedBox(height: 3),
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
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (isMine && pending) ...[
                  const SizedBox(height: 3),
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (showTimestamp) ...[
                  const SizedBox(height: 3),
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
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _timeText(),
                          style: appFont(
                            fontSize: 10.5,
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
          fontSize: 13.5,
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
        borderRadius: BorderRadius.circular(12),
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
      borderRadius: BorderRadius.circular(12),
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

  const _ImageViewer({required this.url, this.title});

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
                  fontSize: 15,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PickupPointsSheet(points: pickupPoints),
    );
  }

  void _openWeather(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      fontSize: 16,
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
                borderRadius: BorderRadius.circular(999),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$memberCount คน',
                    style: appFont(
                      fontSize: 13,
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
                            fontSize: 13,
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                  fontSize: 12.5,
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

  Future<void> _openMap(Map<String, dynamic> p) async {
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
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
                borderRadius: BorderRadius.circular(999),
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
                      fontSize: 16,
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
                      borderRadius: BorderRadius.circular(14),
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
                                  fontSize: 14.5,
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
                                  borderRadius: BorderRadius.circular(999),
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
                                        fontSize: 12,
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
                              fontSize: 13,
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
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedText(context),
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (hasMap) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _openMap(p),
                            borderRadius: BorderRadius.circular(999),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.map_rounded,
                                    size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 5),
                                Text(
                                  'เปิดแผนที่',
                                  style: appFont(
                                    fontSize: 12.5,
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
        borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                    letterSpacing: -0.1,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                if (driverName.isNotEmpty)
                  Text(
                    'คนขับ: $driverName',
                    style: appFont(
                      fontSize: 12.5,
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
                      fontSize: 14.5,
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
                      fontSize: 12,
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
        ],
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _MessageBubble._roleLabels[role] ?? role,
        style: appFont(
          fontSize: 10,
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
  final bool canModerate;
  final VoidCallback onTap;
  final VoidCallback? onUnpin;

  const _PinnedBanner({
    required this.pinned,
    required this.canModerate,
    required this.onTap,
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
                      senderName.isEmpty ? 'ปักหมุด' : 'ปักหมุด · $senderName',
                      style: appFont(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: 13,
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
    final preview = body.isNotEmpty ? body : (hasImage ? '📷 รูปภาพ' : '');

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
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: barColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: appFont(
                fontSize: 11.5,
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
                  fontSize: 12.5,
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
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: mine
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            if (count > 1) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: appFont(
                  fontSize: 11.5,
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
    final preview = body.isNotEmpty ? body : (hasImage ? '📷 รูปภาพ' : '');

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
                    fontSize: 11.5,
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
                      fontSize: 12.5,
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
                    fontSize: 11.5,
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
                      fontSize: 12.5,
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
                fontSize: 12,
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
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
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
                  fontSize: 12.5,
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
/// the top of the message area and auto-clears after a few seconds.
class _JoinedBanner extends StatelessWidget {
  final String label;

  const _JoinedBanner({required this.label});

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
            color: AppTheme.primaryColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.waving_hand_rounded,
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
                    fontSize: 12,
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
                fontSize: 11.5,
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
