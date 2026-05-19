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
                        _SwipableNotificationCard(
                          key: ValueKey(notification['id']),
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

class _SwipableNotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SwipableNotificationCard({
    super.key,
    required this.notification,
    required this.busy,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: busy ? (_) async => false : null,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              'ลบ',
              style: GoogleFonts.anuphan(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      child: _NotificationCard(
        notification: notification,
        busy: busy,
        onTap: onTap,
        onDelete: onDelete,
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
    final typeLabel = _notificationTypeLabel(type);
    final isDark = AppTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: unread
                ? (isDark
                    ? accent.withValues(alpha: 0.06)
                    : accent.withValues(alpha: 0.03))
                : AppTheme.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.4)
                  : AppTheme.border(context),
              width: unread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark
                      ? (unread ? 0.22 : 0.16)
                      : (unread ? 0.07 : 0.04),
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              if (unread)
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.10 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_notificationIcon(type), color: accent, size: 25),
                  ),
                  if (unread)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.surfaceDark : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.errorColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeLabel,
                            style: GoogleFonts.anuphan(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _notificationTimeAgo(notification['created_at']),
                          style: GoogleFonts.anuphan(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        fontSize: 15,
                        fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
              const SizedBox(width: 4),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'ลบการแจ้งเตือน',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppTheme.errorColor.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
