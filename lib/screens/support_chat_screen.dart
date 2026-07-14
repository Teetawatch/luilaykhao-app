import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// ศูนย์ช่วยเหลือ — ห้องสนทนา 1:1 ระหว่างลูกค้ากับทีมงาน (async support inbox)
/// ทีมงานตอบเมื่อว่าง มี realtime + fallback poll เมื่อมีข้อความใหม่
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const _pollInterval = Duration(seconds: 6);

  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _picker = ImagePicker();

  final List<Map<String, dynamic>> _messages = [];
  int? _conversationId;

  bool _loading = true;
  bool _sending = false;
  bool _polling = false;
  bool _loadingOlder = false;
  bool _hasMore = false;
  String? _error;

  Timer? _pollTimer;
  VoidCallback? _disposer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _disposer?.call();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final app = context.read<AppProvider>();
    try {
      final convo = await app.supportConversation();
      final data = await app.supportMessages();
      final msgs = (data['messages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _conversationId = int.tryParse('${convo['id']}');
        _messages
          ..clear()
          ..addAll(msgs);
        _hasMore = data['has_more'] == true;
        _loading = false;
      });

      _markRead();
      _scrollToBottom(jump: true);
      _bindRealtime();
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'โหลดข้อความไม่สำเร็จ';
      });
    }
  }

  Future<void> _bindRealtime() async {
    final id = _conversationId;
    if (id == null) return;
    final app = context.read<AppProvider>();
    _disposer = await app.subscribeSupport(id, (payload) {
      if (!mounted) return;
      _ingest([payload]);
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted || _polling || _loading || _messages.isEmpty) return;
    _polling = true;
    try {
      final data =
          await context.read<AppProvider>().supportMessages(afterId: _latestId());
      final fresh = (data['messages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _ingest(fresh);
    } catch (_) {
      // Transient — next tick retries.
    } finally {
      _polling = false;
    }
  }

  /// Append messages we don't already have (dedupe by server id), then keep the
  /// read pointer and scroll position sensible.
  void _ingest(List<Map<String, dynamic>> incoming) {
    if (!mounted || incoming.isEmpty) return;
    final fresh = incoming.where((m) {
      final id = m['id'];
      return id == null || !_messages.any((e) => e['id'] == id);
    }).toList();
    if (fresh.isEmpty) return;

    final wasAtBottom = _isNearBottom();
    setState(() => _messages.addAll(fresh));
    _markRead();
    if (wasAtBottom) _scrollToBottom();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final oldestId = int.tryParse('${_messages.first['id']}') ?? 0;
      final data = await context
          .read<AppProvider>()
          .supportMessages(beforeId: oldestId);
      final older = (data['messages'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, older);
        _hasMore = data['has_more'] == true;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _markRead() => context.read<AppProvider>().markSupportRead();

  int _latestId() {
    var max = 0;
    for (final m in _messages) {
      final id = int.tryParse('${m['id']}') ?? 0;
      if (id > max) max = id;
    }
    return max;
  }

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120;
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.selectionClick();
    _input.clear();
    setState(() => _sending = true);
    try {
      final msg = await context.read<AppProvider>().sendSupportMessage(text);
      _ingest([msg]);
    } catch (e) {
      if (mounted) {
        _input.text = text; // restore so the user doesn't lose their message
        _snack(e is ApiException ? e.message : 'ส่งข้อความไม่สำเร็จ');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } catch (_) {
      _snack('ไม่สามารถเปิดรูปภาพได้');
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final msg =
          await context.read<AppProvider>().sendSupportImage(picked.path);
      _ingest([msg]);
    } catch (e) {
      if (mounted) _snack(e is ApiException ? e.message : 'ส่งรูปไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: appFont(color: Colors.white))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ศูนย์ช่วยเหลือ',
                style: appFont(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(
              'ทีมงานลุยเลเขา · ตอบกลับโดยเร็วที่สุด',
              style: appFont(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _bootstrap);
    }
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels <= 40 && _hasMore) _loadOlder();
              return false;
            },
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              itemCount: _messages.length + (_loadingOlder ? 1 : 0),
              itemBuilder: (context, index) {
                if (_loadingOlder && index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final m = _messages[index - (_loadingOlder ? 1 : 0)];
                return _MessageBubble(message: m);
              },
            ),
          ),
        ),
        _Composer(
          controller: _input,
          sending: _sending,
          onSend: _send,
          onPickImage: _pickImage,
        ),
      ],
    );
  }
}

// ─────────────────────────── message bubble ───────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final role = '${message['sender_role']}';
    if (role == 'system') return _SystemNotice(text: '${message['body'] ?? ''}');

    final isMine = message['is_mine'] == true;
    final imageUrl = message['image_url']?.toString();
    final localImage = message['_local_image_path']?.toString();
    final body = message['body']?.toString();

    final bg = isMine
        ? AppTheme.primaryColor
        : AppTheme.surface(context);
    final fg = isMine ? Colors.white : AppTheme.onSurface(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(
                  'ทีมงาน',
                  style: appFont(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine
                    ? null
                    : Border.all(color: AppTheme.border(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (localImage != null)
                    Image.file(File(localImage), fit: BoxFit.cover)
                  else if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        height: 160,
                        color: AppTheme.subtleSurface(context),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        height: 120,
                        color: AppTheme.subtleSurface(context),
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  if (body != null && body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                      child: Text(
                        body,
                        style: appFont(fontSize: 15, color: fg, height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(
                _formatTime(message['created_at']),
                style: appFont(
                  fontSize: 10,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemNotice extends StatelessWidget {
  final String text;

  const _SystemNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: appFont(
          fontSize: 12.5,
          height: 1.4,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}

// ─────────────────────────── composer ───────────────────────────

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: sending ? null : onPickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            color: AppTheme.mutedText(context),
            tooltip: 'ส่งรูปภาพ',
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppTheme.fieldSurface(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border(context)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: appFont(fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'พิมพ์ข้อความถึงทีมงาน...',
                  hintStyle: appFont(
                    fontSize: 15,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _SendButton(sending: sending, onSend: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onSend;

  const _SendButton({required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: sending ? null : onSend,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 40, color: AppTheme.mutedText(context)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: appFont()),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      ),
    );
  }
}

String _formatTime(dynamic iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse('$iso')?.toLocal();
  if (dt == null) return '';
  final now = DateTime.now();
  final sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  return sameDay
      ? DateFormat('HH:mm').format(dt)
      : DateFormat('d/MM HH:mm').format(dt);
}
