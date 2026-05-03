import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../screens/booking_flow_screen.dart';
import '../theme/app_theme.dart';
import 'travel_widgets.dart';

class ActiveSeatLockOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const ActiveSeatLockOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<ActiveSeatLockOverlay> createState() => _ActiveSeatLockOverlayState();
}

class _ActiveSeatLockOverlayState extends State<ActiveSeatLockOverlay> {
  Timer? _ticker;
  int? _busyScheduleId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final locks = app.activeSeatLocks.map(asMap).where(_isActiveLock).toList();

    return Stack(
      children: [
        widget.child,
        if (app.isLoggedIn && locks.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: SafeArea(
              bottom: false,
              child: ActiveSeatLockBanner(
                lock: locks.first,
                extraCount: locks.length - 1,
                busy: _busyScheduleId == _scheduleId(locks.first),
                onContinue: () => _continueBooking(locks.first),
                onCancel: () => _cancelLock(locks.first),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _continueBooking(Map<String, dynamic> lock) async {
    final app = context.read<AppProvider>();
    final trip = asMap(lock['trip']);
    final slug = textOf(trip['slug']);
    final scheduleId = _scheduleId(lock);
    if (slug.isEmpty || scheduleId == null) return;

    setState(() => _busyScheduleId = scheduleId);
    try {
      final results = await Future.wait([app.trip(slug), app.schedules(slug)]);
      if (!mounted) return;

      final seatIds = asList(lock['seat_ids'])
          .map((item) => item?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final pickupPointId = int.tryParse(textOf(lock['pickup_point_id']));

      widget.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: Map<String, dynamic>.from(results[0] as Map),
            schedules: List<dynamic>.from(results[1] as List),
            initialScheduleId: scheduleId,
            initialPickupPointId: pickupPointId,
            initialSeatIds: seatIds,
            resumeLockedSeats: true,
          ),
        ),
      );
    } catch (e) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyScheduleId = null);
    }
  }

  Future<void> _cancelLock(Map<String, dynamic> lock) async {
    final app = context.read<AppProvider>();
    final trip = asMap(lock['trip']);
    final slug = textOf(trip['slug']);
    final scheduleId = _scheduleId(lock);
    if (slug.isEmpty || scheduleId == null) return;

    final seatIds = asList(lock['seat_ids'])
        .map((item) => item?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final pickupPointId = int.tryParse(textOf(lock['pickup_point_id']));

    setState(() => _busyScheduleId = scheduleId);
    try {
      final results = await Future.wait([app.trip(slug), app.schedules(slug)]);
      await app.cancelActiveSeatLock(scheduleId, seatIds: seatIds);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('ยกเลิกการจองแล้ว เลือกที่นั่งใหม่ได้เลย'),
        ),
      );
      widget.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => BookingFlowScreen(
            trip: Map<String, dynamic>.from(results[0] as Map),
            schedules: List<dynamic>.from(results[1] as List),
            initialScheduleId: scheduleId,
            initialPickupPointId: pickupPointId,
            startAtSeatSelection: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyScheduleId = null);
    }
  }
}

class ActiveSeatLockBanner extends StatelessWidget {
  final Map<String, dynamic> lock;
  final int extraCount;
  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const ActiveSeatLockBanner({
    required this.lock,
    required this.extraCount,
    required this.busy,
    required this.onContinue,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final title = textOf(
      lock['trip_title'],
      textOf(asMap(lock['trip'])['title']),
    );
    final seats = asList(lock['seat_ids'])
        .map((item) => item?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .join(', ');
    final remainingSeconds = _remainingSeconds(lock);
    final isUrgent = remainingSeconds <= 120;
    final accent = isUrgent ? AppTheme.errorColor : const Color(0xFF0F8F75);
    final remainingText = _remainingText(remainingSeconds);

    return Material(
      elevation: 14,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTheme.isDark(context) ? 0.28 : 0.12,
              ),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.timer_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.onSurface(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'เหลือ $remainingText · ที่นั่ง $seats${extraCount > 0 ? ' · อีก $extraCount รายการ' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: isUrgent
                          ? AppTheme.errorColor
                          : AppTheme.mutedText(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : onContinue,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('ต่อ'),
                ),
                TextButton(
                  onPressed: busy ? null : onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.22),
                      ),
                    ),
                    textStyle: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
                  ),
                  child: const Text('ยกเลิกการจอง'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool _isActiveLock(Map<String, dynamic> lock) {
  return _remainingSeconds(lock) > 0;
}

int? _scheduleId(Map<String, dynamic> lock) {
  return int.tryParse(textOf(lock['schedule_id']));
}

int _remainingSeconds(Map<String, dynamic> lock) {
  final lockedUntil = DateTime.tryParse(textOf(lock['locked_until']));
  if (lockedUntil != null) {
    return lockedUntil.difference(DateTime.now()).inSeconds.clamp(0, 600);
  }
  return (int.tryParse(textOf(lock['locked_ttl_seconds'])) ?? 0).clamp(0, 600);
}

String _remainingText(int seconds) {
  if (seconds <= 0) return 'หมดเวลาแล้ว';
  final minutes = seconds ~/ 60;
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainder นาที';
}
