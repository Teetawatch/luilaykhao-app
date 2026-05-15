part of 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = false;
  bool _saving = false;
  final Set<int> _busyIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await context.read<AppProvider>().loadNotifications();
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _saving = true);
    try {
      await context.read<AppProvider>().markAllNotificationsRead();
      if (mounted) _showSuccess(context, 'อ่านการแจ้งเตือนทั้งหมดแล้ว');
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final id = int.tryParse(_cleanText(notification['id']));
    if (id != null && notification['is_read'] != true) {
      setState(() => _busyIds.add(id));
      try {
        await context.read<AppProvider>().markNotificationRead(id);
      } catch (e) {
        if (mounted) _showError(context, e);
      } finally {
        if (mounted) setState(() => _busyIds.remove(id));
      }
    }

    if (!mounted) return;
    final data = asMap(notification['data']);
    final bookingRef = _cleanText(data['booking_ref']);
    final tripSlug = _cleanText(data['trip_slug']);

    if (bookingRef.isNotEmpty) {
      _pushPremium(context, PaymentScreen(bookingRef: bookingRef));
      return;
    }
    if (tripSlug.isNotEmpty) {
      _pushPremium(context, TripDetailScreen(slug: tripSlug));
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final id = int.tryParse(_cleanText(notification['id']));
    if (id == null) return;

    setState(() => _busyIds.add(id));
    try {
      await context.read<AppProvider>().deleteNotification(id);
      if (mounted) _showSuccess(context, 'ลบการแจ้งเตือนแล้ว');
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context
        .watch<AppProvider>()
        .notifications
        .map(asMap)
        .toList();
    final unread = notifications
        .where((item) => item['is_read'] != true)
        .length;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const TravelSliverAppBar(title: 'การแจ้งเตือน'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormCard(
                      title: 'สถานะการแจ้งเตือน',
                      subtitle: unread > 0
                          ? 'คุณมี $unread รายการใหม่ที่ยังไม่ได้อ่าน'
                          : 'คุณอ่านการแจ้งเตือนครบทุกรายการแล้ว',
                      children: [
                        FilledButton.icon(
                          onPressed: _saving || unread == 0
                              ? null
                              : _markAllRead,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.done_all_outlined),
                          label: const Text('ทำเครื่องหมายว่าอ่านทั้งหมด'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_loading && notifications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (notifications.isEmpty)
                      const _EmptyProfileState(
                        icon: Icons.notifications_none_outlined,
                        title: 'ยังไม่มีการแจ้งเตือน',
                        body:
                            'เมื่อมีการแจ้งเตือนใหม่ จะแสดงที่นี่',
                      )
                    else
                      for (final notification in notifications) ...[
                        _NotificationCard(
                          notification: notification,
                          busy: _busyIds.contains(
                            int.tryParse(_cleanText(notification['id'])),
                          ),
                          onTap: () => _openNotification(notification),
                          onDelete: () => _deleteNotification(notification),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.busy,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = _cleanText(notification['type']);
    final title = _cleanText(notification['title'], fallback: 'การแจ้งเตือน');
    final body = _cleanText(notification['body']);
    final unread = notification['is_read'] != true;
    final accent = _notificationColor(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.35)
                  : AppTheme.border(context),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: AppTheme.isDark(context)
                      ? (unread ? 0.22 : 0.16)
                      : (unread ? 0.07 : 0.04),
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_notificationIcon(type), color: accent, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.anuphan(
                              fontSize: 15,
                              fontWeight: unread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _notificationTimeAgo(notification['created_at']),
                          style: GoogleFonts.anuphan(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'ลบการแจ้งเตือน',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppTheme.textSecondary.withValues(alpha: 0.72),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
