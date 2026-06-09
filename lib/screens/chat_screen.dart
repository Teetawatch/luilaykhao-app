import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

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

  // Unread divider: messages with id beyond this (and not mine) are "new" since
  // we opened. Captured once from our own read marker on first room load.
  int _unreadBoundaryId = 0;
  bool _unreadBoundaryLocked = false;

  // Jump-to-latest affordance.
  bool _showJumpButton = false;
  int _newWhileAway = 0;

  bool _canModerate = false;
  List<String> _reactionEmojis = const ['👍', '❤️', '😂', '😮', '😢', '🙏'];
  int? _myUserId;

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
      onReaction: _onReactionSignal,
      onPinned: _onPinnedSignal,
      onUpdated: _onMessageUpdated,
    );
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
    try {
      final message = await app.sendChatMessage(
        widget.scheduleId,
        text,
        replyToId: replyId,
        mentions: mentions,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _input.clear();
        _replyingTo = null;
        _mentionPicks.clear();
        _mentionQuery = null;
        _sending = false;
      });
      _scrollToBottom();
      _refreshRoom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  /// Mention ids still relevant to the final text — keep a pick only if its
  /// "@label" survived in the message the user actually sent.
  List<int> _activeMentionIds(String text) {
    final ids = <int>[];
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
    if (_sending) return;
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

    setState(() => _sending = true);
    final app = context.read<AppProvider>();
    final replyId = _replyingTo == null
        ? null
        : int.tryParse('${_replyingTo!['id']}');
    try {
      final message = await app.sendChatImage(
        widget.scheduleId,
        picked.path,
        replyToId: replyId,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _replyingTo = null;
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w600),
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
                style: GoogleFonts.anuphan(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSendImage(ImageSource.gallery);
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
        title: Text('ลบข้อความ', style: GoogleFonts.anuphan(fontWeight: FontWeight.w800)),
        content: Text('ต้องการลบข้อความนี้ใช่ไหม? การลบไม่สามารถย้อนกลับได้',
            style: GoogleFonts.anuphan()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ลบ', style: GoogleFonts.anuphan(fontWeight: FontWeight.w700)),
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
        content: Text(text, style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Scrolls to a message already loaded in the list (e.g. tapping a reply
  /// quote). No-op if it's not in the current window.
  void _scrollToMessage(int messageId) {
    final idx = _messages.indexWhere((m) => int.tryParse('${m['id']}') == messageId);
    if (idx == -1 || !_scroll.hasClients) return;
    // Approximate: jump proportionally. Precise anchoring would need item keys;
    // this lands close enough for a short reply hop.
    final ratio = _messages.isEmpty ? 1.0 : idx / _messages.length;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent * ratio,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _openMessageMenu(Map<String, dynamic> message) {
    final role = message['sender_role']?.toString() ?? 'customer';
    if (role == 'system' || message['is_deleted'] == true) return;
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
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                _startReply(message);
              },
            ),
            if (body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text('คัดลอก',
                    style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
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
                      style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _unpinMessage();
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.push_pin_rounded),
                  title: Text('ปักหมุด',
                      style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
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
                    style: GoogleFonts.anuphan(fontWeight: FontWeight.w600)),
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
                    style: GoogleFonts.anuphan(
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
                style: GoogleFonts.anuphan(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                _subtitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
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
                if (_showJumpButton)
                  Positioned(
                    right: 14,
                    bottom: 12,
                    child: _JumpToLatestButton(
                      newCount: _newWhileAway,
                      onTap: _jumpToLatest,
                    ),
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
                style: GoogleFonts.anuphan(
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
                  style: GoogleFonts.anuphan(
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
                style: GoogleFonts.anuphan(
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
                style: GoogleFonts.anuphan(
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

      items.add(
        _MessageBubble(
          message: m,
          showAuthor: isFirstInGroup,
          showAvatar: isLastInGroup,
          showTimestamp: isLastInGroup,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          readByCount: readByCount,
          myUserId: _myUserId,
          onCopy: _copyMessage,
          onLongPress: () => _openMessageMenu(m),
          onReplyTap: _scrollToMessage,
          onReactionTap: (emoji) => _toggleReaction(mId, emoji),
        ),
      );
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
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w600),
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
    return Container(
      constraints: const BoxConstraints(maxHeight: 56),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        border: Border(
          top: BorderSide(color: AppTheme.border(context).withValues(alpha: 0.4)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final m = suggestions[i];
          final label = _mentionLabel(m);
          return InkWell(
            onTap: () => _applyMention(m),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('@',
                      style: GoogleFonts.anuphan(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w800)),
                  Text(label,
                      style: GoogleFonts.anuphan(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context))),
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
            if (_mentionSuggestions.isNotEmpty) _buildMentionBar(),
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
                style: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  hintStyle: GoogleFonts.anuphan(
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
            style: GoogleFonts.anuphan(
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
            style: GoogleFonts.anuphan(
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

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool showAuthor;
  final bool showAvatar;
  final bool showTimestamp;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final int readByCount;
  final int? myUserId;
  final ValueChanged<String> onCopy;
  final VoidCallback onLongPress;
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
    required this.onCopy,
    required this.onLongPress,
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

  /// Split a message body into spans, bolding "@mention" tokens.
  List<InlineSpan> _mentionSpans(String text, Color fg) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'@[^\s@]+');
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: GoogleFonts.anuphan(
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
        ),
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
    final hasText = !isDeleted && body.isNotEmpty;
    final hasImage = imageUrl.isNotEmpty;

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

    return Padding(
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
                            style: GoogleFonts.anuphan(
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
                    padding: hasImage && !hasText
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: shape,
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
                                style: GoogleFonts.anuphan(
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
                          Text.rich(
                            TextSpan(
                              children: [
                                ..._mentionSpans(body, fg),
                                if (isEdited)
                                  TextSpan(
                                    text: '  แก้ไขแล้ว',
                                    style: GoogleFonts.anuphan(
                                      fontSize: 11,
                                      color: fg.withValues(alpha: 0.55),
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            style: GoogleFonts.anuphan(
                              fontSize: 15,
                              height: 1.4,
                              color: fg,
                              fontWeight: FontWeight.w500,
                            ),
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
                if (showTimestamp) ...[
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
                            style: GoogleFonts.anuphan(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _timeText(),
                          style: GoogleFonts.anuphan(
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
        style: GoogleFonts.anuphan(
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

class _ImageViewer extends StatelessWidget {
  final String url;
  final String? title;

  const _ImageViewer({required this.url, this.title});

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
        title: title == null || title!.trim().isEmpty
            ? null
            : Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
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

  const _RoomInfoSheet({
    required this.vehicle,
    required this.members,
    required this.memberCount,
  });

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
                    style: GoogleFonts.anuphan(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$memberCount คน',
                    style: GoogleFonts.anuphan(
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
                          style: GoogleFonts.anuphan(
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
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                    letterSpacing: -0.1,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: GoogleFonts.anuphan(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                if (driverName.isNotEmpty)
                  Text(
                    'คนขับ: $driverName',
                    style: GoogleFonts.anuphan(
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
                    style: GoogleFonts.anuphan(
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
                    style: GoogleFonts.anuphan(
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
        style: GoogleFonts.anuphan(
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
                      style: GoogleFonts.anuphan(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
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
              style: GoogleFonts.anuphan(
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
                style: GoogleFonts.anuphan(
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
                style: GoogleFonts.anuphan(
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
                  style: GoogleFonts.anuphan(
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
                    style: GoogleFonts.anuphan(
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
                  style: GoogleFonts.anuphan(
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
                    style: GoogleFonts.anuphan(
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
              style: GoogleFonts.anuphan(
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
      elevation: 3,
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
              style: GoogleFonts.anuphan(
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
