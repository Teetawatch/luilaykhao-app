part of 'customer_app_screen.dart';

class _Chip extends StatelessWidget {
  final String text;

  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppTheme.accentColor,
      'pending' => AppTheme.warningColor,
      'cancelled' => AppTheme.errorColor,
      _ => AppTheme.primaryColor,
    };
    final label = switch (status) {
      'confirmed' => 'ยืนยันแล้ว',
      'pending' => 'รอชำระ',
      'paid' => 'ชำระแล้ว',
      'cancelled' => 'ยกเลิก',
      'completed' => 'จบทริป',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

String textOf(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String money(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '');
  if (number == null) return _moneyFormat.format(0);
  return _moneyFormat.format(number);
}

String numberText(dynamic value, {String fallback = '0'}) {
  final number = num.tryParse(value?.toString() ?? '');
  if (number == null) return fallback;
  return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 1);
}

bool _scheduleInstallmentAvailable(Map<String, dynamic> schedule) {
  return _asBool(schedule['installment_enabled']);
}

bool _scheduleDepositAvailable(Map<String, dynamic> schedule) {
  if (!_asBool(schedule['deposit_enabled'])) return false;
  final type = (schedule['deposit_type']?.toString() ?? '').toLowerCase();
  if (type == 'percent') {
    final percent = num.tryParse(schedule['deposit_percent']?.toString() ?? '0') ?? 0;
    return percent > 0;
  }
  if (type == 'amount') {
    final amount = num.tryParse(schedule['deposit_amount']?.toString() ?? '0') ?? 0;
    return amount > 0;
  }
  return false;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String dateText(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '-';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  return DateFormat('d MMM yyyy', 'th_TH').format(date);
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: hint),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('ตกลง'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result == null || result.isEmpty ? null : result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SheetSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SheetSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.anuphan(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppTheme.onSurface(context),
          ),
        ),
      ],
    );
  }
}

class _InlineBadge extends StatelessWidget {
  final String text;

  const _InlineBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.anuphan(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// In-app foreground notification banner
// ---------------------------------------------------------------------------

class _InAppNotification {
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;

  const _InAppNotification({
    required this.title,
    required this.body,
    required this.type,
    required this.data,
  });
}

class _InAppNotificationBanner extends StatefulWidget {
  final _InAppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppNotificationBanner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  IconData _icon() {
    return switch (widget.notification.type) {
      'payment' || 'payment_confirmed' || 'installment_due' =>
        Icons.payments_rounded,
      'payment_rejected' => Icons.money_off_rounded,
      'booking' || 'booking_confirmed' => Icons.confirmation_number_rounded,
      'booking_cancelled' => Icons.cancel_rounded,
      'booking_reminder' || 'trip_reminder' => Icons.calendar_month_rounded,
      'seat_alert' => Icons.local_fire_department_rounded,
      'sos_alert' => Icons.sos_rounded,
      'promo' => Icons.card_giftcard_rounded,
      'loyalty' => Icons.star_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  Color _accentColor(bool isDark) {
    return switch (widget.notification.type) {
      'seat_alert' || 'payment_rejected' || 'booking_cancelled' ||
      'sos_alert' =>
        AppTheme.errorColor,
      'booking_reminder' || 'trip_reminder' => const Color(0xFF2563EB),
      'promo' => AppTheme.warningColor,
      'loyalty' => const Color(0xFFEA580C),
      'installment_due' => const Color(0xFFD97706),
      _ => AppTheme.primaryColor,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = _accentColor(isDark);
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 8,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: GestureDetector(
              onTap: () async {
                await _controller.reverse();
                widget.onTap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceDark.withValues(alpha: 0.97)
                      : Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.45 : 0.12,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon(), color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.notification.title.isNotEmpty)
                            Text(
                              widget.notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textMain,
                              ),
                            ),
                          if (widget.notification.body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
