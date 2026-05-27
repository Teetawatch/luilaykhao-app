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
    HapticFeedback.lightImpact();
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
    HapticFeedback.selectionClick();
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
    final type = _cleanText(notification['type']);
    final data = asMap(notification['data']);

    if (type == 'sos_alert') {
      final alert = SosAlert.fromNotificationData(data);
      _pushPremium(context, SosAlertScreen(alert: alert));
      return;
    }

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

    HapticFeedback.mediumImpact();
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
    final topPadding = MediaQuery.paddingOf(context).top;
    final groups = _groupNotifications(notifications);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: topPadding + 60,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            LargeTitleSliverHeader(
              title: 'การแจ้งเตือน',
              subtitle: unread > 0
                  ? '$unread รายการที่ยังไม่ได้อ่าน'
                  : 'อ่านครบทุกรายการแล้ว',
              subtitleColor: unread > 0
                  ? AppTheme.primaryColor
                  : AppTheme.mutedText(context),
              trailing: _MarkAllReadAction(
                visible: unread > 0,
                saving: _saving,
                onPressed: _markAllRead,
              ),
            ),
            if (_loading && notifications.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              )
            else if (notifications.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _NotificationsEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                sliver: SliverList.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (index > 0) const SizedBox(height: 18),
                        _NotificationSectionHeader(
                          label: group.label,
                          count: group.items.length,
                        ),
                        const SizedBox(height: 10),
                        for (final notification in group.items) ...[
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

/// Buckets notifications into iOS-style time sections, preserving the
/// newest-first order returned by the API.
List<_NotificationGroup> _groupNotifications(
  List<Map<String, dynamic>> notifications,
) {
  const order = ['วันนี้', 'เมื่อวาน', 'สัปดาห์นี้', 'ก่อนหน้านี้'];
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final notification in notifications) {
    final label = _notificationGroupLabel(notification['created_at']);
    buckets.putIfAbsent(label, () => []).add(notification);
  }
  return [
    for (final label in order)
      if (buckets[label] != null)
        _NotificationGroup(label: label, items: buckets[label]!),
  ];
}

String _notificationGroupLabel(dynamic value) {
  final date = DateTime.tryParse(_cleanText(value))?.toLocal();
  if (date == null) return 'ก่อนหน้านี้';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'วันนี้';
  if (diff == 1) return 'เมื่อวาน';
  if (diff < 7) return 'สัปดาห์นี้';
  return 'ก่อนหน้านี้';
}

class _NotificationGroup {
  final String label;
  final List<Map<String, dynamic>> items;

  const _NotificationGroup({required this.label, required this.items});
}

class _MarkAllReadAction extends StatelessWidget {
  final bool visible;
  final bool saving;
  final VoidCallback onPressed;

  const _MarkAllReadAction({
    required this.visible,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: !visible
          ? const SizedBox(width: 12, key: ValueKey('empty'))
          : Padding(
              key: const ValueKey('action'),
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: saving ? null : onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Text(
                        'อ่านทั้งหมด',
                        style: GoogleFonts.anuphan(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
    );
  }
}

class _NotificationSectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _NotificationSectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.anuphan(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: GoogleFonts.anuphan(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context).withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'ยังไม่มีการแจ้งเตือน',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เมื่อมีอัปเดตการจอง การชำระเงิน หรือโปรโมชันใหม่ จะแสดงที่นี่',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
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
        padding: const EdgeInsets.only(right: 26),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            const SizedBox(height: 3),
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
      child: _NotificationCard(notification: notification, busy: busy, onTap: onTap),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool busy;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.busy,
    required this.onTap,
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
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
          decoration: BoxDecoration(
            color: unread
                ? Color.alphaBlend(
                    accent.withValues(alpha: isDark ? 0.10 : 0.045),
                    AppTheme.surface(context),
                  )
                : AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: isDark ? 0.30 : 0.18)
                  : AppTheme.border(context).withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread dot (iOS Mail style) — reserves space when read.
              SizedBox(
                width: 14,
                child: unread
                    ? Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_notificationIcon(type), color: accent, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            typeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.anuphan(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _notificationTimeAgo(notification['created_at']),
                          style: GoogleFonts.anuphan(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        fontSize: 15.5,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                        height: 1.2,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.mutedText(context).withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
