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
    final muted = AppTheme.mutedText(context);

    // Apple-style empty state: a single soft-tinted glyph, a concise bold
    // headline, and a lighter one-line explainer — all centred with generous
    // breathing room (HIG: clear, calm, plenty of negative space).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.07),
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppTheme.primaryColor.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
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

/// Maps a backend category `icon` (a Google Material Symbols name, set freely by
/// admins) to a Flutter [IconData]. Flutter can't resolve icon fonts by name at
/// runtime, so we translate the common symbols the admin picker offers and fall
/// back to a neutral activity glyph for anything unmapped.
IconData categoryIcon(String? name) {
  switch (name?.trim()) {
    case 'hiking':
      return Icons.hiking_rounded;
    case 'forest':
      return Icons.forest_rounded;
    case 'terrain':
      return Icons.terrain_rounded;
    case 'landscape':
      return Icons.landscape_rounded;
    case 'park':
    case 'nature':
      return Icons.park_rounded;
    case 'eco':
      return Icons.eco_rounded;
    case 'camping':
    case 'cabin':
      return Icons.cabin_rounded;
    case 'scuba_diving':
      return Icons.scuba_diving_rounded;
    case 'waves':
    case 'water':
      return Icons.waves_rounded;
    case 'pool':
      return Icons.pool_rounded;
    case 'surfing':
      return Icons.surfing_rounded;
    case 'kayaking':
      return Icons.kayaking_rounded;
    case 'sailing':
      return Icons.sailing_rounded;
    case 'directions_boat':
      return Icons.directions_boat_rounded;
    case 'beach_access':
      return Icons.beach_access_rounded;
    case 'phishing':
      return Icons.phishing_rounded;
    case 'set_meal':
      return Icons.set_meal_rounded;
    case 'downhill_skiing':
      return Icons.downhill_skiing_rounded;
    case 'snowboarding':
      return Icons.snowboarding_rounded;
    case 'paragliding':
      return Icons.paragliding_rounded;
    case 'pedal_bike':
      return Icons.pedal_bike_rounded;
    case 'directions_bike':
      return Icons.directions_bike_rounded;
    case 'airport_shuttle':
      return Icons.airport_shuttle_rounded;
    case 'directions_bus':
      return Icons.directions_bus_rounded;
    case 'local_taxi':
      return Icons.local_taxi_rounded;
    case 'directions_car':
      return Icons.directions_car_rounded;
    case 'two_wheeler':
      return Icons.two_wheeler_rounded;
    case 'flight':
      return Icons.flight_rounded;
    case 'train':
      return Icons.train_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'hotel':
      return Icons.hotel_rounded;
    case 'temple_buddhist':
      return Icons.temple_buddhist_rounded;
    case 'festival':
      return Icons.festival_rounded;
    case 'photo_camera':
      return Icons.photo_camera_rounded;
    case 'map':
      return Icons.map_rounded;
    case 'explore':
      return Icons.explore_rounded;
    case 'groups':
      return Icons.groups_rounded;
    case 'stars':
    case 'star':
      return Icons.star_rounded;
    case 'shield_person':
    case 'shield':
      return Icons.shield_rounded;
    case 'verified_user':
      return Icons.verified_user_rounded;
    case 'badge':
      return Icons.badge_rounded;
    case 'schedule':
      return Icons.schedule_rounded;
    default:
      return Icons.local_activity_rounded;
  }
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
          style: appFont(
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
        style: appFont(
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
                              style: appFont(
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
                              style: appFont(
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
