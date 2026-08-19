part of 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = false;
  bool _saving = false;
  bool _clearing = false;
  bool _unreadOnly = false;
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

  Future<void> _clearAll() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ลบการแจ้งเตือนทั้งหมด',
          style: appFont(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'การแจ้งเตือนทั้งหมดจะถูกลบและไม่สามารถกู้คืนได้ ต้องการดำเนินการต่อหรือไม่?',
          style: appFont(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: appFont()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(
              'ลบทั้งหมด',
              style: appFont(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await context.read<AppProvider>().clearAllNotifications();
      if (mounted) _showSuccess(context, 'ลบการแจ้งเตือนทั้งหมดแล้ว');
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _clearing = false);
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

    // ฟีดรูปหลังทริป: เปิดฟีดของทริปนั้น
    if (type == 'trip_post_liked' || type == 'trip_post_comment') {
      _pushPremium(
        context,
        TripFeedScreen(slug: tripSlug.isEmpty ? null : tripSlug),
      );
      return;
    }

    // แบ่งจ่ายกลุ่ม: เปิดหน้าชำระส่วนของตัวเองโดยตรง
    if (type == 'split_share_created' || type == 'split_share_reminder') {
      final shareId = int.tryParse(_cleanText(data['share_id'])) ?? 0;
      if (bookingRef.isNotEmpty && shareId != 0) {
        _pushPremium(
          context,
          PaymentScreen(bookingRef: bookingRef, splitShareId: shareId),
        );
        return;
      }
    }

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
    final visible = _unreadOnly
        ? notifications.where((item) => item['is_read'] != true).toList()
        : notifications;
    final groups = _groupNotifications(visible);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text(
          'การแจ้งเตือน',
          style: AppTheme.appBarTitleStyle(context),
        ),
        actions: [
          _NotificationHeaderActions(
            hasItems: notifications.isNotEmpty,
            unread: unread,
            saving: _saving,
            clearing: _clearing,
            onMarkAllRead: _markAllRead,
            onClearAll: _clearAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 0,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ตัวกรองแทนบรรทัด "N รายการที่ยังไม่ได้อ่าน" ที่เดิมเป็นแค่ข้อความ
            // บอกจำนวนเฉยๆ — ที่ว่างเท่ากันแต่กดใช้งานได้
            if (notifications.isNotEmpty)
              SliverToBoxAdapter(
                child: _NotificationFilterBar(
                  unread: unread,
                  unreadOnly: _unreadOnly,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _unreadOnly = value);
                  },
                ),
              ),
            if (_loading && notifications.isEmpty)
              const SliverToBoxAdapter(
                child: SkeletonList(count: 6, padding: EdgeInsets.only(top: 8)),
              )
            else if (notifications.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _NotificationsEmptyState(),
              )
            else if (groups.isEmpty)
              // กรองแล้วไม่เหลืออะไร — คนละเรื่องกับ "ยังไม่มีการแจ้งเตือน"
              const SliverToBoxAdapter(child: _AllCaughtUpNote())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (index > 0) const SizedBox(height: 22),
                        _NotificationSectionHeader(
                          label: group.label,
                          count: group.items.length,
                        ),
                        const SizedBox(height: 10),
                        _NotificationGroupCard(
                          items: group.items,
                          busyIds: _busyIds,
                          onTap: _openNotification,
                          onDelete: _deleteNotification,
                        ),
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

/// Header actions for the notifications screen: a "mark all read" pill (shown
/// while there are unread items) followed by a "clear all" button (shown
/// whenever any notification exists).
class _NotificationHeaderActions extends StatelessWidget {
  final bool hasItems;
  final int unread;
  final bool saving;
  final bool clearing;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;

  const _NotificationHeaderActions({
    required this.hasItems,
    required this.unread,
    required this.saving,
    required this.clearing,
    required this.onMarkAllRead,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MarkAllReadAction(
          visible: unread > 0,
          saving: saving,
          onPressed: onMarkAllRead,
        ),
        _ClearAllAction(
          visible: hasItems,
          clearing: clearing,
          onPressed: onClearAll,
        ),
      ],
    );
  }
}

class _ClearAllAction extends StatelessWidget {
  final bool visible;
  final bool clearing;
  final VoidCallback onPressed;

  const _ClearAllAction({
    required this.visible,
    required this.clearing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: !visible
          ? const SizedBox(width: 12, key: ValueKey('clear-empty'))
          : Padding(
              key: const ValueKey('clear-action'),
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'ลบการแจ้งเตือนทั้งหมด',
                child: Material(
                  color: AppTheme.errorColor.withValues(alpha: 0.10),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: clearing ? null : onPressed,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: clearing
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.errorColor,
                              ),
                            )
                          : const Icon(
                              Icons.delete_sweep_rounded,
                              size: 20,
                              color: AppTheme.errorColor,
                            ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
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
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                        style: appFont(
                          fontSize: AppText.sizeBody,
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
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: appFont(
              fontSize: AppText.sizeLabel,
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
              style: appFont(
                fontSize: AppText.sizeH2,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เมื่อมีอัปเดตการจอง การชำระเงิน หรือโปรโมชันใหม่ จะแสดงที่นี่',
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeBody,
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

/// ตัวกรอง ทั้งหมด / ยังไม่อ่าน แบบ segmented ตามที่หน้าอื่นในแอปใช้อยู่
class _NotificationFilterBar extends StatelessWidget {
  final int unread;
  final bool unreadOnly;
  final ValueChanged<bool> onChanged;

  const _NotificationFilterBar({
    required this.unread,
    required this.unreadOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            _FilterSegment(
              label: 'ทั้งหมด',
              selected: !unreadOnly,
              onTap: () => onChanged(false),
            ),
            _FilterSegment(
              label: 'ยังไม่อ่าน',
              badge: unread,
              selected: unreadOnly,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _FilterSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.primaryColor
        : AppTheme.mutedText(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            // แผ่นขาวเลื่อนมาทับช่องที่เลือก แบบ segmented control ของ iOS
            color: selected ? AppTheme.surface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                    color: color,
                  ),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.mutedText(context).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    '$badge',
                    style: appFont(
                      fontSize: AppText.sizeMicro,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? Colors.white
                          : AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ข้อความตอนกรอง "ยังไม่อ่าน" แล้วไม่เหลืออะไร — ไม่ใช้ [_NotificationsEmptyState]
/// เพราะอันนั้นบอกว่า "ยังไม่มีการแจ้งเตือน" ซึ่งไม่จริงในกรณีนี้
class _AllCaughtUpNote extends StatelessWidget {
  const _AllCaughtUpNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Column(
        children: [
          Icon(
            Icons.done_all_rounded,
            size: 36,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(height: 12),
          Text(
            'อ่านครบทุกรายการแล้ว',
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดเดียวต่อกลุ่มวัน โดยแต่ละรายการเป็นแถวข้างในคั่นด้วยเส้นบาง
///
/// เดิมทุกรายการเป็นการ์ดของตัวเองที่มีขอบและพื้นสีตามประเภท เลื่อนดูแล้วเป็น
/// สายรุ้ง — พอรวมเป็นการ์ดเดียว กรอบกับพื้นสีต่อแถวหายไปเอง เหลือสีอยู่ที่
/// ไอคอนกับป้ายหมวดซึ่งยังบอกประเภทได้เหมือนเดิม
class _NotificationGroupCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Set<int> busyIds;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _NotificationGroupCard({
    required this.items,
    required this.busyIds,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface(context),
      // ตัดขอบให้พื้นแดงตอนปัดลบโค้งตามการ์ด ไม่โผล่เป็นสี่เหลี่ยมทับมุม
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                // เยื้องให้เริ่มตรงกับตัวหนังสือ ไม่ตัดผ่านแผ่นไอคอน
                indent: 85,
                color: AppTheme.border(context).withValues(alpha: 0.5),
              ),
            _SwipableNotificationRow(
              key: ValueKey(items[i]['id']),
              notification: items[i],
              busy: busyIds.contains(
                int.tryParse(_cleanText(items[i]['id'])),
              ),
              onTap: () => onTap(items[i]),
              onDelete: () => onDelete(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwipableNotificationRow extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SwipableNotificationRow({
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
        color: AppTheme.errorColor,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              'ลบ',
              style: appFont(
                color: Colors.white,
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      child: _NotificationRow(
        notification: notification,
        busy: busy,
        onTap: onTap,
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool busy;
  final VoidCallback onTap;

  const _NotificationRow({
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
      // พื้นของแถวที่ยังไม่อ่านเป็นสีกลาง ไม่ใช่สีตามประเภท — ในการ์ดใบเดียว
      // พื้นสีต่อแถวจะอ่านเป็นแถบลายพาดขวาง สีประจำประเภทยังอยู่ที่จุด ไอคอน
      // และป้ายหมวดเหมือนเดิม
      color: unread
          ? (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : AppTheme.subtleSurface(context))
          : AppTheme.surface(context),
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
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
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _notificationTimeAgo(notification['created_at']),
                          style: appFont(
                            fontSize: AppText.sizeCaption,
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
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
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
                        style: appFont(
                          fontSize: AppText.sizeBody,
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
