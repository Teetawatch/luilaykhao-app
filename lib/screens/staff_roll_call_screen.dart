import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'staff_check_in_screen.dart' show asMap, asList, textOf;

/// Fast head-count / roll-call before departure. Lists every confirmed booking
/// as a big tappable row; tapping toggles check-in (reversible) and updates the
/// live X/Y head-count. A sticky action notifies passengers the van has left.
class StaffRollCallScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const StaffRollCallScreen({
    super.key,
    required this.scheduleId,
    required this.title,
  });

  @override
  State<StaffRollCallScreen> createState() => _StaffRollCallScreenState();
}

class _StaffRollCallScreenState extends State<StaffRollCallScreen> {
  List<Map<String, dynamic>> _bookings = [];
  Map<String, dynamic> _summary = {};
  String? _error;
  bool _loading = true;
  bool _departing = false;
  final Set<String> _busyRefs = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _intOf(dynamic v) => int.tryParse(textOf(v, '0')) ?? 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().loadStaffManifest(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _bookings = asList(
          data['bookings'],
        ).map((e) => asMap(e)).toList();
        _summary = asMap(data['summary']);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> booking) async {
    final ref = textOf(booking['booking_ref']);
    if (ref.isEmpty || _busyRefs.contains(ref)) return;

    final next = booking['checked_in'] != true;
    HapticFeedback.selectionClick();
    setState(() {
      booking['checked_in'] = next; // optimistic
      _busyRefs.add(ref);
    });

    try {
      final result = await context.read<AppProvider>().setStaffCheckIn(
        widget.scheduleId,
        ref,
        next,
      );
      if (!mounted) return;
      setState(() {
        booking['checked_in'] = result['checked_in'] == true;
        _summary = asMap(result['summary']);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => booking['checked_in'] = !next); // revert
      _snack(e is ApiException ? e.message : 'อัปเดตไม่สำเร็จ', isError: true);
    } finally {
      if (mounted) setState(() => _busyRefs.remove(ref));
    }
  }

  Future<void> _depart() async {
    final app = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันออกเดินทาง', style: appFont(fontWeight: FontWeight.w900)),
        content: Text(
          'ระบบจะแจ้งเตือนผู้โดยสารทุกคนว่ารถออกเดินทางแล้ว และโพสต์ลงแชทกลุ่มทริป ต้องการดำเนินการต่อหรือไม่?',
          style: appFont(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('แจ้งออกเดินทาง'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _departing = true);
    HapticFeedback.mediumImpact();
    try {
      final result = await app.markScheduleDeparted(widget.scheduleId);
      if (!mounted) return;
      _snack(
        result['already_sent'] == true
            ? 'เคยแจ้งออกเดินทางไปแล้ววันนี้'
            : 'แจ้งออกเดินทางให้ผู้โดยสารแล้ว',
      );
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : 'แจ้งออกเดินทางไม่สำเร็จ', isError: true);
    } finally {
      if (mounted) setState(() => _departing = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: appFont(color: Colors.white)),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? 'นับหัวผู้โดยสาร' : widget.title),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _buildBody(),
      ),
      bottomNavigationBar: _bookings.isEmpty ? null : _departBar(),
    );
  }

  Widget _buildBody() {
    if (_loading && _bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _bookings.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _HeadcountHeader(
          checkedInPassengers: _summary['checked_in_passengers'] != null
              ? _intOf(_summary['checked_in_passengers'])
              : _intOf(_summary['checked_in']),
          totalPassengers: _intOf(_summary['passengers']),
        ),
        const SizedBox(height: 16),
        ..._bookings.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RollCallRow(
              booking: b,
              busy: _busyRefs.contains(textOf(b['booking_ref'])),
              onTap: () => _toggle(b),
            ),
          ),
        ),
      ],
    );
  }

  Widget _departBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed: _departing ? null : _depart,
          icon: _departing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.directions_bus_rounded),
          label: Text(
            _departing ? 'กำลังแจ้ง...' : 'ออกเดินทาง • แจ้งผู้โดยสาร',
            style: appFont(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _HeadcountHeader extends StatelessWidget {
  final int checkedInPassengers;
  final int totalPassengers;

  const _HeadcountHeader({
    required this.checkedInPassengers,
    required this.totalPassengers,
  });

  @override
  Widget build(BuildContext context) {
    final complete = totalPassengers > 0 && checkedInPassengers >= totalPassengers;
    final progress = totalPassengers == 0 ? 0.0 : checkedInPassengers / totalPassengers;
    final color = complete ? AppTheme.primaryColor : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$checkedInPassengers',
                style: appFont(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 2),
                child: Text(
                  '/ $totalPassengers คน',
                  style: appFont(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
              const Spacer(),
              if (complete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 15, color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'ครบแล้ว',
                        style: appFont(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'แตะที่รายชื่อเพื่อเช็คอิน / ยกเลิก',
            style: appFont(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.border(context).withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RollCallRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool busy;
  final VoidCallback onTap;

  const _RollCallRow({
    required this.booking,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final checkedIn = booking['checked_in'] == true;
    final contact = textOf(booking['contact_name'], '-');
    final groupName = textOf(booking['group_name']);
    final pickup = textOf(
      booking['pickup_location'],
      textOf(booking['pickup_region_label'], textOf(booking['pickup_region'])),
    );
    final count = int.tryParse(textOf(booking['passenger_count'], '1')) ?? 1;
    final color = checkedIn ? AppTheme.primaryColor : AppTheme.warningColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration(
            context,
            radius: 18,
            color: checkedIn
                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                : null,
            borderColor: checkedIn
                ? AppTheme.primaryColor.withValues(alpha: 0.35)
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        checkedIn
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: color,
                        size: 30,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName.isNotEmpty ? groupName : contact,
                      style: appFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    if (pickup.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 13, color: AppTheme.mutedText(context)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              pickup,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.mutedText(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.subtleSurface(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_rounded,
                        size: 13, color: AppTheme.mutedText(context)),
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: appFont(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
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
