import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/trek_recorder_service.dart';
import '../theme/app_theme.dart';

/// "บันทึกการเดินของฉัน" — lets the customer record their own GPS trace during
/// the walk, so their Passport ends up holding the distance they actually
/// covered instead of the route's published estimate.
///
/// Opt-in and stoppable at any point: continuous GPS is the single biggest
/// battery cost in the app, so it never starts on its own.
class TrekRecorderCard extends StatefulWidget {
  final String bookingRef;

  const TrekRecorderCard({super.key, required this.bookingRef});

  @override
  State<TrekRecorderCard> createState() => _TrekRecorderCardState();
}

class _TrekRecorderCardState extends State<TrekRecorderCard> {
  final _recorder = TrekRecorderService.instance;

  Map<String, dynamic>? _saved;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _recorder.addListener(_onRecorderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _recorder.removeListener(_onRecorderChanged);
    super.dispose();
  }

  void _onRecorderChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    // An already-saved walk wins: there is nothing to record twice.
    try {
      final saved = await context.read<AppProvider>().fetchMyTrack(
        widget.bookingRef,
      );
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      // Offline on the mountain is the normal case — fall through to local.
    }

    if (_saved == null) await _recorder.restore(widget.bookingRef);
    if (mounted) setState(() => _checked = true);
  }

  Future<void> _start() async {
    HapticFeedback.selectionClick();
    final started = await _recorder.start(widget.bookingRef);
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ต้องเปิดสิทธิ์ตำแหน่งก่อนจึงจะบันทึกเส้นทางได้'),
        ),
      );
    }
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await _recorder.save(
      (payload) => provider.uploadMyTrack(widget.bookingRef, payload),
    );

    if (!mounted) return;

    if (ok) {
      final saved = await provider
          .fetchMyTrack(widget.bookingRef)
          .catchError((_) => null);
      if (mounted) setState(() => _saved = saved);
      messenger.showSnackBar(
        const SnackBar(content: Text('บันทึกเส้นทางของคุณแล้ว')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('บันทึกไม่สำเร็จ เส้นทางยังอยู่ในเครื่อง ลองอีกครั้งได้'),
        ),
      );
    }
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบเส้นทางที่บันทึกไว้?'),
        content: const Text('ข้อมูลที่บันทึกในเครื่องจะหายไปและกู้คืนไม่ได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _recorder.discard();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();

    final saved = _saved;
    if (saved != null) return _SavedSummary(track: saved);

    final isThisBooking = _recorder.bookingRef == widget.bookingRef;
    final recording = _recorder.isRecording && isThisBooking;
    final hasPoints = isThisBooking && _recorder.points.length >= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                recording
                    ? Icons.fiber_manual_record_rounded
                    : Icons.timeline_rounded,
                size: 18,
                color: recording
                    ? AppTheme.errorColor
                    : AppTheme.mutedText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recording ? 'กำลังบันทึกการเดิน' : 'บันทึกการเดินของฉัน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasPoints
                ? 'ระยะทางและความสูงนี้วัดจาก GPS ของคุณเอง'
                : 'เปิดไว้ระหว่างเดิน แล้วสถิติในสมุดสะสมจะเป็นระยะที่คุณเดินจริง '
                      '(ใช้แบตเพิ่มขึ้น เปิด–ปิดได้ตลอด)',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          if (hasPoints) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LiveStat(
                    label: 'ระยะทาง',
                    value: _recorder.distanceKm.toStringAsFixed(2),
                    unit: 'กม.',
                  ),
                ),
                Expanded(
                  child: _LiveStat(
                    label: 'ไต่ขึ้น',
                    value: '${_recorder.elevationGainM}',
                    unit: 'ม.',
                  ),
                ),
                Expanded(
                  child: _LiveStat(
                    label: 'เวลาเดิน',
                    value: _formatDuration(_recorder.movingTime),
                    unit: '',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _recorder.saving
                      ? null
                      : recording
                      ? _recorder.pause
                      : _start,
                  icon: Icon(
                    recording ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 18,
                  ),
                  label: Text(recording ? 'หยุดชั่วคราว' : 'เริ่มบันทึก'),
                  style: FilledButton.styleFrom(
                    backgroundColor: recording
                        ? AppTheme.mutedText(context)
                        : AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (hasPoints) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _recorder.saving ? null : _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_recorder.saving ? 'กำลังบันทึก…' : 'บันทึก'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (hasPoints)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _recorder.saving ? null : _confirmDiscard,
                child: Text(
                  'ลบเส้นทางนี้',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours > 0 ? '$hours ชม. $minutes น.' : '$minutes นาที';
  }
}

class _LiveStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _LiveStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 3),
        Text.rich(
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
            children: [
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// What the server made of the walk once it was saved, including where it sat
/// among everyone else on the same round.
class _SavedSummary extends StatelessWidget {
  final Map<String, dynamic> track;

  const _SavedSummary({required this.track});

  @override
  Widget build(BuildContext context) {
    final distance = double.tryParse('${track['distance_km'] ?? 0}') ?? 0;
    final gain = int.tryParse('${track['elevation_gain_m'] ?? 0}') ?? 0;
    final pace = double.tryParse('${track['average_pace_kmh'] ?? ''}');
    final rank = int.tryParse('${track['rank_by_distance'] ?? ''}');
    final peers = int.tryParse('${track['peers_count'] ?? 0}') ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'การเดินของคุณในรอบนี้',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LiveStat(
                  label: 'ระยะทาง',
                  value: distance.toStringAsFixed(2),
                  unit: 'กม.',
                ),
              ),
              Expanded(
                child: _LiveStat(
                  label: 'ไต่ขึ้น',
                  value: '$gain',
                  unit: 'ม.',
                ),
              ),
              if (pace != null)
                Expanded(
                  child: _LiveStat(
                    label: 'ความเร็วเฉลี่ย',
                    value: pace.toStringAsFixed(1),
                    unit: 'กม./ชม.',
                  ),
                ),
            ],
          ),
          // Only meaningful once someone else has recorded too.
          if (rank != null && peers > 1) ...[
            const SizedBox(height: 12),
            Text(
              'เดินได้ไกลเป็นอันดับ $rank จาก $peers คนที่บันทึกในรอบนี้',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
