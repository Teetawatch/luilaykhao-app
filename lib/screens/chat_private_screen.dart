import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/chat_voice.dart';
import '../widgets/empty_state_view.dart';
import 'support_chat_screen.dart';

// ถามทีมงานแบบส่วนตัว — เธรดแยกระหว่างลูกทริปหนึ่งคนกับทีมงานของรอบนั้น
//
// ลูกทริปเห็นเฉพาะเธรดของตัวเอง ทีมงาน (สตาฟของรอบ/แอดมิน) เปิดได้ทุกเธรดผ่าน
// [ChatPrivateInboxScreen] — ข้อความไม่เคยขึ้นในห้องแชทรวม และถูกลบพร้อมห้อง
// 3 วันหลังจบทริป (ChatPrivateService ฝั่งเซิร์ฟเวอร์)

String _t(dynamic v) => v?.toString().trim() ?? '';

int _int(dynamic v) => int.tryParse('$v') ?? 0;

String _displayName(dynamic person, {String fallback = 'ผู้ใช้'}) {
  if (person is! Map) return fallback;
  final nick = _t(person['nickname']);
  if (nick.isNotEmpty) return nick;
  final name = _t(person['name']);
  return name.isEmpty ? fallback : name;
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

DateTime? _time(dynamic raw) => DateTime.tryParse(_t(raw))?.toLocal();

/// เรื่องที่คนมักไม่กล้าพิมพ์ในห้องรวม — แตะแล้วเติมลงช่องพิมพ์ให้แก้ต่อเอง
const kPrivateAskSuggestions = [
  'ขอผ้าอนามัยหน่อยค่ะ',
  'รู้สึกไม่ค่อยสบาย',
  'สอบถามเรื่องค่าใช้จ่าย',
  'มีเรื่องไม่สบายใจกับเพื่อนร่วมทริป',
];

/// หน้าคุยส่วนตัวกับทีมงาน — [threadUserId] คือลูกทริปเจ้าของเธรด (ลูกทริปเปิดเอง
/// ไม่ต้องส่ง ทีมงานต้องส่ง)
class ChatPrivateScreen extends StatefulWidget {
  final int scheduleId;
  final int? threadUserId;

  /// ชื่อทริป (บรรทัดรองของ AppBar)
  final String? tripTitle;

  const ChatPrivateScreen({
    super.key,
    required this.scheduleId,
    this.threadUserId,
    this.tripTitle,
  });

  @override
  State<ChatPrivateScreen> createState() => _ChatPrivateScreenState();
}

class _ChatPrivateScreenState extends State<ChatPrivateScreen>
    with WidgetsBindingObserver {
  static const _pollIdle = Duration(seconds: 5);
  static const _pollSocketActive = Duration(seconds: 20);

  final List<Map<String, dynamic>> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _voice = VoiceRecordingController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _polling = false;
  bool _foreground = true;
  bool _composing = false;
  String? _error;

  /// staff = ทีมงานดูเธรดของลูกทริป, customer = ลูกทริปดูเธรดตัวเอง (ตามเซิร์ฟเวอร์)
  bool _asStaff = false;
  int? _myId;
  int? _ownerId;
  Map<String, dynamic>? _thread;
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _staff = const [];

  Timer? _pollTimer;
  DateTime? _lastSocketAt;
  VoidCallback? _unsubscribe;
  VoidCallback? _unwatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(() {
      final composing = _input.text.trim().isNotEmpty;
      if (composing != _composing && mounted) {
        setState(() => _composing = composing);
      }
    });
    _voice.onAutoStop = (clip) {
      if (!mounted) return;
      setState(() {});
      _enqueue({
        '_local_audio_path': clip.path,
        'audio_duration_ms': clip.durationMs,
      });
      AppSnack.show(context, 'ครบ 2 นาที ส่งข้อความเสียงให้แล้ว');
    };
    // ระหว่างเปิดเธรดอยู่ iOS ไม่ต้องวาดแบนเนอร์ระบบทับ (เหมือนห้องแชทรวม)
    _unwatch = PushNotificationService.instance.watchChatRoom((_) => false);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _unsubscribe?.call();
    _unwatch?.call();
    final push = PushNotificationService.instance;
    if (push.visiblePrivateThread == _threadKey) {
      push.visiblePrivateThread = null;
    }
    _voice.dispose();
    unawaited(ChatVoicePlayback.instance.stop());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _startPolling();
      _poll();
      _markRead();
    } else {
      _pollTimer?.cancel();
      if (_voice.isRecording) {
        unawaited(
          _voice.cancel().then((_) {
            if (mounted) setState(() {});
          }),
        );
      }
      unawaited(ChatVoicePlayback.instance.stop());
    }
  }

  String? get _threadKey =>
      _ownerId == null ? null : '${widget.scheduleId}:$_ownerId';

  Future<void> _init() async {
    final app = context.read<AppProvider>();
    _myId = int.tryParse('${app.user?['id']}');
    await _load();
    if (!mounted || _error != null) return;
    PushNotificationService.instance.visiblePrivateThread = _threadKey;
    _unsubscribe = await app.subscribeChatPrivate(
      widget.scheduleId,
      asStaff: _asStaff,
      userId: _ownerId,
      onMessage: _onSocketMessage,
      onUpdated: _onSocketUpdated,
      onRead: _onSocketRead,
    );
    _startPolling();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    try {
      final data = await app.chatPrivateMessages(
        widget.scheduleId,
        userId: widget.threadUserId,
      );
      if (!mounted) return;
      setState(() {
        _asStaff = data['viewer_role'] == 'staff';
        _customer = data['customer'] is Map
            ? Map<String, dynamic>.from(data['customer'] as Map)
            : null;
        _ownerId = int.tryParse('${_customer?['id']}') ?? widget.threadUserId;
        _thread = data['thread'] is Map
            ? Map<String, dynamic>.from(data['thread'] as Map)
            : null;
        _staff = (data['staff'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _messages
          ..clear()
          ..addAll(_maps(data['messages']));
        _hasMore = data['has_more'] == true;
        _loading = false;
        _error = null;
      });
      _scrollToBottom(jump: true);
      _markRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final firstId = _messages
        .map((m) => _int(m['id']))
        .where((id) => id > 0)
        .fold<int>(0, (a, b) => a == 0 || b < a ? b : a);
    if (firstId == 0) return;
    setState(() => _loadingMore = true);
    try {
      final data = await context.read<AppProvider>().chatPrivateMessages(
        widget.scheduleId,
        userId: _ownerId,
        beforeId: firstId,
      );
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, _maps(data['messages']));
        _hasMore = data['has_more'] == true;
      });
    } catch (_) {
      // เลื่อนขึ้นอีกครั้งก็ลองใหม่
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final socketAlive =
        _lastSocketAt != null &&
        DateTime.now().difference(_lastSocketAt!) < const Duration(seconds: 30);
    _pollTimer = Timer.periodic(
      socketAlive ? _pollSocketActive : _pollIdle,
      (_) => _poll(),
    );
  }

  int get _latestId => _messages.fold<int>(0, (a, m) {
    final id = _int(m['id']);
    return id > a ? id : a;
  });

  Future<void> _poll() async {
    if (!mounted || _polling || _loading || !_foreground || _error != null) {
      return;
    }
    _polling = true;
    try {
      final data = await context.read<AppProvider>().chatPrivateMessages(
        widget.scheduleId,
        userId: _ownerId,
        afterId: _latestId,
      );
      if (!mounted) return;
      if (data['thread'] is Map) {
        setState(
          () => _thread = Map<String, dynamic>.from(data['thread'] as Map),
        );
      }
      _ingest(_maps(data['messages']));
    } catch (_) {
      // เน็ตหลุดชั่วคราว รอบหน้าลองใหม่
    } finally {
      _polling = false;
    }
  }

  bool _isThisThread(Map<String, dynamic> data) =>
      _int(data['thread_user_id']) == _ownerId;

  void _onSocketMessage(Map<String, dynamic> data) {
    if (!_isThisThread(data)) return;
    _lastSocketAt = DateTime.now();
    _startPolling();
    if (data['thread'] is Map && mounted) {
      setState(
        () => _thread = Map<String, dynamic>.from(data['thread'] as Map),
      );
    }
    if (data['message'] is Map) {
      _ingest([Map<String, dynamic>.from(data['message'] as Map)]);
    }
  }

  void _onSocketUpdated(Map<String, dynamic> data) {
    if (!_isThisThread(data) || data['message'] is! Map || !mounted) return;
    final next = Map<String, dynamic>.from(data['message'] as Map);
    final idx = _messages.indexWhere((m) => _int(m['id']) == _int(next['id']));
    if (idx < 0) return;
    setState(
      () => _messages[idx] = {...next, 'is_mine': _messages[idx]['is_mine']},
    );
  }

  void _onSocketRead(Map<String, dynamic> data) {
    if (!_isThisThread(data) || data['thread'] is! Map || !mounted) return;
    setState(() => _thread = Map<String, dynamic>.from(data['thread'] as Map));
  }

  /// เติมข้อความใหม่ (กันซ้ำด้วย id) — ข้อความจาก socket ไม่รู้ว่า "ของฉัน" ไหม จึงเทียบ user id เอง
  void _ingest(List<Map<String, dynamic>> incoming) {
    if (!mounted || incoming.isEmpty) return;
    final fresh = incoming
        .where((m) {
          final id = _int(m['id']);
          return id > 0 && !_messages.any((e) => _int(e['id']) == id);
        })
        .map((m) {
          final author = m['user'] is Map ? _int((m['user'] as Map)['id']) : 0;
          return {...m, 'is_mine': author != 0 && author == _myId};
        })
        .toList();
    if (fresh.isEmpty) return;
    final atBottom = _isNearBottom();
    setState(() => _messages.addAll(fresh));
    _markRead();
    if (atBottom) _scrollToBottom();
  }

  void _markRead() {
    if (!_foreground || !mounted || _messages.isEmpty) return;
    unawaited(
      context
          .read<AppProvider>()
          .markChatPrivateRead(
            widget.scheduleId,
            userId: _asStaff ? _ownerId : null,
          )
          .then((thread) {
            if (thread != null && mounted) setState(() => _thread = thread);
          })
          .catchError((_) => null),
    );
  }

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    return _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── ส่ง ────────────────────────────────────────────────────────────────

  void _sendText() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _enqueue({'body': text});
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } catch (_) {
      if (mounted) AppSnack.show(context, 'ไม่สามารถเปิดรูปภาพได้');
      return;
    }
    if (picked == null || !mounted) return;
    _enqueue({'_local_image_path': picked.path});
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (sheet) => SafeArea(
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
                Navigator.pop(sheet);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(
                'เลือกจากคลังรูปภาพ',
                style: appFont(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(sheet);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _startVoice() async {
    if (_voice.isRecording) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    final result = await _voice.start();
    if (!mounted) return;
    switch (result) {
      case VoiceStartResult.started:
        setState(() {});
      case VoiceStartResult.denied:
        AppSnack.show(
          context,
          'อนุญาตให้แอปใช้ไมโครโฟนในการตั้งค่าเครื่องก่อน แล้วลองอีกครั้งนะครับ',
        );
      case VoiceStartResult.failed:
        AppSnack.show(context, 'เริ่มอัดเสียงไม่ได้ ลองอีกครั้งนะครับ');
    }
  }

  Future<void> _finishVoice() async {
    final clip = await _voice.stop();
    if (!mounted) return;
    setState(() {});
    if (clip == null) {
      AppSnack.show(
        context,
        'ข้อความเสียงสั้นไป — แตะไมค์ พูด แล้วกดส่งเมื่อพูดจบนะครับ',
      );
      return;
    }
    HapticFeedback.mediumImpact();
    _enqueue({
      '_local_audio_path': clip.path,
      'audio_duration_ms': clip.durationMs,
    });
  }

  Future<void> _cancelVoice() async {
    HapticFeedback.selectionClick();
    await _voice.cancel();
    if (mounted) setState(() {});
  }

  int _tokenSeq = 0;

  /// แปะข้อความลงเธรดทันที แล้วส่งตามหลัง — เน็ตหลุดก็ยังอยู่พร้อมปุ่มลองใหม่
  void _enqueue(Map<String, dynamic> content) {
    final token =
        'llk-p-${DateTime.now().microsecondsSinceEpoch}-${_tokenSeq++}';
    setState(() {
      _messages.add({
        ...content,
        'client_token': token,
        'is_mine': true,
        'from_customer': !_asStaff,
        'sender_role': _asStaff ? 'staff' : 'customer',
        'created_at': DateTime.now().toIso8601String(),
        '_pending': true,
      });
    });
    _scrollToBottom();
    _dispatch(token);
  }

  Future<void> _dispatch(String token) async {
    final idx = _messages.indexWhere((m) => m['client_token'] == token);
    if (idx < 0) return;
    setState(() {
      _messages[idx]['_pending'] = true;
      _messages[idx]['_failed'] = false;
    });
    final opt = _messages[idx];
    try {
      final result = await context.read<AppProvider>().sendChatPrivate(
        widget.scheduleId,
        userId: _ownerId,
        body: opt['body']?.toString(),
        imagePath: opt['_local_image_path']?.toString(),
        audioPath: opt['_local_audio_path']?.toString(),
        audioDurationMs: int.tryParse('${opt['audio_duration_ms']}'),
      );
      if (!mounted) return;
      final server = Map<String, dynamic>.from(result['message'] as Map);
      setState(() {
        if (result['thread'] is Map) {
          _thread = Map<String, dynamic>.from(result['thread'] as Map);
        }
        final optIdx = _messages.indexWhere((m) => m['client_token'] == token);
        final dupIdx = _messages.indexWhere(
          (m) => _int(m['id']) == _int(server['id']),
        );
        if (dupIdx >= 0 && dupIdx != optIdx) {
          if (optIdx >= 0) _messages.removeAt(optIdx);
        } else if (optIdx >= 0) {
          _messages[optIdx] = server;
        }
      });
      final audio = opt['_local_audio_path']?.toString();
      if (audio != null && ChatVoicePlayback.instance.currentKey != audio) {
        deleteVoiceClip(audio);
      }
    } catch (e) {
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

  Future<void> _openMenu(Map<String, dynamic> m) async {
    if (m['is_mine'] != true || m['is_deleted'] == true) return;
    if (m['_pending'] == true || m['_failed'] == true) return;
    final body = _t(m['body']);
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(
                  'คัดลอก',
                  style: appFont(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(sheet, 'copy'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.errorColor,
              ),
              title: Text(
                'ลบข้อความ',
                style: appFont(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
              onTap: () => Navigator.pop(sheet, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: body));
      if (mounted) AppSnack.show(context, 'คัดลอกข้อความแล้ว');
      return;
    }
    try {
      final updated = await context.read<AppProvider>().deleteChatPrivate(
        widget.scheduleId,
        _int(m['id']),
      );
      if (!mounted) return;
      final idx = _messages.indexWhere((e) => _int(e['id']) == _int(m['id']));
      if (idx >= 0) {
        setState(() => _messages[idx] = {...updated, 'is_mine': true});
      }
    } catch (e) {
      if (mounted) AppSnack.show(context, e.toString());
    }
  }

  // ── วาด ─────────────────────────────────────────────────────────────────

  /// ข้อความนี้อยู่ฝั่งขวา (ฝั่งเรา) ไหม — ทีมงานทุกคนเป็นฝั่งเดียวกัน
  bool _onMySide(Map<String, dynamic> m) =>
      _asStaff ? m['from_customer'] != true : m['from_customer'] == true;

  /// อีกฝั่งอ่านถึงข้อความไหนแล้ว
  int get _otherReadId =>
      _int(_thread?[_asStaff ? 'customer_read_id' : 'staff_read_id']);

  String get _title => _asStaff
      ? _displayName(_customer, fallback: 'ลูกทริป')
      : 'ถามทีมงานแบบส่วนตัว';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.chatCanvas(context),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loading ? 'ข้อความส่วนตัว' : _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppTheme.appBarTitleSize,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _asStaff
                  ? 'ข้อความส่วนตัว · ลูกทริปคนอื่นไม่เห็น'
                  : (widget.tripTitle ?? 'ทีมงานประจำรอบเท่านั้นที่เห็น'),
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
      body: Column(
        children: [
          if (!_loading && _error == null && !_asStaff)
            _PrivacyBanner(staff: _staff),
          Expanded(child: _buildBody()),
          if (!_loading && _error == null) _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return EmptyStateView(
        icon: Icons.lock_outline_rounded,
        title: 'เปิดข้อความส่วนตัวไม่ได้',
        body: _error,
        actionLabel: 'ลองอีกครั้ง',
        onAction: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _init();
        },
      );
    }
    if (_messages.isEmpty) {
      return _asStaff
          ? EmptyStateView(
              icon: Icons.lock_person_rounded,
              title: 'ยังไม่มีข้อความ',
              body:
                  'พิมพ์ถึง ${_displayName(_customer, fallback: 'ลูกทริป')} ได้เลย '
                  'คนอื่นในทริปไม่เห็นข้อความนี้',
            )
          : _AskSuggestions(
              onPick: (text) {
                _input.text = text;
                _input.selection = TextSelection.collapsed(offset: text.length);
              },
            );
    }

    final lastMineId = _messages
        .where((m) => _onMySide(m) && _int(m['id']) > 0)
        .fold<int>(0, (a, m) => _int(m['id']) > a ? _int(m['id']) : a);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels <= 80 && _hasMore) _loadMore();
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        itemCount: _messages.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (_loadingMore && i == 0) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final m = _messages[i - (_loadingMore ? 1 : 0)];
          final id = _int(m['id']);
          final token = m['client_token']?.toString();
          return PrivateMessageBubble(
            message: m,
            onMySide: _onMySide(m),
            // ทีมงานเห็นชื่อทีมงานคนอื่นที่ตอบไป ลูกทริปเห็นชื่อทีมงานทุกข้อความ
            showName: _asStaff
                ? (_onMySide(m) && m['is_mine'] != true)
                : !_onMySide(m),
            readByOther: id > 0 && id == lastMineId && _otherReadId >= id,
            readLabel: _asStaff ? 'อ่านแล้ว' : 'ทีมงานอ่านแล้ว',
            onRetry: (m['_failed'] == true && token != null)
                ? () => _dispatch(token)
                : null,
            onLongPress: () => _openMenu(m),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
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
        child: _voice.isRecording
            ? Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: ChatVoiceRecordingBar(
                  controller: _voice,
                  onCancel: _cancelVoice,
                  onSend: _finishVoice,
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'ส่งรูปภาพ',
                      onPressed: _showAttachSheet,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 26,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        textInputAction: TextInputAction.newline,
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: _asStaff
                              ? 'ตอบแบบส่วนตัว...'
                              : 'พิมพ์ถึงทีมงาน...',
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_composing)
                      Material(
                        color: AppTheme.primaryColor,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sendText,
                          child: const Padding(
                            padding: EdgeInsets.all(11),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 20,
                              semanticLabel: 'ส่ง',
                            ),
                          ),
                        ),
                      )
                    else
                      ChatVoiceMicButton(onTap: _startVoice),
                  ],
                ),
              ),
      ),
    );
  }
}

/// แถบบนสุดของลูกทริป — บอกชัด ๆ ว่าใครเห็นข้อความนี้ (และถ้ายังไม่มีใคร ให้ไปทางไหน)
class _PrivacyBanner extends StatelessWidget {
  final List<Map<String, dynamic>> staff;

  const _PrivacyBanner({required this.staff});

  @override
  Widget build(BuildContext context) {
    final names = staff
        .map((s) => _displayName(s, fallback: 'ทีมงาน'))
        .toList();
    final muted = AppTheme.mutedText(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ทีมงานประจำรอบเท่านั้นที่เห็น ไม่ขึ้นในห้องแชทรวม',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  names.isEmpty
                      ? 'รอบนี้ยังไม่มีทีมงานประจำ — ข้อความจะถึงทีมงานทันทีที่จัดสตาฟ '
                            'เรื่องด่วนทักศูนย์ช่วยเหลือได้เลย'
                      : 'ถึง: ${names.join(', ')}',
                  style: appFont(fontSize: AppText.sizeCaption, color: muted),
                ),
                if (names.isEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SupportChatScreen(),
                      ),
                    ),
                    child: Text(
                      'ทักศูนย์ช่วยเหลือ',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
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

/// เธรดว่างของลูกทริป — ชวนถามพร้อมตัวอย่างเรื่องที่คนมักไม่กล้าพิมพ์ในห้องรวม
class _AskSuggestions extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _AskSuggestions({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        const Icon(
          Icons.lock_person_rounded,
          size: 44,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 12),
        Text(
          'ถามได้ทุกเรื่องที่ไม่อยากพิมพ์ในห้องรวม',
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'เรื่องสุขภาพ ค่าใช้จ่าย หรือเรื่องที่ไม่สบายใจ — ทีมงานตอบในนี้ '
          'และแจ้งเตือนถึงคุณคนเดียว',
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: AppText.sizeBody,
            color: AppTheme.mutedText(context),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in kPrivateAskSuggestions)
              ActionChip(
                label: Text(
                  s,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onPick(s);
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// บับเบิลของเธรดส่วนตัว — ตัวอักษร / รูป / เสียง และสถานะกำลังส่ง/ส่งไม่สำเร็จ/อ่านแล้ว
class PrivateMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool onMySide;
  final bool showName;
  final bool readByOther;
  final String readLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;

  const PrivateMessageBubble({
    super.key,
    required this.message,
    required this.onMySide,
    required this.showName,
    required this.readByOther,
    this.readLabel = 'อ่านแล้ว',
    this.onRetry,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final deleted = message['is_deleted'] == true;
    final pending = message['_pending'] == true;
    final failed = message['_failed'] == true;
    final body = _t(message['body']);
    final imageUrl = deleted ? '' : ApiConfig.mediaUrl(message['image_url']);
    final localImage = deleted ? '' : _t(message['_local_image_path']);
    final audioUrl = deleted ? '' : ApiConfig.mediaUrl(message['audio_url']);
    final localAudio = deleted ? '' : _t(message['_local_audio_path']);
    final hasVoice = audioUrl.isNotEmpty || localAudio.isNotEmpty;
    final at = _time(message['created_at']);

    final bg = onMySide
        ? AppTheme.primaryColor
        : AppTheme.chatIncomingBubble(context);
    final fg = onMySide ? Colors.white : AppTheme.onSurface(context);
    final muted = AppTheme.mutedText(context);

    Widget content;
    if (deleted) {
      content = Text(
        'ข้อความนี้ถูกลบ',
        style: appFont(
          fontSize: AppText.sizeBody,
          fontStyle: FontStyle.italic,
          color: fg.withValues(alpha: 0.6),
        ),
      );
    } else if (hasVoice) {
      content = ChatVoiceBubble(
        url: audioUrl.isEmpty ? null : audioUrl,
        localPath: audioUrl.isEmpty ? localAudio : null,
        durationMs: _int(message['audio_duration_ms']),
        foreground: fg,
      );
    } else if (imageUrl.isNotEmpty || localImage.isNotEmpty) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220, maxHeight: 280),
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 660,
                )
              : Image.file(
                  File(localImage),
                  fit: BoxFit.cover,
                  cacheWidth: 660,
                ),
        ),
      );
    } else {
      content = Text(
        body,
        style: appFont(fontSize: AppText.sizeBody, color: fg, height: 1.45),
      );
    }

    final isMedia =
        !deleted && !hasVoice && (imageUrl.isNotEmpty || localImage.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: onMySide
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 3),
              child: Text(
                _displayName(message['user'], fallback: 'ทีมงาน'),
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              child: Container(
                padding: isMedia
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.fromLTRB(14, 10, 14, 11),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: onMySide
                      ? null
                      : Border.all(
                          color: AppTheme.border(
                            context,
                          ).withValues(alpha: 0.65),
                        ),
                ),
                child: content,
              ),
            ),
          ),
          const SizedBox(height: 3),
          if (failed)
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'ส่งไม่สำเร็จ · แตะเพื่อลองใหม่',
                style: appFont(
                  fontSize: AppText.sizeMicro,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.errorColor,
                ),
              ),
            )
          else if (pending)
            Text(
              'กำลังส่ง…',
              style: appFont(fontSize: AppText.sizeMicro, color: muted),
            )
          else
            Text(
              [
                if (readByOther) readLabel,
                if (at != null) _clock(at),
              ].join(' · '),
              style: appFont(
                fontSize: AppText.sizeMicro,
                fontWeight: FontWeight.w500,
                color: readByOther ? AppTheme.primaryColor : muted,
              ),
            ),
        ],
      ),
    );
  }
}

// ── กล่องข้อความของทีมงาน ───────────────────────────────────────────────

/// ทีมงานเห็นทุกเธรดส่วนตัวของรอบ — ใครยังไม่ได้ตอบอยู่บนสุดพร้อมป้ายนับ
class ChatPrivateInboxScreen extends StatefulWidget {
  final int scheduleId;
  final String? tripTitle;

  const ChatPrivateInboxScreen({
    super.key,
    required this.scheduleId,
    this.tripTitle,
  });

  @override
  State<ChatPrivateInboxScreen> createState() => _ChatPrivateInboxScreenState();
}

class _ChatPrivateInboxScreenState extends State<ChatPrivateInboxScreen> {
  List<Map<String, dynamic>> _threads = const [];
  bool _loading = true;
  String? _error;
  VoidCallback? _unsubscribe;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _unsubscribe?.call();
    super.dispose();
  }

  Future<void> _subscribe() async {
    final app = context.read<AppProvider>();
    void refresh(Map<String, dynamic> _) {
      // ข้อความเข้าหลายเธรดพร้อมกัน — รวมเป็นการดึงครั้งเดียว
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), _load);
    }

    final dispose = await app.subscribeChatPrivate(
      widget.scheduleId,
      asStaff: true,
      onMessage: refresh,
      onRead: refresh,
    );
    if (!mounted) {
      dispose();
      return;
    }
    _unsubscribe = dispose;
  }

  Future<void> _load() async {
    try {
      final threads = await context.read<AppProvider>().chatPrivateThreads(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _open(int userId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPrivateScreen(
          scheduleId: widget.scheduleId,
          threadUserId: userId,
          tripTitle: widget.tripTitle,
        ),
      ),
    );
    if (mounted) _load();
  }

  /// ทีมงานเริ่มคุยส่วนตัวกับลูกทริปก่อน — เลือกจากสมาชิกในห้อง
  Future<void> _startNew() async {
    List<Map<String, dynamic>> customers;
    try {
      final room = await context.read<AppProvider>().chatRoom(
        widget.scheduleId,
      );
      customers = (room['members'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((m) => m['role'] == 'customer')
          .toList();
    } catch (e) {
      if (mounted) AppSnack.show(context, e.toString());
      return;
    }
    if (!mounted) return;
    if (customers.isEmpty) {
      AppSnack.show(context, 'ยังไม่มีลูกทริปที่ใช้แอปในห้องนี้');
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'ส่งข้อความส่วนตัวถึง',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(sheet),
                  ),
                ),
              ),
              for (final c in customers)
                ListTile(
                  leading: _Avatar(person: c),
                  title: Text(
                    _displayName(c),
                    style: appFont(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(sheet, _int(c['id'])),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked > 0 && mounted) _open(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'ข้อความส่วนตัว',
          style: appFont(
            fontSize: AppTheme.appBarTitleSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'เริ่มคุยกับลูกทริป',
            onPressed: _startNew,
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return ScrollableEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'โหลดข้อความส่วนตัวไม่ได้',
        body: _error,
        actionLabel: 'ลองอีกครั้ง',
        onAction: _load,
      );
    }
    if (_threads.isEmpty) {
      return const ScrollableEmptyState(
        icon: Icons.lock_person_rounded,
        title: 'ยังไม่มีใครถามแบบส่วนตัว',
        body:
            'ลูกทริปถามเรื่องที่ไม่อยากพิมพ์ในห้องรวมได้ที่นี่ '
            'ข้อความใหม่จะแจ้งเตือนถึงทีมงานทุกคนของรอบ',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _threads.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 76,
        color: AppTheme.border(context).withValues(alpha: 0.5),
      ),
      itemBuilder: (context, i) => PrivateThreadTile(
        thread: _threads[i],
        onTap: () => _open(_int(_threads[i]['thread_user_id'])),
      ),
    );
  }
}

/// แถวหนึ่งในกล่องข้อความทีมงาน
class PrivateThreadTile extends StatelessWidget {
  final Map<String, dynamic> thread;
  final VoidCallback onTap;

  const PrivateThreadTile({
    super.key,
    required this.thread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final customer = thread['customer'];
    final unread = _int(thread['unread']);
    final last = thread['last_message'] is Map
        ? Map<String, dynamic>.from(thread['last_message'] as Map)
        : const <String, dynamic>{};
    final preview = _t(last['preview']);
    final at = _time(last['created_at']);
    final muted = AppTheme.mutedText(context);

    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(person: customer),
      title: Text(
        _displayName(customer, fallback: 'ลูกทริป'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: appFont(
          fontSize: AppText.sizeSubtitle,
          fontWeight: FontWeight.w800,
          color: AppTheme.onSurface(context),
        ),
      ),
      subtitle: Text(
        (last['from_customer'] == false ? 'ทีมงาน: ' : '') + preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
          color: unread > 0 ? AppTheme.onSurface(context) : muted,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (at != null)
            Text(
              _clock(at),
              style: appFont(fontSize: AppText.sizeCaption, color: muted),
            ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                '$unread',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final dynamic person;

  const _Avatar({required this.person});

  @override
  Widget build(BuildContext context) {
    final url = person is Map ? ApiConfig.mediaUrl(person['avatar_url']) : '';
    final name = _displayName(person, fallback: '?');
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
      backgroundImage: url.isEmpty ? null : CachedNetworkImageProvider(url),
      child: url.isEmpty
          ? Text(
              name.characters.first.toUpperCase(),
              style: appFont(
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            )
          : null,
    );
  }
}
