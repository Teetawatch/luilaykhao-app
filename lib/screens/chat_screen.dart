import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _sending = false;
  String? _error;
  VoidCallback? _disposer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _disposer?.call();
    _input.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final app = context.read<AppProvider>();
    await _load();
    _disposer = await app.subscribeChat(widget.scheduleId, _onIncoming);
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
      app.markChatRead(widget.scheduleId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
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
    if (!mounted) return;
    final id = data['id'];
    if (id != null && _messages.any((m) => m['id'] == id)) return;
    final wasAtBottom = _isNearBottom();
    setState(() => _messages.add({...data, 'is_mine': false}));
    context.read<AppProvider>().markChatRead(widget.scheduleId);
    if (wasAtBottom) _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final app = context.read<AppProvider>();
    try {
      final message = await app.sendChatMessage(widget.scheduleId, text);
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _input.clear();
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

  void _onScroll() {
    if (_scroll.position.pixels <= 80) _loadMore();
  }

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? 'แชทกลุ่มทริป',
              style: GoogleFonts.anuphan(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'ลูกค้า · สตาฟ · ทีมงาน',
              style: GoogleFonts.anuphan(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'ยังไม่มีข้อความ เริ่มทักทายเพื่อนร่วมทริปได้เลย',
          style: GoogleFonts.anuphan(
            fontSize: 13.5,
            color: AppTheme.mutedText(context),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: _messages.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loadingMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final m = _messages[index - (_loadingMore ? 1 : 0)];
        return _MessageBubble(message: m);
      },
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border(
            top: BorderSide(color: AppTheme.border(context)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.anuphan(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.subtleSurface(context),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
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
                  padding: const EdgeInsets.all(12),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const _MessageBubble({required this.message});

  static const _roleLabels = {
    'customer': 'ลูกค้า',
    'staff': 'สตาฟ',
    'admin': 'ทีมงาน',
    'system': 'ระบบ',
  };

  String _timeText() {
    final raw = message['created_at']?.toString();
    final dt = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
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

    final bg = isMine ? AppTheme.primaryColor : AppTheme.surface(context);
    final fg = isMine ? Colors.white : AppTheme.onSurface(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.74,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: isMine
                    ? null
                    : Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMine) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          author,
                          style: GoogleFonts.anuphan(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _RoleTag(role: role),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    message['body']?.toString() ?? '',
                    style: GoogleFonts.anuphan(
                      fontSize: 14,
                      height: 1.4,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _timeText(),
                    style: GoogleFonts.anuphan(
                      fontSize: 10,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  final String role;

  const _RoleTag({required this.role});

  @override
  Widget build(BuildContext context) {
    if (role == 'customer') return const SizedBox.shrink();
    final color = role == 'admin'
        ? const Color(0xFFB45309)
        : const Color(0xFF0E7490);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _MessageBubble._roleLabels[role] ?? role,
        style: GoogleFonts.anuphan(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
