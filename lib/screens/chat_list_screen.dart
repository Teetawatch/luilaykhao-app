import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

/// Bottom-nav "แชท" tab — lists every trip group chat the user belongs to, with
/// the latest message preview and an unread badge, LINE-style. Tapping opens the
/// room. Backed by [AppProvider.loadChatConversations].
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AppProvider>().isLoggedIn) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await context.read<AppProvider>().loadChatConversations();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadedOnce = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.isLoggedIn) {
      return const LoginScreen(popOnSuccess: false);
    }

    final conversations = app.chatConversations
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const TravelSliverAppBar(title: 'แชท', showBackButton: false),
            if (_loading && !_loadedOnce && conversations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (conversations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyChats(error: _error),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  100 + MediaQuery.of(context).padding.bottom,
                ),
                sliver: SliverList.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) =>
                      _ConversationTile(conversation: conversations[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;

  const _ConversationTile({required this.conversation});

  String _t(dynamic v) => v?.toString().trim() ?? '';

  String _previewText() {
    final last = conversation['last_message'];
    if (last is! Map) return 'ยังไม่มีข้อความ — เริ่มทักทายได้เลย';
    final role = _t(last['sender_role']);
    final body = _t(last['body']);
    final hasImage = _t(last['image_url']).isNotEmpty;
    final sender = _t(last['sender_name']);
    final text = body.isNotEmpty ? body : (hasImage ? '📷 รูปภาพ' : '');
    if (role == 'system') return text;
    if (sender.isEmpty) return text;
    return '$sender: $text';
  }

  String _timeText() {
    final raw = _t(conversation['last_activity']);
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (diff == 0) return '$hh:$mm';
    if (diff == 1) return 'เมื่อวาน';
    const months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    return '${dt.day} ${months[dt.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final scheduleId = int.tryParse('${conversation['schedule_id']}') ?? 0;
    final title = _t(conversation['trip_title']);
    final vehicle = _t(conversation['vehicle_name']);
    final unread = int.tryParse('${conversation['unread_count']}') ?? 0;
    final image = ApiConfig.mediaUrl(conversation['trip_image']);
    final time = _timeText();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: scheduleId == 0
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    scheduleId: scheduleId,
                    title: title.isEmpty ? 'แชทกลุ่มทริป' : title,
                  ),
                ),
              ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              _Thumb(image: image),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'แชทกลุ่มทริป' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface(context),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: appFont(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: unread > 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.mutedText(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _previewText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                              fontSize: 13,
                              fontWeight:
                                  unread > 0 ? FontWeight.w700 : FontWeight.w500,
                              color: unread > 0
                                  ? AppTheme.onSurface(context)
                                  : AppTheme.mutedText(context),
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: appFont(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (vehicle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_bus_outlined,
                            size: 12,
                            color: AppTheme.mutedText(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            vehicle,
                            style: appFont(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _Thumb extends StatelessWidget {
  final String image;

  const _Thumb({required this.image});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 54,
        height: 54,
        child: image.isEmpty
            ? Container(
                color: AppTheme.subtleSurface(context),
                child: Icon(
                  Icons.forum_rounded,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  size: 24,
                ),
              )
            : CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: AppTheme.subtleSurface(context)),
                errorWidget: (_, _, _) => Container(
                  color: AppTheme.subtleSurface(context),
                  child: const Icon(Icons.image_rounded),
                ),
              ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  final String? error;

  const _EmptyChats({this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              error != null
                  ? Icons.error_outline_rounded
                  : Icons.forum_outlined,
              size: 34,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            error != null ? 'โหลดแชทไม่สำเร็จ' : 'ยังไม่มีแชททริป',
            style: appFont(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error ??
                'เมื่อคุณจองทริป ห้องแชทกลุ่มสำหรับพูดคุยกับเพื่อนร่วมทริปและทีมงานจะปรากฏที่นี่',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}
