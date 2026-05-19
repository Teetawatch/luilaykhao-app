part of 'profile_screen.dart';

class StaffDashboardSection extends StatefulWidget {
  final AppProvider app;

  const StaffDashboardSection({super.key, required this.app});

  @override
  State<StaffDashboardSection> createState() => _StaffDashboardSectionState();
}

class _StaffDashboardSectionState extends State<StaffDashboardSection> {
  bool _loading = false;
  bool _expanded = true;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.app.loadStaffSchedules();
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedules = widget.app.staffSchedules.map((e) => asMap(e)).toList();
    final summary = widget.app.staffSummary;

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final todaySchedules = schedules
        .where((s) => _cleanText(s['departure_date']) == todayStr)
        .toList();
    final upcomingSchedules = schedules
        .where((s) {
          final d = _cleanText(s['departure_date']);
          return d.isNotEmpty && d.compareTo(todayStr) > 0;
        })
        .toList();
    final pastSchedules = schedules
        .where((s) {
          final d = _cleanText(s['return_date'], fallback: _cleanText(s['departure_date']));
          return d.isNotEmpty && d.compareTo(todayStr) < 0;
        })
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StaffSectionHeader(
          summary: summary,
          expanded: _expanded,
          loading: _loading,
          onToggle: () => setState(() => _expanded = !_expanded),
          onRefresh: _refresh,
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          _StaffSummaryRow(summary: summary, totalSchedules: schedules.length),
          if (todaySchedules.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _StaffGroupLabel(label: 'วันนี้', color: Color(0xFFDC2626)),
            const SizedBox(height: 8),
            for (final s in todaySchedules) ...[
              _StaffScheduleCard(schedule: s, isToday: true),
              const SizedBox(height: 10),
            ],
          ],
          if (upcomingSchedules.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _StaffGroupLabel(label: 'กำลังจะมาถึง', color: Color(0xFF2563EB)),
            const SizedBox(height: 8),
            for (final s in upcomingSchedules) ...[
              _StaffScheduleCard(schedule: s),
              const SizedBox(height: 10),
            ],
          ],
          if (pastSchedules.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _StaffGroupLabel(label: 'ผ่านมาแล้ว', color: Color(0xFF6B7280)),
            const SizedBox(height: 8),
            for (final s in pastSchedules.take(3)) ...[
              _StaffScheduleCard(schedule: s),
              const SizedBox(height: 10),
            ],
          ],
          if (schedules.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: _sectionDecoration(context: context, radius: 22),
              child: Column(
                children: [
                  Icon(Icons.work_outline, size: 40, color: AppTheme.mutedText(context)),
                  const SizedBox(height: 12),
                  Text(
                    'ยังไม่มีงานที่ได้รับมอบหมาย',
                    style: GoogleFonts.anuphan(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'งานที่ได้รับมอบหมายจากแอดมินจะปรากฏที่นี่',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.anuphan(
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
      ],
    );
  }
}

class _StaffSectionHeader extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool expanded;
  final bool loading;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;

  const _StaffSectionHeader({
    required this.summary,
    required this.expanded,
    required this.loading,
    required this.onToggle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onToggle,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'งานสตาฟ',
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppTheme.mutedText(context),
                ),
              ],
            ),
          ),
        ),
        if (loading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            onPressed: onRefresh,
            icon: Icon(Icons.refresh, size: 20, color: AppTheme.mutedText(context)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }
}

class _StaffSummaryRow extends StatelessWidget {
  final Map<String, dynamic> summary;
  final int totalSchedules;

  const _StaffSummaryRow({required this.summary, required this.totalSchedules});

  @override
  Widget build(BuildContext context) {
    final totalReviews = _numberValue(summary['total_reviews']);
    final avgRating = summary['avg_rating'] != null
        ? double.tryParse(summary['avg_rating'].toString()) ?? 0.0
        : 0.0;
    final totalSchedules = _numberValue(summary['total_schedules'], fallback: this.totalSchedules);
    final upcomingCount = _numberValue(summary['upcoming_count']);

    return Row(
      children: [
        Expanded(
          child: _StaffStatBox(
            icon: Icons.calendar_today_outlined,
            value: totalSchedules.toString(),
            label: 'งานทั้งหมด',
            color: const Color(0xFF0D9488),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StaffStatBox(
            icon: Icons.upcoming_outlined,
            value: upcomingCount.toString(),
            label: 'กำลังจะมาถึง',
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StaffStatBox(
            icon: Icons.star_rounded,
            value: totalReviews == 0 ? '-' : avgRating.toStringAsFixed(1),
            label: 'คะแนนเฉลี่ย',
            color: AppTheme.warningColor,
          ),
        ),
      ],
    );
  }
}

class _StaffStatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StaffStatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.anuphan(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffGroupLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _StaffGroupLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.anuphan(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _StaffScheduleCard extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final bool isToday;

  const _StaffScheduleCard({required this.schedule, this.isToday = false});

  @override
  State<_StaffScheduleCard> createState() => _StaffScheduleCardState();
}

class _StaffScheduleCardState extends State<_StaffScheduleCard> {
  bool _pickupsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final trip = _toMap(s['trip']);
    final vehicle = s['vehicle'] != null ? _toMap(s['vehicle']) : null;

    final tripTitle = _cleanText(trip['title'], fallback: 'ไม่ระบุทริป');
    final location = _cleanText(trip['location']);
    final departureDate = _cleanText(s['departure_date']);
    final returnDate = _cleanText(s['return_date']);
    final status = _cleanText(s['status']);
    final totalConfirmed = _numberValue(s['total_confirmed']);
    final checkedIn = _numberValue(s['checked_in_count']);
    final totalSeats = _numberValue(s['total_seats']);
    final pickupBreakdown = (s['pickup_breakdown'] as List? ?? []).map(_toMap).toList();
    final noPickupCount = _numberValue(s['no_pickup_count']);

    final checkinProgress = totalConfirmed > 0
        ? (checkedIn / totalConfirmed).clamp(0.0, 1.0)
        : 0.0;

    final dateText = _staffDateRange(departureDate, returnDate);
    final vehicleName = vehicle != null ? _cleanText(vehicle['name']) : '';

    final accentColor = widget.isToday ? const Color(0xFFDC2626) : const Color(0xFF0D9488);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isToday
              ? const Color(0xFFDC2626).withValues(alpha: 0.25)
              : AppTheme.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isToday)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'วันนี้',
                                style: GoogleFonts.anuphan(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          Text(
                            tripTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.anuphan(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 13, color: AppTheme.textSecondary),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.anuphan(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StaffScheduleStatusBadge(status: status),
                  ],
                ),

                const SizedBox(height: 12),

                // Date & Vehicle row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StaffInfoChip(
                      icon: Icons.calendar_month_outlined,
                      label: dateText,
                      color: accentColor,
                    ),
                    if (vehicleName.isNotEmpty)
                      _StaffInfoChip(
                        icon: Icons.directions_bus_outlined,
                        label: vehicleName,
                        color: AppTheme.textSecondary,
                      ),
                    if (totalSeats > 0)
                      _StaffInfoChip(
                        icon: Icons.event_seat_outlined,
                        label: '$totalSeats ที่นั่ง',
                        color: AppTheme.textSecondary,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Check-in progress
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code_scanner, size: 15, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          'QR Check-in',
                          style: GoogleFonts.anuphan(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          totalConfirmed == 0
                              ? 'ยังไม่มีผู้โดยสาร'
                              : '$checkedIn / $totalConfirmed คน',
                          style: GoogleFonts.anuphan(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    if (totalConfirmed > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: checkinProgress,
                          color: checkinProgress >= 1.0
                              ? AppTheme.primaryColor
                              : accentColor,
                          backgroundColor: accentColor.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkedIn == totalConfirmed
                            ? 'เช็คอินครบแล้ว'
                            : 'เหลือ ${totalConfirmed - checkedIn} คน ยังไม่เช็คอิน',
                        style: GoogleFonts.anuphan(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),

                // Pickup breakdown
                if (pickupBreakdown.isNotEmpty || noPickupCount > 0) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _pickupsExpanded = !_pickupsExpanded),
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined, size: 15, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          'จุดรับผู้โดยสาร',
                          style: GoogleFonts.anuphan(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _pickupsExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: AppTheme.mutedText(context),
                        ),
                      ],
                    ),
                  ),
                  if (_pickupsExpanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.subtleSurface(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < pickupBreakdown.length; i++) ...[
                            _PickupPointRow(point: pickupBreakdown[i]),
                            if (i < pickupBreakdown.length - 1 ||
                                noPickupCount > 0)
                              Divider(
                                height: 12,
                                color: AppTheme.border(context).withValues(alpha: 0.5),
                              ),
                          ],
                          if (noPickupCount > 0)
                            _PickupPointRow(
                              point: {
                                'label': 'ไม่ระบุจุดรับ',
                                'passenger_count': noPickupCount,
                              },
                              isDefault: true,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // Footer action
          if (widget.isToday || status == 'confirmed' || status == 'active')
            _StaffScheduleAction(schedule: s),
        ],
      ),
    );
  }
}

class _PickupPointRow extends StatelessWidget {
  final Map<String, dynamic> point;
  final bool isDefault;

  const _PickupPointRow({required this.point, this.isDefault = false});

  @override
  Widget build(BuildContext context) {
    final label = _cleanText(point['label'], fallback: 'จุดรับไม่ระบุ');
    final regionLabel = _cleanText(point['region_label']);
    final showRegion = !isDefault && regionLabel.isNotEmpty && regionLabel != label;
    final count = _numberValue(point['passenger_count']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            isDefault ? Icons.help_outline : Icons.trip_origin,
            size: 14,
            color: isDefault ? AppTheme.textSecondary : const Color(0xFF0D9488),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDefault ? AppTheme.textSecondary : AppTheme.textMain,
                ),
              ),
              if (showRegion)
                Text(
                  regionLabel,
                  style: GoogleFonts.anuphan(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count คน',
            style: GoogleFonts.anuphan(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0D9488),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffScheduleAction extends StatelessWidget {
  final Map<String, dynamic> schedule;

  const _StaffScheduleAction({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.border(context).withValues(alpha: 0.6)),
        ),
      ),
      child: InkWell(
        onTap: () => _pushPremium(context, const StaffCheckInScreen()),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Text(
                'เปิดหน้า QR Check-in',
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D9488),
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.mutedText(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffScheduleStatusBadge extends StatelessWidget {
  final String status;

  const _StaffScheduleStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('กำลังดำเนินการ', const Color(0xFF0D9488)),
      'confirmed' => ('ยืนยันแล้ว', const Color(0xFF2563EB)),
      'completed' => ('จบแล้ว', const Color(0xFF6B7280)),
      'cancelled' => ('ยกเลิก', const Color(0xFFDC2626)),
      _ => ('รอยืนยัน', const Color(0xFFD97706)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _StaffInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StaffInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border(context).withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.anuphan(
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

String _staffDateRange(String departure, String returnDate) {
  final d = _parseDateShort(departure);
  final r = _parseDateShort(returnDate);
  if (d.isEmpty) return 'ไม่ระบุวันที่';
  if (r.isEmpty || r == d) return d;
  return '$d - $r';
}

String _parseDateShort(String raw) {
  if (raw.isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  const months = [
    '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];
  return '${date.day} ${months[date.month]} ${date.year + 543}';
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
