part of 'profile_screen.dart';

class _IdentityPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _IdentityPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: appFont(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;

  const _SectionHeading(this.title);

  @override
  Widget build(BuildContext context) {
    // Apple Settings–style inset group label: muted, semibold, tighter letter
    // spacing so it reads as a section header rather than a content title.
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2),
      child: Text(
        title,
        style: appFont(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedText(context),
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _FormCard({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _sectionDecoration(context: context, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: appFont(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: appFont(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _EditableProfilePhoto extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String? localImagePath;
  final VoidCallback onPick;

  const _EditableProfilePhoto({
    required this.name,
    required this.imageUrl,
    required this.localImagePath,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'ล' : name.trim().characters.first;

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: localImagePath != null
                      ? Image.file(File(localImagePath!), fit: BoxFit.cover)
                      : imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => ColoredBox(
                            color: AppTheme.outlineColor.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          errorWidget: (_, _, _) =>
                              _AvatarInitial(initial: initial),
                        )
                      : _AvatarInitial(initial: initial),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 4,
                child: Material(
                  color: AppTheme.primaryColor,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    onTap: onPick,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('เปลี่ยนรูปโปรไฟล์'),
          ),
        ],
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;

  const _AvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initial,
          style: appFont(
            color: AppTheme.primaryColor,
            fontSize: 38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AvatarSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AvatarSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.fieldSurface(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: appFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;
  final String? Function(String?)? validator;
  final int? maxLength;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.validator,
    this.maxLength,
  });

  @override
  State<_ProfileTextField> createState() => _ProfileTextFieldState();
}

class _ProfileTextFieldState extends State<_ProfileTextField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      obscureText: widget.obscureText && !_visible,
      validator: widget.validator,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, size: 20),
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              )
            : null,
        filled: true,
        fillColor: AppTheme.fieldSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      style: appFont(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMain,
      ),
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyProfileState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _sectionDecoration(context: context, radius: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 26, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: appFont(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppTheme.primaryColor,
      'pending' => AppTheme.warningColor,
      'cancelled' || 'refunded' => AppTheme.errorColor,
      _ => AppTheme.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: appFont(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const effectiveColor = AppTheme.primaryColor;
    return ActionChip(
      avatar: Icon(icon, size: 17, color: effectiveColor),
      label: Text(label),
      onPressed: onTap,
      labelStyle: appFont(
        color: effectiveColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      backgroundColor: effectiveColor.withValues(alpha: 0.08),
      side: BorderSide(color: effectiveColor.withValues(alpha: 0.14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = _numberValue(review['rating']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(context: context, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _cleanText(review['trip_title'], fallback: 'ทริปของคุณ'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < rating ? Icons.star_rounded : Icons.star_border,
                    color: AppTheme.warningColor,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateText(review['created_at']),
                style: appFont(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          if (_cleanText(review['comment']).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _cleanText(review['comment']),
              style: appFont(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _sectionDecoration(context: context, radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: appFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: appFont(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
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

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _HelpTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _sectionDecoration(context: context, radius: 22),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: appFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: appFont(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? trailing;
  final Widget? trailingWidget;
  final bool showChevron;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.trailingWidget,
    this.showChevron = true,
    required this.onTap,
  });
}

BoxDecoration _sectionDecoration({BuildContext? context, double radius = 24}) {
  if (context != null) {
    return AppTheme.cardDecoration(context, radius: radius);
  }

  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppTheme.outlineColor.withValues(alpha: 0.55)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _cleanText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _notificationTypeLabel(String type) {
  return switch (type) {
    'booking' || 'booking_confirmed' => 'การจอง',
    'booking_cancelled' => 'ยกเลิกการจอง',
    'booking_reminder' || 'trip_reminder' => 'แจ้งเตือนทริป',
    'payment' || 'payment_confirmed' => 'การชำระเงิน',
    'payment_rejected' => 'ชำระเงินไม่สำเร็จ',
    'installment_due' => 'ผ่อนชำระ',
    'seat_alert' => 'ที่นั่งใกล้เต็ม',
    'sos_alert' => 'SOS ฉุกเฉิน',
    'promo' => 'โปรโมชัน',
    'system' => 'ระบบ',
    'loyalty' => 'คะแนนสะสม',
    'vehicle_approaching' => 'รถใกล้ถึงแล้ว',
    _ => 'การแจ้งเตือน',
  };
}

IconData _notificationIcon(String type) {
  return switch (type) {
    'seat_alert' => Icons.local_fire_department_rounded,
    'sos_alert' => Icons.sos_rounded,
    'booking_reminder' || 'trip_reminder' => Icons.calendar_month_rounded,
    'promo' => Icons.card_giftcard_rounded,
    'system' => Icons.info_outline_rounded,
    'loyalty' => Icons.star_rounded,
    'payment' ||
    'payment_confirmed' ||
    'payment_rejected' => Icons.payments_rounded,
    'installment_due' => Icons.schedule_rounded,
    'booking' || 'booking_confirmed' => Icons.confirmation_number_rounded,
    'booking_cancelled' => Icons.cancel_rounded,
    'vehicle_approaching' => Icons.directions_bus_rounded,
    _ => Icons.notifications_none_rounded,
  };
}

Color _notificationColor(String type) {
  return switch (type) {
    'seat_alert' => AppTheme.errorColor,
    'sos_alert' => const Color(0xFFE11D48),
    'booking_reminder' || 'trip_reminder' => const Color(0xFF2563EB),
    'promo' => AppTheme.warningColor,
    'system' => AppTheme.textSecondary,
    'loyalty' => const Color(0xFFEA580C),
    'payment' || 'payment_confirmed' => AppTheme.primaryColor,
    'payment_rejected' || 'booking_cancelled' => AppTheme.errorColor,
    'installment_due' => const Color(0xFFD97706),
    'booking' || 'booking_confirmed' => AppTheme.primaryColor,
    'vehicle_approaching' => const Color(0xFF2563EB),
    _ => AppTheme.primaryColor,
  };
}

String _notificationTimeAgo(dynamic value) {
  final raw = _cleanText(value);
  if (raw.isEmpty) return '';

  final date = DateTime.tryParse(raw);
  if (date == null) return raw;

  final diff = DateTime.now().difference(date.toLocal());
  if (diff.inMinutes < 1) return 'เมื่อกี้';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  return dateText(raw);
}

String? _cleanLocation(dynamic value) {
  final location = _cleanText(value);
  if (location.isEmpty) return null;

  const placeholders = {
    'San Francisco, CA',
    'San Francisco',
    'CA',
    'Unknown',
    'ไม่ระบุ',
  };

  return placeholders.contains(location) ? null : location;
}

String? _nullableText(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}

String? Function(String?) _required(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}

/// Parse a stored birth date ('YYYY-MM-DD' or ISO timestamp) into a date, or null.
DateTime? _parseProfileBirthDate(dynamic value) {
  final raw = _cleanText(value);
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}

/// Format a date as the 'YYYY-MM-DD' string the API expects, or null.
String? _formatProfileBirthDate(DateTime? date) {
  if (date == null) return null;
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

const _profileThaiMonths = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// Human label "15 ม.ค. 2543 · อายุ 25 ปี" (Buddhist era year + computed age).
String _profileBirthDateLabel(DateTime date) {
  final now = DateTime.now();
  var age = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    age--;
  }
  return '${date.day} ${_profileThaiMonths[date.month - 1]} ${date.year + 543} · อายุ $age ปี';
}

/// Tap-to-pick birth date field styled to match [_ProfileTextField].
class _ProfileDateField extends StatelessWidget {
  final DateTime? value;
  final String label;
  final IconData icon;
  final ValueChanged<DateTime> onPicked;

  const _ProfileDateField({
    required this.value,
    required this.label,
    required this.icon,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(now.year - 25, now.month, now.day),
          firstDate: DateTime(now.year - 100),
          lastDate: now,
          helpText: 'เลือกวัน/เดือน/ปีเกิด',
        );
        if (picked != null) {
          onPicked(DateTime(picked.year, picked.month, picked.day));
        }
      },
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
          filled: true,
          fillColor: AppTheme.fieldSurface(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        child: value == null
            ? null
            : Text(
                _profileBirthDateLabel(value!),
                style: appFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
      ),
    );
  }
}

int _numberValue(dynamic value, {int fallback = 0}) {
  final number = num.tryParse(value?.toString() ?? '');
  return number?.round() ?? fallback;
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = _cleanText(value).toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

String _formatCompact(int value) {
  if (value >= 1000000) {
    final compact = value / 1000000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}k';
  }
  return value.toString();
}

bool _isTripToday(Map<String, dynamic> booking) {
  final status = _cleanText(booking['status']).toLowerCase();
  if (status == 'cancelled' || status == 'refunded' || status == 'completed') {
    return false;
  }
  final schedule = asMap(booking['schedule']);
  // ใช้วันออกรถจริง — รอบที่รถออกคืนก่อนวันทริปถือว่า "เดินทางวันนี้"
  // ตั้งแต่วันที่รถออก
  final date = scheduleDepartsAt(schedule) ??
      DateTime.tryParse(_cleanText(schedule['departure_date']));
  if (date == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(date.year, date.month, date.day) == today;
}

bool _isUpcomingBooking(Map<String, dynamic> booking) {
  final status = _cleanText(booking['status']).toLowerCase();
  if (status == 'cancelled' || status == 'refunded' || status == 'completed') {
    return false;
  }

  final schedule = asMap(booking['schedule']);
  final date = scheduleDepartsAt(schedule) ??
      DateTime.tryParse(_cleanText(schedule['departure_date']));
  if (date == null) {
    return status == 'pending' || status == 'confirmed';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return !DateTime(date.year, date.month, date.day).isBefore(today);
}

bool _isPastBooking(Map<String, dynamic> booking) {
  final status = _cleanText(booking['status']).toLowerCase();
  if (status == 'completed') return true;
  if (status == 'cancelled' || status == 'refunded') return false;

  final schedule = asMap(booking['schedule']);
  final rawReturn = _cleanText(
    schedule['return_date'],
    fallback: _cleanText(schedule['departure_date']),
  );
  final date = DateTime.tryParse(rawReturn);
  if (date == null) return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(date.year, date.month, date.day).isBefore(today);
}

String _travelDateText(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  if (dateText(schedule['departure_date']) == '-') return 'รอระบุวันเดินทาง';
  // ใช้วัน-เวลาออกรถจริงเป็นจุดเริ่มต้นเมื่อรอบนั้นกำหนดไว้
  final start = departureText(schedule);
  final end = dateText(schedule['return_date']);
  if (end == '-' || end == start) return start;
  return '$start - $end';
}

String _statusLabel(String status) {
  return switch (status) {
    'confirmed' => 'ยืนยันแล้ว',
    'pending' => 'รอชำระ',
    'cancelled' => 'ยกเลิก',
    'refunded' => 'คืนเงินแล้ว',
    'completed' => 'จบทริป',
    _ => status.isEmpty ? 'ไม่ระบุ' : status,
  };
}

/// Maps a loyalty tier code from the backend (regular/silver/gold) to its
/// Thai display label. Falls back to the raw value for any future tier.
String _loyaltyTierLabel(String tier) {
  return switch (tier.toLowerCase()) {
    'regular' => 'สมาชิกทั่วไป',
    'silver' => 'ระดับเงิน',
    'gold' => 'ระดับทอง',
    'platinum' => 'ระดับแพลทินัม',
    _ => tier,
  };
}

void _pushPremium(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, animation, _) => screen,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

Future<void> _openTrackingForBooking(
  BuildContext context,
  Map<String, dynamic> booking,
) async {
  final ref = _cleanText(booking['booking_ref']);
  if (ref.isEmpty) {
    _showError(context, 'ไม่พบเลขการจองสำหรับติดตามรถ');
    return;
  }

  final app = context.read<AppProvider>();
  final provider = context.read<TrackingProvider>();

  provider.stopTracking();
  await provider.startTracking(ref, authToken: app.token);
  if (!context.mounted) return;

  if (provider.errorMessage.isNotEmpty || provider.booking == null) {
    _showError(
      context,
      provider.errorMessage.isNotEmpty
          ? provider.errorMessage
          : 'ไม่พบข้อมูลติดตามรถของการจองนี้',
    );
    return;
  }

  final unavailableMessage = _trackingUnavailableMessage(provider.booking);
  if (unavailableMessage != null) {
    provider.stopTracking();
    _showError(context, unavailableMessage);
    return;
  }

  _pushPremium(context, const TrackingMapPage());
}

String? _trackingUnavailableMessage(dynamic booking) {
  final status = booking.status.toString().toLowerCase();
  if (status == 'completed' || status == 'cancelled' || status == 'refunded') {
    return 'การติดตามรถของทริปนี้สิ้นสุดแล้ว';
  }

  final tripDate = DateTime.tryParse(booking.departureDate.toString());
  if (tripDate == null) return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(tripDate.year, tripDate.month, tripDate.day);
  if (date.isAfter(today)) return 'สามารถติดตามรถได้ในวันเดินทาง';
  if (date.isBefore(today)) return 'การติดตามรถของทริปนี้สิ้นสุดแล้ว';
  return null;
}

Future<void> _showLanguagePicker(BuildContext context) async {
  final app = context.read<AppProvider>();
  final selected = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'เลือกภาษา',
                style: appFont(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final option in const [('th', 'ภาษาไทย'), ('en', 'English')])
              ListTile(
                leading: Icon(
                  app.locale.languageCode == option.$1
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: app.locale.languageCode == option.$1
                      ? AppTheme.primaryColor
                      : AppTheme.mutedText(sheetContext),
                ),
                title: Text(
                  option.$2,
                  style: appFont(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.of(sheetContext).pop(option.$1),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
  if (selected == null) return;
  await app.setLocale(Locale(selected));
}

void _showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: appFont(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
}

void _showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : error.toString();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: appFont(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.errorColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
}
